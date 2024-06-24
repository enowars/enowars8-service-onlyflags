use anyhow::Context;
use sqlx::MySqlPool;
use tokio::io::{AsyncBufReadExt, AsyncWrite, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};

use crate::replacer::FlagReplacer;

mod replacer {
    use base64::engine::general_purpose::STANDARD;
    use base64::Engine;
    use itertools::Itertools;
    use num_bigint::{BigUint, RandBigInt};
    use std::sync::OnceLock;
    pub struct FlagReplacer {
        id: u32,

        a: Vec<BigUint>,
    }

    impl FlagReplacer {
        fn get_regex() -> &'static regex::Regex {
            static FLAG_REGEX: OnceLock<regex::Regex> = OnceLock::new();
            FLAG_REGEX.get_or_init(|| {
                regex::Regex::new(r#"ENO(?P<data>[A-Za-z0-9+/]{48})"#).expect("compiled regex")
            })
        }

        fn get_p() -> &'static num_bigint::BigUint {
            static P: OnceLock<num_bigint::BigUint> = OnceLock::new();
            P.get_or_init(|| {
                num_bigint::BigUint::parse_bytes(
                    b"100000000000000000000000000000000000000000000000000000000000000000000007f",
                    16,
                )
                .expect("P parsed")
            })
        }

        pub fn new(id: u32) -> Self {
            let mut rng = rand::thread_rng();
            Self {
                id,

                a: vec![rng.gen_biguint(288), rng.gen_biguint(288)],
            }
        }

        pub fn from_data(id: u32, data: String) -> Option<Self> {
            data.split(",")
                .map(|s| BigUint::parse_bytes(s.as_bytes(), 10))
                .collect::<Option<Vec<_>>>()
                .map(|a| Self { id, a })
        }

        pub fn is_match(haystack: &str) -> bool {
            Self::get_regex().is_match(haystack)
        }

        pub fn replace_all(self, haystack: &str) -> String {
            Self::get_regex().replace_all(haystack, self).into_owned()
        }

        /// get the censor parameters
        /// NOTE: Client should expect more than 2 parameters
        pub fn get_data(&self) -> String {
            self.a.iter().join(",")
        }
    }
    impl regex::Replacer for FlagReplacer {
        fn replace_append(&mut self, caps: &regex::Captures<'_>, dst: &mut String) {
            let data = &caps["data"];
            let data = STANDARD.decode(data).expect("data is base64 string");
            let n = BigUint::from_bytes_be(&data);

            let p = Self::get_p();
            let mut r = BigUint::ZERO;
            for c in self.a.iter().chain([&n]) {
                r = (c + r * self.id) % p;
            }
            r %= p;

            dst.push_str("ONE{");
            dst.push_str(&STANDARD.encode(r.to_bytes_be()));
            dst.push_str("}")
        }
    }
}

async fn write_help<W: AsyncWrite + std::marker::Unpin>(
    mut w: W,
    open_forum: bool,
) -> anyhow::Result<()> {
    w.write_all(b"List of commands:\nHELP - Show this help")
        .await?;
    if open_forum {
        w.write_all(b"\nLOGIN <username> - sign into your account")
            .await?;
    }
    w.write_all(b"\nLIST - List all active thread\nJOIN <thread> - show a thread\nSHOW - show a thread\nPOST - post to current thread\n").await?;
    if open_forum {
        w.write_all(b"STALK <username> - see what a specific user has posted\n")
            .await?;
    }
    Ok(())
}

struct Post {
    id: i32,
    username: String,
    content: String,
}

async fn dump_posts<W: AsyncWrite + std::marker::Unpin>(
    mut wr: W,
    posts: Vec<Post>,
) -> anyhow::Result<()> {
    if posts.len() > 0 {
        for i in posts {
            wr.write_all(format!("{}", i.id).as_bytes()).await?;
            wr.write_all(b"(").await?;
            wr.write_all(i.username.as_bytes()).await?;
            wr.write_all(b"):").await?;
            wr.write_all(i.content.as_bytes()).await?;
            wr.write_all(b"\n").await?;
        }
    } else {
        wr.write_all(b"No posts were found.\n").await?;
    }
    Ok(())
}

