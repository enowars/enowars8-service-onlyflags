use anyhow::Context;
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use lazy_static::lazy_static;
use sqlx::MySqlPool;
use tokio::io::{AsyncBufReadExt, AsyncWrite, AsyncWriteExt, BufReader, WriteHalf};
use tokio::net::{TcpListener, TcpStream};

lazy_static! {
    static ref FLAG_REGEX: regex::Regex =
        regex::Regex::new(r#"ENO(?P<data>[A-Za-y0-9+/]{48})"#).expect("compiled regex");
}

struct FlagReplacer;

impl regex::Replacer for FlagReplacer {
    fn replace_append(&mut self, caps: &regex::Captures<'_>, dst: &mut String) {
        dst.push_str("ONE");
        let data = &caps["data"];
        let data = STANDARD.decode(data).unwrap();

        dst.push_str(&STANDARD.encode(data));
    }
}

async fn write_help<W: AsyncWrite + std::marker::Unpin>(mut w: W) -> anyhow::Result<()> {
    w.write_all(b"List of commands:\nHELP - Show this help\nLIST - List all active thread\nJOIN <thread> - show a thread\nSHOW - show a thread\nPOST - post to current thread\n").await?;
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
    write_help(&mut wr).await?;
    wr.write_all(b"\n>").await?;
    let mut lines = b.lines();
    while let Some(line) = lines.next_line().await? {
        match (open_forum, loggin_in.clone()) {
            (true, Some(username)) => {
                let password = line.trim();
                // TODO: make sqlx query
                match password == "lol" {
                    true => {
                        user = Some(username);
                        loggin_in = None;
                    }
                    false => {
                        loggin_in = Some(username);
                    }
                }
            }
            (false, _) | (true, None) => {
                match line {
                    help if help.trim().to_lowercase() == "help" => {
                        write_help(&mut wr).await?;
                    }
                    login if login.trim().to_lowercase().starts_with("login") => {
                        let login = login["login".len()..].trim();
                        if login.is_empty() {
                            wr.write_all(b"please specify a username.").await?;
                        } else {
                            wr.write_all(b"Enter the password:").await?;
                            loggin_in = Some(login.to_string());
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
                            let res =
                                sqlx::query!("SELECT content FROM post WHERE thread = ?", thread)
                                    .fetch_all(&pool)
                                    .await?;
                            if res.len() > 0 {
                                for i in res {
                                    wr.write_all(b"anon:").await?;
                                    wr.write_all(i.content.as_bytes()).await?;
                                    wr.write_all(b"\n").await?;
                                }
                            } else {
                                wr.write_all(b"No posts were found.\n").await?;
                            }
                        }
                        None => {
                            wr.write_all(b"No thread selected.\n").await?;
                        }
                    },
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
                                    let (content, censor): (String, Option<Vec<u8>>) =
                                        match open_forum {
                                            true if FLAG_REGEX.is_match(post) => {
                                                // TODO: generate
                                                let flag_replacer = FlagReplacer;
                                                (
                                                    FLAG_REGEX
                                                        .replace_all(post, flag_replacer)
                                                        .into_owned(),
                                                    Some(vec![]),
                                                )
                                            }
                                            _ => (post.to_owned(), None),
                                        };
                                    sqlx::query!(
                                        "INSERT INTO post(username, thread, content, censor_data) VALUES(?,?,?,?)",
                                        username,
                                        thread,
                                        content,
                                        censor
                                    )
                                    .execute(&pool)
                                    .await?;
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
                }
                wr.write_all(b"\n>").await?;
            }
        }
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

        tokio::spawn(async move { handle_client(socket, pool, open_forum).await });
    }
}
