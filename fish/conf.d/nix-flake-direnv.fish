# Auto-provision direnv for any repo containing a flake.nix, so that cd-ing
# into it loads the flake's Nix dev shell with zero per-repo setup.
#
# What happens on cd:
#   1. Walk up from $PWD (bounded, stops at the nearest .git) looking for a
#      flake.nix.
#   2. If found and there's no .envrc yet, write one (`use flake`) and
#      `direnv allow` it once.
#   3. direnv's own fish hook (config.fish) takes over from there on every
#      later cd/prompt, loading and unloading the flake's dev shell
#      automatically as you move in and out of the directory tree.
#
# Gracefully does nothing if direnv or nix aren't installed, if you're not in
# a flake at all, or if the flake fails to evaluate -- direnv reports
# failures to stderr without breaking the shell.
#
# Note: this auto-runs `direnv allow`, which lets `nix develop`/`nix
# print-dev-env` (and therefore arbitrary code from flake.nix) execute the
# first time you cd into a new flake repo, without the usual manual
# confirmation step. That's the point (fully automatic), but it does mean
# you're trusting any flake.nix you cd into. Remove the `direnv allow` line
# below if you'd rather review and allow each repo by hand.
function __wezterm_nix_flake_autoload --on-variable PWD --description 'Auto-provision direnv for Nix flakes'
    status --is-command-substitution
    and return

    command -q direnv
    or return
    command -q nix
    or return

    set -l dir $PWD
    for depth in (seq 1 8)
        test -e "$dir/.envrc"
        and return

        if test -e "$dir/flake.nix"
            echo "use flake" >"$dir/.envrc"
            direnv allow "$dir" >/dev/null 2>&1
            return
        end

        test -e "$dir/.git"
        and return

        set -l parent (command dirname "$dir")
        test "$parent" = "$dir"
        and return
        set dir $parent
    end
end

# Also run for the shell's starting directory, not just on later `cd`s.
__wezterm_nix_flake_autoload