async fn handle_client(
    mut socket: TcpStream,
    pool: MySqlPool,
    open_forum: bool,
) -> anyhow::Result<()> {
    let (rd, mut wr) = socket.split();
    let b = BufReader::new(rd);
    let mut thread: Option<String> = None;
    let mut loggin_in: Option<String> = None;
    let mut user: Option<String> = None;
    wr.write_all(b"Welcome to the premium forum. All posts are anonymous.\n")
        .await?;
    write_help(&mut wr, open_forum).await?;
    wr.write_all(b"\n>").await?;
    let mut lines = b.lines();
    'loopa: while let Some(line) = lines.next_line().await? {
        match (open_forum, loggin_in.clone()) {
            (true, Some(username)) => {
                let password = line.trim();
                let res = sqlx::query!("SELECT password FROM user WHERE username = ?", username)
                    .fetch_one(&pool)
                    .await?;
                if password == res.password {
                    user = Some(username);
                    wr.write_all(b"Successfully logged in.\n").await?;
                } else {
                    wr.write_all(b"Username or password is wrong.\n").await?;
                }
                loggin_in = None;
            }
            (false, _) | (true, None) => match line {
                help if help.trim().to_lowercase() == "help" => {
                    write_help(&mut wr, open_forum).await?;
                }
                login if login.trim().to_lowercase().starts_with("login") && open_forum => {
                    let login = login["login".len()..].trim();
                    if login.is_empty() {
                        wr.write_all(b"please specify a username.\n").await?;
                    } else {
                        wr.write_all(b"\nEnter the password: ").await?;
                        wr.flush().await?;
                        loggin_in = Some(login.to_string());
                        continue 'loopa;
                    }
                }
                list if list.trim().to_lowercase() == "list" => {
                    let res = sqlx::query!("SELECT DISTINCT thread FROM post")
                        .fetch_all(&pool)
                        .await?;
                    let mut it = res.iter();
                    if let Some(row) = it.next() {
                        wr.write_all(b"threads: ").await?;
                        wr.write_all(row.thread.as_bytes()).await?;
                        for row in it {
                            wr.write_all(b",").await?;
                            wr.write_all(row.thread.as_bytes()).await?;
                        }
                        wr.write_all(b"\n").await?;
                    } else {
                        wr.write_all(b"no threads found\n").await?;
                    }
                }
                join if join.trim().to_lowercase().starts_with("join") => {
                    let join = join["join".len()..].trim();
                    if join.is_empty() {
                        wr.write_all(b"Please specify a thread.\n").await?;
                    } else {
                        thread = Some(join.to_owned());

                        wr.write_all(b"changed thread to ").await?;
                        wr.write_all(join.as_bytes()).await?;
                        wr.write_all(b"\n").await?;
                    }
                }
                show if show.trim().to_lowercase() == "show" => match &thread {
                    Some(thread) => {
                        let res = sqlx::query_as!(
                            Post,
                            "SELECT id, username, content FROM post WHERE thread = ?",
                            thread
                        )
                        .fetch_all(&pool)
                        .await?;
                        dump_posts(&mut wr, res).await?;
                    }
                    None => {
                        wr.write_all(b"No thread selected.\n").await?;
                    }
                },
                stalk if stalk.trim().to_lowercase().starts_with("stalk") && open_forum => {
                    let stalk = stalk["stalk".len()..].trim();
                    if stalk.is_empty() {
                        wr.write_all(b"Please specify a thread.\n").await?;
                    } else {
                        let username = Some(stalk.to_owned());

                        let res = sqlx::query_as!(
                            Post,
                            "SELECT id, username, content FROM post WHERE username = ?",
                            username
                        )
                        .fetch_all(&pool)
                        .await?;

                        dump_posts(&mut wr, res).await?;
                    }
                }
                post if post.to_lowercase().starts_with("post") => {
                    let post = post["post".len()..].trim();
                    if post.is_empty() {
                        wr.write_all(b"No post content given.\n").await?;
                    } else {
                        match (
                            &thread,
                            match (open_forum, &user) {
                                (false, _) => Some("anon"),
                                (true, Some(u)) => Some(u.as_str()),
                                (true, None) => None,
                            },
                        ) {
                            (Some(thread), Some(username)) => {
                                let (content, censor_data): (String, Option<(u32, String, _)>) =
                                    match open_forum {
                                        true if FlagReplacer::is_match(post) => {
                                            let mut transaction = pool.begin().await?;
                                            sqlx::query!(r"INSERT INTO post(username, thread, content) VALUES ('','','')")
                                                .execute(&mut *transaction).await?;
                                            let id = match sqlx::query!(
                                                r#"SELECT LAST_INSERT_ID() as "id!: u32""#
                                            )
                                            .fetch_one(&mut *transaction)
                                            .await
                                            {
                                                Ok(r) => r.id,
                                                Err(e) => {
                                                    transaction
                                                        .rollback()
                                                        .await
                                                        .context("Failed to roll back")?;
                                                    return Err(e.into());
                                                }
                                            };
                                            let res = match sqlx::query!(
                                                r#"SELECT censor_data from user WHERE username = ?"#,
                                                username
                                            ).fetch_one(&mut * transaction).await {
                                                Ok(r) => r.censor_data,
                                                Err(e) => {
                                                    transaction
                                                        .rollback()
                                                        .await
                                                        .context("Failed to roll back")?;
                                                    return Err(e.into());
                                                }
                                            };
                                            let flag_replacer = res
                                                .map(|censor_data| {
                                                    FlagReplacer::from_data(id, censor_data)
                                                })
                                                .flatten();
                                            let (flag_replacer, data) = if let Some(fr) =
                                                flag_replacer
                                            {
                                                let data = fr.get_data();
                                                (fr, data)
                                            } else {
                                                let fr = FlagReplacer::new(id);
                                                let data = fr.get_data();
                                                match sqlx::query!("UPDATE user SET censor_data = ? WHERE username = ?", data, username).execute(&mut *transaction).await {
                                                    Ok(_) => {},
                                                    Err(e) => {
                                                        transaction.rollback().await?;
                                                        return Err(e.into());
                                                    }
                                                }
                                                (fr, data)
                                            };
                                            (
                                                flag_replacer.replace_all(post),
                                                Some((id, data, transaction)),
                                            )
                                        }
                                        _ => (post.to_owned(), None),
                                    };
                                if let Some(data) = censor_data {
                                    let (id, censor_data, mut transaction) = data;
                                    sqlx::query!(
                                        "UPDATE post SET username = ?, thread = ?, content = ? WHERE id = ?",
                                        username,
                                        thread,
                                        content,
                                        id
                                    )
                                    .execute(&mut *transaction)
                                    .await?;
                                    transaction
                                        .commit()
                                        .await
                                        .context("Failed to commit tos violation")?;
                                    wr.write_all(b"TOS Violation detected:\nYou are not allowed to share flags on the open forum.\n\ncensor_data:").await?;
                                    wr.write_all(&censor_data.into_bytes()).await?;
                                    wr.write_all(b"\n").await?;
                                } else {
                                    sqlx::query!(
                                        "INSERT INTO post(username, thread, content) VALUES(?,?,?)",
                                        username,
                                        thread,
                                        content,
                                    )
                                    .execute(&pool)
                                    .await?;
                                    wr.write_all(b"Posted.\n").await?;
                                }
                            }
                            (_, None) => {
                                wr.write_all(b"Please log in.\n").await?;
                            }
                            (None, _) => {
                                wr.write_all(b"No thread was selected.\n").await?;
                            }
                        }
                    }
                }
                _ => {
                    wr.write_all(b"Command unknown.\n").await?;
                }
            },
        }
        wr.write_all(b"\n>").await?;
        wr.flush().await?;
    }
    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let pool =
        sqlx::MySqlPool::connect(&std::env::var("DATABASE_URL").context("DATABASE_URL missing")?)
            .await?;
    let open_forum = std::env::var("OPEN_FORUM").unwrap_or("false".into()) == "true";
    let listener = TcpListener::bind("0.0.0.0:1337").await?;

    loop {
        let (socket, _) = listener.accept().await?;
        let pool = pool.clone();

        tokio::spawn(async move {
            match handle_client(socket, pool, open_forum).await {
                Ok(()) => {}
                Err(e) => {
                    println!("{e:?}");
                }
            }
        });
    }
}
