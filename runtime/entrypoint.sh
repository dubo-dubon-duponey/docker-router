#!/usr/bin/env bash

# Generic config management
OVERWRITE_CONFIG=${OVERWRITE_CONFIG:-}
OVERWRITE_DATA=${OVERWRITE_DATA:-}
OVERWRITE_CERTS=${OVERWRITE_CERTS:-}

config::writable(){
  local folder="$1"
  [ -w "$folder" ] || {
    >&2 printf "$folder is not writable. Check your mount permissions.\n"
    exit 1
  }
}

config::setup(){
  local folder="$1"
  local overwrite="$2"
  local f
  local localfolder
  localfolder="$(basename "$folder")"

  # Clean-up if we are to overwrite
  [ ! "$overwrite" ] || rm -Rf "${folder:?}"/*

  # If we have a local source
  if [ -e "$localfolder" ]; then
    # Copy any file in there over the destination if it doesn't exist
    for f in "$localfolder"/*; do
      if [ ! -e "/$f" ]; then
        >&2 printf "(Over-)writing file /$f.\n"
        cp -R "$f" "/$f" 2>/dev/null || {
          >&2 printf "Failed to create file. Permissions issue likely.\n"
          exit 1
        }
      fi
    done
  fi
}

config:writable /certs
config:writable /data
config::setup   /config  "$OVERWRITE_CONFIG"
config::setup   /data    "$OVERWRITE_DATA"
config::setup   /certs   "$OVERWRITE_CERTS"

# ACME
HTTPS_PORT="${HTTPS_PORT:-}"
STAGING="${STAGING:-}"

# Try to get the default index in
[ -e /data/index.html ] || cp data/* /data/ || {
  >&2 printf "Failed to create default data file. Permissions issue likely.\n"
}

args=(caddy -conf /config/caddy.conf -agree -disable-http-challenge -https-port "$HTTPS_PORT" -http-port 1080)

[ ! "$STAGING" ] || args+=(-ca https://acme-staging-v02.api.letsencrypt.org/directory)

exec "${args[@]}" "$@"
