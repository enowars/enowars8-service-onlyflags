#!/bin/bash
bin="/app/bin/proxy"

DEVICE="$(ip -o link | grep "asd[0-9]" | sed -E 's/^.*(asd[0-9]).*$/\1/')"
export DEVICE

exec "$bin" "start"
