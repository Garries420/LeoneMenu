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
for _, group in ipairs(groups) do
    group.ranks = {}
    for index, weapon in ipairs(group.weapons) do
        local name, id, tier, alternate = unpack(weapon)
        local rank = tier or index
        by_name[name] = {group = group, rank = rank}
        group.ranks[id] = rank
        if alternate then group.ranks[alternate] = rank end
    end
end

function W.defaults()
    return {binds = {}, next_id = 1, auto_accept = imgui.new.bool(false)}
end

local function bind_name(row)
    return 'sell_weapon_' .. row.id
end

local function register_bind(row)
    local function sell()
        local weapon = Rules.trim(row.weapon):lower()
        if not by_name[weapon] then return end

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

local function add_bind()
    local row = {id = cfg.next_id, weapon = '', keys = {}}
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
        register_bind(row)
        cfg.next_id = math.max(cfg.next_id, row.id + 1)
    end
    if #cfg.binds == 0 then add_bind() end
    shared.event_handler:register('SERVER_MESSAGE', function() return cfg.auto_accept[0] end, accept_offer)
end

local function weapon_tooltip()
    if not imgui.IsItemHovered() then return end
    imgui.BeginTooltip()
    imgui.TextUnformatted('Available weapon names')
    imgui.Separator()
    imgui.TextUnformatted('9mm, sdpistol, deagle, shotgun, spas12, mp5')
    imgui.TextUnformatted('ak47, m4, rifle, sniper')
    imgui.TextUnformatted('flowers, cane, shovel, poolcue, golfclub, dildo, katana')
    imgui.TextUnformatted('knuckles, baseballbat')
    local donor_color = imgui.ImVec4(183/255, 209/255, 235/255, 1)
    imgui.TextColored(donor_color, 'uzi - Sapphire+ Donator only')
    imgui.TextColored(donor_color, 'tec9 - Sapphire+ Donator only')
    imgui.EndTooltip()
end

function W:render_ui_settings()
    imgui.DrawChild('Weapons', function(width)
        imgui.TextWrapped('type the weapons name you want to sell, add a keybind, and when you aim and click this keybind it will sell the weapon for 0$. + to add more and - to remove')
        local height = imgui.GetFrameHeight()
        local button = imgui.ImVec2(height, 0)
        local key_size = imgui.ImVec2(180, 0)
        local field_width = math.min(350, width - key_size.x - height - 2 * imgui.GetStyle().ItemSpacing.x)
        local add, remove
        for i, row in ipairs(cfg.binds) do
            imgui.PushID(row.id)
            row.weapon = H.input('##weapon_name', row.weapon, 'Weapon name', field_width, 32)
            weapon_tooltip()
            if imgui.IsItemDeactivatedAfterEdit() then save() end
            imgui.SameLine()
            local keys = shared.hotkey_manager:draw_key_editor(bind_name(row), key_size)
            if keys then row.keys = keys; save() end
            imgui.SameLine()
            if i == 1 then
                add = imgui.AnimButton('+##weapon_add', button)
            elseif imgui.AnimButton('-##weapon_remove', button) then
                remove = i
            end
            imgui.PopID()
        end
        if add then add_bind(); save() end
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
