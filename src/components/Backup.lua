-- Module: F:\2025\EDrive\dev\luapack\src\components\Backup.lua

local bit = require("bit")
local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")

local CONFIG_PATH = "config/Leone Menu/backup.json"

local default_data = {
    overlay = Overlay.setup_overlay_defaults(
        false,
        0.943,
        0.487,
        12,
        8,
        5,
        4,
        true,
        { 0, 0, 0, 0.588 },
        true,
        { 0, 0, 0, 0.588 }
    ),
}

default_data.wanted=imgui.new.bool(false)
default_data.bind={keys={}}
local H=require('src.ui.Helpers')
local shared=require('src.shared')
local locations=require('src.core.CustomLocations')
local Rules=require('src.core.Rules')
local show_locations=false
local backup_active=false
local interior_labels,labels_scanned={},false
local interior_game_text_until=0
local function observe_label(id,text)
    interior_labels[id]=type(text)=='string' and Rules.trim(Rules.strip(text)):upper()=='INTERIOR' or nil
end
local function interior_label_visible()
    local can_read=sampTextdrawIsExists and sampTextdrawGetString
    if not labels_scanned then
        labels_scanned=true
        -- A script reload can occur after the server has already shown the label.
        if can_read then
            for id=0,2047 do if sampTextdrawIsExists(id) then observe_label(id,sampTextdrawGetString(id)) end end
        end
    end
    for id in pairs(interior_labels)do
        if can_read then
            if sampTextdrawIsExists(id) then observe_label(id,sampTextdrawGetString(id)) else interior_labels[id]=nil end
        end
        if interior_labels[id] then return true end
    end
    return os.clock()<interior_game_text_until
end

local _config = default_data

local Backup = {}

function Backup:is_requesting(player_id)
    if not sampIsPlayerConnected(player_id) then
        return false
    end

    local color = sampGetPlayerColor(player_id)
    local alpha = bit.rshift(color, 24)

    return alpha == 0xAA
end

function Backup:register()
    carboneum.load(CONFIG_PATH, _config)
    shared.event_handler:register('SHOW_TEXTDRAW',function()return true end,function(id,data)observe_label(id,data.text)end)
    shared.event_handler:register('TEXTDRAW_SET_STRING',function()return true end,observe_label)
    shared.event_handler:register('HIDE_TEXTDRAW',function()return true end,function(id)interior_labels[id]=nil end)
    shared.event_handler:register('DISPLAY_GAME_TEXT',function()return true end,function(_,time,text)
        interior_game_text_until=Rules.trim(Rules.strip(text)):upper()=='INTERIOR' and os.clock()+time/1000 or 0
    end)

    shared.hotkey_manager:register('faction_backup',_config.bind.keys,function()
        local radio_only=interior_label_visible()
        if backup_active and not radio_only then
            sampSendChat('/nobackup');backup_active=false;return
        end
        local x,y,z=getCharCoordinates(PLAYER_PED)
        local interior=getActiveInterior()
        local special=locations.find(x,y,z,interior)
        local place
        if interior==0 then
            local zone=require('src.utils.ZoneManager'):get_zone(x,y)
            place=special and (special.name..', '..zone) or zone
        else
            place=special and special.name or 'Interior'
        end
        local wanted, ending = "", ""
        if _config.wanted[0] then
            -- MoonLoader opcode 01C0 returns a result flag before the level.
            local _, stars = storeWantedLevel(PLAYER_HANDLE)
            if type(stars) == "number" and stars >= 1 and stars <= 6 and stars % 1 == 0 then
                wanted = ("Wanted with %d %s! "):format(stars, stars == 1 and "charge" or "charges")
                ending = "!"
            end
        end
        sampSendChat("/pr I need urgent backup, " .. wanted .. "Currently at " .. place .. ending)
        if not radio_only then sampSendChat('/fbackup');backup_active=true end
    end)
    MainWindow:add_page("backup", {
        icon = fa("BULLHORN"),
        title = "Backup",
        icon_box_color = imgui.ImVec4(0.95, 0.5, 0.2, 1),
        prepare_search = function() show_locations=false end,
        render_function = Backup.render_ui_settings
    })
end

function Backup:get_config()
    return _config
end

function Backup:get_overlay_config()
    return _config.overlay
end

function Backup:save_config()
    return carboneum.save(CONFIG_PATH, _config)
end

function Backup:render_ui_settings()
    if show_locations then
        imgui.Heading('All custom locations')
        imgui.BeginChild('backup_locations',imgui.ImVec2(0,-45),true)
        for _,b in ipairs(locations) do
            imgui.Text(b.name)
            if locations.has_interior(b.name) then imgui.Text(b.name..' Interior') end
            imgui.Separator()
        end
        imgui.EndChild()
        if imgui.AnimButton('Back') then show_locations=false end
        return
    end
    imgui.DrawChild("Backup", function(width)

        imgui.Text("Show active backup requests")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton('##show_active_backups',_config.overlay.display)
        imgui.Separator()
        imgui.Text('Faction backup keybind')
        imgui.SameLine(width-350)
        if imgui.AnimButton('All custom locations') then show_locations=true end
        imgui.SameLine(width-180)
        local keys=shared.hotkey_manager:draw_key_editor('faction_backup',imgui.ImVec2(180,0))
        if keys then _config.bind.keys=keys end
        imgui.Separator()
        H.toggle('Mention wanted level','backup_wanted',_config.wanted,width)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    require("src.components.Misc"):render_portable_radio()

    if _config.overlay.display[0] then
        Overlay.render_overlay_settings(_config.overlay, "backup")
    end
end

return Backup
