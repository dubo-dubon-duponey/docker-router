# What

A docker image for [Caddy](https://github.com/caddyserver/caddy/).

 * multi-architecture (linux/amd64, linux/arm64, linux/arm/v7, linux/arm/v6)
 * based on debian:buster-slim
 * no cap needed
 * running as a non-root user
 * lightweight (~40MB)
 * no plugins (but you can customize at build time if you want)
 * no HTTP exposed (just HTTPS)

## Run

```bash
chown -R 1000:1000 "[host_path1]"
chown -R 1000:1000 "[host_path2]"
chown -R 1000:1000 "[host_path3]"

docker run -d \
    --net=bridge \
    --env EMAIL=me@somwhere.tld \
    --volume [host_path1]:/config \
    --volume [host_path2]:/data \
    --volume [host_path3]:/certs \
    --publish 443:1443 \
    --cap-drop ALL \
    dubodubonduponey/caddy:v1
```

## Notes

### Network

 * if you intend on running on port 443, you must use `bridge` and publish the port
 * if using `host` or `macvlan`, you will not be able to use a privileged port

### Configuration

The `DOMAIN` environment variable is meant as a convenience to test the default configuration file
(which is really a hello world).

For anything beyond that, you should roll your own configuration, inside `[host_path1]/config.conf` (mounted on `/config`).

`[host_path2]` (mounted on `/data`) is meant to hold files you might want to serve.

Technically, caddy does not need write access to these two.

`[host_path3]` (mounted on `/certs`), on the other hand, will be used by caddy for cert management and renewal (hence must be writable).

Guest access does not work currently, and is disabled.

### Advanced configuration

Any additional arguments provided when running the image will get fed to the `caddy` binary.
