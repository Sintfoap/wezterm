local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ============================================================================
-- Appearance
-- ============================================================================
config.color_scheme = "Catppuccin Mocha"
config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	"JetBrainsMono Nerd Font",
})
config.font_size = 13.0
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.hide_tab_bar_if_only_one_tab = true
config.scrollback_lines = 10000
config.audible_bell = "Disabled"
config.adjust_window_size_when_changing_font_size = false

-- ============================================================================
-- Shell: launch fish inside WezTerm, but never break WezTerm if fish isn't
-- installed -- fall back to whatever WezTerm would otherwise use.
-- ============================================================================
local fish_ok = wezterm.run_child_process({ "fish", "--version" })
if fish_ok then
	config.default_prog = { "fish", "-l" }
end

-- Note: the "cd into a repo with a flake.nix -> load its Nix dev shell"
-- behavior lives in the fish config (fish/conf.d/nix-flake-direnv.fish),
-- since it's the shell -- not WezTerm -- that reacts to `cd`. See the
-- top-level README for how it's wired together.

-- ============================================================================
-- Leader key + basic tmux-style pane/tab bindings
-- ============================================================================
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
	-- Panes
	{ key = "|", mods = "LEADER|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "z", mods = "LEADER", action = wezterm.action.TogglePaneZoomState },

	-- Tabs
	{ key = "c", mods = "LEADER", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "n", mods = "LEADER", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = wezterm.action.ActivateTabRelative(-1) },
}

-- ============================================================================
-- Plugins
--
-- resurrect.wezterm: tmux-resurrect-style session persistence. Autosaves
-- workspaces/windows/tabs periodically and on focus loss, restores on
-- startup, and adds its own workspace create/save/restore keybindings
-- (Alt+Shift+N, Alt+W, Alt+R, ...) plus a status-bar indicator. One plugin
-- covers session persistence, workspace switching, and status bar, which is
-- why there's only one here.
--
-- The original MLFlexer/resurrect.wezterm was archived in 2026; this uses
-- the actively maintained StephenGemin fork instead (same API).
-- ============================================================================
local resurrect = wezterm.plugin.require("https://github.com/StephenGemin/resurrect.wezterm")
resurrect.setup(config, {
	periodic_interval = 15 * 60,
	save_on_focus_loss = true,
	status_bar = true,
})

return config
