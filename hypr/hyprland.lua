-- Hyprland Lua configuration migrated from hyprland.conf
-- Target: Hyprland 0.55+ Lua configuration API.
--
-- IMPORTANT:
--   1. Hyprland 0.55+ prefers this file over hyprland.conf.
--   2. monitors.lua and workspaces.lua are loaded as Lua modules below.
--
-- References:
--   https://wiki.hypr.land/Configuring/Start/
--   https://wiki.hypr.land/Configuring/Basics/Variables/
--   https://wiki.hypr.land/Configuring/Basics/Binds/
require("monitors")

local HOME = os.getenv("HOME")

-- ---------------------------------------------------------------------------
-- Compatibility helper for the existing pywal colors file.
-- The original config sourced a hyprlang file containing variables such as
-- $color5 and $color9. Lua cannot source that file as Lua, so we parse those
-- simple $name = value assignments here.
-- ---------------------------------------------------------------------------

local function read_hyprlang_vars(path)
    local vars = {}
    local file = io.open(path, "r")
    if not file then
        return vars
    end

    for line in file:lines() do
        local name, value = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
        if name and value then
            vars[name] = value
        end
    end

    file:close()
    return vars
end

local wal = read_hyprlang_vars(HOME .. "/.cache/wal/colors-hyprland")

-- Keep the old $color9 / $color5 references.
local color9 = wal.color9 or "rgba(ffffffaa)"
local color5 = wal.color5 or "rgba(888888aa)"

-- Match the workspace dots: color1 = active, color2 = inactive non-empty.
local activeBorder = wal.color1 or color9
local inactiveBorder = wal.color2 or color5

-- The shell's style (the wallpaper picker's Paper/Glass switch, saved by Theme.qml, which sets the
-- same window opacity live): every window opaque on paper, see-through on glass (and before a style
-- has been picked)
local function quickshell_style()
    local file = io.open(HOME .. "/.cache/quickshell-style", "r")
    if not file then
        return nil
    end
    local value = file:read("*l")
    file:close()
    return value
end
local paper = quickshell_style() == "paper"

-- ---------------------------------------------------------------------------
-- External configs
-- ---------------------------------------------------------------------------
-- monitors.lua is required at the top of this file.
-- workspaces.conf exists but is empty; no Lua counterpart is needed.

-- ---------------------------------------------------------------------------
-- Programs / variables
-- ---------------------------------------------------------------------------

local terminal = "kitty"
local fileManager = "nautilus"



local mainMod = "SUPER"

-- ---------------------------------------------------------------------------
-- Plugin loading
-- ---------------------------------------------------------------------------
-- IMPORTANT: plugin configuration must be registered after the plugin exists.
-- The old hyprland.conf loaded this during exec-once, which happens too late
-- for plugin.* keys in a Lua config.
local dynamicCursorsPlugin =
    HOME .. "/.local/share/hyprpm/dynamic-cursors/dynamic-cursors.so"

hl.plugin.load(dynamicCursorsPlugin)


-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------

-- The GPUs with a monitor plugged in (looked up at every start; the cards' numbers can change between
-- boots): Hyprland uses only those, and renders on the first, a non-NVIDIA one (the integrated GPU)
-- when there is one. The NVIDIA settings are only for when it renders on an NVIDIA card; otherwise
-- apps render on the integrated GPU too, not through NVIDIA's libraries.
local function display_gpus()
    local gpus, seen = {}, {}
    local list = io.popen("grep -l '^connected$' /sys/class/drm/card*-*/status 2>/dev/null")
    for path in list:lines() do
        local card = path:match("/(card%d+)%-")
        if card and not seen[card] then
            seen[card] = true
            local uevent = io.open("/sys/class/drm/" .. card .. "/device/uevent", "r")
            local driver = uevent and uevent:read("*a"):match("DRIVER=(%S+)")
            if uevent then uevent:close() end
            table.insert(gpus, { device = "/dev/dri/" .. card, driver = driver })
        end
    end
    list:close()
    table.sort(gpus, function(a, b)
        if (a.driver == "nvidia") ~= (b.driver == "nvidia") then return b.driver == "nvidia" end
        return a.device < b.device
    end)
    return gpus
end
local gpus = display_gpus()
local gpu = gpus[1]   -- the one Hyprland renders on
if gpu then
    local devices = {}
    for _, g in ipairs(gpus) do table.insert(devices, g.device) end
    hl.env("AQ_DRM_DEVICES", table.concat(devices, ":"))
end

if not gpu or gpu.driver == "nvidia" then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("WLR_DRM_NO_ATOMIC", "1")
else
    hl.env("LIBVA_DRIVER_NAME", "radeonsi")   -- (/etc/environment says nvidia)
end
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

-- ---------------------------------------------------------------------------
-- General / input / decoration / misc
-- ---------------------------------------------------------------------------

