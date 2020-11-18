ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime

#######################
# Extra builder for healthchecker
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

#dmp RUN git config --global url."http://127.0.0.1:1081/github".insteadOf https://github.com

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone https://$GIT_REPO .
RUN           git checkout $GIT_VERSION

# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v -ldflags "-s -w" \
                -o /dist/boot/bin/http-health ./cmd/http

#######################
# Builder custom
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder

#dmp RUN git config --global url."http://127.0.0.1:1081/github".insteadOf https://github.com

# This is 1.0.5 (final?)
# XXX move to v2 ASAP
ARG           GIT_REPO=github.com/caddyserver/caddy
ARG           GIT_VERSION=11ae1aa6b88e45b077dd97cb816fe06cd91cca67

# Caddy prometheus plugin
ARG           PROM_REPO=github.com/miekg/caddy-prometheus
ARG           PROM_VERSION=1fe4cb19becd5b9a1bf85ef841a2a348aa3d78e5

# Cache plugin
ARG           CACHE_REPO=github.com/nicolasazrak/caddy-cache
ARG           CACHE_VERSION=77032df0837be011283122f6ce041dc26ecd60c0

# Forward proxy plugin
ARG           PROXY_REPO=github.com/caddyserver/forwardproxy
ARG           PROXY_VERSION=247c0bafaabd39e17ecf82c2c957c46957c2efcc

# Permission plugin
ARG           PERM_REPO=github.com/dhaavi/caddy-permission
ARG           PERM_VERSION=b16954bb0741752da81c36fb661d0619b416a52b

# Prometheus plugin
WORKDIR       $GOPATH/src/$PROM_REPO
RUN           git clone https://$PROM_REPO .
RUN           git checkout $PROM_VERSION

# Cache (XXX careful with conflicts between this and CORS)
WORKDIR       $GOPATH/src/$CACHE_REPO
RUN           git clone https://$CACHE_REPO .
RUN           git checkout $CACHE_VERSION

# Forward proxy plugin
WORKDIR       $GOPATH/src/$PROXY_REPO
RUN           git clone https://$PROXY_REPO .
RUN           git checkout $PROXY_VERSION

# Permission plugin
WORKDIR       $GOPATH/src/$PERM_REPO
RUN           git clone https://$PERM_REPO .
RUN           git checkout $PERM_VERSION

# Checkout and build
WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone https://$GIT_REPO .
RUN           git checkout $GIT_VERSION

# Copy over entrypoint
COPY          build/main.go cmd/caddy/main.go

# Build it
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v -ldflags "-s -w" \
                -o /dist/boot/bin/caddy ./cmd/caddy

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin
RUN           chmod 555 /dist/boot/bin/*

#######################
# Running image
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE

# Get relevant bits from builder
COPY          --from=builder --chown=$BUILD_UID:root /dist .

ENV           DOMAIN="dev-null.farcloser.world"
ENV           EMAIL="dubo-dubon-duponey@farcloser.world"
ENV           STAGING=""
ENV           USERNAME=dmp
ENV           PASSWORD=nhehehehe

ENV           CADDYPATH=/certs
ENV           HTTP_PORT=1080
ENV           HTTPS_PORT=1443
ENV           PROXY_PORT=1081
ENV           METRICS_PORT=9180

# NOTE: this will not be updated at runtime and will always EXPOSE default values
# Either way, EXPOSE does not do anything, except function as a documentation helper
EXPOSE        $HTTP_PORT/tcp
EXPOSE        $HTTPS_PORT/tcp
EXPOSE        $METRICS_PORT/tcp

# Default volumes certs, since these are expected to be writable, and tmp folder for caching
VOLUME        /certs
VOLUME        /tmp

ENV           HEALTHCHECK_URL=http://127.0.0.1:10042/healthcheck

HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
