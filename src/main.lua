-- Module: F:\2025\EDrive\dev\luapack\src\main.lua

__luapack_timestamp = __luapack_timestamp

script_name("Leone Menu")
script_version("1.0.11")
script_authors("Kev", "Futurestunt", "Garry")

local bit = require("bit")
local fa = require("fAwesome7")
local ffi = require("ffi")
local imgui = require("upmimgui")
local sampev = require("samp.events")
imgui.SetDpiScalingMode(3)

require("src.ui.Widgets")
local shared = require("src.shared")

local SCRIPT_TAG = '{1E3348}[Leone Menu] {FFFFFF}'
local SCRIPT_COLOR = 0xFF1E3348

local CAMERA_MODES = {
    SNIPER = 0x7,
    ROCKETLAUNCHER = 0x8,
    ROCKETLAUNCHER_HS = 0x33,
    AIMWEAPON = 0x35,
    CAMERA = 0x2E
}

local CURSOR_SHOWING = 0x00000001

ffi.cdef [[
    typedef struct {
        long x;
        long y;
    } POINT;

    typedef struct {
        unsigned int cbSize;
        unsigned int flags;
        void* hCursor;
        POINT ptScreenPos;
    } CURSORINFO;

    int GetCursorInfo(CURSORINFO* pci);
]]

local registered_commands = {}
local _commands_state = {
    is_cmd_self_sent = {},
    is_script_sending_command = {},
}
local _is_loading_interior = false

string.trim = string.trim or function(s)
    return s:match("^%s*(.-)%s*$")
end

