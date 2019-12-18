#######################
# Extra builder for healthchecker
#######################
ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/boot/bin/http-health ./cmd/http

##########################
# Builder custom
# Custom steps required to build this specific image
##########################
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder

# Versions: v2 2019/09/10
#XXX BROKEN ARG         CADDY_VERSION=44b7ce98505ab8a34f6c632e661dd2cfae475a17
# v2
# https://github.com/caddyserver/caddy/wiki/v2:-Documentation#config-intro
# ARG           CADDY_VERSION=b4f4fcd437c2f9816f9511217bde703679808679

# v1.0.3
# ARG           CADDY_VERSION=bff2469d9d76ba5924f6d9affcf60bf44dcfa06c
# master 19/10/11
ARG           CADDY_VERSION=99914d22043f707f3f69bb5ee509d3353d75e943

ARG           PROM_VERSION=1fe4cb19becd5b9a1bf85ef841a2a348aa3d78e5

ARG           CACHE_VERSION=77032df0837be011283122f6ce041dc26ecd60c0

WORKDIR       $GOPATH/src/github.com/miekg/caddy-prometheus
RUN           git clone https://github.com/miekg/caddy-prometheus.git .
RUN           git checkout $PROM_VERSION

WORKDIR       $GOPATH/src/github.com/nicolasazrak/caddy-cache
RUN           git clone https://github.com/nicolasazrak/caddy-cache.git .
RUN           git checkout $CACHE_VERSION


# Checkout and build
WORKDIR       $GOPATH/src/github.com/caddyserver/caddy
RUN           git clone https://github.com/caddyserver/caddy.git .
RUN           git checkout $CADDY_VERSION

# v1
COPY          build/main.go cmd/caddy/main.go

# Build it
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/boot/bin/caddy ./cmd/caddy

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
ENV           HTTPS_PORT=1443
ENV           METRICS_PORT=9180

ENV           HEALTHCHECK_URL=http://127.0.0.1:10042/healthcheck

# NOTE: this will not be updated at runtime and will always EXPOSE default values
# Either way, EXPOSE does not do anything, except function as a documentation helper
EXPOSE        $HTTPS_PORT/tcp
EXPOSE        $METRICS_PORT/tcp

# Default volumes certs, since these are expected to be writable
VOLUME        /certs
# VOLUME        /tmp

HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
