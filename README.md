# What

Docker image for a HTTPS routing server.

This is based on [Caddy](https://github.com/caddyserver/caddy/).

## Image features

* multi-architecture:
  * [x] linux/amd64
  * [x] linux/arm64
* hardened:
  * [x] image runs read-only
  * [x] image runs with no capabilities (you need NET_BIND_SERVICE if you want to use privileged ports obviously)
  * [x] process runs as a non-root user, disabled login, no shell
* lightweight
  * [x] based on our slim [Debian Bookworm](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [x] multi-stage build with zero packages installed in the runtime image
* observable
  * [x] healthcheck
  * [x] log to stdout
  * [x] prometheus endpoint

## Run

```bash
docker run -d \
    --env DOMAIN=something.mydomain.com \
    --env EMAIL=me@mydomain.com \
    --net bridge \
    --publish 443:1443/tcp \
    --cap-drop ALL \
    --read-only \
    docker.io/dubodubonduponey/router
```

You do need to expose port 443 publicly from your docker host so that LetsEncrypt can issue your certificate.

## Notes

### Custom configuration file

If you want to customize your Caddy config, mount a volume into `/config` on the container and customize `/config/caddy.conf`.

```bash
chown -R 1000:nogroup "[host_path_for_config]"

docker run -d \
    --volume [host_path_for_config]:/config:ro \
    --env DOMAIN=something.mydomain.com \
    --env EMAIL=me@mydomain.com \
    --net bridge \
    --publish 443:1443 \
    --cap-drop ALL \
    --read-only \
    docker.io/dubodubonduponey/router
```

### Networking

If you want to use another networking mode but `bridge` (and run the service on standard ports), you have to run the container as `root`, grant the appropriate `cap` and set the ports:

```bash
docker run -d \
    --env DOMAIN=something.mydomain.com \
    --env EMAIL=me@mydomain.com \
    --net=host \
    --env HTTPS_PORT=443 \
    --cap-add CAP_NET_BIND_SERVICE \
    --user root \
    --cap-drop ALL \
    --read-only \
    docker.io/dubodubonduponey/router
```

### Configuration reference

The default setup uses a Caddy config file in `/config/caddy.conf` that sets-up a basic https server.

 * the `/certs` folder is used to store LetsEncrypt certificates (it's a volume by default, which you may want to mount)
 * the `/config` folder holds the configuration

#### Runtime

You may specify the following environment variables at runtime:

 * DOMAIN (eg: `something.mydomain.com`) controls the domain name of your server
 * EMAIL (eg: `me@mydomain.com`) controls the email used to issue your server certificate
 * STAGING (empty by default) controls whether you want to use LetsEncrypt staging environment (useful when debugging so not to burn your quota)

You can also tweak the following for control over which internal ports are being used (useful if intend to run with host/macvlan, see above)

 * HTTPS_PORT (default to 1443)
 * MOD_METRICS_BIND (default to 4242)

Of course using any privileged port for these requires CAP_NET_BIND_SERVICE and a root user.

Finally, any additional arguments provided when running the image will get fed to the `caddy` binary.

### Prometheus

The default configuration files expose a Prometheus metrics endpoint on port 9253.

## Moar?

See [DEVELOP.md](DEVELOP.md)
