package bake

command: {
  image: #Dubo & {
    args: {
      BUILD_TITLE: "Caddy"
      BUILD_DESCRIPTION: "A dubo image for Caddy based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }
  }
}
