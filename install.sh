#!/usr/bin/env bash
# Symlinks this repo's configs into place under $XDG_CONFIG_HOME (~/.config).
# Safe to re-run: it only ever links files that are missing or already point
# here, and refuses to clobber a real pre-existing file.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

link() {
	local src="$1" dest="$2"
	mkdir -p "$(dirname "$dest")"
	if [ -e "$dest" ] || [ -L "$dest" ]; then
		if [ "$(realpath "$dest" 2>/dev/null || true)" = "$(realpath "$src")" ]; then
			echo "ok:   $dest (already in place)"
			return
		fi
		echo "skip: $dest already exists (not touching it)"
		return
	fi
	ln -s "$src" "$dest"
	echo "linked: $dest -> $src"
}

# If this repo was cloned directly into ~/.config/wezterm, wezterm.lua is
# already sitting exactly where WezTerm looks for it -- the check above
# turns this into a no-op "ok" rather than a spurious "skip".
link "$repo_dir/wezterm.lua" "$config_home/wezterm/wezterm.lua"
link "$repo_dir/fish/config.fish" "$config_home/fish/config.fish"
link "$repo_dir/fish/conf.d/nix-flake-direnv.fish" "$config_home/fish/conf.d/nix-flake-direnv.fish"
link "$repo_dir/direnv/direnvrc" "$config_home/direnv/direnvrc"

echo
echo "Done. Requires on PATH: wezterm, fish, direnv, nix (with flakes enabled)."
echo "Anything missing is skipped gracefully at runtime, but install it to get the full setup."
