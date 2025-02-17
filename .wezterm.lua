require("color_schemes")
require("events")
require("keymaps")
require("mousemaps")

local wezterm = require("wezterm")
local config = require("config")

local color_schemes = wezterm.get_builtin_color_schemes()
for k, v in pairs(config.color_schemes) do
	color_schemes[k] = v
end

-- config.color_scheme = "Tokyo Night Storm"
-- config.color_scheme = "Tokyo Night Moon"
-- config.color_scheme = "Tokyo Night"
-- config.color_scheme = "Catppuccin Frappe"
-- config.color_scheme = "Catppuccin Macchiato"
-- config.color_scheme = "Catppuccin Mocha"
config.color_scheme = "GruvboxDarkHard"
-- config.color_scheme = "Matrix (terminal.sexy)"

config.font_size = 14
config.font = wezterm.font_with_fallback({
	{ family = "BigBlueTermPlus Nerd Font", weight = "Regular" },
	-- { family = "BigBlueTerm437 Nerd Font", weight = "Regular" },
	-- { family = "Cartograph CF", weight = "Regular" },
	-- { family = "ComicShannsMono Nerd Font", weight = "Regular" },
	-- { family = "Fira Code", weight = "Regular" },
	-- { family = "ProggyClean Nerd Font", weight = "Regular" },
	-- { family = "ShureTechMono Nerd Font", weight = "Regular" },
	-- { family = "Terminess Nerd Font", weight = "Regular" },
	-- { family = "UbuntuMono Nerd Font", weight = "Regular" },
})

config.adjust_window_size_when_changing_font_size = false
config.bold_brightens_ansi_colors = "BrightAndBold"
config.default_cursor_style = "BlinkingBlock"
config.enable_scroll_bar = false
-- config.enable_wayland = true
config.exit_behavior_messaging = "Verbose"
-- config.front_end = "OpenGL" -- ["OpenGL", "Software", "WebGpu"]
config.hide_mouse_cursor_when_typing = true
config.hide_tab_bar_if_only_one_tab = false
-- config.macos_window_background_blur = 0
config.max_fps = 144
config.mouse_wheel_scrolls_tabs = false
config.native_macos_fullscreen_mode = true
config.scrollback_lines = 100000
config.show_tab_index_in_tab_bar = true
config.tab_bar_at_bottom = false
-- config.term = "wezterm"
config.use_fancy_tab_bar = true
config.webgpu_power_preference = "HighPerformance"
-- config.webgpu_preferred_adapter = wezterm.gui.enumerate_gpus()[2]
-- config.window_background_opacity = 1
-- config.window_close_confirmation = "NeverPrompt"
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
-- config.window_padding = { left = 10, right = 10, top = 25, bottom = 10 }
config.window_padding = { left = 0, right = 0, top = 10, bottom = 0 }

-- Determine system path.
local dotfiles_path = "~/.dotfiles/images/wezterm-wallpapers/"
if wezterm.target_triple:match("windows") then
	dotfiles_path = "\\\\wsl.localhost\\Arch\\home\\chev\\.dotfiles\\images\\wezterm-wallpapers\\"
	config.wsl_domains = {
		{
			name = "WSL:Arch",
			distribution = "Arch",
			username = "chev",
			default_cwd = "/home/chev",
		},
	}
	config.default_domain = "WSL:Arch"
	config.default_cwd = "/home/chev"
	-- config.default_prog = { "wsl.exe" }
	config.win32_system_backdrop = "Disable" -- ["Auto", "Acrylic", "Mica", "Tabbed" "Disable"]
elseif wezterm.target_triple:match("darwin") then
	dotfiles_path = "/Users/alexford/.dotfiles/images/wezterm-wallpapers/"
end

local function get_random_wallpaper()
	-- Get random wallpaper image.
	local wallpapers = wezterm.read_dir(dotfiles_path)
	if #wallpapers > 0 then
		math.randomseed(os.time())
		return wallpapers[math.random(#wallpapers)]
	end
	return nil
end

-- if wallpaper then
config.background = {
	{
		source = {
			File = get_random_wallpaper(),
		},
		opacity = 1,
		attachment = "Fixed",
		repeat_x = "NoRepeat",
		repeat_y = "NoRepeat",
		vertical_align = "Bottom",
		horizontal_align = "Center",
		height = "Cover",
		width = "Cover",
	},
	{
		source = {
			Color = color_schemes[config.color_scheme].background,
		},
		opacity = 0.9,
		width = "100%",
		height = "100%",
	},
}
-- end

return config
