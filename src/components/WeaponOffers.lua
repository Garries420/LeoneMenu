local imgui = require('upmimgui')
local H = require('src.ui.Helpers')
local Rules = require('src.core.Rules')
local shared = require('src.shared')

local W = {}
local cfg, save

-- MoonLoader slots are one-based. Melee, gifts and brass knuckles share a
-- single ranking here, even though GTA stores them in different slots.
local groups = {
    {slots = {3}, weapons = {{'9mm', 22}, {'sdpistol', 23}, {'deagle', 24}}},
    {slots = {4}, weapons = {{'shotgun', 25}, {'spas12', 27}}},
    {slots = {5}, weapons = {{'tec9', 32}, {'uzi', 28}, {'mp5', 29}}},
    {slots = {6}, weapons = {{'ak47', 30}, {'m4', 31}}},
    {slots = {7}, weapons = {{'rifle', 33}, {'sniper', 34}}},
    {slots = {1, 2, 11}, weapons = {
        {'flowers', 14, 1}, {'cane', 15, 1}, {'shovel', 6, 1}, {'poolcue', 7, 1},
        {'golfclub', 2, 1}, {'dildo', 10, 1, 11}, {'katana', 8, 1},
        {'knuckles', 1, 2}, {'baseballbat', 5, 3},
    }},
}
local by_name = {}
local weapon_names = {}
for _, group in ipairs(groups) do
    group.ranks = {}
    for index, weapon in ipairs(group.weapons) do
        local name, id, tier, alternate = unpack(weapon)
        local rank = tier or index
        by_name[name] = {group = group, rank = rank}
        weapon_names[#weapon_names+1]=name
        group.ranks[id] = rank
        if alternate then group.ranks[alternate] = rank end
    end
end

local drop_names={'sdpistol','9mm','shotgun','mp5','uzi','tec9','rifle','m4','ak47'}
local aliases={['colt45']='9mm', ['silencedpistol']='sdpistol', ['silencepistol']='sdpistol',
    ['countyrifle']='rifle', ['countryrifle']='rifle', ['combatshotgun']='spas12', ['sniperrifle']='sniper',
    ['deserteagle']='deagle'}

local function weapon_name(text)
    local key=Rules.trim(text):lower():gsub('[%s%-]','')
    return aliases[key] or (by_name[key] and key)
end

function W.defaults()
    return {binds = {}, next_id = 1, auto_accept = imgui.new.bool(false)}
end

local function bind_name(row)
    return 'sell_weapon_' .. row.id
end

local function register_bind(row)
    local function sell()
        local weapon = weapon_name(row.weapon)
        if not weapon then return end
        if row.self_craft then
            sampSendChat('/makegun '..weapon)
            return
        end

        local aimed, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)
        if not aimed or ped == PLAYER_PED or not doesCharExist(ped) then return end
        local found, id = sampGetPlayerIdByCharHandle(ped)
        if found and sampIsPlayerConnected(id) then
            sampSendChat(('/sellgun %d %s 0'):format(id, weapon))
        end
    end

    local hotkeys = shared.hotkey_manager
    local name = bind_name(row)
    if not hotkeys:register(name, row.keys, sell) then
        row.keys = {}
        hotkeys:register(name, row.keys, sell)
    end
end

local function add_bind(self_craft)
    local row = {id = cfg.next_id, weapon = '', keys = {}, self_craft = self_craft}
    cfg.next_id = row.id + 1
    table.insert(cfg.binds, row)
    register_bind(row)
end

local function accept_offer(_, text)
    local name, price = Rules.strip(text):match(
        '^%* Arms Dealer .- wants to sell you an? (.-) for %$(%d+), %(type /accept weapon%) to buy%.$')
    if not name or tonumber(price) > 1 or not doesCharExist(PLAYER_PED) then return end
    local offer = by_name[Rules.trim(name):lower()]
    if not offer then return end

    for _, slot in ipairs(offer.group.slots) do
        local owned = getCharWeaponInSlot(PLAYER_PED, slot)
        local rank = offer.group.ranks[owned]
        if owned ~= 0 and (not rank or rank >= offer.rank) then return end
    end
    sampSendChat('/accept weapon')
end

function W:register(config, on_save)
    cfg, save = config, on_save
    for _, row in ipairs(cfg.binds) do
        row.weapon=weapon_name(row.weapon) or row.weapon
        register_bind(row)
        cfg.next_id = math.max(cfg.next_id, row.id + 1)
    end
    if #cfg.binds == 0 then add_bind() end
    shared.event_handler:register('SERVER_MESSAGE', function() return cfg.auto_accept[0] end, accept_offer)
end

local function weapon_label(name)
    return (name=='uzi' or name=='tec9') and (name..' - Sapphire+') or name
end