hl.config({
    general = {
        gaps_in = 8,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border   = activeBorder,
            inactive_border = inactiveBorder,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    cursor = {
        inactive_timeout = 5,
        no_hardware_cursors = true,
    },

    decoration = {
        rounding = 10,
        active_opacity = paper and 1.0 or 0.9,      -- Paper/Glass (see quickshell_style above)
        inactive_opacity = paper and 1.0 or 0.75,
        fullscreen_opacity = 1.0,

        blur = {
            enabled = true,
            size = 3,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
            -- blur only the (cached) wallpaper, not whatever is behind each window, so most blur is
            -- computed once; overlays (special workspaces, the launcher's column) opt out below to show
            -- the windows behind them
            xray = true,
            popups = true,
        },

        shadow = {
            enabled = true,
            range = 24,
            render_power = 2,
            offset = "0 6",
            color = "rgba(000000d9)",
            color_inactive = "rgba(00000000)",
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        focus_on_activate = true,
        vrr = 0,
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
        },
    },

    xwayland = {
        force_zero_scaling = true,
    },

})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = 0,
})

-- ---------------------------------------------------------------------------
-- Dynamic cursors plugin
-- ---------------------------------------------------------------------------
-- hypr-dynamic-cursors uses the Lua plugin namespace `dynamic_cursors`
-- (underscore, not the legacy hyprlang `dynamic-cursors` spelling).
--
-- Its current Lua API also changed two details from the old .conf syntax:
--   * stretch.function -> stretch.activation
--   * shaperule -> hl.plugin.dynamic_cursors.shape_rule(...)
--
-- The plugin itself recommends guarding configuration with this check so a
-- missing/unloadable plugin does not create config errors.

if hl.plugin.dynamic_cursors then
    hl.config({
        plugin = {
            dynamic_cursors = {
                mode = "stretch",
                threshold = 2,

                rotate = {
                    length = 12,
                    offset = 30,
                },

                stretch = {
                    limit = 1000,
                    activation = "negative_quadratic",
                },

                shake = {
                    enabled = false,
                },
            },
        },
    })

    hl.plugin.dynamic_cursors.shape_rule({
        shape = "grab",
        mode = "stretch",
        stretch = {
            limit = 2000,
        },
    })
end

-- ---------------------------------------------------------------------------
-- Animations
-- ---------------------------------------------------------------------------

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("fluid", {
    type = "bezier",
    points = {
        { 0.15, 0.85 },
        { 0.25, 1.0 },
    },
})

hl.curve("snappy", {
    type = "bezier",
    points = {
        { 0.3, 1.0 },
        { 0.4, 1.0 },
    },
})

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 3,
    bezier = "fluid",
    style = "popin 5%",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 2.5,
    bezier = "snappy",
})

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 4,
    bezier = "snappy",
})

-- ease-out quint, as in Quickshell's panels: starts fast and slows gently, so the slide doesn't
-- cover most of the screen in its first few frames
hl.curve("outQuint", {
    type = "bezier",
    points = {
        { 0.22, 1.0 },
        { 0.36, 1.0 },
    },
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 4.5,
    bezier = "outQuint",
    style = "slide",
})

hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 4,
    bezier = "fluid",
    style = "slidefadevert -35%",
})

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 2,
    bezier = "snappy",
    style = "popin 70%",
})

-- ---------------------------------------------------------------------------
-- Autostart
-- ---------------------------------------------------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl dispatch dpms off && sleep 0.5 && hyprctl dispatch dpms on")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start sysstatsd.service")
    hl.exec_cmd("QS_ICON_THEME=Adwaita qs")  -- Quickshell: the bar, panels and app launcher (Adwaita finds icons the default theme misses)
    hl.exec_cmd("wpaperd -d -c " .. HOME .. "/.config/hypr/wpaperd.toml")
    hl.exec_cmd("swaync")
    hl.exec_cmd("pypr")
    hl.exec_cmd("swaync-client -df")
    hl.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ 0")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- ---------------------------------------------------------------------------
-- Keybinds: workspaces
-- ---------------------------------------------------------------------------

for i = 1, 10 do
    local key = i % 10
    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i })
    )
end

hl.bind(mainMod .. " + SHIFT + S",
    hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + S",
    hl.dsp.workspace.toggle_special("magic"))

-- ---------------------------------------------------------------------------
-- Keybinds: applications / window actions
-- ---------------------------------------------------------------------------

hl.bind(mainMod .. " + B", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("pypr toggle music"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call mpvpaper toggle"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("mpv $(wl-paste)"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("pavucontrol"))

-- Switch the style between paper (everything opaque) and glass (see-through), as in the wallpaper picker.
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call theme toggleStyle"))

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("qs ipc call stats toggle"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("pypr toggle term"))

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))

-- Hide the shell and let the tiled windows take its space.
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("qs ipc call shell toggle"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs ipc call overview toggle"))   -- workspace overview

hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))

-- Cycle through every workspace, including the empty ones. The built-in
-- "e-1"/"e+1" only ever lands on workspaces that have windows in them, so the
-- next id is computed here instead.
local WORKSPACE_COUNT = 10

local function cycle_workspace(delta)
    local id = hl.get_active_workspace().id
    if id < 1 or id > WORKSPACE_COUNT then
        id = delta > 0 and 0 or WORKSPACE_COUNT + 1
    end
    hl.dispatch(hl.dsp.focus({ workspace = (id - 1 + delta) % WORKSPACE_COUNT + 1 }))
