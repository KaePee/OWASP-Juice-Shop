# OWASP Juice Shop

`install_juice-shop.sh` starts Juice Shop locally. It uses Docker when the Docker
daemon is running; otherwise, it clones the source into `~/juice-shop`, installs
its npm dependencies, and starts it with Node.js.

## Setup

Run the script from this directory:

```sh
./install_juice-shop.sh
```

The source setup requires Git, `curl`, and Node.js 20 or newer with npm. The
script installs missing Git through Homebrew or a supported Linux package
manager, and installs the current Node.js LTS with nvm when needed. On macOS,
missing Git triggers the Xcode Command Line Tools installer; finish that
installation and rerun the script. Linux package installation may ask for sudo.

Docker is optional. If Docker is installed and running, the script pulls the
Juice Shop image if needed and runs it instead of setting up the source. Open
http://localhost:3000 while it is running.

The installer also puts `juice-shop-start` and `juice-shop-stop` in
`/usr/local/bin` (sudo access may be requested). Use those commands from any
directory to start or gracefully stop Juice Shop. Source installs run in the
background and write output to `~/juice-shop/juice-shop.log`. Set
`JUICE_SHOP_DIR` when invoking either command to use a different source
directory, for example `JUICE_SHOP_DIR=/path/to/juice-shop juice-shop-start`.
