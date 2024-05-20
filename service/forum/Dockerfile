FROM rust:1-slim-buster as builder
WORKDIR /usr/src/forum
COPY . .
RUN SQLX_OFFLINE=true cargo install --path .

FROM debian:buster-slim
COPY --from=builder /usr/local/cargo/bin/forum /usr/local/bin/forum

EXPOSE 1337
STOPSIGNAL 9

CMD ["forum"]

