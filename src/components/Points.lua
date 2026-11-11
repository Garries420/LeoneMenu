-- Module: F:\2025\EDrive\dev\luapack\src\components\Points.lua

local bit = require("bit")
local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local Timer = require("src.core.Timer")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")

local CONFIG_PATH = "config/Leone Menu/points.json"

local default_data = {
    auto_capture = imgui.new.bool(false),
    overlay = Overlay.setup_overlay_defaults(
        true,
        0.015,
        0.375,
        14,
        6,
        1,
        2,
        true,
        { 0, 0, 0, 0.588 },
        true,
        { 0, 0, 0, 0.588 }
    ),
}
default_data.overlay.display_next_information = imgui.new.bool(true)

local _config = default_data

local _points = {}

local _active_point_war = {
    refresh_timer = Timer.new(imgui.new.int(45)),

    name = "",
    captured_by = "",
    time_left = 0,
}

local _last_nearby_point = {
    name = "",
    position = {
        x = 0.0,
        y = 0.0,
        z = 0.0,
    },
}

local function _detect_point(text, color, is_argb)

    local rgba_color = color
    if is_argb then
        local a = bit.band(bit.rshift(color, 24), 0xFF)
        local r = bit.band(bit.rshift(color, 16), 0xFF)
        local g = bit.band(bit.rshift(color, 8), 0xFF)
        local b = bit.band(color, 0xFF)
        rgba_color = bit.bor(bit.lshift(r, 24), bit.lshift(g, 16), bit.lshift(b, 8), a)
    end

    if rgba_color ~= Colors.YELLOW2 then
        return nil
    end

    local point = text:match("^(.-)\nOwner%: .-$")
    if not point then
        return nil
    end

    return point
end

local function _search_point_3d_text()
    for id = 0, 2048 do
        if sampIs3dTextDefined(id) then
            local text, color, pos_x, pos_y, pos_z, distance, ignoreWalls, player, vehicle = sampGet3dTextInfoById(id)
            local point = _detect_point(text, color, true)
            if point then
                _last_nearby_point.name = point
                _last_nearby_point.position.x = pos_x
                _last_nearby_point.position.y = pos_y
                _last_nearby_point.position.z = pos_z
            end
        end
    end
end

local function _end_point_war()
    if _active_point_war.name ~= "" then shared.event_handler:process("POINT_ENDED", _active_point_war.name) end
    _active_point_war.refresh_timer:pause()

    _active_point_war.name = ""
    _active_point_war.captured_by = ""
    _active_point_war.time_left = 0
end

local function _start_point_war(name, captured_by, time_left)
    _active_point_war.refresh_timer:resume()

    _active_point_war.name = name
    _active_point_war.captured_by = captured_by
    _active_point_war.time_left = time_left
end

