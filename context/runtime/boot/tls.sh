#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

tls::start(){
  local bind="$1"
  local target="$2"

  local flags=(--cacert "${ADVANCED_MOD_MTLS_TRUST:-$_default_mod_mtls_trust}" \
    --cert /certs/certificates/local/"${DOMAIN:-}/${DOMAIN:-}".crt \
    --key /certs/certificates/local/"${DOMAIN:-}/${DOMAIN:-}".key \
    --timed-reload 300s \
  )

  # --disable-authentication
  ghostunnel "${flags[@]}" server --listen "$bind" --target "$target" --allow-all &
}
