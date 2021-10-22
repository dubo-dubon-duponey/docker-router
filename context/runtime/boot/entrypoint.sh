#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"
# shellcheck source=/dev/null
source "$root/mdns.sh"

helpers::dir::writable "/certs"
helpers::dir::writable "$XDG_DATA_HOME" create
helpers::dir::writable "$XDG_DATA_DIRS" create
helpers::dir::writable "$XDG_RUNTIME_DIR" create
helpers::dir::writable "$XDG_STATE_HOME" create
helpers::dir::writable "$XDG_CACHE_HOME" create

# mDNS blast if asked to
[ ! "${MDNS_HOST:-}" ] || {
  _mdns_port="$([ "$TLS" != "" ] && printf "%s" "${PORT_HTTPS:-443}" || printf "%s" "${PORT_HTTP:-80}")"
  [ ! "${MDNS_STATION:-}" ] || mdns::add "_workstation._tcp" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  mdns::add "${MDNS_TYPE:-_http._tcp}" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  mdns::start &
}

# Start caddy (not a sidecar)
start::sidecar
