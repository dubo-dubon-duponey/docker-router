target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Caddy"
    BUILD_DESCRIPTION = "A dubo image for Caddy"
  }
  tags = [
    "dubodubonduponey/caddy",
  ]
}
