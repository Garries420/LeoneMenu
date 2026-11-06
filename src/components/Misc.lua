-- Module: F:\2025\EDrive\dev\luapack\src\components\Misc.lua

local bit = require("bit")
local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local keys = require("game.keys")
local Timer = require("src.core.Timer")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Player = require("src.utils.Player")
local shared = require("src.shared")

local SPRUNK_WAIT_TIME = 0.050
local SPECIAL_ACTION_DRINK_SPRUNK = 23

local CONFIG_PATH = "config/Leone Menu/miscellaneous.json"

local default_data = {
    font = {
        path = ""
    },
    auto_eject = {
        enabled = imgui.new.bool(true),
    },
    auto_accept_repair = {
        enabled = imgui.new.bool(true),
    },
    auto_pick_lock = {
        enabled = imgui.new.bool(true),
    },
    beacon_resolver = {
        enabled = imgui.new.bool(true),
    },
    portable_radio = {
        show_frequency = imgui.new.bool(true),
    },
    sprunk_spam = {
        enabled = imgui.new.bool(true),
    },
    sniper_frisk_sound = {
        enabled = imgui.new.bool(true),
    },
}

local _config = default_data

local _auto_eject_state = {
    timer = Timer.new(imgui.new.int(5)),
}

local _portable_radio = {
    current_frequency = 0,
}

local _sprunk_spam_state = {
    last = os.clock(),
}

local _vehicle_storage_state = {
    selected_slot = 0,
    selected_car = "",
}

local fonts = {
    list = {},
    selected = imgui.new.int(0),
}

local function get_system_fonts()
    local dirs = {
        getFolderPath(0x14),
        os.getenv('LOCALAPPDATA') .. '\\Microsoft\\Windows\\Fonts'
    }
    local exts = { '*.ttf', '*.otf' }
    local found = {}

    for _, dir in ipairs(dirs) do
        if dir then
            for _, ext in ipairs(exts) do
                local search, file = findFirstFile(dir .. '\\' .. ext)
                if search then
                    while file do
                        local full_path = dir .. '\\' .. file
                        table.insert(found, full_path)

                        file = findNextFile(search)
                    end
                    findClose(search)
                end
            end
        end
    end
    return found
end

local function _force_recon(delay)
    delay = delay or 0

    sampSetGamestate(5)

    local bs = raknetNewBitStream()
    raknetEmulRpcReceiveBitStream(40, bs)
    raknetDeleteBitStream(bs)

    if sampIsDialogActive() then
        sampCloseCurrentDialogWithButton(0)
    end

    lua_thread.create(function()
        wait(delay * 1000)
        sampSetGamestate(1)
    end)
end

local function resolve_beacons_in_text(text, color)
    if not _config.beacon_resolver.enabled[0] then
        return text
    end

    local function to_rp_name(nickname)
        return nickname:gsub("_", " ")
    end

    text = text:gsub("(%f[%w])([Bb])(%d+)%f[%W]", function(_, org_b, id)
        local player_id = tonumber(id)
        if player_id and sampIsPlayerConnected(player_id) then
            local player_name = sampGetPlayerNickname(player_id)
            local player_color = bit.band(sampGetPlayerColor(player_id), 0xFFFFFF)

            return string.format("%s%d {{%06x}%s%s}", org_b, player_id, player_color,
                to_rp_name(player_name), color)
        end

        return org_b .. id
    end)

    return text
end

