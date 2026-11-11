-- Module: F:\2025\EDrive\dev\luapack\src\components\Turfs.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local Timer = require("src.core.Timer")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")

local CONFIG_PATH = "config/Leone Menu/turfs.json"

local default_data = {
    auto_capture = imgui.new.bool(false),
    spam_capture = imgui.new.bool(false),
    spam_interval = imgui.new.float(10),

    overlay = Overlay.setup_overlay_defaults(
        true,
        0.015,
        0.34,
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
default_data.overlay.display_war_information = imgui.new.bool(true)

local _config = default_data

local _turfs = {
    ["East Beach"] = { min_x = 2725.0, min_y = -1140.5, max_x = 2962.0, max_y = -1645.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Las Colinas"] = { min_x = 1852.0, min_y = -939.5, max_x = 2961.0, max_y = -1140.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Playa del Seville"] = { min_x = 2568.0, min_y = -1645.5, max_x = 2962.0, max_y = -2162.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Los Flores"] = { min_x = 2570.0, min_y = -1140.5, max_x = 2725.0, max_y = -1644.5, owner = "{2641FE}Neutral", hours = 0 },
    ["East Los Santos East"] = { min_x = 2434.0, min_y = -1140.5, max_x = 2572.0, max_y = -1589.5, owner = "{2641FE}Neutral", hours = 0 },
    ["East Los Santos West"] = { min_x = 2291.0, min_y = -1140.5, max_x = 2434.0, max_y = -1589.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Jefferson"] = { min_x = 2063.0, min_y = -1140.5, max_x = 2292.0, max_y = -1588.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Glen Park"] = { min_x = 1822.0, min_y = -1143.5, max_x = 2062.0, max_y = -1588.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Ganton"] = { min_x = 2202.0, min_y = -1588.5, max_x = 2570.0, max_y = -1741.5, owner = "{2641FE}Neutral", hours = 0 },
    ["North Willowfield"] = { min_x = 2202.0, min_y = -1739.5, max_x = 2570.0, max_y = -1932.5, owner = "{2641FE}Neutral", hours = 0 },
    ["South Willowfield"] = { min_x = 2202.0, min_y = -1931.5, max_x = 2570.0, max_y = -2162.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Idlewood"] = { min_x = 1822.0, min_y = -1588.5, max_x = 2202.0, max_y = -1953.5, owner = "{2641FE}Neutral", hours = 0 },
    ["El Corona"] = { min_x = 1687.0, min_y = -1954.5, max_x = 2201.0, max_y = -2161.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Little Mexico"] = { min_x = 1687.0, min_y = -1601.5, max_x = 1821.0, max_y = -1954.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Commerce"] = { min_x = 1342.0, min_y = -1491.5, max_x = 1821.0, max_y = -1601.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Pershing Square"] = { min_x = 1316.0, min_y = -1601.5, max_x = 1687.0, max_y = -1873.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Verdant Bluffs"] = { min_x = 917.0, min_y = -1873.5, max_x = 1686.0, max_y = -2162.5, owner = "{2641FE}Neutral", hours = 0 },
    ["LSI Airport"] = { min_x = 953.0, min_y = -2162.5, max_x = 2178.0, max_y = -2786.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Ocean Docks"] = { min_x = 2178.0, min_y = -2162.5, max_x = 2961.0, max_y = -2785.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Downtown Los Santos"] = { min_x = 1342.0, min_y = -1143.5, max_x = 1823.0, max_y = -1491.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Mulholland Intersection"] = { min_x = 1347.0, min_y = -933.5, max_x = 1852.0, max_y = -1143.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Temple"] = { min_x = 631.0, min_y = -933.5, max_x = 1347.0, max_y = -1142.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Mulholland"] = { min_x = 631.0, min_y = -667.5, max_x = 1582.0, max_y = -933.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Market"] = { min_x = 917.0, min_y = -1142.5, max_x = 1342.0, max_y = -1602.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Vinewood"] = { min_x = 631.0, min_y = -1142.5, max_x = 917.0, max_y = -1403.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Marina"] = { min_x = 631.0, min_y = -1403.5, max_x = 918.0, max_y = -1742.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Verona Beach"] = { min_x = 917.0, min_y = -1601.5, max_x = 1316.0, max_y = -1873.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Richman"] = { min_x = 59.0, min_y = -933.5, max_x = 631.0, max_y = -1295.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Rodeo"] = { min_x = 59.0, min_y = -1295.5, max_x = 631.0, max_y = -1742.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Santa Maria Beach"] = { min_x = 60.0, min_y = -1742.5, max_x = 918.0, max_y = -2107.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Dillimore"] = { min_x = 555.0, min_y = -396.0, max_x = 866.0, max_y = -667.0, owner = "{2641FE}Neutral", hours = 0 },
    ["Blueberry"] = { min_x = 78.0, min_y = 79.0, max_x = 393.0, max_y = -205.0, owner = "{2641FE}Neutral", hours = 0 },
    ["Montgomery"] = { min_x = 1120.0, min_y = 506.5, max_x = 1527.0, max_y = 120.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Palomino Creek"] = { min_x = 2094.0, min_y = 276.5, max_x = 2575.0, max_y = -158.5, owner = "{2641FE}Neutral", hours = 0 },
}

local _active_turf_war = {
    refresh_timer = Timer.new(imgui.new.float(45)),

    name = "",
    captured_by = "",
    time_left = 0,
}

local spam_capture_timer = Timer.new(_config.spam_interval)

local Turfs = {}

local function _send_system_priority_command(command)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt32(bs, #command)
    raknetBitStreamWriteString(bs, command)
    raknetSendRpcEx(50, bs, 0, 8, 0, false)
    raknetDeleteBitStream(bs)
end

local function _end_turf_war()
    _active_turf_war.refresh_timer:pause()

    _active_turf_war.name = ""
    _active_turf_war.captured_by = ""
    _active_turf_war.time_left = 0
end

local function _start_turf_war(name, captured_by, time_left)
    _active_turf_war.refresh_timer:resume()

    _active_turf_war.name = name
    _active_turf_war.captured_by = captured_by
    _active_turf_war.time_left = time_left
end

local function _register_event_handlers()

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text:match("^Welcome to Horizon Roleplay, .-%.$")
        end,
        function()
            samp_send_hidden_command("turfs")
        end
    )

    shared.event_handler:register(
        "SHOW_DIALOG",
        function(id, style, title, button1, button2, text)
            if title:match("^%{FFA500%}Horizon Roleplay Turfs %- %{FFFFFF%}Page %d+%/%d+$") then
                return { id, title, text }
            end
            return false
        end,
        function(id, title, text)
            local fetched_turfs = {}
            for name, owner, hours in text:gmatch("{FFA500}Name:{FFFFFF} (.-) {FFA500}| Owner:(.-) {FFA500}| Captured By:{FFFFFF} .- {FFA500}| Hours:{FFFFFF} (%d+)") do
                owner = owner:gsub("%s+", "", 1)

                if owner == "{FFFFFF}Neutral" then
                    owner = "{2641FE}Neutral"
                end

                table.insert(fetched_turfs, { name = name, owner = owner, hours = tonumber(hours) })
            end

            for _, fetched_turf in ipairs(fetched_turfs) do
                if _turfs[fetched_turf.name] then
                    _turfs[fetched_turf.name].owner = fetched_turf.owner
                    _turfs[fetched_turf.name].hours = fetched_turf.hours
                end

                if fetched_turf.hours == 0 and _active_turf_war.refresh_timer:is_paused() then
                    samp_send_hidden_command("turfinfo")
                end
            end

            if title == "{FFA500}Horizon Roleplay Turfs - {FFFFFF}Page 1/2" and is_command_self_sent("turfs") == false then
                sampSendDialogResponse(id, 1, 1, "")
            end

            return is_command_self_sent("turfs")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW and _config.auto_capture[0] and not Player:is_on_admin_duty() then
                local turf_name = text:match("^(.-) has become available for capture%.$")
                if turf_name then
                    return { turf_name }
                end
            end
            return false
        end,
        function(turf_name)
            local px, py, pz = getCharCoordinates(PLAYER_PED)
            local current_turf_name = Turfs:get_current_turf(px, py)

            if current_turf_name and current_turf_name == turf_name then
                _send_system_priority_command("/capturf")
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text == "Turf Info:"
        end,
        function()
            return is_command_self_sent("turfinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE then
                local turf_name, captured_by, time_left = text:match(
                    "^%* (.-) | Capper: .- | .-: (.-) | Time left: (.-)$")

                if turf_name and captured_by and time_left then
                    if _turfs[turf_name] then
                        return { turf_name, captured_by, time_left }
                    end
                end
            end
            return false
        end,
        function(turf_name, captured_by, time_left)
            if time_left == "Less than 1 minute" then
                time_left = 1
            else
                time_left = tonumber(time_left:match("(%d+)")) or 0
            end

            _start_turf_war(turf_name, captured_by, time_left)

            return is_command_self_sent("turfinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local turf_name, captured_by = text:match(
                    "^.- is attempting to take control of (.-) for (.-) %(15 minutes remaining%)%.$")

                if turf_name and captured_by then
                    if _turfs[turf_name] then
                        return { turf_name, captured_by }
                    end
                end
            end
            return false
        end,
        function(turf_name, captured_by)
            _start_turf_war(turf_name, captured_by, 15)
        end
    )

    shared.event_handler:register(
        "GANG_ZONE_FLASH",
        function(zoneid, color)
            return zoneid >= 0 and zoneid <= 33
        end,
        function()
            if _active_turf_war.refresh_timer:is_paused() then
                lua_thread.create(function()
                    wait(0)
                    samp_send_hidden_command("turfinfo")
                end)
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local turf, captured_by = text:match("^.- has taken control of (.-) for (.-)%.$")
                if turf and captured_by and _turfs[turf] then
                    return { turf, captured_by }
                end
            end
            return false
        end,
        function(turf, captured_by)
            _turfs[turf].owner = captured_by
            _turfs[turf].hours = 73

            _end_turf_war()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.GRAD2 and not _active_turf_war.refresh_timer:is_paused() and text == "Nobody is attempting to capture any turfs or no turfs are available for capture yet."
        end,
        function()
            _end_turf_war()

            return is_command_self_sent("turfinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.WHITE and text:match("^The time is now %d+:00+%.$")
        end,
        function()
            for _, turf in pairs(_turfs) do
                if turf.hours > 0 then
                    turf.hours = turf.hours - 1
                end
            end
        end
    )

    shared.event_handler:register(
        "PED_TICK",
        function(x, y, z)
            if _config.spam_capture[0] and spam_capture_timer:is_ready() and not Player:is_on_admin_duty() then
                return { x, y, z }
            end
            return false
        end,
        function(x, y, z)
            local turf_name = Turfs:get_current_turf(x, y)

            if turf_name and _turfs[turf_name].hours <= 1 then
                spam_capture_timer:trigger()
                _send_system_priority_command("/capturf")
            end
        end
    )
end

local function _register_commands()
    sampRegisterChatCommand(
        "acapt",
        function()
            _config.auto_capture[0] = not _config.auto_capture[0]
            msg(string.format("Auto Cap Turf has been %s{FFFFFF}.",
                _config.auto_capture[0] and "{6DFB6D}enabled" or "{FF0000}disabled"))
        end
    )

    sampRegisterChatCommand(
        "spamt",
        function(args)
            if args~='' then
                local interval=tonumber(args)
                if not interval or interval<1 or interval>3600 then return msg('USAGE: /spamt [1-3600 seconds]') end
                _config.spam_interval[0]=interval
                return msg(string.format('Spam Cap Turf delay set to {6DFB6D}%g s',interval))
            end
            _config.spam_capture[0] = not _config.spam_capture[0]
            if _config.spam_capture[0] then
                msg(string.format('Spam Cap Turf is {6DFB6D}enabled{FFFFFF}, {6DFB6D}%gs{FFFFFF} delay. {6DFB6D}/spamt amount to edit delay',_config.spam_interval[0]))
            else msg('Spam Cap Turf has been {FF0000}disabled') end
        end
    )

    sampRegisterChatCommand(
        "findturf",
        function(args)
            if args == "" then
                return msg("Usage: /findturf <turf name>")
            end

            local lower_name = args:lower()
            for name, turf in pairs(_turfs) do
                if name:lower():find(lower_name, 1, true) then
                    local center_x = (turf.min_x + turf.max_x) / 2
                    local center_y = (turf.min_y + turf.max_y) / 2
                    placeWaypoint(center_x, center_y, 5)
                    msg(string.format("Waypoint placed to the center of turf %s.", name))
                    return
                end
            end

            msg(string.format("Turf '{BE60F7}%s{FFFFFF}' not found.", args))
        end
    )
end

function Turfs:get_active_turf()
    return _active_turf_war
end

function Turfs:get_current_turf(x, y)
    for name, turf in pairs(_turfs) do
        if x >= turf.min_x and x <= turf.max_x and y >= turf.max_y and y <= turf.min_y then
            return name
        end
    end
    return nil
end

function Turfs:get_next_turf()
    local next_turf_name = nil
    local lowest_hours = 73
    for name, turf in pairs(_turfs) do
        if turf.hours > 0 and turf.hours < lowest_hours then
            lowest_hours = turf.hours
            next_turf_name = name
        end
    end
    return next_turf_name
end

function Turfs:get_turf_data(name)
    return _turfs[name]
end

function Turfs:get_all_turfs()
    return _turfs
end

function Turfs:register()
    carboneum.load(CONFIG_PATH, _config)
    _config.overlay.display_inside_interiors=nil
    -- Automatic captures require a fresh opt-in after each script load.
    _config.auto_capture[0] = false

    _register_event_handlers()
    _register_commands()

    _active_turf_war.refresh_timer:pause()
    samp_send_hidden_command("turfs")


end

function Turfs:get_config()
    return _config
end

function Turfs:get_overlay_config()
    return _config.overlay
end

function Turfs:save_config()
    return carboneum.save(CONFIG_PATH, _config)
end

function Turfs:render_ui_settings()
    imgui.DrawChild("Turfs", function(width)
        imgui.Text("Show upcoming turf war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_overlay_upcoming_war", _config.overlay.display_next_information)

        imgui.Separator()

        imgui.Text("Show active turf war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_overlay_active_war", _config.overlay.display_war_information)

        imgui.Separator()
        imgui.Text("Automatically capture turfs as soon as they become available - /acapt")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_auto_capture", _config.auto_capture)

        imgui.Separator()

        imgui.Text("Run capture command periodically - /spamt")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_spam_capture", _config.spam_capture)

        if _config.spam_capture[0] then
            imgui.Separator()

            imgui.Text("Capture spam interval")
            imgui.SameLine(width - 40)
            imgui.SetNextItemWidth(40)
            imgui.DragFloat("##turfs_spam_interval", _config.spam_interval, 1, 1, 10.0, "%.1fs")
        end
    end)


end

return Turfs
