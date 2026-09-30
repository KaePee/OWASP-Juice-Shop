#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="${JUICE_SHOP_DIR:-$HOME/juice-shop}"
IMAGE="bkimminich/juice-shop:latest"
URL="http://localhost:3000"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
COMMAND_DIR="/usr/local/bin"

if [[ -t 1 ]]; then
	COLOR_GREEN=$'\033[32m'
	COLOR_YELLOW=$'\033[33m'
	COLOR_RED=$'\033[31m'
	COLOR_RESET=$'\033[0m'
else
	COLOR_GREEN=""
	COLOR_YELLOW=""
	COLOR_RED=""
	COLOR_RESET=""
fi

info() { printf '%s\n' "$*"; }
success() { printf '%s\n' "${COLOR_GREEN}[OK]${COLOR_RESET} $*"; }
warning() { printf '%s\n' "${COLOR_YELLOW}[INFO]${COLOR_RESET} $*"; }
error() { printf '%s\n' "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2; }

on_error() {
	local exit_code=$?
	error "Command failed on line $1 (exit code $exit_code)."
	exit "$exit_code"
}

on_interrupt() {
	info "\nJuice Shop stopped."
	exit 130
}

trap 'on_error "$LINENO"' ERR
trap on_interrupt INT TERM

run_as_root() {
	if [[ "$(id -u)" -eq 0 ]]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		error "Root privileges are required to install system packages. Install sudo or rerun as root."
		return 1
	fi
}

install_linux_packages() {
	local packages=("$@")

	if command -v apt-get >/dev/null 2>&1; then
		run_as_root apt-get update
		run_as_root apt-get install -y "${packages[@]}"
	elif command -v dnf >/dev/null 2>&1; then
		run_as_root dnf install -y "${packages[@]}"
	elif command -v yum >/dev/null 2>&1; then
		run_as_root yum install -y "${packages[@]}"
	elif command -v pacman >/dev/null 2>&1; then
		run_as_root pacman -Sy --noconfirm "${packages[@]}"
	elif command -v zypper >/dev/null 2>&1; then
		run_as_root zypper --non-interactive install "${packages[@]}"
	elif command -v apk >/dev/null 2>&1; then
		run_as_root apk add --no-cache "${packages[@]}"
	else
		error "No supported Linux package manager was found. Install these packages manually: ${packages[*]}"
		return 1
	fi
}

ensure_git() {
	if command -v git >/dev/null 2>&1; then
		success "Git is available ($(git --version))."
		return
	fi

	warning "Git is missing; installing it."
	if [[ "$(uname -s)" == "Darwin" ]]; then
		if command -v brew >/dev/null 2>&1; then
			brew install git
		elif command -v xcode-select >/dev/null 2>&1; then
			xcode-select --install || true
			error "Install the Command Line Tools, then run this script again."
			exit 1
		else
			error "Install Git or Xcode Command Line Tools, then run this script again."
			exit 1
		fi
	else
		install_linux_packages git curl ca-certificates
	fi

	command -v git >/dev/null 2>&1 || {
		error "Git installation did not complete successfully."
		return 1
	}
	success "Git is installed."
}

load_nvm() {
	export NVM_DIR
	if [[ -s "$NVM_DIR/nvm.sh" ]]; then
		# shellcheck disable=SC1090
		. "$NVM_DIR/nvm.sh"
		return 0
	fi
	return 1
}

node_is_supported() {
	command -v node >/dev/null 2>&1 || return 1
	local major
	major="$(node -p 'Number(process.versions.node.split(".")[0])')"
	[[ "$major" -ge 20 ]]
}

ensure_node() {
	if load_nvm; then
		nvm use --silent default >/dev/null 2>&1 || true
	fi

	if node_is_supported; then
		success "Node.js $(node --version) and npm $(npm --version) are available."
		return
	fi

	warning "Node.js 20 or newer is required; installing the current LTS with nvm."
	if ! command -v curl >/dev/null 2>&1; then
		if [[ "$(uname -s)" == "Darwin" ]]; then
			error "curl is required to install Node.js and was not found."
			return 1
		fi
		install_linux_packages curl ca-certificates
	fi

	if ! command -v nvm >/dev/null 2>&1; then
		curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | PROFILE=/dev/null bash
		load_nvm || {
			error "Could not load nvm after installation."
			return 1
		}
	fi

	nvm install --lts
	nvm alias default 'lts/*'
	nvm use --silent default
	node_is_supported || {
		error "Node.js 20 or newer could not be installed."
		return 1
	}
	success "Node.js $(node --version) and npm $(npm --version) are ready."
}

run_with_docker() {
	info "Checking the Juice Shop Docker image..."
	if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
		info "Downloading $IMAGE..."
		docker pull "$IMAGE"
	else
		success "The Juice Shop Docker image is already present."
	fi

	install_control_commands
	"$COMMAND_DIR/juice-shop-start"
}

install_control_commands() {
	local script_dir
	script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

	info "Installing juice-shop-start and juice-shop-stop into $COMMAND_DIR..."
	run_as_root install -d -m 755 "$COMMAND_DIR"
	run_as_root install -m 755 "$script_dir/juice-shop-start" "$COMMAND_DIR/juice-shop-start"
	run_as_root install -m 755 "$script_dir/juice-shop-stop" "$COMMAND_DIR/juice-shop-stop"
	success "Run juice-shop-start or juice-shop-stop from any directory."
}

run_from_source() {
	ensure_git
	ensure_node

	if [[ -d "$APP_DIR" ]]; then
		if [[ -d "$APP_DIR/.git" ]]; then
			success "Reusing the existing checkout at $APP_DIR."
		elif [[ -f "$APP_DIR/package.json" ]] && [[ "$(node -p 'require(process.argv[1]).name' "$APP_DIR/package.json" 2>/dev/null || true)" == "juice-shop" ]]; then
			success "Reusing the existing Juice Shop source at $APP_DIR."
		else
			error "$APP_DIR already exists but is not a Juice Shop checkout. Set JUICE_SHOP_DIR to another path or move that directory."
			return 1
		fi
	else
		info "Cloning Juice Shop into $APP_DIR..."
		git clone --depth 1 https://github.com/juice-shop/juice-shop.git "$APP_DIR"
	fi

	cd "$APP_DIR"
	if [[ ! -f node_modules/.juice-shop-install-complete ]]; then
		info "Installing Juice Shop npm dependencies..."
		if [[ -f package-lock.json ]]; then
			npm ci
		else
			npm install
		fi
		mkdir -p node_modules
		touch node_modules/.juice-shop-install-complete
	else
		success "npm dependencies are already installed."
	fi

	install_control_commands
	"$COMMAND_DIR/juice-shop-start"
}

main() {
	info "${COLOR_GREEN}=================================${COLOR_RESET}"
	info "       OWASP Juice Shop setup"
	info "${COLOR_GREEN}=================================${COLOR_RESET}"

	if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
		success "Docker is installed and running."
		run_with_docker
	else
		warning "A working Docker installation was not found; using the source installation."
		run_from_source
	fi

	info "${COLOR_GREEN}=================================${COLOR_RESET}"
	success "Juice Shop has stopped."
}

main "$@"