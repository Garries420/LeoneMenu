-- Module: F:\2025\EDrive\dev\luapack\src\ui\Overlay.lua

local bit = require("bit")
local imgui = require("upmimgui")
local fa = require("fAwesome7")

local ElementRealigner = require("src.utils.ElementRealigner")

local OVERLAY_FLAGS = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize +
    imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoNav +
    imgui.WindowFlags.NoMove + imgui.WindowFlags.NoInputs

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new(config, condition, render_content)
    local self = setmetatable({}, Overlay)

    self.config = config
    self.condition = condition
    self.render_content = render_content

    imgui.OnFrame(
        function() return pass_render_checks() and self.condition() end,
        function()
            -- MoonLoader can process acceptance/server events after the updater's
            -- visibility check but before D3DPresent. Re-check current state here.
            if pass_render_checks() and self.condition() then self:render() end
        end
    ).HideCursor = true

    return self
end

function Overlay.setup_overlay_defaults(display, pos_x, pos_y, font_size, padding, border_thickness, rounding, bg_render,
                                        bg_color, border_render, border_color)
    return {
        display = imgui.new.bool(display ~= false),
        pos = {
            x = imgui.new.float(pos_x or 0.5),
            y = imgui.new.float(pos_y or 0.5)
        },
        font_size = imgui.new.int(font_size or 20),
        scale = imgui.new.float(1),
        horizontal = imgui.new.bool(false),
        padding = imgui.new.int(padding or 4),
        border_thickness = imgui.new.int(border_thickness or 1),
        rounding = imgui.new.int(rounding or 8),

        bg_render = imgui.new.bool(bg_render ~= false),
        bg_color = imgui.new.float[4](
            bg_color and bg_color[1] or 0,
            bg_color and bg_color[2] or 0,
            bg_color and bg_color[3] or 0,
            bg_color and bg_color[4] or 0.196
        ),

        border_render = imgui.new.bool(border_render ~= false),
        border_color = imgui.new.float[4](
            border_color and border_color[1] or 0,
            border_color and border_color[2] or 0,
            border_color and border_color[3] or 0,
            border_color and border_color[4] or 0.196
        ),
    }
end

function Overlay.render_overlay_settings(config, prefix, draw_extra_appearance)
    prefix = prefix or ""
    local cfg = config

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Position & Appearance##" .. prefix, function(width)
        imgui.Text("Overlay position on screen")
        imgui.SameLine(width - 100)
        if imgui.AnimButton(fa("RETWEET") .. " Position", imgui.ImVec2(100, 0)) then
            ElementRealigner:realign_element(
                function(x, y)
                    cfg.pos.x[0] = x
                    cfg.pos.y[0] = y
                end, {preview=prefix}
            )
        end

        imgui.Separator()
        imgui.Text("Draw a background")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("bg_render", cfg.bg_render)
        imgui.SameLine(width - imgui.ToggleButtonWidth() - 34 - imgui.GetStyle().ItemSpacing.x)
        imgui.ColorEdit4("##bg_color", cfg.bg_color, imgui.ColorEditFlags.NoInputs)

        imgui.Separator()
        imgui.Text("Draw a border")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("border_render", cfg.border_render)
        imgui.SameLine(width - imgui.ToggleButtonWidth() - 34 - imgui.GetStyle().ItemSpacing.x)
        imgui.ColorEdit4("##border_color", cfg.border_color, imgui.ColorEditFlags.NoInputs)
        if draw_extra_appearance then draw_extra_appearance(width) end
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Style Properties##" .. prefix, function(child_width)
        local sliders = {
            { id = "##font_size", value = cfg.font_size, min = 1, max = 64, text = "Font size" },
            { id = "##padding", value = cfg.padding, min = 0, max = 64, text = "Padding" },
            { id = "##border_thickness", value = cfg.border_thickness, min = 1, max = 64, text = "Border Thickness" },
            { id = "##rounding", value = cfg.rounding, min = 0, max = 64, text = "Rounding" },
        }

        local radius = imgui.ScaleValue(4)
        local spacing = imgui.ScaleValue(10)

        local total_width = #sliders * radius * 2 + (#sliders - 1) * spacing

        local start_x = math.max(0, (child_width - total_width) / 2)
        local start_y = imgui.GetCursorPos().y

        imgui.BeginGroup()
        for i, s in ipairs(sliders) do
            imgui.SetCursorPos(imgui.ImVec2(start_x + (i - 1) * (radius * 2 + spacing), start_y))
            imgui.SemiCircularSlider(s.id, s.value, s.min, s.max, radius, " px", nil, s.text)
        end
        imgui.EndGroup()
    end)
end

function Overlay:TextOutline(text, thickness)
    local pos = imgui.GetCursorPos()
    local scale=self.config.scale and self.config.scale[0] or 1
    for i = 1, thickness do
        local offset=i*scale
        imgui.SetCursorPos(imgui.ImVec2(pos.x + offset, pos.y))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
        imgui.SetCursorPos(imgui.ImVec2(pos.x - offset, pos.y))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
        imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y + offset))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
        imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y - offset))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
    end
    imgui.SetCursorPos(pos)
