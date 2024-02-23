ARG           FROM_REGISTRY=docker.io/dubodubonduponey

ARG           FROM_IMAGE_BUILDER=base:builder-bookworm-2023-09-05
ARG           FROM_IMAGE_AUDITOR=base:auditor-bookworm-2023-09-05
ARG           FROM_IMAGE_RUNTIME=base:runtime-bookworm-2023-09-05
ARG           FROM_IMAGE_TOOLS=tools:linux-bookworm-2023-09-05

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-ghost

ARG           GIT_REPO=github.com/ghostunnel/ghostunnel
ARG           GIT_VERSION=v1.7.3
ARG           GIT_COMMIT=0e0510cd4a6e685fe8c80ced0b2a64c2444eb287

ENV           WITH_BUILD_SOURCE="."
ENV           WITH_BUILD_OUTPUT="ghostunnel"
ENV           WITH_LDFLAGS="-X main.version=${GIT_VERSION}"

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"
RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=NETRC \
              [[ "${GOFLAGS:-}" == *-mod=vendor* ]] || go mod download

FROM          --platform=$BUILDPLATFORM fetcher-ghost                                                                   AS builder-ghost

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT
ENV           GOOS=$TARGETOS
ENV           GOARCH=$TARGETARCH

ENV           CGO_CFLAGS="${CFLAGS:-} ${ENABLE_PIE:+-fPIE}"
ENV           GOFLAGS="-trimpath ${ENABLE_PIE:+-buildmode=pie} ${GOFLAGS:-}"

RUN           export GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)"; \
              [ "${CGO_ENABLED:-}" != 1 ] || { \
                eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
                export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
                export AR="${DEB_TARGET_GNU_TYPE}-ar"; \
                export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
                export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
                [ ! "${ENABLE_STATIC:-}" ] || { \
                  [ ! "${WITH_CGO_NET:-}" ] || { \
                    ENABLE_STATIC=; \
                    LDFLAGS="${LDFLAGS:-} -static-libgcc -static-libstdc++"; \
                  }; \
                  [ "$GOARCH" == "amd64" ] || [ "$GOARCH" == "arm64" ] || [ "${ENABLE_PIE:-}" != true ] || ENABLE_STATIC=; \
                }; \
                WITH_LDFLAGS="${WITH_LDFLAGS:-} -linkmode=external -extld="$CC" -extldflags \"${LDFLAGS:-} ${ENABLE_STATIC:+-static}${ENABLE_PIE:+-pie}\""; \
                WITH_TAGS="${WITH_TAGS:-} cgo ${ENABLE_STATIC:+static static_build}"; \
              }; \
              go build -ldflags "-s -w -v ${WITH_LDFLAGS:-}" -tags "${WITH_TAGS:-} net${WITH_CGO_NET:+c}go osusergo" -o /dist/boot/bin/"$WITH_BUILD_OUTPUT" "$WITH_BUILD_SOURCE"



FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-caddy

ARG           GIT_REPO=github.com/caddyserver/caddy
# Works until < go1.8
#ARG           GIT_VERSION=v2.4.3
#ARG           GIT_COMMIT=9d4ed3a3236df06e54c80c4f6633b66d68ad3673
# 2.4.5 need tweak to scep (minor version bump), but then the build segfaults
# 2.4.6 segfaults
#ARG           GIT_VERSION=v2.4.6
#ARG           GIT_COMMIT=e7457b43e4703080ae8713ada798ce3e20b83690
#ARG           GIT_VERSION=v2.5.2
#ARG           GIT_COMMIT=ad3a83fb9169899226ce12a61c16b5bf4d03c482
ARG           GIT_VERSION=v2.7.6
ARG           GIT_COMMIT=6d9a83376b5e19b3c0368541ee46044ab284038b

ENV           WITH_BUILD_SOURCE="./cmd/caddy"
ENV           WITH_BUILD_OUTPUT="caddy"

ENV           CGO_ENABLED=1
#ENV           ENABLE_STATIC=true
# ENV           ENABLE_PIE=true

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

# scep v2.0.0 checksum does not match anymore
# It's unclear whether the rename of the module to v2 is responsible, but one way or the other this
# *critical* module is suspicious
# RUN           echo "replace github.com/micromdm/scep/v2 v2.0.0 => github.com/micromdm/scep/v2 v2.1.0" >> go.mod

