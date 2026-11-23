-- Hyprland >= 0.55 reads ONLY Lua. ~/.config/hypr/hyprland.lua is a symlink to this file;
-- if it is missing Hyprland regenerates the stock default over your setup.
-- 0 animacji, 0 bloatu, 0 pasków, zawsze pełen ekran, 0 gapów.
-- mainMod + mouse hold = floating window; lshift + rshift = pl/gb; ctrl+alt+F1..F5 = tty.

local terminal = "foot"
local menu     = os.getenv("HOME") .. "/.config/src/menu"
local wsswitch = os.getenv("HOME") .. "/.config/src/workspcswitch"
local mainMod  = "SUPER"

hl.env("XDG_DATA_DIRS", "/data/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")
hl.env("FLATPAK_USER_DIR", "/data/flatpak")
hl.env("MOZ_ENABLE_WAYLAND", "1")

hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/autostart/run")
end)

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
        allow_tearing = true,
    },
    misc = {
        disable_autoreload = true,
        -- THEME:BEGIN background - generowane przez ~/dev/rice/theme, nie edytuj recznie
        background_color = 0x000000,
        -- THEME:END background
        disable_hyprland_logo = true,
        enable_swallow = false,
    },
    decoration = {
        -- THEME:BEGIN rounding - generowane przez ~/dev/rice/theme, nie edytuj recznie
        rounding = 0,
        -- THEME:END rounding
    },
    input = {
        kb_layout = "pl,gb",
        kb_options = "grp:shifts_toggle",
    },
    animations = { enabled = false },
})

hl.monitor({ output = "DVI-D-1", mode = "preferred", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1",    mode = "preferred", position = "1920x0", scale = 1 })

for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DVI-D-1", default = (i == 1) })
end
for i = 6, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1", default = (i == 6) })
end

-- volume
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd([[wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+ && notify-send -t 800 -u low -h string:x-dunst-stack-tag:vol "Volume" "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d%%", $2*100}')"]]))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd([[wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && notify-send -t 800 -u low -h string:x-dunst-stack-tag:vol "Volume" "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d%%", $2*100}')"]]))

hl.bind(mainMod .. " + W",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Q",      hl.dsp.window.kill())
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))

-- okna
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

-- monitor
hl.bind(mainMod .. " + comma",         hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + period",        hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "r" }))

-- workspace (oba monitory jednoczesnie)
hl.bind(mainMod .. " + Z",         hl.dsp.exec_cmd(wsswitch .. " prev"))
hl.bind(mainMod .. " + X",         hl.dsp.exec_cmd(wsswitch .. " next"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(wsswitch .. " move_prev"))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(wsswitch .. " move_next"))

-- mouse: float + drag / resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- tty
for _, n in ipairs({ 1, 3, 4, 5 }) do
    hl.bind("CTRL + ALT + F" .. n, hl.dsp.exec_cmd("chvt " .. n))
end