local function _register_event_handlers()

    shared.event_handler:register(
        "PED_TICK_IN_CAR",
        function(x, y, z, vehicle_handle, is_driver)
            if _config.auto_eject.enabled[0] and is_driver then
                return { vehicle_handle }
            end
            return false
        end,
        function(vehicle_handle)
            if getCarHealth(vehicle_handle) <= 250.0 then
                if _auto_eject_state.timer:is_ready() then
                    _auto_eject_state.timer:trigger()
                    local players_in_vehicle = {}

                    for target_player_id = 0, sampGetMaxPlayerId(true) do
                        if sampIsPlayerConnected(target_player_id) then
                            local ok, target_ped = sampGetCharHandleBySampPlayerId(target_player_id)
                            if ok and doesCharExist(target_ped) and isCharInCar(target_ped, vehicle_handle) then
                                table.insert(players_in_vehicle, target_player_id)
                            end
                        end
                    end

                    if #players_in_vehicle > 0 then
                        shared.notification:show("Ejecting players from the burning vehicle...",
                            shared.notification.types.INFO)

                        lua_thread.create(function()
                            for _, target_player_id in ipairs(players_in_vehicle) do
                                sampSendChat("/eject " .. target_player_id)
                                wait(750)
                            end
                        end)
                    end
                end
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.LIGHTBLUE and _config.auto_accept_repair.enabled[0] then
                local match = text:match(
                    "^%* Car Mechanic .- wants to repair your car for %$1, %(type %/accept repair%) to accept%.$")
                if match then
                    return true
                end
            end
            return false
        end,
        function()
            if isCharInAnyCar(PLAYER_PED) then
                sampSendChat("/accept repair")
            end
            return false
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE and _config.auto_pick_lock.enabled[0] and text == "You have failed to pick the lock!" then
                return true
            end
            return false
        end,
        function()
            sampSendChat("/picklock")
        end
    )

    shared.event_handler:register(
        "PED_TICK_ON_FOOT",
        function(x, y, z)
            if _config.sprunk_spam.enabled[0] and (getCharHealth(PLAYER_PED) - 5000000) ~= 100.0 then
                local my_id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))

                if sampGetPlayerSpecialAction(my_id) == SPECIAL_ACTION_DRINK_SPRUNK then
                    return true
                end
            end
            return false
        end,
        function()
            if os.clock() - _sprunk_spam_state.last >= SPRUNK_WAIT_TIME then
                setGameKeyState(keys.player.FIREWEAPON, 255)
                _sprunk_spam_state.last = os.clock()
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.GRAD1 and _config.sniper_frisk_sound.enabled[0] and text == "Weapon: Sniper Rifle." then
                return true
            end
            return false
        end,
        function()
            clearMissionAudio(1)
            loadMissionAudio(1, 5205)
            playMissionAudio(1)
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if _config.beacon_resolver.enabled[0] then
                return { color, text }
            end

            return false
        end,
        function(color, text)

            local last_hex_color
            for hex_color in text:gmatch("{%x%x%x%x%x%x}") do
                last_hex_color = hex_color
            end
            local normal_color = last_hex_color or string.format("{%06X}", bit.rshift(color, 8))

            text = resolve_beacons_in_text(text, normal_color)

            return { color, text }
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.FREQUENCY then
                local frequency, player_name, content = text:match("^%*%* Radio %((%-?%d+) kHz%) %*%* (.-): (.+)$")
                if frequency and player_name and content then
                    return { color, tonumber(frequency), player_name, content }
                end
            end
            return false
        end,
        function(color, frequency, player_name, content)
            local raw_name = player_name:gsub(" ", "_")
            local player_id = Player:get_player_id_by_name(raw_name)

            local show_frequency=_config.portable_radio.show_frequency[0]
            if not player_id then
                if not show_frequency then return {color,'** Radio ** '..player_name..': '..content} end
                return
            end

            local player_color = bit.band(sampGetPlayerColor(player_id), 0xFFFFFF)
            local prefix=show_frequency and ('** Radio (%d kHz) ** '):format(frequency) or '** Radio ** '
            local text=prefix..string.format("{%06X}%s (%d){FFFFFF}: {6DFB6D}%s", player_color, player_name, player_id, content)

            local last_hex_color
            for hex_color in text:gmatch("{%x%x%x%x%x%x}") do
                last_hex_color = hex_color
            end
            local normal_color = last_hex_color or string.format("{%06X}", bit.rshift(color, 8))

            text = resolve_beacons_in_text(text, normal_color)

            return { color, text }
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE then
                local frequency = text:match("^You have set the frequency of your portable radio to (%-?%d+) kHz%.$")
                if frequency then
                    return { tonumber(frequency) }
                end
            end
            return false
        end,
        function(frequency)
            if frequency == _portable_radio.current_frequency then
                return
            end

            _portable_radio.current_frequency = frequency
        end
    )


end