local function _register_event_handlers()

    shared.event_handler:register(
        "CREATE_3D_TEXT",
        function(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
            local point = _detect_point(text, color, false)
            if point then
                return { point, position }
            end

            return false
        end,
        function(point, position)
            _last_nearby_point.name = point
            _last_nearby_point.position.x = position.x
            _last_nearby_point.position.y = position.y
            _last_nearby_point.position.z = position.z
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text:match("^Welcome to Horizon Roleplay, .-%.$")
        end,
        function()
            samp_send_hidden_command("points")
        end
    )

    shared.event_handler:register(
        "SHOW_DIALOG",
        function(id, style, title, button1, button2, text)
            if title == "{FFA500}Horizon Roleplay Points" then
                return { text }
            end
            return false
        end,
        function(text)
            local fetched_points = {}
            for name, owner, hours in text:gmatch("{FFA500}Name:{FFFFFF} (.-) {FFA500}| {FFA500}Owner:(.-) {FFA500}| {FFA500}Captured By:{FFFFFF} .- {FFA500}| {FFA500}Hours:{FFFFFF} (%d+)") do
                owner = owner:gsub("%s+", "", 1)

                table.insert(fetched_points, { name = name, owner = owner, hours = tonumber(hours) })
            end

            for _, fetched_point in ipairs(fetched_points) do
                if not _points[fetched_point.name] then
                    _points[fetched_point.name] = fetched_point
                else
                    _points[fetched_point.name].owner = fetched_point.owner
                    _points[fetched_point.name].hours = fetched_point.hours
                end

                if fetched_point.hours == 0 and _active_point_war.refresh_timer:is_paused() then
                    samp_send_hidden_command("pointinfo")
                end
            end

            return is_command_self_sent("points")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW and _config.auto_capture[0] and not Player:is_on_admin_duty() then
                local point_name = text:match("^(.-) has become available for capture%.$")
                if point_name then
                    return { point_name }
                end
            end
            return false
        end,
        function(point_name)
            if point_name == _last_nearby_point.name then
                local px, py, pz = getCharCoordinates(PLAYER_PED)

                if is_within_distance_3d(px, py, pz, _last_nearby_point.position.x, _last_nearby_point.position.y, _last_nearby_point.position.z, 5.0) then
                    sampSendChat("/capture")
                end
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local point, captured_by = text:match("^.- has taken control of the (.-) for (.-)%.$")
                if point and captured_by and _points[point] then
                    return { point, captured_by }
                end
            end
            return false
        end,
        function(point, captured_by)
            _points[point].owner = captured_by
            _points[point].hours = 25

            _end_point_war()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.GRAD2 and not _active_point_war.refresh_timer:is_paused() and text == "No family has capped the point or the point is not ready to be capped."
        end,
        function()
            _end_point_war()

            return is_command_self_sent("pointinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text == "Point Info:"
        end,
        function()
            return is_command_self_sent("pointinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE then
                local point_name, captured_by, time_left = text:match(
                    "^%* (.-) | Capper: .- | .-: (.-) | Time left: (.-)$")

                if point_name and captured_by and time_left then
                    if _points[point_name] then
                        return { point_name, captured_by, time_left }
                    end
                end
            end
            return false
        end,
        function(point_name, captured_by, time_left)
            if time_left == "Less than 1 minute" then
                time_left = 1
            else
                time_left = tonumber(time_left:match("(%d+)")) or 0
            end

            _start_point_war(point_name, captured_by, time_left)

            return is_command_self_sent("pointinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local point_name, captured_by = text:match(
                    "^.- is attempting to take over of the (.-) for (.-), they'll own it in 10 minutes.$")

                if point_name and captured_by then
                    if _points[point_name] then
                        return { point_name, captured_by }
                    end
                end
            end
            return false
        end,
        function(point_name, captured_by)
            _start_point_war(point_name, captured_by, 10)
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.WHITE and text:match("^The time is now %d+:00+%.$")
        end,
        function()
            for _, point in pairs(_points) do
                if point.hours > 0 then
                    point.hours = point.hours - 1
                end
            end
        end
    )
end

local function _register_commands()
    sampRegisterChatCommand(
        "acapp",
        function()
            _config.auto_capture[0] = not _config.auto_capture[0]
            msg(string.format("Auto Cap Point has been %s{FFFFFF}.",
                _config.auto_capture[0] and "{6DFB6D}enabled" or "{FF0000}disabled"))
        end
    )
end

local Points = {}

function Points:get_active_point()
    return _active_point_war
end

function Points:get_next_point()
    local next_turf_name = nil
    local lowest_hours = 25
    for name, point in pairs(_points) do
        if point.hours > 0 and point.hours < lowest_hours then
            lowest_hours = point.hours
            next_turf_name = name
        end
    end
    return next_turf_name
end

function Points:get_point_data(name)
    return _points[name]
end

function Points:register()
    carboneum.load(CONFIG_PATH, _config)
    -- Automatic captures require a fresh opt-in after each script load.
    _config.auto_capture[0] = false

    _register_event_handlers()
    _register_commands()

    _search_point_3d_text()

    _active_point_war.refresh_timer:pause()
    samp_send_hidden_command("points")


end

function Points:get_config()
    return _config
end

function Points:get_overlay_config()
    return _config.overlay
end

function Points:save_config()
    return carboneum.save(CONFIG_PATH, _config)
end

function Points:render_ui_settings()
    imgui.DrawChild("Points", function(width)
        imgui.Text("Show upcoming point war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##points_overlay_upcoming_war", _config.overlay.display_next_information)

        imgui.Separator()

        imgui.Text("Show active point war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##points_overlay_active_war", _config.overlay.display)
        imgui.Separator()
        imgui.Text("Automatically capture points as soon as they become available - /acapp")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##points_auto_capture", _config.auto_capture)
    end)


end

return Points
