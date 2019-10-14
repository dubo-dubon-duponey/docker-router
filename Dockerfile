##########################
# Builder custom
# Custom steps required to build this specific image
##########################
FROM          --platform=$BUILDPLATFORM dubodubonduponey/base:builder                                   AS builder

# Versions: v2 2019/09/10
#XXX BROKEN ARG         CADDY_VERSION=44b7ce98505ab8a34f6c632e661dd2cfae475a17

# v2
# https://github.com/caddyserver/caddy/wiki/v2:-Documentation#config-intro
# ARG           CADDY_VERSION=b4f4fcd437c2f9816f9511217bde703679808679

# v1.0.3
ARG           CADDY_VERSION=bff2469d9d76ba5924f6d9affcf60bf44dcfa06c
# master 19/10/11
# ARG           CADDY_VERSION=24b2e02ee558ec8cbe4ed7b362a4d1065e573587

# Checkout and build
WORKDIR       $GOPATH/src/github.com/caddyserver/caddy
RUN           git clone https://github.com/caddyserver/caddy.git .
RUN           git checkout $CADDY_VERSION

# v1
COPY          main.go cmd/caddy/main.go
COPY          http-client.go cmd/http-client/http-client.go
# Build it
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o dist/http-client ./cmd/http-client
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o dist/caddy ./cmd/caddy

WORKDIR       /dist/bin
RUN           cp "$GOPATH"/src/github.com/caddyserver/caddy/dist/caddy        .
RUN           cp "$GOPATH"/src/github.com/caddyserver/caddy/dist/http-client  .
RUN           chmod 555 ./*

#######################
# Running image
#######################
FROM        dubodubonduponey/base:runtime

# Get relevant bits from builder
COPY        --from=builder /dist .

ENV         DOMAIN="dev-null.farcloser.world"
ENV         EMAIL="dubo-dubon-duponey@farcloser.world"
ENV         STAGING=""

ENV         CADDYPATH=/certs
ENV         HTTPS_PORT=1443
ENV         METRICS_PORT=9180

# NOTE: this will not be updated at runtime and will always EXPOSE default values
# Either way, EXPOSE does not do anything, except function as a documentation helper
EXPOSE      $HTTPS_PORT/tcp
EXPOSE      $METRICS_PORT/tcp

# Default volumes certs, since these are expected to be writable
VOLUME      /certs

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=1 CMD DOMAIN=$DOMAIN HTTPS_PORT=$HTTPS_PORT http-client || exit 1
