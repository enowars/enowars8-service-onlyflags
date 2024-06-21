#!/usr/bin/env bash

set -eux

ROOT="$(dirname "$(dirname "$0")")"

rsync -a --exclude=data "$ROOT/checker" checker:/services/checker_onlyflags
rsync -a --exclude=data "$ROOT/service" onlyflags:/services/onlyflags

ssh checker /usr/bin/env bash -c '"cd /services/checker_onlyflags && docker compose down && docker compose up -d"'
ssh onlyflags /usr/bin/env bash -c '"cd /services/onlyflags && docker compose down && docker compose up -d"'
