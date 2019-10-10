#!/usr/bin/env bash

# Generic config management
config::writable(){
  local folder="$1"
  [ -w "$folder" ] || {
    >&2 printf "%s is not writable. Check your mount permissions.\n" "$folder"
    exit 1
  }
}

# Ensure the certs and data folders are writable
config::writable /certs
config::writable /data

# Specifics to this image
HTTPS_PORT="${HTTPS_PORT:-}"
STAGING="${STAGING:-}"

args=(caddy -conf /config/caddy.conf -agree -disable-http-challenge -https-port "$HTTPS_PORT" -http-port 1080)

[ ! "$STAGING" ] || args+=(-ca https://acme-staging-v02.api.letsencrypt.org/directory)

exec "${args[@]}" "$@"