end

function Overlay:TextRGB(text)
    local cfg = self.config
    if not cfg then return end

    local style = imgui.GetStyle()
    local current_color = style.Colors[imgui.Col.Text]

    local function explode_rgba(rgba)
        local r = bit.band(bit.rshift(rgba, 24), 0xFF)
        local g = bit.band(bit.rshift(rgba, 16), 0xFF)
        local b = bit.band(bit.rshift(rgba, 8), 0xFF)
        local a = bit.band(rgba, 0xFF)
        return r, g, b, a
    end

    text = text:gsub('{(%x%x%x%x%x%x)}',function(c)
        c=c:upper()
        if self.allowed_colors and self.allowed_colors[c] then return '{'..c..'FF}' end
        if c=='FFFFFF' or c=='00FF00' or c=='6DFB6D' or c=='FF0000' or c=='FF4444' then return '{'..c..'FF}' end
        return '{1E3348FF}'
    end)

    local pos = 1
    local first_segment = true

    for tag_start, color_hex, tag_end in text:gmatch('()%{(%x%x%x%x%x%x%x%x)%}()') do

        local segment = text:sub(pos, tag_start - 1)
        if #segment > 0 then
            if not first_segment then
                imgui.SameLine(nil, 0)
            end

            imgui.PushFont(nil, cfg.font_size[0]*(cfg.scale and cfg.scale[0] or 1))
            self:TextOutline(segment, 2)
            imgui.TextColored(current_color, segment)
            imgui.PopFont()

            first_segment = false
        end

        local packed_color = tonumber(color_hex, 16)
        if packed_color then
            local r, g, b, a = explode_rgba(packed_color)
            current_color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
        end

        pos = tag_end
    end

    local remaining = text:sub(pos)
    if #remaining > 0 then
        if not first_segment then
            imgui.SameLine(nil, 0)
        end

        imgui.PushFont(nil, cfg.font_size[0]*(cfg.scale and cfg.scale[0] or 1))
        self:TextOutline(remaining, 1)
        imgui.TextColored(current_color, remaining)
        imgui.PopFont()
    end
end

function Overlay:render()
    local cfg = self.config
    if not cfg then return end
    local scale=cfg.scale and cfg.scale[0] or 1

    -- Layout may read ImGui state only here, on the selected render context.
    local anchor, offset_y, offset_x
    if self.prepare_layout then anchor,offset_y,offset_x=self.prepare_layout() end
    local display_size = imgui.GetIO().DisplaySize
    local pos = anchor or cfg.pos
    local pos_x = pos.x[0] * display_size.x
    local pos_y = pos.y[0] * display_size.y + (offset_y or 0)

    local pivot = imgui.ImVec2(0.0, 0.0)
    if pos_x > display_size.x * 0.5 then
        pivot.x = 1.0
    end

    cfg.padding_anchor=cfg.padding_anchor or cfg.padding[0]
    local delta=(cfg.padding[0]-cfg.padding_anchor)*scale
    pos_x=pos_x+(offset_x or 0)+(pivot.x==1 and delta or -delta)
    pos_y=pos_y-delta
    imgui.SetNextWindowPos(imgui.ImVec2(pos_x, pos_y), imgui.Cond.Always, pivot)

    if cfg.bg_render[0] then
        imgui.PushStyleColor(imgui.Col.WindowBg,
            imgui.ImVec4(cfg.bg_color[0], cfg.bg_color[1], cfg.bg_color[2], cfg.bg_color[3]))
    else

        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
    end

    if cfg.border_render[0] and cfg.border_thickness[0] > 0 then
        imgui.PushStyleColor(imgui.Col.Border,
            imgui.ImVec4(cfg.border_color[0], cfg.border_color[1], cfg.border_color[2], cfg.border_color[3]))
        imgui.PushStyleVar(imgui.StyleVar.WindowBorderSize, cfg.border_thickness[0]*scale)
    else
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleVar(imgui.StyleVar.WindowBorderSize, 0)
    end

    imgui.PushStyleVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(cfg.padding[0]*scale, cfg.padding[0]*scale))
    imgui.PushStyleVar(imgui.StyleVar.WindowRounding, cfg.rounding[0]*scale)

    local window_name = "Overlay##" .. tostring(self)
    imgui.Begin(window_name, nil, OVERLAY_FLAGS)

    if self.render_content then
        self.render_content(self)
    end

    self.last_width = imgui.GetWindowWidth()
    self.last_height = imgui.GetWindowHeight()
    self.last_scale = scale
    imgui.End()

    imgui.PopStyleVar()
    imgui.PopStyleVar()
    imgui.PopStyleVar()
    imgui.PopStyleColor()
    imgui.PopStyleColor()
end

return Overlay