function table.contains(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end

    for i = 1, #tbl do
        if tbl[i] == value then
            return true
        end
    end
    return false
end

function table.remove_value(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end

    for i = 1, #tbl do
        if tbl[i] == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

function is_within_distance_3d(x1, y1, z1, x2, y2, z2, max_distance)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return (dx * dx + dy * dy + dz * dz) <= (max_distance * max_distance)
end

function is_cursor_active()

    local ci = ffi.new("CURSORINFO[1]")
    ci[0].cbSize = ffi.sizeof(ci[0])

    local result = ffi.C.GetCursorInfo(ci)
    if result == 0 then
        return false
    end

    return bit.band(ci[0].flags, CURSOR_SHOWING) ~= 0 or sampIsCursorActive()
end

function pass_render_checks()
    return sampGetGamestate() == 3 and
        not (sampGetChatDisplayMode() == 0 or
            sampIsScoreboardOpen() or
            isSampfuncsConsoleActive() or
            isPauseMenuActive())
end

function is_aiming(scoped_only)
    local camera_mode_id = readMemory(0xB6F1A8, 1, false)

    local is_scope_mode = camera_mode_id == CAMERA_MODES.SNIPER or
        camera_mode_id == CAMERA_MODES.ROCKETLAUNCHER or
        camera_mode_id == CAMERA_MODES.ROCKETLAUNCHER_HS

    local is_aim_mode = is_scope_mode or
        camera_mode_id == CAMERA_MODES.AIMWEAPON or
        camera_mode_id == CAMERA_MODES.CAMERA

    if scoped_only then
        return is_scope_mode
    end

    return is_aim_mode
end

function msg(...)
    local values={...};for i,v in ipairs(values) do values[i]=tostring(v) end
    local message=table.concat(values,' ')
    message=message:gsub('{(%x%x%x%x%x%x)}',function(c)
        c=c:upper();return ({FFFFFF=true,['00FF00']=true,['6DFB6D']=true,['33CCFF']=true,['FF0000']=true,['FF4444']=true})[c] and ('{'..c..'}') or '{1E3348}'
    end)
    sampAddChatMessage(SCRIPT_TAG .. message, SCRIPT_COLOR)
end

local originalSampRegisterChatCommand = sampRegisterChatCommand

function sampRegisterChatCommand(command, callback)
    registered_commands["/" .. command] = callback
    originalSampRegisterChatCommand(command, callback)
end

function send_user_command(text)
    local cmd,args=text:match('^/(%S+)%s*(.*)$')
    local callback=cmd and registered_commands['/'..cmd:lower()]
    if callback then callback(args or '') else sampSendChat(text) end
end

function get_registered_commands()
    return registered_commands
end

function samp_send_hidden_command(command, args)
    local cmd_key = "/" .. command
    args = args or ""

    local full_cmd = args ~= "" and (cmd_key .. " " .. args) or cmd_key

    _commands_state.is_script_sending_command[cmd_key] = true
    sampSendChat(full_cmd)
end

function is_command_self_sent(command)
    local cmd_key = "/" .. command
    return _commands_state.is_cmd_self_sent[cmd_key] or false
end

local function setup_directories()
    local base_dir = getWorkingDirectory() .. '\\config'
    local sputnik_dir = base_dir .. '\\Leone Menu'

    if not doesDirectoryExist(base_dir) then
        createDirectory(base_dir)
    end
    if not doesDirectoryExist(sputnik_dir) then
        createDirectory(sputnik_dir)
    end
end

local AcceptVest = require("src.components.AcceptVest")
local AutoVest = require("src.components.AutoVest")
local Backup = require("src.components.Backup")
local Equipment = require("src.components.Equipment")
local Find = require("src.components.Find")
local Fixes = require("src.components.Fixes")
local Keybinds = require("src.components.Keybinds")
local Lawyer = require("src.components.Lawyer")
local Misc = require("src.components.Misc")
local PedCounter = require("src.components.PedCounter")
local Phone = require("src.components.Phone")
local Points = require("src.components.Points")
local Turfs = require("src.components.Turfs")

local AcceptVestOverlay = require("src.overlays.AcceptVest")
local AutoVestOverlay = require("src.overlays.AutoVest")
local BackupOverlay = require("src.overlays.Backup")
local PedCounterOverlay = require("src.overlays.PedCounter")
local PointsOverlay = require("src.overlays.Points")
local TurfsOverlay = require("src.overlays.Turfs")

local Home = require("src.components.Home")
local Extras = require("src.components.Extras")
local Capture = require("src.components.Capture")

local components = {
    { component = Home },
    { component = Extras },
    { component = Capture },
    { component = AcceptVest,    overlay = AcceptVestOverlay },
    { component = AutoVest,      overlay = AutoVestOverlay },
    { component = Backup,        overlay = BackupOverlay },
    { component = Equipment,     overlay = nil },
    { component = Find,          overlay = nil },
    { component = Fixes,         overlay = nil },
    { component = Keybinds,      overlay = nil },
    { component = Lawyer },
    { component = Misc,          overlay = nil },
    { component = PedCounter,    overlay = PedCounterOverlay },
    { component = Phone,         overlay = nil },
    { component = Points,        overlay = PointsOverlay },
    { component = Turfs,         overlay = TurfsOverlay },
}

local function initialize_components()
    for _, pair in ipairs(components) do
        local component = pair.component
        local overlay = pair.overlay

        if component and component.register then
            local success, err = pcall(function()
                component:register()
            end)
            if not success then
                msg("Failed to initialize component:", err)
            end
        end

        if overlay and overlay.create then
            local success, err = pcall(function()
                overlay.create()
            end)
            if not success then
                msg("Failed to initialize overlay:", err)
            end
        end
    end
end

local function process_player_tick()

    if not doesCharExist(PLAYER_PED) then
        return
    end

    local x, y, z = getCharCoordinates(PLAYER_PED)
    local is_on_foot = not isCharInAnyCar(PLAYER_PED)

    shared.event_handler:process("PED_TICK", x, y, z)

    if is_on_foot then
        shared.event_handler:process("PED_TICK_ON_FOOT", x, y, z)
    else
        local vehicle_handle = storeCarCharIsInNoSave(PLAYER_PED)
        local is_driver = (getDriverOfCar(vehicle_handle) == PLAYER_PED)
        shared.event_handler:process("PED_TICK_IN_CAR", x, y, z, vehicle_handle, is_driver)
    end
end

function sampev.onServerMessage(color, text)
    return shared.event_handler:process("SERVER_MESSAGE", color, text)
end

function sampev.onSendDeathNotification(reason,killer)
    return shared.event_handler:process('LOCAL_DEATH',reason,killer)
end

function sampev.onSendTakeDamage(player,damage,weapon,bodypart)
    return shared.event_handler:process('LOCAL_DAMAGE',player,damage,weapon,bodypart)
end

function sampev.onEditAttachedObject(index)
    return shared.event_handler:process("EDIT_ATTACHED_OBJECT", index)
end

function sampev.onSendDialogResponse(id, button, list, input)
    return shared.event_handler:process('SEND_DIALOG_RESPONSE',id,button,list,input)
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    return shared.event_handler:process("SHOW_DIALOG", id, style, title, button1, button2, text)
end

function sampev.onShowTextDraw(id, data)

    if data.text == "~r~Objects loading..." then
        _is_loading_interior = true
    elseif data.text == "~g~Objects loaded!" then
        _is_loading_interior = false
        end

    return shared.event_handler:process("SHOW_TEXTDRAW", id, data)
end

function sampev.onToggleSelectTextDraw(state, hovercolor)
    return shared.event_handler:process("TOGGLE_SELECT_TEXTDRAW", state, hovercolor)
end

function sampev.onTextDrawHide(id)
    return shared.event_handler:process('HIDE_TEXTDRAW',id)
end

function sampev.onTextDrawSetString(id,text)
    return shared.event_handler:process('TEXTDRAW_SET_STRING',id,text)
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
    return shared.event_handler:process("CREATE_3D_TEXT", id, color, position, distance, testLOS, attachedPlayerId,
        attachedVehicleId, text)
end

function sampev.onDisplayGameText(style, time, text)
    return shared.event_handler:process("DISPLAY_GAME_TEXT", style, time, text)
end

function sampev.onPlayerJoin(player_id, color, is_npc, nick)
    return shared.event_handler:process("PLAYER_JOIN", player_id, color, is_npc, nick)
end

function sampev.onPlayerQuit(player_id, reason)
    return shared.event_handler:process("PLAYER_QUIT", player_id, reason)
end

function sampev.onPlayerStreamIn(player_id, team, model, position, rotation, color, fighting_style)
    return shared.event_handler:process("PLAYER_STREAM_IN", player_id, team, model, position, rotation, color,
        fighting_style)
end

function sampev.onPlayerStreamOut(player_id)
    return shared.event_handler:process("PLAYER_STREAM_OUT", player_id)
end

function sampev.onSetPlayerAttachedObject(player_id, index, create, object)
    return shared.event_handler:process("SET_PLAYER_ATTACHED_OBJECT", player_id, index, create, object)
end

function sampev.onGangZoneFlash(zoneid, color)
    return shared.event_handler:process("GANG_ZONE_FLASH", zoneid, color)
end

function sampev.onGangZoneStopFlash(zoneid)
    return shared.event_handler:process("GANG_ZONE_STOP_FLASH", zoneid)
end

function sampev.onSendEnterVehicle(vehicleid, passenger)
    return shared.event_handler:process("SEND_ENTER_VEHICLE", vehicleid, passenger)
end

function sampev.onSendCommand(cmd)
    local cmd_name = cmd:match("^(%/%S*)")
    local is_script_sent = _commands_state.is_script_sending_command[cmd_name] == true

    if is_script_sent then
        _commands_state.is_cmd_self_sent[cmd_name] = false
        _commands_state.is_script_sending_command[cmd_name] = nil
    else
        _commands_state.is_cmd_self_sent[cmd_name] = true
    end

    -- Backup calls do not depend on streamed objects and must not wait for them.
    local immediate_backup=cmd_name=='/pr' or cmd_name=='/fbackup' or cmd_name=='/nobackup'
    if _is_loading_interior and not immediate_backup then
        lua_thread.create(function()

            while _is_loading_interior do
                wait(100)
            end

            if is_script_sent then
                _commands_state.is_script_sending_command[cmd_name] = true
            end

            if shared.event_handler:process("SEND_COMMAND", cmd) then
                sampSendChat(cmd)
            end
        end)
        return false
    end

    return shared.event_handler:process("SEND_COMMAND", cmd)
end

function imgui.DarkTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local c = imgui.Col

    local function rgba(r, g, b, a)
        return imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
    end

    local spacing = {
        xs = 4.0,
        sm = 8.0,
        md = 16.0,
        lg = 24.0,
        xl = 32.0
    }

    style.WindowRounding = 12.0
    style.WindowBorderSize = 0.0
    style.WindowTitleAlign = imgui.ImVec2(0.0, 0.5)
    style.WindowPadding = imgui.ImVec2(spacing.sm, spacing.sm)
    style.WindowMinSize = imgui.ImVec2(320.0, 240.0)

    style.FrameRounding = 8.0
    style.FrameBorderSize = 1.0
    style.FramePadding = imgui.ImVec2(spacing.sm, spacing.sm)
    style.ItemSpacing = imgui.ImVec2(spacing.sm, spacing.sm)
    style.ItemInnerSpacing = imgui.ImVec2(spacing.xs, spacing.xs)
    style.IndentSpacing = spacing.lg

    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 6.0

    style.GrabRounding = 8.0
    style.GrabMinSize = 14.0
    style.ChildRounding = 8.0
    style.ChildBorderSize = 1.0
    style.PopupRounding = 12.0
    style.PopupBorderSize = 1.0
    style.TabRounding = 8.0
    style.TabBorderSize = 0.0
    style.CellPadding = imgui.ImVec2(spacing.sm, spacing.xs)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.SelectableTextAlign = imgui.ImVec2(0.0, 0.5)

    local surface = rgba(16, 16, 20, 255)
    local surface_variant = rgba(28, 27, 31, 128)
    local surface_container = rgba(25, 25, 29, 140)
    local surface_bright = rgba(40, 40, 44, 160)

    local primary = rgba(30, 51, 72, 255)
    local primary_container = rgba(30, 51, 72, 255)

    local secondary = rgba(30, 51, 72, 255)

    local outline = rgba(147, 143, 153, 76)
    local outline_variant = rgba(73, 69, 79, 102)

    local on_surface = rgba(230, 225, 229, 255)
    local on_surface_variant = rgba(202, 196, 208, 255)
    local on_surface_disabled = rgba(202, 196, 208, 97)

    local primary_hover = rgba(30, 51, 72, 210)
    local primary_pressed = rgba(30, 51, 72, 170)
    local surface_hover = rgba(230, 225, 229, 15)
    local surface_pressed = rgba(230, 225, 229, 25)

    style.Colors[c.Text] = on_surface
    style.Colors[c.TextDisabled] = on_surface_disabled
    style.Colors[c.WindowBg] = surface
    style.Colors[c.ChildBg] = surface_variant
    style.Colors[c.PopupBg] = surface
    style.Colors[c.Border] = outline
    style.Colors[c.BorderShadow] = rgba(0, 0, 0, 0)

    style.Colors[c.FrameBg] = surface_variant
    style.Colors[c.FrameBgHovered] = primary_hover
    style.Colors[c.FrameBgActive] = primary_container

    style.Colors[c.TitleBg] = surface
    style.Colors[c.TitleBgActive] = surface_container
    style.Colors[c.TitleBgCollapsed] = surface_variant

    style.Colors[c.MenuBarBg] = surface_variant

    style.Colors[c.ScrollbarBg] = surface
    style.Colors[c.ScrollbarGrab] = surface_bright
    style.Colors[c.ScrollbarGrabHovered] = outline
    style.Colors[c.ScrollbarGrabActive] = on_surface_variant

    style.Colors[c.CheckMark] = primary
    style.Colors[c.SliderGrab] = primary
    style.Colors[c.SliderGrabActive] = primary_pressed

    style.Colors[c.Button] = primary_container
    style.Colors[c.ButtonHovered] = primary_hover
    style.Colors[c.ButtonActive] = primary_pressed

    style.Colors[c.Header] = surface_container
    style.Colors[c.HeaderHovered] = primary_hover
    style.Colors[c.HeaderActive] = primary_pressed

    style.Colors[c.Separator] = outline_variant
    style.Colors[c.SeparatorHovered] = primary_hover
    style.Colors[c.SeparatorActive] = primary

    style.Colors[c.ResizeGrip] = rgba(0, 0, 0, 0)
    style.Colors[c.ResizeGripHovered] = primary_hover
    style.Colors[c.ResizeGripActive] = primary

    style.Colors[c.Tab] = surface_variant
    style.Colors[c.TabHovered] = surface_hover
    style.Colors[c.TabSelected] = primary_container
    style.Colors[c.TabSelectedOverline] = primary
    style.Colors[c.TabDimmed] = surface_variant
    style.Colors[c.TabDimmedSelected] = surface_container

    style.Colors[c.PlotLines] = secondary
    style.Colors[c.PlotLinesHovered] = primary
    style.Colors[c.PlotHistogram] = primary
    style.Colors[c.PlotHistogramHovered] = primary_hover

    style.Colors[c.TableHeaderBg] = surface_container
    style.Colors[c.TableBorderStrong] = outline
    style.Colors[c.TableBorderLight] = outline_variant
    style.Colors[c.TableRowBg] = rgba(0, 0, 0, 0)
    style.Colors[c.TableRowBgAlt] = surface_hover

    style.Colors[c.TextSelectedBg] = primary_pressed
    style.Colors[c.DragDropTarget] = primary_hover

    style.Colors[c.NavCursor] = primary
    style.Colors[c.NavWindowingHighlight] = primary_hover
    style.Colors[c.NavWindowingDimBg] = rgba(0, 0, 0, 128)
    style.Colors[c.ModalWindowDimBg] = rgba(0, 0, 0, 102)
end

imgui.OnInitialize(function()

    local font = Misc:get_config().font
    if font.path == "" then
        font.path = getFolderPath(0x14) .. "\\calibri.ttf"
    else

        if not doesFileExist(font.path) then
            font.path = getFolderPath(0x14) .. "\\calibri.ttf"
        end
    end

    local reference_height = 1440.0
    local res_x, res_y = getScreenResolution()
    local font_size = 18.0 * (res_y / reference_height)

    font_size = math.max(12, math.min(font_size, 18))

    imgui.GetIO().IniFilename = nil
    imgui.DarkTheme()

    imgui.GetIO().Fonts:Clear()
    imgui.GetIO().FontDefault = imgui.GetIO().Fonts:AddFontFromFileTTF(font.path, font_size)

    local icon_config = imgui.ImFontConfig()
    icon_config.MergeMode = true
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), font_size, icon_config)
end)

