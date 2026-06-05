------------------
---- MONITORS ----
------------------
-- Helper function to read if the physical laptop lid is open or closed
local function is_lid_open()
	-- Keep in mind that on dell the path is LID0 but it might differ on other laptops
	local path = "/proc/acpi/button/lid/LID0/state"
	local file = io.open(path, "r")
	if file then
		local content = file:read("*all")
		file:close()
		return string.find(content, "open") ~= nil
	end

	-- Safety fallback. Assume open
	return true
end

hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto-left",
	scale = 1,
	disabled = not is_lid_open()
})

hl.monitor({
	output   = "",
	mode     = "preferred",
	position = "auto",
	scale    = 1,
})

-- Trigger when the switch is turning on (Lid is CLOSED -> Turn display OFF)
hl.bind("switch:on:Lid Switch", function()
	hl.monitor({
		output = "eDP-1",
		mode = "preferred",
		position = "auto-left",
		scale = 1,
		disabled = true, -- important bit
	})
end, { locked = true })

-- Trigger when the switch is turning off (Lid is OPENED -> Turn display ON)
hl.bind("switch:off:Lid Switch", function()
	hl.monitor({
		output = "eDP-1",
		mode = "preferred",
		position = "auto-left",
		scale = 1,
		disabled = false, -- important bit
	})
end, { locked = true })

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "foot"
local fileManager = "yazi"
local menu        = "fuzzel"
local browser     = "firefox"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
	hl.exec_cmd("waybar & hyprpaper & hyprsunset")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("GTK_THEME", "Dracula")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
--

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in          = 3,
		gaps_out         = 5,

		border_size      = 2,

		col              = {
			active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = false,

		-- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
		allow_tearing    = false,

		layout           = "dwindle",
	},

	decoration = {
		rounding         = 10,
		rounding_power   = 2,

		-- Change transparency of focused and unfocused windows
		active_opacity   = 1.0,
		inactive_opacity = 1.0,

		shadow           = {
			enabled      = false,
			range        = 4,
			render_power = 3,
			color        = 0xee1a1a1a,
		},

		blur             = {
			enabled  = false,
			size     = 3,
			passes   = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = false,
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
	dwindle = {
		preserve_split = true, -- You probably want this
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
	master = {
		new_status = "master",
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
		disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
	},
})


---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout    = "us",
		kb_variant   = "",
		kb_model     = "",
		kb_options   = "caps:swapescape,compose:ralt",
		kb_rules     = "",

		follow_mouse = 1,

		sensitivity  = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad     = {
			natural_scroll = false,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
-- hl.device({
-- 	name        = "epic-mouse-v1",
-- 	sensitivity = -0.5,
-- })
--

-- TABLETS
hl.device({
	name = "xp-pen-star-g640",
	active_area_size = { 160, 90 },
	active_area_position = { 0, 5 },
})

hl.device({
	name = "hanvon-ugee-deco-lw-pen",
	active_area_size = { 254, 142.875 }, -- Spans full width; scales height down to perfect 16:9
	active_area_position = { 0, 4.76 }  -- Vertically centers the active area on your 152
})

local TABLET = "hanvon-ugee-deco-lw-pen"
local STATE_FILE = "/tmp/tablet_ultrawide_side"

local function toggle_tablet_profile()
	-- Grab all connected monitors natively
	local monitors = hl.get_monitors()
	local ultrawide_port = nil

	-- Find the port hosting the 3440x1440 resolution
	for _, m in ipairs(monitors) do
		if m.width == 3440 and m.height == 1440 then
			ultrawide_port = m.name
			break
		end
	end

	-- Decision Logic
	if ultrawide_port then
		-- THE ULTRAWIDE IS CONNECTED
		-- Read last state from the file tracker safely
		local f = io.open(STATE_FILE, "r")
		local last_state = "left"
		if f then
			last_state = f:read("*a"):match("%w+") or "left" -- Robustly extracts just the word
			f:close()
		end

		if last_state == "left" then
			hl.device({
				name = TABLET,
				output = ultrawide_port,
				region_size = { 2400, 1440 },
				region_position = { 1040, 0 },
			})

			-- Update state file
			local f_write = io.open(STATE_FILE, "w")
			if f_write then
				f_write:write("right")
				f_write:close()
			end

			hl.notification.create({
				text = "Ultrawide: Right-Aligned Workspace",
				timeout = 3000,
				icon = "ok"
			})
		else
			hl.device({
				name = TABLET,
				output = ultrawide_port,
				region_size = { 2400, 1440 },
				region_position = { 0, 0 },
			})

			-- Update state file
			local f_write = io.open(STATE_FILE, "w")
			if f_write then
				f_write:write("left")
				f_write:close()
			end

			hl.notification.create({
				text = "Ultrawide: Left-Aligned Workspace",
				timeout = 3000,
				icon = "ok"
			})
		end
	else
		-- UNIVERSAL 16:9 FALLBACK
		-- Grab the name of the currently focused monitor natively
		local current_port = "eDP-1" -- Safe baseline fallback
		local active_monitor = hl.get_active_monitor()
		if active_monitor then
			current_port = active_monitor.name
		end

		hl.device({
			name = TABLET,
			output = current_port,
			active_area_size = { 254, 142.875 }, -- Spans full width; scales height down to perfect 16:9
			active_area_position = { 0, 4.76 } -- Vertically centers the active area on your 152
		})

		hl.notification.create({
			text = "Standard 16:9 Aspect Ratio Mode",
			timeout = 3000,
			icon = "ok"
		})
	end
end

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + Y", toggle_tablet_profile);

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " -e " .. fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + U", hl.dsp.layout("togglesplit")) -- dwindle only

-- fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
-- Reset DE
hl.bind(mainMod .. " + R", function()
	hl.exec_cmd("pkill waybar; pkill hyprpaper; waybar & hyprpaper")
end
)

-- PDF opening shortcut
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(terminal .. " -e ~/.config/hypr/scripts/open_pdf.sh"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Also use vim bindings
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Swap windows
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Precision 1% adjustments (holding SUPER)
hl.bind(mainMod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"))
hl.bind(mainMod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"))
hl.bind(mainMod .. " + XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 1%+"))
hl.bind(mainMod .. " + XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 1%-"))

-- Screenshot
hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | wl-copy]]))
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | wl-copy]]))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name           = "suppress-maximize-events",
	match          = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name     = "fix-xwayland-drags",
	match    = {
		class      = "^$",
		title      = "^$",
		xwayland   = true,
		float      = true,
		fullscreen = false,
		pin        = false,
	},

	no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name  = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move  = "20 monitor_h-120",
	float = true,
})
