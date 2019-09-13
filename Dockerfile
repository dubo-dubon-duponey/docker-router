##########################
# Building image
##########################
FROM        --platform=$BUILDPLATFORM golang:1.13-buster                                                  AS builder

# Install dependencies and tools
ARG         DEBIAN_FRONTEND="noninteractive"
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN         apt-get update                                                                                > /dev/null
RUN         apt-get install -y --no-install-recommends \
                git=1:2.20.1-2 \
                ca-certificates=20190110                                                                  > /dev/null
RUN         update-ca-certificates

WORKDIR     /build

# Versions: v2 2019/09/10
#XXX BROKEN ARG         CADDY_VERSION=44b7ce98505ab8a34f6c632e661dd2cfae475a17

# v2
# https://github.com/caddyserver/caddy/wiki/v2:-Documentation#config-intro
#ARG         CADDY_VERSION=b4f4fcd437c2f9816f9511217bde703679808679

# v1.0.3
ARG         CADDY_VERSION=bff2469d9d76ba5924f6d9affcf60bf44dcfa06c
ARG         TARGETPLATFORM

# Checkout and build
WORKDIR     /go/src/github.com/caddyserver/caddy
RUN         git clone https://github.com/caddyserver/caddy.git .
RUN         git checkout $CADDY_VERSION

WORKDIR     /go/src/github.com/caddyserver/caddy/cmd/caddy/
# v1
COPY        main.go .

# Build it
RUN         arch=${TARGETPLATFORM#*/} && \
            env GOOS=linux GOARCH=${arch%/*} GO111MODULE=on go build

#######################
# Running image
#######################
FROM        debian:buster-slim

LABEL       dockerfile.copyright="Dubo Dubon Duponey <dubo-dubon-duponey@jsboot.space>"

ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"

WORKDIR     /dubo-dubon-duponey

# Build time variable
ARG         BUILD_USER=dubo-dubon-duponey
ARG         BUILD_UID=1000
ARG         BUILD_GROUP=$BUILD_USER
ARG         BUILD_GID=$BUILD_UID

ARG         CONFIG=/config
ARG         DATA=/data
ARG         CADDYPATH=/certs

# Get relevant bits from builder
COPY        --from=builder /etc/ssl/certs /etc/ssl/certs
COPY        --from=builder /go/src/github.com/caddyserver/caddy/cmd/caddy/caddy /bin/caddy

# Get relevant local files into cwd
COPY        runtime .

# Set links
RUN         mkdir $CONFIG && mkdir $DATA && mkdir $CADDYPATH && \
            chown $BUILD_UID:$BUILD_GID $CONFIG && chown $BUILD_UID:$BUILD_GID $DATA && chown $BUILD_UID:$BUILD_GID $CADDYPATH && \
            ln -sf /dev/stdout access.log && \
            ln -sf /dev/stderr error.log

# Create user
RUN         addgroup --system --gid $BUILD_GID $BUILD_GROUP && \
            adduser --system --disabled-login --no-create-home --home /nonexistent --shell /bin/false \
                --gecos "in dockerfile user" \
                --ingroup $BUILD_GROUP \
                --uid $BUILD_UID \
                $BUILD_USER

USER        $BUILD_USER

ENV         STAGING=""
ENV         EMAIL="dubo-dubon-duponey@jsboot.space"
ENV         CADDYPATH=$CADDYPATH
ENV         DOMAIN=somewhere.tld
ENV         PORT=1443

EXPOSE      $PORT

VOLUME      $CONFIG
VOLUME      $DATA
VOLUME      $CADDYPATH

ENTRYPOINT  ["./entrypoint.sh"]
