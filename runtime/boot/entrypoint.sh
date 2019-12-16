#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Ensure the certs folder is writable
[ -w "/certs" ] || {
  >&2 printf "/certs is not writable. Check your mount permissions.\n"
  exit 1
}

# Specifics to this image
HTTPS_PORT="${HTTPS_PORT:-}"
STAGING="${STAGING:-}"

args=(caddy -conf /config/caddy.conf -agree -disable-http-challenge -https-port "$HTTPS_PORT" -http-port 1080)

[ ! "$STAGING" ] || args+=(-ca https://acme-staging-v02.api.letsencrypt.org/directory)

exec "${args[@]}" "$@"
