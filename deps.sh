#!/usr/bin/env bash
# Checks for (and optionally installs) the tools this config relies on.
#
# Usage:
#   ./deps.sh            check only, print what's missing
#   ./deps.sh --install   also install missing packages via your package
#                          manager (asks for sudo as needed)
#
# nix is checked but never auto-installed here: installing it is a bigger,
# system-wide step (build users, a daemon) that you should run yourself --
# see the printed instructions below if it's missing.
set -euo pipefail

install_mode=false
if [ "${1:-}" = "--install" ]; then
	install_mode=true
fi

check() {
	local name="$1"
	if command -v "$name" >/dev/null 2>&1; then
		printf "  [x] %-10s %s\n" "$name" "$(command -v "$name")"
		return 0
	fi
	printf "  [ ] %-10s not found\n" "$name"
	return 1
}

echo "Checking dependencies..."
fish_present=1
check fish || fish_present=0
direnv_present=1
check direnv || direnv_present=0
zoxide_present=1
check zoxide || zoxide_present=0
nix_present=1
check nix || nix_present=0
echo

if [ "$nix_present" = 1 ]; then
	if ! nix flake --help >/dev/null 2>&1; then
		echo "nix is installed, but flakes aren't enabled. Add this line to"
		echo "/etc/nix/nix.conf (or ~/.config/nix/nix.conf) and restart the nix"
		echo "daemon:"
		echo "  experimental-features = nix-command flakes"
		echo
	fi
else
	echo "nix isn't installed. It's not auto-installed by this script since"
	echo "it's a bigger, system-wide step (creates build users/a daemon)."
	echo "Recommended installer (enables flakes by default):"
	echo '  curl --proto '"'"'=https'"'"' -sSf -L https://install.determinate.systems/nix | sh -s -- install'
	echo "See https://nixos.org/download for alternatives."
	echo
fi

missing_pkgs=()
[ "$fish_present" = 1 ] || missing_pkgs+=("fish")
[ "$direnv_present" = 1 ] || missing_pkgs+=("direnv")
[ "$zoxide_present" = 1 ] || missing_pkgs+=("zoxide")

if [ ${#missing_pkgs[@]} -eq 0 ]; then
	echo "fish, direnv, and zoxide are all installed."
	exit 0
fi

echo "Missing: ${missing_pkgs[*]}"

if [ "$install_mode" != true ]; then
	echo "Re-run with --install to install these via your package manager."
	exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
	# A single broken/unreachable PPA can fail `apt-get update` outright even
	# though the repos actually needed here are fine -- don't let that abort
	# the install attempt.
	sudo apt-get update || true
	sudo apt-get install -y "${missing_pkgs[@]}"
elif command -v brew >/dev/null 2>&1; then
	brew install "${missing_pkgs[@]}"
elif command -v dnf >/dev/null 2>&1; then
	sudo dnf install -y "${missing_pkgs[@]}"
elif command -v pacman >/dev/null 2>&1; then
	sudo pacman -S --needed "${missing_pkgs[@]}"
else
	echo "No supported package manager found (apt-get/brew/dnf/pacman)."
	echo "Install manually: ${missing_pkgs[*]}"
	exit 1
fi
