#!/usr/bin/env bash

# Only certs technically needs to be writable
[ -w /certs ] || {
  >&2 printf "/certs is not writable.\n"
  exit 1
}

# If no config, try to have the default one, and fail if this fails
[ -e /config/config.conf ] || cp config/* /config/ || {
  >&2 printf "Failed to create default config file. Permissions issue likely.\n"
  exit 1
}

# Try to get the default index in
[ -e /data/index.html ] || cp data/* /data/ || {
  >&2 printf "Failed to create default data file. Permissions issue likely.\n"
}

args=(caddy -conf /config/config.conf -agree -disable-http-challenge -https-port "$PORT" -http-port "1080")

[ ! "$STAGING" ] || args+=(-ca https://acme-staging-v02.api.letsencrypt.org/directory)

exec "${args[@]}"
