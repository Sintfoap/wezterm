# wezterm config

Personal [WezTerm](https://wezterm.org/) setup: fish as the default shell,
automatic Nix flake dev shells, and a couple of QoL defaults.

## Layout

```
wezterm.lua                    WezTerm config (appearance, keys, plugins)
fish/config.fish                fish config (direnv hook)
fish/conf.d/nix-flake-direnv.fish   auto-provisions direnv for flake.nix repos
direnv/direnvrc                 adds `use flake` support to direnv
install.sh                      symlinks the above into ~/.config
```

`wezterm.lua` sits at the repo root on purpose, so this works with either
way of getting it onto your machine:

- **Cloned straight into `~/.config/wezterm`** (WezTerm's own recommended
  pattern) — `wezterm.lua` is already exactly where WezTerm looks for it.
  Still run `./install.sh` from inside that clone to wire up the fish and
  direnv pieces, which need to land under `~/.config/fish` and
  `~/.config/direnv` instead.
- **Cloned anywhere else** — run `./install.sh` and everything, including
  `wezterm.lua`, gets symlinked into place.

## Install

```sh
./install.sh
```

Symlinks each file into `$XDG_CONFIG_HOME` (defaults to `~/.config`). It
won't overwrite a file that's already there — it prints `skip:` instead so
you can merge by hand if you already have configs in place. If a file is
already exactly where it needs to be (e.g. `wezterm.lua` when cloned
directly into `~/.config/wezterm`), it prints `ok:` and leaves it alone.

Requires on `PATH`: `wezterm`, `fish`, `direnv`, `nix` (with flakes enabled),
and optionally `zoxide`. Any of these being missing degrades gracefully at
runtime rather than breaking your shell — see below.

## What's in it

**WezTerm** (`wezterm.lua`)
- Catppuccin Mocha color scheme, JetBrains Mono font, sane padding/scrollback.
- `default_prog` launches `fish -l`, but only if `fish --version` actually
  succeeds at config-load time — otherwise WezTerm falls back to its normal
  default shell instead of failing to open a pane. On Windows-plus-WSL setups
  this is superseded by the WSL bridge section below.
- A `CTRL+a` leader key with tmux-style pane/tab bindings (`leader |`/`-` to
  split, `leader h/j/k/l` to move between panes, `leader c` new tab, etc).
- [resurrect.wezterm](https://github.com/StephenGemin/resurrect.wezterm) —
  session persistence (tmux-resurrect for WezTerm). One `setup()` call gives
  you autosave every 15 minutes and on focus loss, restore on startup, a
  status-bar indicator, and its own workspace create/save/restore
  keybindings (`Alt+Shift+N` new workspace, `Alt+W` save, `Alt+R` fuzzy
  restore, etc — full list in its README). This is a maintained fork; the
  original `MLFlexer/resurrect.wezterm` was archived in 2026.

**fish + direnv + Nix** (`fish/`, `direnv/`)

The actual "cd into a repo → get its Nix dev shell" behavior is a shell
concern, not a WezTerm one, so it lives in fish:

1. `fish/conf.d/nix-flake-direnv.fish` runs on every `cd`. It looks in the
   current directory and walks upward (stopping at the nearest `.git`) for a
   `flake.nix`. If it finds one and there's no `.envrc` yet, it writes
   `use flake` into one and runs `direnv allow` on it, once.
2. From then on, direnv's own fish hook (wired up in `fish/config.fish`)
   handles loading and unloading that flake's dev shell automatically as you
   move in and out of the directory — no further action needed.
3. `direnv/direnvrc` defines `use_flake`, so `.envrc` files with `use flake`
   work with plain direnv + nix, no extra tooling required.

`fish/config.fish` also sets up [zoxide](https://github.com/ajeetdsouza/zoxide)
if it's installed: `z <partial name>` jumps to your most-visited matching
directory (a maintained, faster rewrite of the classic `z`; `zi` gives an
interactive picker). No config changes needed — install the `zoxide` binary
and it's picked up automatically.

**Gracefully skips itself** if `direnv` or `nix` aren't on `PATH`, if the
directory isn't a flake, or if the flake fails to evaluate — direnv reports
failures to stderr on your next prompt without breaking the shell.

**Security note:** this auto-runs `direnv allow` the first time you cd into
a new flake repo, which lets its `flake.nix` execute via `nix develop` /
`nix print-dev-env` without the usual manual confirmation step. That's the
tradeoff for it being fully automatic — you're implicitly trusting any
flake.nix you cd into. If you'd rather review each new repo by hand, delete
the `direnv allow "$dir" >/dev/null 2>&1` line in
`fish/conf.d/nix-flake-direnv.fish`; direnv will then just prompt you to run
`direnv allow` yourself the first time.

**Optional upgrade:** installing
[nix-direnv](https://github.com/nix-community/nix-direnv) (e.g. via
`home-manager` or `nix profile install nixpkgs#nix-direnv`) gives you a
faster, caching `use flake` implementation and takes over automatically —
nothing here needs to change.

## WSL setup (Windows + this config living inside a WSL distro)

If WezTerm itself is the **Windows** build (check with `where wezterm.exe`
in PowerShell — this is what you get from the normal WezTerm installer) but
this repo lives inside a WSL distro's filesystem, Windows `wezterm.exe`
won't find `wezterm.lua` on its own: it looks in your Windows user profile
by default, not inside WSL.

Point it at the file explicitly with the `WEZTERM_CONFIG_FILE` environment
variable, set on the **Windows** side:

1. Find your distro name and confirm the config path, from PowerShell:
   ```powershell
   wsl -l -v
   wsl -e bash -lc "wslpath -w ~/.config/wezterm/wezterm.lua"
   ```
   The second command must go through `bash -lc` like this -- `wsl -e wslpath
   -w ~/...` (without a shell in between) never expands the `~`, since `-e`
   runs the program directly instead of through a shell. That silently
   produces a bogus relative path instead of erroring, which is exactly what
   causes the confusing "file not found" loop below if you copy it in
   anyway. The `bash -lc` form prints the real Windows-style path to paste
   below (something like
   `\\wsl.localhost\Ubuntu\home\interstellar\.config\wezterm\wezterm.lua`).
2. Set the env var permanently (PowerShell, then close and reopen any
   terminal for it to take effect):
   ```powershell
   setx WEZTERM_CONFIG_FILE "\\wsl.localhost\Ubuntu\home\interstellar\.config\wezterm\wezterm.lua"
   ```
   (swap in the exact path from step 1 if it differs.)

Once that's set, `wezterm.lua`'s WSL bridge section takes over: it asks
Windows for your installed WSL distros (`wsl.exe -l -q`), builds a
`wsl_domains` entry for each one with `fish -l` as that domain's shell, and
sets `default_domain` to the first one it finds — so every new window, tab,
or split opens straight into WSL running fish, instead of PowerShell. The
plain `default_prog` fish check further up the file only affects the native
Windows domain, which you'll rarely land in with this set.

This step degrades gracefully too: if `WEZTERM_CONFIG_FILE` isn't set,
Windows WezTerm just uses its normal config location and none of this
applies. If `wsl.exe` isn't found or no distro is detected, the WSL bridge
section is a no-op and WezTerm behaves like a stock Windows terminal.

Everything else — the fish config, the nix-flake-direnv auto-load, the
direnv setup — still needs `fish`, `direnv`, and `nix` installed **inside**
WSL (not Windows), since that's where they actually run once a pane lands
there.

## Adding more plugins

Kept this to one WezTerm plugin deliberately since it already covers
sessions, workspaces, and the status bar. Browse
[michaelbrusegard/awesome-wezterm](https://github.com/michaelbrusegard/awesome-wezterm)
if you want more (tab-bar themes, smart-splits, etc) — add them the same way,
with `wezterm.plugin.require(...)` in `wezterm.lua`.