local function weapon_selector(row, width, craft_color)
    local selected=weapon_name(row.weapon)
    if row.self_craft then
        imgui.PushStyleColor(imgui.Col.FrameBg,craft_color)
        imgui.PushStyleColor(imgui.Col.FrameBgHovered,craft_color)
        imgui.PushStyleColor(imgui.Col.PopupBg,craft_color)
    end
    imgui.SetNextItemWidth(width)
    if imgui.BeginCombo('##weapon_name',selected and weapon_label(selected) or 'Select a weapon') then
        for _,name in ipairs(weapon_names) do
            local sapphire=name=='uzi' or name=='tec9'
            if sapphire then imgui.PushStyleColor(imgui.Col.Text,imgui.ImVec4(183/255,209/255,235/255,1)) end
            if imgui.Selectable(weapon_label(name),name==selected) then
                row.weapon=name
                save()
            end
            if sapphire then imgui.PopStyleColor() end
            if name==selected then imgui.SetItemDefaultFocus() end
        end
        imgui.EndCombo()
    end
    if row.self_craft then imgui.PopStyleColor(3) end
end

function W.drop_defaults()
    local choices={}
    for _,name in ipairs(drop_names) do choices[name]=imgui.new.bool(false) end
    return {enabled=imgui.new.bool(false),choices=choices}
end

function W.register_paycheck_drop(config)
    local pending={}
    shared.event_handler:register('SERVER_CONNECTED',function()return true end,function() pending={} end)
    shared.event_handler:register('SERVER_MESSAGE',function()return config.enabled[0] end,function(_,text)
        local tier,gift=Rules.trim(Rules.strip(text)):lower():match('^(%a+) donator gift:%s*(.+)$')
        if tier~='diamond' and tier~='sapphire' and tier~='ruby' then return end
        local name=weapon_name(gift)
        if name and config.choices[name] and config.choices[name][0] and not pending[name] then
            local current=pending
            current[name]=true
            lua_thread.create(function()
                wait(100) -- Let SA-MP apply the paycheck's weapon grant before sending the command.
                if current~=pending then return end
                pending[name]=nil
                if config.enabled[0] and config.choices[name][0] and sampGetGamestate()==3 and sampIsLocalPlayerSpawned() then
                    sampSendChat('/dropgun '..name)
                end
            end)
        end
    end)
end

function W.render_paycheck_drop(config,on_save)
    imgui.DrawChild('Paycheck Weapons',function(width)
        imgui.Text('Automatically drop bad weapons on paycheck')
        local toggle_width=imgui.ToggleButtonWidth()
        if config.enabled[0] then
            imgui.SameLine(width-toggle_width-86-imgui.GetStyle().ItemSpacing.x)
            local opened=imgui.AnimButton('Config##paycheck_weapons',imgui.ImVec2(86,0))
            local anchor=imgui.GetItemRectMin()
            if imgui.IsItemHovered() then imgui.SetTooltip('The weapons you tick here will be dropped on a paycheck.') end
            if opened then imgui.OpenPopup('paycheck_weapon_choices') end
            imgui.SetNextWindowPos(anchor,imgui.Cond.Appearing,imgui.ImVec2(0,1))
            if imgui.BeginPopup('paycheck_weapon_choices') then
                for _,name in ipairs(drop_names) do
                    if imgui.Checkbox(name,config.choices[name]) then on_save() end
                end
                imgui.EndPopup()
            end
        end
        imgui.SameLine(width-toggle_width)
        if imgui.ToggleButton('##paycheck_drop',config.enabled) then on_save() end
    end)
end

function W:render_ui_settings()
    imgui.DrawChild('Weapons', function(width)
        imgui.TextWrapped('Select a weapon and assign a keybind. Aim at a player to sell for $0, or add a self-craft bind to use /makegun.')
        local height = imgui.GetFrameHeight()
        local button = imgui.ImVec2(height, 0)
        local key_size = imgui.ImVec2(180, 0)
        local field_width = math.max(70,math.min(350, width - key_size.x - 2 * height - 3 * imgui.GetStyle().ItemSpacing.x))
        local craft_color=imgui.ImVec4(0.26,0.20,0.36,1)
        local add, remove
        for i, row in ipairs(cfg.binds) do
            imgui.PushID(row.id)
            weapon_selector(row,field_width,craft_color)
            imgui.SameLine()
            local keys = shared.hotkey_manager:draw_key_editor(bind_name(row), key_size)
            if keys then row.keys = keys; save() end
            imgui.SameLine()
            if i == 1 then
                if imgui.AnimButton('+##weapon_add', button) then add='sell' end
                if imgui.IsItemHovered() then imgui.SetTooltip('click this to add a new weapon to sell to someone else') end
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Button,craft_color)
                if imgui.AnimButton('+##weapon_craft_add', button) then add='craft' end
                imgui.PopStyleColor()
                if imgui.IsItemHovered() then imgui.SetTooltip('click this to add a new weapon that you sell to yourself') end
            elseif imgui.AnimButton('-##weapon_remove', button) then
                remove = i
            end
            imgui.PopID()
        end
        if add then add_bind(add=='craft'); save() end
        if remove then
            local row = table.remove(cfg.binds, remove)
            shared.hotkey_manager:unregister(bind_name(row))
            save()
        end
        imgui.Separator()
        local tip = "Only accepts if the weapon offered is better than yours, or you don't currently have that weapon on you"
        if H.toggle('Auto accept weapons if offered at 1$ or 0$', 'weapon_auto_accept', cfg.auto_accept, width, tip) then
            save()
        end
        if imgui.IsItemHovered() then imgui.SetTooltip(tip) end
    end)
end

return W
