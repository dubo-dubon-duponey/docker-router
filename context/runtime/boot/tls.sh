#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

tls::start(){
  local port="$1"
  local target="$2"

  local flags=(--cacert "${ADVANCED_MOD_MTLS_TRUST:-$_default_mod_mtls_trust}" \
    --cert /certs/certificates/local/"${DOMAIN:-}/${DOMAIN:-}".crt \
    --key /certs/certificates/local/"${DOMAIN:-}/${DOMAIN:-}".key \
    --timed-reload 300s \
  )

  # --disable-authentication
  ghostunnel "${flags[@]}" server --listen "0.0.0.0:$port" --target "$target" --allow-all
}
