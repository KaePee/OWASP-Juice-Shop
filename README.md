## Helper scripts to start and stop OWASP Juice Shop

Copy the install script to your desired location and make it executable with `chmod +x install.sh`.

## Or
```bash
tmp="$(mktemp -d)" && base="https://raw.githubusercontent.com/KaePee/OWASP-Juice-Shop/main/OWASP-Juice-Shop" && curl -fsSL "$base/install_juice-shop.sh" -o "$tmp/install_juice-shop.sh" && curl -fsSL "$base/juice-shop-start" -o "$tmp/juice-shop-start" && curl -fsSL "$base/juice-shop-stop" -o "$tmp/juice-shop-stop" && bash "$tmp/install_juice-shop.sh"
```

Start juice-shop `juice-shop-start` and stop it `juice-shop-stop`