local function _register_commands()

    sampRegisterChatCommand(
        "recon",
        function(args)
            local delay = tonumber(args) or 0

            _force_recon(delay)

            local msg_text = delay == 0 and "Reconnecting..." or
                "Reconnecting in " .. delay .. " second" .. (delay == 1 and "..." or "s...")
            msg(msg_text)
        end
    )

    sampRegisterChatCommand(
        "nick",
        function(args)
            if args == "" then
                return msg('Usage: /nick <name>')
            end

            if not Player:is_valid_samp_name(args) then
                return msg("You have entered an invalid roleplay name.")
            end

            sampSetLocalPlayerName(args)
            _force_recon(0)
            msg("Reconnecting with the name '" .. args .. "'.")
        end
    )

    sampRegisterChatCommand(
        "leone",
        function(args)
            if args == "cmds" then
                local visible_cmds = {}
                for cmd, _ in pairs(get_registered_commands()) do
                    table.insert(visible_cmds, cmd)
                end

                table.sort(visible_cmds)
                msg("{BE60F7}" .. #visible_cmds .. " registered commands{FFFFFF}:")

                local line = {}
                for i, cmd in ipairs(visible_cmds) do
                    table.insert(line, cmd)
                    if #line == 6 then
                        msg(table.concat(line, ", "))
                        line = {}
                    end
                end

                if #line > 0 then
                    msg(table.concat(line, ", "))
                end
            else
                if MainWindow:is_open() then
                    MainWindow:hide()
                else
                    MainWindow:show()
                end
            end
        end
    )
end

local Misc = {}

function Misc:register()
    carboneum.load(CONFIG_PATH, _config)
    _config.portable_radio.import_url = nil

    fonts.list = get_system_fonts()
    for i, font_path in ipairs(fonts.list) do
        if font_path == _config.font.path then
            fonts.selected[0] = i - 1
        end
    end

    _register_event_handlers()
    _register_commands()

    MainWindow:add_page("miscellaneous", {
        icon = fa("ELLIPSIS"),
        title = "Miscellaneous",
        icon_box_color = imgui.ImVec4(0.6, 0.6, 0.6, 1),
        render_function = Misc.render_ui_settings
    })
end

function Misc:get_config()
    return _config
end

function Misc:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function Misc:render_portable_radio()
    imgui.DrawChild("Portable Radio", function(width)

        imgui.Text("Show frequency in chat messages")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        if imgui.ToggleButton("##show_frequency", _config.portable_radio.show_frequency) then
            Misc:save_config()
        end
        require("src.components.Extras"):render_radio(width)
    end)
end

function Misc:render_ui_settings()

    imgui.DrawChild("Font Selector", function(width)
        imgui.Text("Change font for on-screen elements")

        imgui.SameLine(width - 200)
        local current_font_name = (fonts.list[fonts.selected[0] + 1] or _config.font.path):match("[^\\]+$") or "Default"
        imgui.SetNextItemWidth(200)
        if imgui.BeginCombo("##font_selector", current_font_name) then
            for i, font_path in ipairs(fonts.list) do
                local name = font_path:match("[^\\]+$") or font_path
                local is_selected = (fonts.selected[0] == i - 1)

                if imgui.Selectable(name, is_selected) then
                    fonts.selected[0] = i - 1

                    local font_config = imgui.ImFontConfig()
                    imgui.GetIO().FontDefault = imgui.GetIO().Fonts:AddFontFromFileTTF(font_path, 18.0, font_config)

                    local icon_config = imgui.ImFontConfig()
                    icon_config.MergeMode = true
                    icon_config.GlyphMinAdvanceX = 16.0
                    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 16.0,
                        icon_config)
                end

                if is_selected then imgui.SetItemDefaultFocus() end
            end
            imgui.EndCombo()
        end

        imgui.SameLine(width - 200 - 50 - 10)
        if imgui.AnimButton(fa("FLOPPY_DISK"), imgui.ImVec2(50, 0)) then
            local selected_path = fonts.list[fonts.selected[0] + 1]
            if selected_path then
                _config.font.path = selected_path
            end
        end
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Automatization", function(width)

        imgui.Text("Automatically eject all players from vehicle when it catches fire")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##auto_eject", _config.auto_eject.enabled)

        imgui.Separator()

        imgui.Text("Automatically accept $1 repair offers from players")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##auto_accept_repair", _config.auto_accept_repair.enabled)
        require("src.components.Extras"):render_repair(width)

        imgui.Separator()

        imgui.Text("Automatically retry picking a vehicle lock after a failed attempt")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##auto_pick_lock", _config.auto_pick_lock.enabled)

        imgui.Separator()

        imgui.Text("Spam LMB while holding a Sprunk can to quickly recover health")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##sprunk_spam", _config.sprunk_spam.enabled)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Beacon Resolver", function(width)
        imgui.Text('Resolve player IDs when written as "B20" to their actual name instead')
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##beacon_resolver", _config.beacon_resolver.enabled)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Frisking", function(width)
        imgui.Text("Play sound when frisking a player who has a sniper rifle")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##sniper_frisk_sound", _config.sniper_frisk_sound.enabled)
        require("src.components.Extras"):render_frisk(width)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    require("src.components.Extras"):render_random()
    require("src.components.Extras"):render_vehicles()
end

return Misc
