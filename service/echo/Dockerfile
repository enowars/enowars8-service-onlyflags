FROM rust:1-slim-buster as builder
WORKDIR /usr/src/echo
COPY . .
RUN cargo install --path .

FROM debian:buster-slim
COPY --from=builder /usr/local/cargo/bin/echo /usr/local/bin/echo

EXPOSE 1337
STOPSIGNAL 9

CMD ["echo"]

