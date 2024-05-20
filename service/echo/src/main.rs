use tokio::io::{self, AsyncWriteExt};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("0.0.0.0:1337").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;

        tokio::spawn(async move {
            let (mut rd, mut wr) = socket.split();

            if wr
                .write_all(
                    b"you have successfully connected to the Onlyflag network.\nHave fun <3\n",
                )
                .await
                .is_err()
                || io::copy(&mut rd, &mut wr).await.is_err()
            {
                eprintln!("failed to copy");
            }
        });
    }
}
