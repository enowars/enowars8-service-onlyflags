#!/usr/bin/env bash

set -eux

ROOT="$(dirname "$(dirname "$0")")"

rsync -a --exclude=data "$ROOT/checker" checker:/services/checker_onlyflags &
rsync -a --exclude=data "$ROOT/service" onlyflags:/services/onlyflags &
wait

ssh checker /usr/bin/env bash -c '"cd /services/checker_onlyflags/checker && docker compose build"' &
ssh onlyflags /usr/bin/env bash -c '"cd /services/onlyflags/service && docker compose build"' &
wait

ssh checker /usr/bin/env bash -c '"cd /services/checker_onlyflags/checker && docker compose down && docker compose up -d"' &
ssh onlyflags /usr/bin/env bash -c '"cd /services/onlyflags/service && docker compose down && docker compose up -d"' &
wait
