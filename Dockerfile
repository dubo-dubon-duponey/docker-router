ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-10-15@sha256:1609d1af44c0048ec0f2e208e6d4e6a525c6d6b1c0afcc9d71fccf985a8b0643
ARG           FROM_IMAGE_AUDITOR=base:auditor-bullseye-2021-10-15@sha256:2c95e3bf69bc3a463b00f3f199e0dc01cab773b6a0f583904ba6766b3401cb7b
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-10-15@sha256:5c54594a24e3dde2a82e2027edd6d04832204157e33775edc66f716fa938abba
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-10-15@sha256:4de02189b785c865257810d009e56f424d29a804cc2645efb7f67b71b785abde

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fecthers
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-main

ARG           GIT_REPO=github.com/caddyserver/caddy
# 2.4.5 need tweak to scep (minor version bump), but then the build segfaults
ARG           GIT_VERSION=v2.4.3
ARG           GIT_COMMIT=9d4ed3a3236df06e54c80c4f6633b66d68ad3673

ENV           WITH_BUILD_SOURCE="./cmd/caddy"
ENV           WITH_BUILD_OUTPUT="caddy"

ENV           CGO_ENABLED=1
ENV           ENABLE_STATIC=true
# ENV           ENABLE_PIE=true

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

# scep v2.0.0 checksum does not match anymore
# It's unclear whether the rename of the module to v2 is responsible, but one way or the other this
# *critical* module is suspicious
# RUN           echo "replace github.com/micromdm/scep/v2 v2.0.0 => github.com/micromdm/scep/v2 v2.1.0" >> go.mod

# Forward proxy plugin
ARG           GIT_REPO_PROXY=github.com/caddyserver/forwardproxy
#ARG           GIT_VERSION_PROXY=247c0ba
#ARG           GIT_COMMIT_PROXY=247c0bafaabd39e17ecf82c2c957c46957c2efcc
# XXX untested and unclear how it worked before
ARG           GIT_VERSION_PROXY=8c6ef2b
ARG           GIT_COMMIT_PROXY=8c6ef2bd4a8f40340b3ecd249f8eed058c567b76

# Caddy prometheus plugin
ARG           GIT_REPO_PROM=github.com/miekg/caddy-prometheus
ARG           GIT_VERSION_PROM=1fe4cb1
ARG           GIT_COMMIT_PROM=1fe4cb19becd5b9a1bf85ef841a2a348aa3d78e5

# Cache plugin
ARG           GIT_REPO_CACHE=github.com/sillygod/cdp-cache
ARG           GIT_VERSION_CACHE=a00fa59
ARG           GIT_COMMIT_CACHE=a00fa59f10239705c798c19261637d7d2cd4555e

# Permission plugin
ARG           GIT_REPO_PERM=github.com/dhaavi/caddy-permission
ARG           GIT_VERSION_PERM=b16954b
ARG           GIT_COMMIT_PERM=b16954bb0741752da81c36fb661d0619b416a52b

# Replace in response plugin
ARG           GIT_REPO_REPLACE=github.com/caddyserver/replace-response
ARG           GIT_VERSION_REPLACE=9d5652c
ARG           GIT_COMMIT_REPLACE=9d5652c0256308fddaef1453d463d2a281498cb6

# XXX probably does not work with caddy 2, and also has a problem with github.com/mholt/caddy v1.0.0
# RUN           echo "replace github.com/tencentcloud/tencentcloud-sdk-go v3.0.82+incompatible => github.com/tencentcloud/tencentcloud-sdk-go v1.0.191" >> go.mod
# RUN           echo "require $GIT_REPO_PROXY $GIT_COMMIT_PROXY" >> go.mod
# Seems to be caddy 1 too
# RUN           echo "require $GIT_REPO_PROM $GIT_COMMIT_PROM" >> go.mod
RUN           echo "require $GIT_REPO_CACHE $GIT_COMMIT_CACHE" >> go.mod
# RUN           echo "require $GIT_REPO_PERM $GIT_COMMIT_PERM" >> go.mod
RUN           echo "require $GIT_REPO_REPLACE $GIT_COMMIT_REPLACE" >> go.mod

# hadolint ignore=DL3045
COPY          build/main.go ./cmd/caddy/main.go

RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=NETRC \
              go mod tidy; \
              [[ "${GOFLAGS:-}" == *-mod=vendor* ]] || go mod download

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM fetcher-main                                                                    AS builder-main

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

COPY          --from=builder-main   /dist/boot              /dist/boot

COPY          --from=builder-tools  /boot/bin/goello-server-ng /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health   /dist/boot/bin

RUN           setcap 'cap_net_bind_service+ep'              /dist/boot/bin/caddy

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;


#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS runtime

ENV           _SERVICE_NICK="caddy"
ENV           _SERVICE_TYPE="http"

COPY          --from=assembly --chown=$BUILD_UID:root /dist /
### Front server configuration
# Port to use
ENV           PORT_HTTPS=443
ENV           PORT_HTTP=80
EXPOSE        443
EXPOSE        80
# Log verbosity for
ENV           LOG_LEVEL="warn"
# Domain name to serve
ENV           DOMAIN="$_SERVICE_NICK.local"
ENV           ADDITIONAL_DOMAINS="https://*.debian.org"
# Whether the server should behave as a proxy (disallows mTLS)
ENV           SERVER_NAME="DuboDubonDuponey/1.0 (Caddy/2) [$_SERVICE_NICK]"
# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt - use "" to disable TLS entirely
ENV           TLS="internal"
# 1.2 or 1.3
ENV           TLS_MIN=1.3
# Issuer name to appear in certificates
#ENV           TLS_ISSUER="Dubo Dubon Duponey"
# Either disable_redirects or ignore_loaded_certs if one wants the redirects
ENV           TLS_AUTO=disable_redirects
# Staging
# https://acme-staging-v02.api.letsencrypt.org/directory
# Plain
# https://acme-v02.api.letsencrypt.org/directory
# PKI
# https://pki.local
ENV           TLS_SERVER="https://acme-v02.api.letsencrypt.org/directory"
# Either require_and_verify or verify_if_given, or "" to disable mTLS altogether
ENV           MTLS="require_and_verify"
# Root certificate to trust for mTLS
ENV           MTLS_TRUST="/certs/mtls_ca.crt"
# Realm for authentication - set to "" to disable authentication entirely
ENV           AUTH="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           AUTH_USERNAME="dubo-dubon-duponey"
ENV           AUTH_PASSWORD="cmVwbGFjZV9tZV93aXRoX3NvbWV0aGluZwo="
### mDNS broadcasting
# Type to advertise
ENV           MDNS_TYPE="_$_SERVICE_TYPE._tcp"
# Name is used as a short description for the service
ENV           MDNS_NAME="$_SERVICE_NICK mDNS display name"
# The service will be annonced and reachable at $MDNS_HOST.local (set to empty string to disable mDNS announces entirely)
ENV           MDNS_HOST="$_SERVICE_NICK"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           MDNS_STATION=true
# Caddy certs will be stored here
VOLUME        /certs
# Caddy uses this
VOLUME        /tmp
# Used by the backend service
VOLUME        /data
ENV           HEALTHCHECK_URL="http://127.0.0.1:10000/?healthcheck"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1


