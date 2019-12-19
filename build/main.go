package main

import (
	"github.com/caddyserver/caddy/caddy/caddymain"

	_ "github.com/miekg/caddy-prometheus"
	// XXX doesn't seem to work (get 500) - commenting out for now
	// _ "github.com/nicolasazrak/caddy-cache"
)

func main() {
	caddymain.EnableTelemetry = false
	caddymain.Run()
}
