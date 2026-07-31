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

-- If a spawned shell dies immediately (missing binary, bad WSL domain,
-- broken flake env, etc), keep the pane open showing why instead of the
-- whole window silently vanishing. Still closes automatically on a normal
-- `exit`.
config.exit_behavior = "CloseOnCleanExit"

-- ============================================================================
-- Shell: launch fish inside WezTerm, but never break WezTerm if fish isn't
-- installed -- fall back to whatever WezTerm would otherwise use. This only
-- affects the native/local domain (Linux, macOS, or the Windows side of a
-- WSL setup) -- see the WSL bridge section below for the WSL case.
--
-- wezterm.run_child_process raises a Lua error (rather than just returning
-- false) when the program itself can't be found at all -- as opposed to
-- running and exiting non-zero, which it does report as a plain false. Since
-- "not installed" is exactly the case being checked for here, every call
-- goes through this pcall wrapper so a missing program can't crash config
-- loading.
-- ============================================================================
local function try_run(argv)
	local called_ok, success, stdout = pcall(wezterm.run_child_process, argv)
	if not called_ok then
		return false, nil
	end
	return success, stdout
end

local fish_ok = try_run({ "fish", "--version" })
if fish_ok then
	config.default_prog = { "fish", "-l" }
end

-- Note: the "cd into a repo with a flake.nix -> load its Nix dev shell"
-- behavior lives in the fish config (fish/conf.d/nix-flake-direnv.fish),
-- since it's the shell -- not WezTerm -- that reacts to `cd`. See the
-- top-level README for how it's wired together.

-- ============================================================================
-- WSL bridge (Windows only, no-op everywhere else)
--
-- This config file can live inside a WSL distro's filesystem while still
-- being loaded by the Windows build of WezTerm (via the WEZTERM_CONFIG_FILE
-- env var pointing at its \\wsl.localhost\... path -- see the README). In
-- that setup, the `default_prog` set above only affects the native Windows
-- domain, which isn't where fish/direnv/nix live -- it never touches WSL.
--
-- The obvious approach is a wsl_domains + default_domain config (each
-- installed distro gets its own named domain). That's what this used to do,
-- but WezTerm has a long-standing bug where a WSL domain's cwd handling can
-- resolve to an empty string on launch, which wsl.exe rejects outright
-- (Wsl/E_INVALIDARG), instead of falling back to default_cwd:
-- https://github.com/wezterm/wezterm/issues/2126
--
-- The workaround (used here, and the one documented in that issue thread)
-- is to skip wsl_domains and instead point default_prog at a fully-formed
-- wsl.exe invocation, with --cd ~ baked directly into argv so there's no
-- cwd-inheritance step for WezTerm to get wrong. This targets a single
-- distro (the first one found) rather than giving each installed distro its
-- own domain -- fine for the common single-distro case; if you have several
-- distros and want to pick between them, see WezTerm's wsl_domains docs and
-- reintroduce that instead.
-- ============================================================================
if wezterm.target_triple:find("windows") then
	local wsl_ok, wsl_out = try_run({ "wsl.exe", "-l", "-q" })
	if wsl_ok then
		-- `wsl -l -q` emits UTF-16LE when its output isn't a real console (as
		-- is the case here), i.e. every character is followed by a null byte.
		-- Strip those, then pull out runs of name-safe characters -- that
		-- sidesteps decoding it by hand and skips any BOM/control bytes, and
		-- works unchanged if the output turns out to be plain ASCII instead.
		local cleaned = wsl_out:gsub("%z", "")
		-- Docker Desktop's WSL2 backend registers its own hidden utility
		-- distros alongside real ones; they have no usable shell/home
		-- environment, so picking one as the default would spawn-fail
		-- immediately. Never treat them as candidates.
		local skip = { ["docker-desktop"] = true, ["docker-desktop-data"] = true }
		local distros = {}
		for name in cleaned:gmatch("[%w%.%-_]+") do
			if not skip[name] then
				table.insert(distros, name)
			end
		end

		if #distros > 0 then
			local distro = distros[1]

			-- Ask the distro who its actual default user is and pin it
			-- explicitly, rather than leaving it to wsl.exe's own default
			-- (which is not guaranteed to be your normal login user).
			local username = nil
			local who_ok, who_out = try_run({ "wsl.exe", "-d", distro, "--", "whoami" })
			if who_ok and who_out then
				local u = who_out:gsub("%z", ""):gsub("%s+", "")
				if u ~= "" then
					username = u
				end
			end

			local argv = { "wsl.exe", "--distribution", distro, "--cd", "~" }
			if username then
				table.insert(argv, "--user")
				table.insert(argv, username)
			end
			table.insert(argv, "--exec")
			table.insert(argv, "fish")
			table.insert(argv, "-l")
			config.default_prog = argv
		end
	end
end

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
