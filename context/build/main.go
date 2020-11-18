package main

import (
	"github.com/caddyserver/caddy/caddy/caddymain"

	_ "github.com/miekg/caddy-prometheus"
	_ "github.com/nicolasazrak/caddy-cache"
	_ "github.com/caddyserver/forwardproxy"
	_ "github.com/dhaavi/caddy-permission"
)

func main() {
	caddymain.EnableTelemetry = false
	caddymain.Run()
}