# Forward proxy plugin
ARG           GIT_REPO_PROXY=github.com/caddyserver/forwardproxy
# XXX untested and unclear how it worked before
#ARG           GIT_VERSION_PROXY=8c6ef2b
#ARG           GIT_COMMIT_PROXY=8c6ef2bd4a8f40340b3ecd249f8eed058c567b76
#
ARG           GIT_VERSION_PROXY=c8ab19b
ARG           GIT_COMMIT_PROXY=c8ab19b557a8d3521cf22a89f90894404774b709


# Caddy prometheus plugin
ARG           GIT_REPO_PROM=github.com/miekg/caddy-prometheus
ARG           GIT_VERSION_PROM=1fe4cb1
ARG           GIT_COMMIT_PROM=1fe4cb19becd5b9a1bf85ef841a2a348aa3d78e5

# Cache plugin
ARG           GIT_REPO_CACHE=github.com/caddyserver/cache-handler
ARG           GIT_VERSION_CACHE=v0.11.0
ARG           GIT_COMMIT_CACHE=a3fd43026ed8268d369c553588c606cf0ae80817

# Permission plugin
ARG           GIT_REPO_PERM=github.com/dhaavi/caddy-permission
ARG           GIT_VERSION_PERM=b16954b
ARG           GIT_COMMIT_PERM=b16954bb0741752da81c36fb661d0619b416a52b

# Replace in response plugin
ARG           GIT_REPO_REPLACE=github.com/caddyserver/replace-response
#ARG           GIT_VERSION=d7523f4
#ARG           GIT_COMMIT_REPLACE=d7523f42f84a2fa09d64c957f1e6795ece355425
ARG           GIT_VERSION_REPLACE=a85d4dd
ARG           GIT_COMMIT_REPLACE=a85d4ddc11d635c093074205bd32f56d05fc7811

# XXX probably does not work with caddy 2, and also has a problem with github.com/mholt/caddy v1.0.0
# RUN           echo "replace github.com/tencentcloud/tencentcloud-sdk-go v3.0.82+incompatible => github.com/tencentcloud/tencentcloud-sdk-go v1.0.191" >> go.mod
# RUN           echo "require $GIT_REPO_PROXY $GIT_COMMIT_PROXY" >> go.mod
# Seems to be caddy 1 too
# RUN           echo "require $GIT_REPO_PROM $GIT_COMMIT_PROM" >> go.mod
# RUN           echo "require $GIT_REPO_PERM $GIT_COMMIT_PERM" >> go.mod

# Seem to crash everything at this point
#RUN           echo "require $GIT_REPO_CACHE $GIT_COMMIT_CACHE" >> go.mod

RUN           echo "require $GIT_REPO_REPLACE $GIT_COMMIT_REPLACE" >> go.mod

# hadolint ignore=DL3045
COPY          build/main.go ./cmd/caddy/main.go

RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=NETRC \
              go mod tidy -compat=1.17; \
              [[ "${GOFLAGS:-}" == *-mod=vendor* ]] || go mod download

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM fetcher-caddy                                                                    AS builder-caddy

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT
ENV           GOOS=$TARGETOS
ENV           GOARCH=$TARGETARCH

ENV           CGO_CFLAGS="${CFLAGS:-} ${ENABLE_PIE:+-fPIE}"
ENV           GOFLAGS="-trimpath ${ENABLE_PIE:+-buildmode=pie} ${GOFLAGS:-}"

RUN           export GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)"; \
              [ "${CGO_ENABLED:-}" != 1 ] || { \
                eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
                export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
                export AR="${DEB_TARGET_GNU_TYPE}-ar"; \
                export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
                export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
                [ ! "${ENABLE_STATIC:-}" ] || { \
                  [ ! "${WITH_CGO_NET:-}" ] || { \
                    ENABLE_STATIC=; \
                    LDFLAGS="${LDFLAGS:-} -static-libgcc -static-libstdc++"; \
                  }; \
                  [ "$GOARCH" == "amd64" ] || [ "$GOARCH" == "arm64" ] || [ "${ENABLE_PIE:-}" != true ] || ENABLE_STATIC=; \
                }; \
                WITH_LDFLAGS="${WITH_LDFLAGS:-} -linkmode=external -extld="$CC" -extldflags \"${LDFLAGS:-} ${ENABLE_STATIC:+-static}${ENABLE_PIE:+-pie}\""; \
                WITH_TAGS="${WITH_TAGS:-} cgo ${ENABLE_STATIC:+static static_build}"; \
              }; \
              go build -ldflags "-s -w -v ${WITH_LDFLAGS:-}" -tags "${WITH_TAGS:-} net${WITH_CGO_NET:+c}go osusergo" -o /dist/boot/bin/"$WITH_BUILD_OUTPUT" "$WITH_BUILD_SOURCE"

