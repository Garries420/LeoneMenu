-- Module: F:\2025\EDrive\dev\luapack\src\components\PedCounter.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")

local CONFIG_PATH = "config/Leone Menu/pedcounter.json"

local default_data = {
    overlay = Overlay.setup_overlay_defaults(
        true,
        0.999,
        0.978,
        15,
        5,
        0,
        1,
        true,
        { 0, 0, 0, 0.588 },
        false,
        { 0, 0, 0, 0.588 }
    ),
}
default_data.overlay.display_outside_interiors = imgui.new.bool(true)

local _config = default_data

local PedCounter = {}

function PedCounter:get_active_slots()
    return sampGetPlayerCount(true) - 1
end

function PedCounter:register()
    carboneum.load(CONFIG_PATH, _config)

    MainWindow:add_page("ped_counter", {
        icon = fa("PERSON_WALKING"),
        title = "Ped Counter",
        icon_box_color = imgui.ImVec4(0.2, 0.7, 0.5, 1),
        render_function = PedCounter.render_ui_settings
    })
end

function PedCounter:get_config()
    return _config
end

function PedCounter:get_overlay_config()
    return _config.overlay
end

function PedCounter:save_config()
    return carboneum.save(CONFIG_PATH, _config)
end

function PedCounter:render_ui_settings()
    imgui.DrawChild("Ped Counter", function(width)
        imgui.Text("Show overlay with active ped slot count")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##active_ped_slots", _config.overlay.display)

        if _config.overlay.display[0] then
            imgui.Separator()

            imgui.Text("Enable overlay outside interiors")
            imgui.SameLine(width - imgui.ToggleButtonWidth())
            imgui.ToggleButton("##ped_counter_outside_interiors", _config.overlay.display_outside_interiors)
        end
    end)

    if _config.overlay.display[0] then
        Overlay.render_overlay_settings(_config.overlay, "ped_counter")
    end
end

return PedCounter
