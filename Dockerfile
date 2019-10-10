##########################
# Building image
##########################
FROM        --platform=$BUILDPLATFORM golang:1.13-buster                                                  AS builder

# Install dependencies and tools
ARG         DEBIAN_FRONTEND="noninteractive"
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN         apt-get update                                                                                > /dev/null
RUN         apt-get install -y --no-install-recommends \
                make=4.2.1-1.2 \
                git=1:2.20.1-2 \
                ca-certificates=20190110                                                                  > /dev/null
RUN         update-ca-certificates

WORKDIR     /build

ARG         TARGETPLATFORM

# Versions: v2 2019/09/10
#XXX BROKEN ARG         CADDY_VERSION=44b7ce98505ab8a34f6c632e661dd2cfae475a17

# v2
# https://github.com/caddyserver/caddy/wiki/v2:-Documentation#config-intro
#ARG         CADDY_VERSION=b4f4fcd437c2f9816f9511217bde703679808679

# v1.0.3
ARG         CADDY_VERSION=bff2469d9d76ba5924f6d9affcf60bf44dcfa06c

# Checkout and build
WORKDIR     /go/src/github.com/caddyserver/caddy
RUN         git clone https://github.com/caddyserver/caddy.git .
RUN         git checkout $CADDY_VERSION

WORKDIR     /go/src/github.com/caddyserver/caddy/cmd/caddy/
# v1
COPY        main.go .

# Build it
RUN         arch=${TARGETPLATFORM#*/} && \
            env GOOS=linux GOARCH=${arch%/*} go build

#######################
# Running image
#######################
FROM        debian:buster-slim
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"

# Build args
ARG         BUILD_UID=1000

# Labels build args
ARG         BUILD_CREATED="1976-04-14T17:00:00-07:00"
ARG         BUILD_URL="https://github.com/dubodubonduponey/nonexistent"
ARG         BUILD_DOCUMENTATION="https://github.com/dubodubonduponey/nonexistent"
ARG         BUILD_SOURCE="https://github.com/dubodubonduponey/nonexistent"
ARG         BUILD_VERSION="unknown"
ARG         BUILD_REVISION="unknown"
ARG         BUILD_VENDOR="dubodubonduponey"
ARG         BUILD_LICENSES="MIT"
ARG         BUILD_REF_NAME="dubodubonduponey/nonexistent"
ARG         BUILD_TITLE="A DBDBDP image"
ARG         BUILD_DESCRIPTION="So image. Much DBDBDP. Such description."

LABEL       org.opencontainers.image.created="$BUILD_CREATED"
LABEL       org.opencontainers.image.authors="Dubo Dubon Duponey <dubo-dubon-duponey@farcloser.world>"
LABEL       org.opencontainers.image.url="$BUILD_URL"
LABEL       org.opencontainers.image.documentation="$BUILD_DOCUMENTATION"
LABEL       org.opencontainers.image.source="$BUILD_SOURCE"
LABEL       org.opencontainers.image.version="$BUILD_VERSION"
LABEL       org.opencontainers.image.revision="$BUILD_REVISION"
LABEL       org.opencontainers.image.vendor="$BUILD_VENDOR"
LABEL       org.opencontainers.image.licenses="$BUILD_LICENSES"
LABEL       org.opencontainers.image.ref.name="$BUILD_REF_NAME"
LABEL       org.opencontainers.image.title="$BUILD_TITLE"
LABEL       org.opencontainers.image.description="$BUILD_DESCRIPTION"

# Get universal relevant files
COPY        runtime  /
COPY        --from=builder /etc/ssl/certs                             /etc/ssl/certs

# Create a restriced user account (no shell, no home, disabled)
# Setup directories and permissions
# The user can access the files as the owner, and root can access as the group (that way, --user=root still works without caps).
# Write is granted, although that doesn't really matter in term of security
RUN         adduser --system --no-create-home --home /nonexistent --gecos "in dockerfile user" \
                --uid $BUILD_UID \
                dubo-dubon-duponey \
              && chmod 550 entrypoint.sh \
              && chown $BUILD_UID:root entrypoint.sh \
              && mkdir -p /config \
              && mkdir -p /data \
              && mkdir -p /certs \
              && chown -R $BUILD_UID:root /config \
              && chown -R $BUILD_UID:root /data \
              && chown -R $BUILD_UID:root /certs \
              && find /config -type d -exec chmod -R 770 {} \; \
              && find /config -type f -exec chmod -R 660 {} \; \
              && find /data -type d -exec chmod -R 770 {} \; \
              && find /data -type f -exec chmod -R 660 {} \; \
              && find /certs -type d -exec chmod -R 770 {} \; \
              && find /certs -type f -exec chmod -R 660 {} \;

# Default volumes for data and certs, since these are expected to be writable
VOLUME      /data
VOLUME      /certs

# Downgrade to system user
USER        dubo-dubon-duponey

ENTRYPOINT  ["/entrypoint.sh"]

##########################################
# Image specifics
##########################################

# Get relevant bits from builder
COPY        --from=builder /etc/ssl/certs                                       /etc/ssl/certs
COPY        --from=builder /go/src/github.com/caddyserver/caddy/cmd/caddy/caddy /bin/caddy

ENV         DOMAIN="somewhere.tld"
ENV         EMAIL="dubo-dubon-duponey@farcloser.world"
ENV         STAGING=""

ENV         CADDYPATH=/certs
ENV         HTTPS_PORT=1443

# NOTE: this will not be updated at runtime and will always EXPOSE default values
# Either way, EXPOSE does not do anything, except function as a documentation helper
EXPOSE      $HTTPS_PORT/tcp
