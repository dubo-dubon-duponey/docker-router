package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	_ "github.com/caddyserver/caddy/v2/modules/standard"

	// _ "github.com/miekg/caddy-prometheus"
	_ "github.com/sillygod/cdp-cache"
	// _ "github.com/caddyserver/forwardproxy"
	// _ "github.com/dhaavi/caddy-permission"
	_ "github.com/caddyserver/replace-response"
)

func main() {
	caddycmd.Main()
}
