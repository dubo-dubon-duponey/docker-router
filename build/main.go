package main

import (
	"github.com/caddyserver/caddy/caddy/caddymain"

	_ "github.com/miekg/caddy-prometheus"
)

func main() {
	caddymain.EnableTelemetry = false
	caddymain.Run()
}