local saved_for_reload=false
function save_config()
    if saved_for_reload then return true end
    local saved=true
    for _, pair in ipairs(components) do
        local component = pair.component

        if component and component.save_config then
            local ok, result, err = pcall(component.save_config, component)
            if not ok or result==false then
                saved=false
                print('Failed to save component config:', ok and err or result)
            end
        end
    end
    return saved
end

function main()
    while not isSampAvailable() do
        wait(0)
    end

    setup_directories()
    initialize_components()
    require("src.ui.Dialogs").start()

    shared.event_handler:process("onScriptInit")

    Extras:loaded()
    local Updates=require("src.core.Updates")
    Updates.start()
    msg("Leone Menu loaded. Use {1E3348}/leone{FFFFFF}.")

    local last_save=os.time()
    while true do
        local ready=Extras:can_update()
        if Home.update_check_requested then
            Home.update_check_requested=false
            Updates.request_check()
        end
        Updates.tick(ready)
        if Home.reload_requested and ready and not Updates.busy and not Updates.skins_busy then
            Home.reload_requested=false
            if Updates.restart_required then
                msg(Updates.status)
            elseif not save_config() then
                last_save=os.time()
                msg('Could not save settings. Reload canceled.')
            else
                last_save=os.time()
                local menu=require('src.ui.MainWindow')
                menu:hide(false)
                wait(0)
                if not Extras:can_update() or menu:is_open() then
                    Home.reload_requested=true
                else
                    saved_for_reload=true
                    local ok,result=pcall(function()
                        Extras:stop_startup_audio()
                        imgui.ShutdownRenderer()
                        return thisScript():reload()
                    end)
                    if ok and result~=false then return end
                    saved_for_reload=false
                    print('[Leone Menu] Live reload did not complete: '..tostring(result))
                    msg('Could not reload Leone Menu. Restart GTA to reload it.')
                end
            end
        end
        if os.time()-last_save>=30 then save_config();last_save=os.time() end
        shared.hotkey_manager:update()
        process_player_tick()
        wait(0)
    end
end