end

hl.bind(mainMod .. " + CTRL + left",
    function() cycle_workspace(-1) end)

hl.bind(mainMod .. " + CTRL + right",
    function() cycle_workspace(1) end)


-- Screenshots
-- Capture selected region to clipboard
hl.bind("SUPER + W", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- Capture selected region and edit
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd('grim -g "$(slurp)" - | satty --filename -'))

-- ---------------------------------------------------------------------------
-- Special workspaces
-- ---------------------------------------------------------------------------

hl.bind("ALT + 1", hl.dsp.workspace.toggle_special("one"))
hl.bind("ALT + SHIFT + 1",
    hl.dsp.window.move({ workspace = "special:one" }))

hl.bind("ALT + 2", hl.dsp.workspace.toggle_special("two"))
hl.bind("ALT + SHIFT + 2",
    hl.dsp.window.move({ workspace = "special:two" }))

hl.bind("ALT + 3", hl.dsp.workspace.toggle_special("three"))
hl.bind("ALT + SHIFT + 3",
    hl.dsp.window.move({ workspace = "special:three" }))

hl.bind("ALT + 4", hl.dsp.workspace.toggle_special("four"))
hl.bind("ALT + SHIFT + 4",
    hl.dsp.window.move({ workspace = "special:four" }))

-- ---------------------------------------------------------------------------
-- Miscellaneous binds
-- ---------------------------------------------------------------------------

hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m window -o ~/Screenshots/"))
hl.bind("ALT + Print",
    hl.dsp.exec_cmd("hyprshot -m active -m output -o ~/Screenshots/"))
hl.bind("ALT + F4", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind("ALT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind("ALT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind("ALT + r", hl.dsp.exec_cmd("~/.config/swaync/refresh.sh"))
hl.bind("ALT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind("ALT + t",
    hl.dsp.exec_cmd("/home/shubham/Downloads/trilium-linux-x64/trilium"))
hl.bind("ALT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("ALT + w", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind("CTRL + Print",
    hl.dsp.exec_cmd("hyprshot -m region -o ~/Screenshots/"))

-- Mouse binds.
hl.bind(mainMod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true })

hl.bind(mainMod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true })

-- ---------------------------------------------------------------------------
-- Media / brightness binds
-- ---------------------------------------------------------------------------

hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })

hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })

hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true })

hl.bind("XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true })

hl.bind("XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl s 10%+"),
    { locked = true, repeating = true })

hl.bind("XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl s 10%-"),
    { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- ---------------------------------------------------------------------------
-- Window rules
-- ---------------------------------------------------------------------------

hl.window_rule({
    match = { class = "firefox" },
    opacity = "1.0",
})

hl.window_rule({
    match = { class = "^(kitty-)(.*)" },
    float = true,
})

-- Blur behind the Quickshell frame and panels (the glass style makes them see-through).
-- ignore_alpha sits just under the frame's own opacity (saved by Quickshell), so only the frame is
-- blurred: not the transparent rest of the screen-sized surface, and not the frame's fainter
-- anti-aliased edge pixels, where the blur would pull light from under the frame into a thin line
-- along its curves. Quickshell sets the same rule live when the opacity changes (Theme.qml).
local function quickshell_opacity()
    local file = io.open(HOME .. "/.cache/quickshell-opacity", "r")
    if not file then
        return 1
    end
    local value = tonumber(file:read("*l"))
    file:close()
    return value or 1
end

hl.layer_rule({
    name = "quickshell-blur",
    match = { namespace = "^qs-(shell|region-stats|region-left|region-top)$" },
    blur = true,
    xray = true,   -- blur the cached wallpaper only (see decoration.blur.xray)
    ignore_alpha = quickshell_opacity() * 0.9,
})

-- the wallpaper picker shows the windows behind it. (The left column's panels used to as well, but each
-- surface is blurred on its own, and that blur took in the frame band next to them: a lighter line along
-- their edges, and a square round the frame's left corners.)
hl.layer_rule({
    name = "quickshell-blur-wall",
    match = { namespace = "^qs-region-wall$" },
    blur = true,
    xray = false,
    ignore_alpha = quickshell_opacity() * 0.9,
})

-- windows on special workspaces (Super+S, Alt+1-4) show the workspace behind them instead of just
-- the wallpaper
hl.window_rule({
    name = "special-see-through",
    match = { workspace = "s[true]" },
    xray = false,
})

-- so do the pyprland scratchpads, which are moved onto the current workspace while shown
hl.window_rule({
    name = "scratchpad-see-through",
    match = { class = "^kitty-(dropterm|pulsemixer)$" },
    xray = false,
})

-- pyprland scratchpads (drop terminal, ...) come up with a magenta
-- border unless it is set explicitly.
hl.window_rule({
    name = "scratchpad-border",   -- wallpaper.sh replaces it by name with the new palette's colors
    match = { class = "^kitty-.*$" },
    border_color = activeBorder .. " " .. inactiveBorder,
})

hl.window_rule({
    match = { class = "jetbrains-idea" },
    opacity = "1.0",
})
