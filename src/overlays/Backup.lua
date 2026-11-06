-- Module: F:\2025\EDrive\dev\luapack\src\overlays\Backup.lua

local bit = require("bit")
local Backup = require("src.components.Backup")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")

local function create()
    local cfg = Backup:get_overlay_config()

    local overlay=Overlay.new(
        cfg,
        function()

            if not cfg.display[0] then
                return false
            end

            if Player:is_on_admin_duty() then
                return false
            end

            return true
        end,
        function(self)
            local backup_requests = {}

            for player_id = 0, sampGetMaxPlayerId(false) do
                if sampIsPlayerConnected(player_id) then
                    if Backup:is_requesting(player_id) then
                        table.insert(backup_requests, player_id)
                    end
                end
            end

            if #backup_requests == 0 then
                self:TextRGB("No backups active")
                return
            end

            for _, player_id in ipairs(backup_requests) do
                local name = sampGetPlayerNickname(player_id)
                self:TextRGB(string.format("{FFFF00}%s (%d)", name, player_id))
            end
        end
    )
    overlay.allowed_colors={["FFFF00"]=true}
end

return {
    create = create
}
