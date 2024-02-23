package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"
	_ "github.com/caddyserver/caddy/v2/modules/standard"
	_ "github.com/caddyserver/replace-response"

	_ "github.com/caddyserver/cache-handler"

	// _ "github.com/miekg/caddy-prometheus"
	// _ "github.com/caddyserver/forwardproxy"
	// _ "github.com/dhaavi/caddy-permission"
)

func main() {
	caddycmd.Main()
}
