-- Module: F:\2025\EDrive\dev\luapack\src\overlays\PedCounter.lua

local Overlay = require("src.ui.Overlay")
local PedCounter = require("src.components.PedCounter")

local function color_byte(value)
    return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

local function color_tag(color)
    return ("{%02X%02X%02X%02X}"):format(color_byte(color[0]), color_byte(color[1]), color_byte(color[2]), color_byte(color[3]))
end

local function create()
    local cfg = PedCounter:get_overlay_config()

    Overlay.new(
        cfg,
        function()
            if not cfg.display[0] then
                return false
            end

            if not cfg.display_outside_interiors[0] and getActiveInterior() == 0 then
                return false
            end

            return true
        end,
        function(self)
            local number_color = cfg.sync_text_colors[0] and cfg.label_color or cfg.number_color
            self:TextRGB(color_tag(cfg.label_color) .. "PEDS: " .. color_tag(number_color) .. PedCounter:get_active_slots())
        end
    )
end

return {
    create = create
}