#######################
# Builder assembly
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS assembly

COPY          --from=builder-caddy   /dist/boot              /dist/boot
COPY          --from=builder-ghost   /dist /dist

COPY          --from=builder-tools   /boot/bin/goello-server-ng /dist/boot/bin
COPY          --from=builder-tools   /boot/bin/http-health   /dist/boot/bin

RUN           setcap 'cap_net_bind_service+ep' /dist/boot/bin/caddy
RUN           setcap 'cap_net_bind_service+ep' /dist/boot/bin/ghostunnel

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;


#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS runtime

ENV           _SERVICE_NICK="router"
ENV           _SERVICE_TYPE="http"

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

#####
# Global
#####
# Log verbosity (debug, info, warn, error, fatal)
ENV           LOG_LEVEL="warn"
# Domain name to serve
ENV           DOMAIN="$_SERVICE_NICK.local"

#####
# Mod mDNS
#####
# Whether to disable mDNS broadcasting or not
ENV           MOD_MDNS_ENABLED=true
# Name is used as a short description for the service
ENV           MOD_MDNS_NAME="$_SERVICE_NICK display name"
# The service will be annonced and reachable at MOD_MDNS_HOST.local
ENV           MOD_MDNS_HOST="$_SERVICE_NICK"

#####
# Mod TLS
#####
# Whether to enable client certificate validation or not
ENV           MOD_TLS_ENABLED=false
ENV           MOD_TLS_TARGET=""
ENV           ADVANCED_MOD_TLS_PORT=443

#####
# Mod mTLS
#####
# Whether to enable client certificate validation or not
ENV           MOD_MTLS_ENABLED=false
# Either require_and_verify or verify_if_given
ENV           MOD_MTLS_MODE="verify_if_given"

#####
# Mod Basic Auth
#####
# Whether to enable basic auth
ENV           MOD_BASICAUTH_ENABLED=false
# Realm displayed for auth
ENV           MOD_BASICAUTH_REALM="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           MOD_BASICAUTH_USERNAME="dubo-dubon-duponey"
ENV           MOD_BASICAUTH_PASSWORD="cmVwbGFjZV9tZV93aXRoX3NvbWV0aGluZwo="

#####
# Mod HTTP
#####
# Whether to disable the HTTP mod altogether
ENV           MOD_HTTP_ENABLED=true
# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt
ENV           MOD_HTTP_TLS_MODE="internal"

#####
# Advanced settings
#####
# Service type
ENV           ADVANCED_MOD_MDNS_TYPE="_$_SERVICE_TYPE._tcp"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           ADVANCED_MOD_MDNS_STATION=true
# Root certificate to trust for client cert verification
ENV           ADVANCED_MOD_MTLS_TRUST="/certs/pki/authorities/local/root.crt"
# Ports for http and https - recent changes in docker make it no longer necessary to have caps, plus we have our NET_BIND_SERVICE cap set anyhow - it's 2021, there is no reason to keep on venerating privileged ports
ENV           ADVANCED_MOD_HTTP_PORT=443
ENV           ADVANCED_MOD_HTTP_PORT_INSECURE=80
# By default, tls should be restricted to 1.3 - you may downgrade to 1.2+ for compatibility with older clients (webdav client on macos, older browsers)
ENV           ADVANCED_MOD_HTTP_TLS_MIN=1.3
# Name advertised by Caddy in the server http header
ENV           ADVANCED_MOD_HTTP_SERVER_NAME="DuboDubonDuponey/1.0 (Caddy/2)"
# ACME server to use (for testing)
# Staging
# https://acme-staging-v02.api.letsencrypt.org/directory
# Plain
# https://acme-v02.api.letsencrypt.org/directory
# PKI
# https://pki.local
ENV           ADVANCED_MOD_HTTP_TLS_SERVER="https://acme-v02.api.letsencrypt.org/directory"
# Either disable_redirects or ignore_loaded_certs if one wants the redirects
ENV           ADVANCED_MOD_HTTP_TLS_AUTO=disable_redirects
# Whether to disable TLS and serve only plain old http
ENV           ADVANCED_MOD_HTTP_TLS_ENABLED=true
# Additional domains aliases
ENV           ADVANCED_MOD_HTTP_ADDITIONAL_DOMAINS=""

#####
# Wrap-up
#####
EXPOSE        443
EXPOSE        80

# Caddy certs will be stored here
VOLUME        /certs
# Caddy uses this
VOLUME        /tmp
# Used by the backend service
VOLUME        /data

ENV           HEALTHCHECK_URL="http://127.0.0.1:10000/?healthcheck"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
