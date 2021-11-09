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
[ "${MDNS_ENABLED:-}" != true ] || {
  if [ -e "/config/goello/main.json" ]; then
    while read line -r; do
      _mdns_records+=("$line")
    done < <(jq -rc .[] /config/goello/main.json)
  else
    _mdns_port="$([ "$TLS" != "" ] && printf "%s" "${ADVANCED_PORT_HTTPS:-443}" || printf "%s" "${ADVANCED_PORT_HTTP:-80}")"
    [ ! "${MDNS_STATION:-}" ] || mdns::records::add "_workstation._tcp" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
    mdns::records::add "${MDNS_TYPE:-_http._tcp}" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  fi
  mdns::records::broadcast &
}

sidecar::tls::start(){
  local flags=(--cacert /certs/pki/authorities/local/root.crt \
    --cert /certs/certificates/local/"${DOMAIN:-}/${DOMAIN:-}".crt \
    --key /certs/certificates/local/"${DOMAIN:-}/${DOMAIN:-}".key \
    --timed-reload 300s \
  )
  local port="$1"
  local target="$2"

  # --disable-authentication
  ghostunnel "${flags[@]}" server --listen "0.0.0.0:$port" --target "$target" --allow-all
}

# XXX change this mess
if [ "$GHOST_TARGET" ]; then
  [ "${PROXY_HTTPS_ENABLED:-}" != true ] || start::sidecar &
  sidecar::tls::start "$GHOST_PORT" "$GHOST_TARGET"
else
  [ "${PROXY_HTTPS_ENABLED:-}" != true ] || start::sidecar &
fi
