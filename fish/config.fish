if status is-interactive
    # Quiet down -- WezTerm's own UI already tells you what's going on.
    set -g fish_greeting

    # direnv: loads/unloads per-directory environments automatically. This is
    # what actually makes `cd`-ing into a Nix flake repo pick up its dev
    # shell -- see fish/conf.d/nix-flake-direnv.fish for how the .envrc gets
    # created in the first place.
    if command -q direnv
        direnv hook fish | source
    end
end
