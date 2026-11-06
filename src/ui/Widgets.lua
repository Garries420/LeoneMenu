-- Module: F:\2025\EDrive\dev\luapack\src\ui\Widgets.lua

local fa = require("fAwesome7")
local ffi = require("ffi")
local imgui = require("upmimgui")

local function ImGuiEnum(name)
    return setmetatable({ __name = name }, {
        __index = function(t, k)
            return imgui.lib[t.__name .. k]
        end
    })
end

imgui.DrawFlags = ImGuiEnum("ImDrawFlags_")
imgui.ChildFlags = ImGuiEnum("ImGuiChildFlags_")
imgui.TableFlags = ImGuiEnum("ImGuiTableFlags_")
imgui.TableColumnFlags = ImGuiEnum("ImGuiTableColumnFlags_")

local function show_cursor_on_hover(orig_func)
    return function(...)
        local result = orig_func(...)
        if imgui.IsItemHovered() then
            imgui.SetMouseCursor(imgui.MouseCursor.Hand)
        end
        return result
    end
end

imgui.Button = show_cursor_on_hover(imgui.Button)
imgui.SmallButton = show_cursor_on_hover(imgui.SmallButton)
imgui.InvisibleButton = show_cursor_on_hover(imgui.InvisibleButton)
imgui.Checkbox = show_cursor_on_hover(imgui.Checkbox)
imgui.Selectable = show_cursor_on_hover(imgui.Selectable)
imgui.ColorButton = show_cursor_on_hover(imgui.ColorButton)
imgui.ColorEdit4 = show_cursor_on_hover(imgui.ColorEdit4)
imgui.DragFloat = show_cursor_on_hover(imgui.DragFloat)
imgui.DragInt = show_cursor_on_hover(imgui.DragInt)
imgui.SliderInt = show_cursor_on_hover(imgui.SliderInt)
imgui.BeginCombo = show_cursor_on_hover(imgui.BeginCombo)

function imgui.ScaleValue(value)
    local font_factor = imgui.GetFontSize()
    return value * font_factor
end

function imgui.ScaleVec2(vec)
    return imgui.ImVec2(imgui.ScaleValue(vec.x), imgui.ScaleValue(vec.y))
end

function imgui.ToggleButtonWidth()
    local height = imgui.GetFrameHeight()
    local width = height * 2.7
    return width
end

function imgui.SemiCircularSlider(id, value, min, max, radius, format, tooltip, text, disabled)
    local style = imgui.GetStyle()
    local io = imgui.GetIO()

    radius = radius or (imgui.GetFontSize() * 3.2)
    format = format or ""
    disabled = disabled or false

    local angle_min, angle_max = math.pi * 0.75, math.pi * 2.25
    local arc_thickness = imgui.GetFontSize() * 0.3
    local knob_radius = imgui.GetFontSize() * 0.45

    local function normalize(val)
        return imgui.ImSaturate((val - min) / (max - min))
    end

    local storage = imgui.GetStateStorage()
    local angle_key = imgui.GetID(id .. "_angle")
    local normalized_key = imgui.GetID(id .. "_normalized")

    local normalized_value = normalize(value[0])
    local target_angle = angle_min + (angle_max - angle_min) * normalized_value
    local current_angle = storage:GetFloat(angle_key, target_angle)
    local current_normalized = storage:GetFloat(normalized_key, normalized_value)

    local label_height = text and imgui.CalcTextSize(text).y or 0
    local total_size = imgui.ImVec2(radius * 2, radius * 2 + label_height + 5)
    imgui.InvisibleButton("##" .. id, total_size)

    local is_active = imgui.IsItemActive() and not disabled
    local is_hovered = imgui.IsItemHovered() and not disabled

    local cursor_pos = imgui.GetItemRectMin()
    local center = imgui.ImVec2(cursor_pos.x + radius, cursor_pos.y + radius)
    local draw_list = imgui.GetWindowDrawList()

    local delta_time = io.DeltaTime
    local speed = is_active and 20.0 or 8.0
    local angle_diff = target_angle - current_angle

    local factor = imgui.ImSaturate(delta_time * speed)
    current_angle = current_angle + angle_diff * factor
    current_normalized = current_normalized + (normalized_value - current_normalized) * factor

    local segments = math.max(48, math.ceil(radius * 1.2))

    draw_list:PathArcTo(center, radius, angle_min, angle_max, segments)
    draw_list:PathStroke(imgui.GetColorU32(imgui.ImVec4(0.24, 0.24, 0.27, 1)), false, arc_thickness)

    if current_normalized > 0.01 then
        local filled_angle = current_angle
        local col = disabled and imgui.ImLerp(style.Colors[imgui.Col.SliderGrab], imgui.ImVec4(0, 0, 0, 1), 0.5)
            or style.Colors[imgui.Col.SliderGrab]
        draw_list:PathArcTo(center, radius, angle_min, filled_angle, segments)
        draw_list:PathStroke(imgui.GetColorU32(col), false, arc_thickness)
    end

    local knob_color = disabled and style.Colors[imgui.Col.TextDisabled]
        or (is_active and style.Colors[imgui.Col.SliderGrabActive] or style.Colors[imgui.Col.SliderGrab])
    local knob_pos = imgui.ImVec2(center.x + radius * math.cos(current_angle),
        center.y + radius * math.sin(current_angle))
    draw_list:AddCircleFilled(knob_pos, knob_radius, imgui.GetColorU32(knob_color), 12)

    local value_text = string.format("%d%s", value[0], format)
    local text_size = imgui.CalcTextSize(value_text)
    draw_list:AddText(imgui.ImVec2(center.x - text_size.x * 0.5, center.y - text_size.y * 0.5),
        imgui.GetColorU32(disabled and style.Colors[imgui.Col.TextDisabled] or style.Colors[imgui.Col.Text]),
        value_text)

    if text then
        local label_size = imgui.CalcTextSize(text)
        draw_list:AddText(imgui.ImVec2(cursor_pos.x + radius - label_size.x * 0.5,
                cursor_pos.y + radius * 2 + 5),
            imgui.GetColorU32(disabled and style.Colors[imgui.Col.TextDisabled] or style.Colors[imgui.Col.Text]),
            text)
    end

    if tooltip and is_hovered then
        imgui.BeginTooltip()
        imgui.Text(tooltip)
        imgui.EndTooltip()
    end

    if is_active and imgui.IsMouseDown(0) then
        local mouse = imgui.GetMousePos()
        local mouse_angle = math.atan2(mouse.y - center.y, mouse.x - center.x)

        if mouse_angle < 0 then
            mouse_angle = mouse_angle + 2 * math.pi
        end

        if mouse_angle < angle_min - math.pi * 0.25 then
            mouse_angle = mouse_angle + 2 * math.pi
        end

        if mouse_angle >= angle_min and mouse_angle <= angle_max then
            local new_norm = (mouse_angle - angle_min) / (angle_max - angle_min)
            value[0] = math.max(min, math.min(max, math.floor(min + (max - min) * new_norm + 0.5)))
            current_angle = mouse_angle
            current_normalized = new_norm
        end
    end

    storage:SetFloat(angle_key, current_angle)
    storage:SetFloat(normalized_key, current_normalized)

    return is_active
end

function imgui.Hint(str_id, hint)
    local animation_duration = 0.4
    local current_time = imgui.GetTime()
    local is_hovered = imgui.IsItemHovered()

    local storage = imgui.GetStateStorage()
    local start_time_key = imgui.GetID(str_id .. "_hint_start")
    local was_hovered_key = imgui.GetID(str_id .. "_was_hovered")

    local was_hovered = storage:GetBool(was_hovered_key, false)

    if is_hovered then
        local start_time = storage:GetFloat(start_time_key, -1)

        if not was_hovered or start_time == -1 then
            start_time = current_time
            storage:SetFloat(start_time_key, start_time)
        end

        local elapsed = current_time - start_time
        local alpha = math.min(elapsed / animation_duration, 1.0)

        if alpha > 0.01 then
            imgui.PushStyleVar_Float(imgui.StyleVar.Alpha, alpha)
            imgui.SetTooltip(hint)
            imgui.PopStyleVar()
        end
    end

    storage:SetBool(was_hovered_key, is_hovered)
end

function imgui.StatusDot(id, radius, selected)
    local cursor_pos = imgui.GetCursorScreenPos()
    local center = imgui.ImVec2(cursor_pos.x + radius, cursor_pos.y + radius)
    local style = imgui.GetStyle()

    local storage = imgui.GetStateStorage()
    local progress_key = imgui.GetID(id .. "_status_progress")

    local animation_progress = storage:GetFloat(progress_key, selected and 1.0 or 0.0)

    local target = selected and 1.0 or 0.0
    local animation_speed = 12.0
    local delta_time = imgui.GetIO().DeltaTime
    animation_progress = animation_progress +
        (target - animation_progress) * imgui.ImSaturate(delta_time * animation_speed)

    storage:SetFloat(progress_key, animation_progress)

    local icon = animation_progress > 0.5 and fa("CIRCLE_CHECK") or fa("CIRCLE_XMARK")
    local check_color = style.Colors[imgui.Col.CheckMark]
    local disabled_color = style.Colors[imgui.Col.TextDisabled]
    local status_color = imgui.ImLerp(disabled_color, check_color, animation_progress)

    local icon_size = imgui.CalcTextSize(icon)
    imgui.SetCursorScreenPos(imgui.ImVec2(center.x - icon_size.x / 2, center.y - icon_size.y / 2))
    imgui.TextColored(status_color, icon)

    imgui.SetCursorScreenPos(cursor_pos)
    if imgui.InvisibleButton(id, imgui.ImVec2(radius * 2, radius * 2)) then
        selected = not selected
    end

    imgui.SetCursorScreenPos(imgui.ImVec2(cursor_pos.x + radius * 2, cursor_pos.y))
    return selected
end

function imgui.PageButtonHeight()
    return imgui.GetFrameHeight() * 1.2
end

function imgui.PageButton(active, icon, label, button_width, status_opts, icon_box_color)
    local style = imgui.GetStyle()
    local button_height = imgui.PageButtonHeight()
    local rounding = style.FrameRounding

    local draw_list = imgui.GetWindowDrawList()
    local cursor_pos = imgui.GetCursorScreenPos()

    local str_id = label:match('##.+$') or label
    label = label:gsub('##.+$', '')

    local storage = imgui.GetStateStorage()
    local click_time_key = imgui.GetID(str_id .. "_click_time")
    local hover_start_key = imgui.GetID(str_id .. "_hover_start")

    local click_time = storage:GetFloat(click_time_key, 0.0)
    local hover_start = storage:GetFloat(hover_start_key, 0.0)

    local adjusted_button_width = button_width
    if status_opts then
        adjusted_button_width = button_width - 30
    end

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0, 0, 0, 0))
    local clicked = imgui.InvisibleButton(str_id, imgui.ImVec2(adjusted_button_width, button_height))
    imgui.PopStyleColor(3)

    local is_hovered = imgui.IsItemHovered()
    if clicked and not active then
        click_time = os.clock()
        storage:SetFloat(click_time_key, click_time)
    end

    local anim_speed = 0.32
    local hover_progress = 0

    if is_hovered and hover_start <= 0 then
        hover_start = os.clock()
        storage:SetFloat(hover_start_key, hover_start)
    elseif not is_hovered and hover_start > 0 then
        hover_start = -os.clock()
        storage:SetFloat(hover_start_key, hover_start)
    end

    if hover_start > 0 then
        hover_progress = imgui.ImSaturate((os.clock() - hover_start) / anim_speed)
    elseif hover_start < 0 then
        hover_progress = imgui.ImSaturate(1 - (os.clock() + hover_start) / anim_speed)
        if hover_progress == 0 then
            hover_start = 0
            storage:SetFloat(hover_start_key, hover_start)
        end
    end

    local elapsed = os.clock() - click_time
    local active_alpha = imgui.ImSaturate(elapsed / 0.3) * 0.6

    local active_bg = imgui.ImVec4(
        style.Colors[imgui.Col.ButtonActive].x,
        style.Colors[imgui.Col.ButtonActive].y,
        style.Colors[imgui.Col.ButtonActive].z,
        imgui.ImSaturate(active_alpha)
    )
    local hover_bg = style.Colors[imgui.Col.ButtonHovered]
    local base_bg = active and active_bg or imgui.ImVec4(0, 0, 0, 0)
    local bg_color = active and base_bg or imgui.ImLerp(base_bg, hover_bg, hover_progress)

    if bg_color.w > 0 then
        draw_list:AddRectFilled(
            cursor_pos,
            imgui.ImVec2(cursor_pos.x + button_width, cursor_pos.y + button_height),
            imgui.ColorConvertFloat4ToU32(bg_color),
            rounding
        )
    end

    local icon_box_size = imgui.GetFontSize() * 1.5
    local icon_box_padding = style.FramePadding.x
    local icon_box_x = cursor_pos.x + icon_box_padding
    local icon_box_y = cursor_pos.y + (button_height - icon_box_size) * 0.5
    icon_box_color = icon_box_color or style.Colors[imgui.Col.ButtonActive]
    draw_list:AddRectFilled(
        imgui.ImVec2(icon_box_x, icon_box_y),
        imgui.ImVec2(icon_box_x + icon_box_size, icon_box_y + icon_box_size),
        imgui.ColorConvertFloat4ToU32(icon_box_color),
        style.FrameRounding * 0.75
    )

    local icon_size = imgui.CalcTextSize(icon)
    local icon_x = icon_box_x + (icon_box_size - icon_size.x) * 0.5
    local icon_y = icon_box_y + (icon_box_size - icon_size.y) * 0.5
    local text_color = imgui.GetColorU32(active and imgui.Col.Text or imgui.Col.TextDisabled)
    draw_list:AddText(imgui.ImVec2(icon_x, icon_y), text_color, icon)

    local text_size = imgui.CalcTextSize(label)
    local label_x = icon_box_x + icon_box_size + style.ItemSpacing.x
    local label_y = cursor_pos.y + (button_height - text_size.y) * 0.5

    draw_list:AddText(imgui.ImVec2(label_x, label_y), text_color, label)

    if status_opts then
        local dot_radius = imgui.GetFontSize() * 0.5
        local dot_x = cursor_pos.x + button_width - style.FramePadding.x - (dot_radius * 2)
        local dot_y = cursor_pos.y + (button_height / 2) - dot_radius

        local prev_cursor = imgui.GetCursorScreenPos()
        imgui.SetCursorScreenPos(imgui.ImVec2(dot_x, dot_y))

        local status_id = str_id .. "_status"
        local old_value = status_opts.value
        status_opts.value = imgui.StatusDot(status_id, dot_radius, status_opts.value)

        imgui.SetCursorScreenPos(prev_cursor)

        if status_opts.on_toggle and old_value ~= status_opts.value then
            status_opts.on_toggle(status_opts.value)
        end
    end

    return clicked
end

function imgui.Heading(text)
    local heading_size = imgui.GetFontSize() * 1.2
    imgui.PushFont(nil, heading_size)
    imgui.Text(text)
    imgui.PopFont()
end

function imgui.StyledInputText(id, value, hint, size, max_len, flags)

    flags = flags or 0
    value = value or ""
    max_len = max_len or 256

    local style = imgui.GetStyle()

    if #value > max_len then
        value = value:sub(1, max_len)
    end

    local buf_size = max_len + 1
    local buf = ffi.new("char[?]", buf_size, value)

    local min_width = imgui.GetFontSize() * 7.5
    local width = min_width
    if size then
        if size.x == -1 then
            width = imgui.GetContentRegionAvail().x
        else
            width = size.x
        end
    elseif hint then
        width = math.max(imgui.CalcTextSize(hint).x + style.FramePadding.x * 4, min_width)
    end

    imgui.PushItemWidth(width)
    local changed = imgui.InputTextWithHint("##" .. id, hint or "", buf, buf_size, flags)
    imgui.PopItemWidth()

    local out = ffi.string(buf)

    return out, changed
end

function imgui.DrawChild(name, content_callback, size)
    if imgui.BeforeSettingsSection then imgui.BeforeSettingsSection(name) end
    size = size or imgui.ImVec2(-1, 0)
    local style = imgui.GetStyle()

    local storage = imgui.GetStateStorage()
    local fade_key = imgui.GetID(name .. "_fade_alpha")
    local last_frame_key = imgui.GetID(name .. "_last_frame")

    local current_frame = imgui.GetFrameCount()
    local last_frame = storage:GetInt(last_frame_key, -1)
    local is_first_frame = (last_frame == -1) or (current_frame > last_frame + 1)

    storage:SetInt(last_frame_key, current_frame)

    local current_alpha = storage:GetFloat(fade_key, is_first_frame and 0.0 or 1.0)
    if is_first_frame then current_alpha = 0.0 end

    local target_alpha = 1.0
    local fade_speed = 4.0
    local delta_time = imgui.GetIO().DeltaTime

    current_alpha = current_alpha + (target_alpha - current_alpha) * imgui.ImSaturate(delta_time * fade_speed)
    storage:SetFloat(fade_key, current_alpha)

    imgui.PushStyleVar(imgui.StyleVar.Alpha, current_alpha)
    imgui.BeginChild(name, size, imgui.ChildFlags.AlwaysUseWindowPadding + imgui.ChildFlags.AutoResizeY, imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)

    local has_visible_heading = not name:match("^##(.+)$")
    if has_visible_heading then
        local display_name = name:match("^(.-)##") or name
        local available_width = imgui.GetContentRegionAvail().x

        local heading_font_size = imgui.GetFontSize() * 1.2
        imgui.PushFont(nil, heading_font_size)
        local text_size = imgui.CalcTextSize(display_name)
        imgui.PopFont()

        local padding = style.WindowPadding.y
        local rect_height = text_size.y + padding * 2

        local cursor_screen_pos = imgui.GetCursorScreenPos()
        local draw_list = imgui.GetWindowDrawList()
        draw_list:AddRectFilled(
            cursor_screen_pos,
            imgui.ImVec2(cursor_screen_pos.x + available_width, cursor_screen_pos.y + rect_height),
            imgui.GetColorU32(style.Colors[imgui.Col.ChildBg]),
            style.ChildRounding
        )

        local child_cursor_pos = imgui.GetCursorPos()
        imgui.SetCursorPos(imgui.ImVec2(
            child_cursor_pos.x + (available_width - text_size.x) * 0.5,
            child_cursor_pos.y + padding
        ))
        imgui.Heading(display_name)

        imgui.SetCursorPos(imgui.ImVec2(child_cursor_pos.x, child_cursor_pos.y + rect_height + padding))
    end

    content_callback(imgui.GetContentRegionAvail().x + style.WindowPadding.x)

    imgui.EndChild()
    imgui.PopStyleVar()
end

function imgui.DrawChildrenRow(children, spacing)
    local available_width = imgui.GetContentRegionAvail().x
    local style_spacing = imgui.GetStyle().ItemSpacing.x
    local total_spacing = (spacing or style_spacing) * (#children - 1)
    local remaining_width = available_width - total_spacing

    for i, child in ipairs(children) do
        local width = child.width or (remaining_width / #children)

        if i > 1 then
            imgui.SameLine()
            if spacing and spacing > 0 then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + spacing - style_spacing)
            end
        end

        imgui.DrawChild(
            child.name,
            child.content_callback,
            imgui.ImVec2(width, 0)
        )
    end
end

function imgui.ToggleButton(str_id, state, text, disabled)
    local pos=imgui.GetCursorScreenPos()
    local h=imgui.GetFrameHeight();local w=h*2.7
    local draw=imgui.GetWindowDrawList()
    imgui.InvisibleButton(str_id,imgui.ImVec2(w,h))
    local clicked=imgui.IsItemClicked(0) and not disabled
    if clicked then state[0]=not state[0] end
    local on=state[0]
    local bg=on and imgui.ImVec4(30/255,51/255,72/255,1) or imgui.ImVec4(0.12,0.12,0.14,1)
    local border=on and imgui.ImVec4(0.5,0.64,0.77,1) or imgui.ImVec4(0.45,0.45,0.48,1)
    local ink=disabled and imgui.ImVec4(0.48,0.48,0.5,1) or imgui.ImVec4(1,1,1,1)
    draw:AddRectFilled(pos,imgui.ImVec2(pos.x+w,pos.y+h),imgui.GetColorU32(bg),h/2)
    draw:AddRect(pos,imgui.ImVec2(pos.x+w,pos.y+h),imgui.GetColorU32(border),h/2)
    local r=h*0.31
    local cx=on and (pos.x+w-h/2) or (pos.x+h/2)
    draw:AddCircleFilled(imgui.ImVec2(cx,pos.y+h/2),r,imgui.GetColorU32(ink),16)
    local label=on and 'ON' or 'OFF';local size=imgui.CalcTextSize(label)
    local tx=on and pos.x+h*0.34 or pos.x+h*1.1
    draw:AddText(imgui.ImVec2(tx,pos.y+(h-size.y)/2),imgui.GetColorU32(ink),label)
    if text then imgui.SameLine();imgui.Text(text) end
    return clicked
end

function imgui.SegmentedControl(name, items, selected_item_ptr, fixed_size)
    local style = imgui.GetStyle()
    local draw_list = imgui.GetWindowDrawList()
    local colors = style.Colors
    local start_pos = imgui.GetCursorScreenPos()
    local item_height = fixed_size and fixed_size.y > 0 and fixed_size.y or (imgui.GetFrameHeight())

    local storage = imgui.GetStateStorage()
    local selected_pos_key = imgui.GetID(name .. "_selected_pos")
    local target_pos_key = imgui.GetID(name .. "_target_pos")

    local selected_pos = storage:GetFloat(selected_pos_key, 0.0)
    local target_pos = storage:GetFloat(target_pos_key, 0.0)

    local total_width = 0
    local item_widths = {}

    if fixed_size then

        local available_width = fixed_size.x == -1 and imgui.GetContentRegionAvail().x or fixed_size.x
        local item_width = available_width / #items

        for i = 1, #items do
            item_widths[i] = item_width
        end

        total_width = available_width
    else

        for i, item in ipairs(items) do
            local item_width = imgui.CalcTextSize(item).x + style.FramePadding.x * 2
            item_widths[i] = item_width
            total_width = total_width + item_width
        end
    end

    target_pos = 0
    for i = 1, selected_item_ptr[0] do
        target_pos = target_pos + (item_widths[i] or 0)
    end
    storage:SetFloat(target_pos_key, target_pos)

    local animation_speed = 12.0
    local delta_time = imgui.GetIO().DeltaTime
    selected_pos = selected_pos + (target_pos - selected_pos) * imgui.ImSaturate(delta_time * animation_speed)
    storage:SetFloat(selected_pos_key, selected_pos)

    local border_color = imgui.GetColorU32(colors[imgui.Col.Border])
    draw_list:AddRect(
        start_pos,
        imgui.ImVec2(start_pos.x + total_width, start_pos.y + item_height),
        border_color,
        style.FrameRounding,
        nil,
        math.max(style.FrameBorderSize, 1)
    )

    if selected_item_ptr[0] >= 0 and selected_item_ptr[0] < #items then
        local selected_width = item_widths[selected_item_ptr[0] + 1] or 0
        local selected_bg_min = imgui.ImVec2(start_pos.x + selected_pos, start_pos.y)
        local selected_bg_max = imgui.ImVec2(selected_bg_min.x + selected_width, start_pos.y + item_height)

        local rounding, flags = 0, nil
        if #items == 1 then
            rounding = style.FrameRounding
        elseif selected_item_ptr[0] == 0 then
            rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersLeft
        elseif selected_item_ptr[0] == #items - 1 then
            rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersRight
        end

        draw_list:AddRectFilled(
            selected_bg_min,
            selected_bg_max,
            imgui.GetColorU32(colors[imgui.Col.Button]),
            rounding,
            flags
        )
    end

    local current_pos = start_pos
    for index, item in ipairs(items) do
        local item_width = item_widths[index]

        local hover_alpha_key = imgui.GetID(name .. "_hover_alpha_" .. index)
        local hover_target_key = imgui.GetID(name .. "_hover_target_" .. index)

        local hover_alpha = storage:GetFloat(hover_alpha_key, 0.0)
        local hover_target = storage:GetFloat(hover_target_key, 0.0)

        imgui.SetCursorScreenPos(current_pos)
        if imgui.InvisibleButton('##selector_' .. name .. '_' .. index, imgui.ImVec2(item_width, item_height)) then
            selected_item_ptr[0] = index - 1
        end

        local is_selected = selected_item_ptr[0] == index - 1
        local is_hovered = imgui.IsItemHovered()

        hover_target = (is_hovered and not is_selected) and 1.0 or 0.0
        hover_alpha = hover_alpha + (hover_target - hover_alpha) * 8.0 * delta_time

        storage:SetFloat(hover_alpha_key, hover_alpha)
        storage:SetFloat(hover_target_key, hover_target)

        if not is_selected and hover_alpha > 0.01 then
            local base_color = colors[imgui.Col.FrameBg]
            local hover_color = colors[imgui.Col.ButtonHovered]
            local hover_bg_color = imgui.ImVec4(
                base_color.x + (hover_color.x - base_color.x) * hover_alpha,
                base_color.y + (hover_color.y - base_color.y) * hover_alpha,
                base_color.z + (hover_color.z - base_color.z) * hover_alpha,
                base_color.w + (hover_color.w - base_color.w) * hover_alpha
            )

            local rounding, flags = 0, nil
            if index == 1 and index == #items then
                rounding = style.FrameRounding
            elseif index == 1 then
                rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersLeft
            elseif index == #items then
                rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersRight
            end

            local item_rect_max = imgui.ImVec2(current_pos.x + item_width, current_pos.y + item_height)
            draw_list:AddRectFilled(current_pos, item_rect_max, imgui.GetColorU32(hover_bg_color), rounding, flags)
        end

        if index > 1 then
            local y_offset = style.CellPadding.y
            local separator_color = imgui.GetColorU32(colors[imgui.Col.Border])
            local border_width = math.max(style.FrameBorderSize, 1)
            draw_list:AddLine(
                imgui.ImVec2(current_pos.x, current_pos.y + y_offset),
                imgui.ImVec2(current_pos.x, current_pos.y + item_height - y_offset),
                separator_color,
                border_width
            )
        end

        local text_size = imgui.CalcTextSize(item)
        local text_pos = imgui.ImVec2(
            current_pos.x + (item_width - text_size.x) * 0.5,
            current_pos.y + (item_height - text_size.y) * 0.5
        )

        local text_color = is_selected and colors[imgui.Col.Text] or
            (hover_alpha > 0.01 and
                imgui.ImLerp(colors[imgui.Col.TextDisabled], colors[imgui.Col.Text], hover_alpha) or
                colors[imgui.Col.TextDisabled])

        draw_list:AddText(text_pos, imgui.GetColorU32(text_color), item)
        current_pos.x = current_pos.x + item_width
    end
end

function imgui.DataTable(id, options)

    if not imgui._datatable_strings then
        imgui._datatable_strings = {}
    end
    local string_storage = imgui._datatable_strings

    local storage = imgui.GetStateStorage()
    local sort_column_key = imgui.GetID(id .. "_sort_column")
    local sort_ascending_key = imgui.GetID(id .. "_sort_ascending")
    local current_page_key = imgui.GetID(id .. "_current_page")

    local sort_column = storage:GetInt(sort_column_key, -1)
    local sort_ascending = storage:GetInt(sort_ascending_key, 1) == 1
    local current_page = storage:GetInt(current_page_key, 1)

    local column_filters = {}
    local has_column_filters = false

    for _, column in ipairs(options.columns) do
        if column.filterable then
            has_column_filters = true
            local filter_key = id .. "_filter_" .. column.key
            column_filters[column.key] = string_storage[filter_key] or ""
        end
    end

    local data_changed = false

    if has_column_filters then
        if imgui.AnimButton(fa("FILTER") .. " Filters") then
            imgui.OpenPopup("FILTER:" .. id)
        end

        if imgui.BeginPopup("FILTER:" .. id) then
            imgui.Text("Column Filters")
            imgui.Separator()

            for _, column in ipairs(options.columns) do
                if column.filterable then
                    local filter_text, filter_changed = imgui.StyledInputText(
                        "##filter_" .. column.key,
                        column_filters[column.key],
                        "Filter by " .. column.label:lower(),
                        imgui.ImVec2(300, 0)
                    )
                    if filter_changed then
                        column_filters[column.key] = filter_text
                        local filter_key = id .. "_filter_" .. column.key
                        string_storage[filter_key] = filter_text
                        current_page = 1
                        storage:SetInt(current_page_key, current_page)
                    end
                end
            end

            imgui.Separator()
            if imgui.AnimButton("Clear All Filters", imgui.ImVec2(-1, 0)) then
                for _, column in ipairs(options.columns) do
                    if column.filterable then
                        column_filters[column.key] = ""
                        local filter_key = id .. "_filter_" .. column.key
                        string_storage[filter_key] = ""
                    end
                end
                current_page = 1
                storage:SetInt(current_page_key, current_page)
            end

            imgui.EndPopup()
        end

        imgui.Separator()
    end

    local display_data = {}
    for i, row in ipairs(options.data) do
        local include_row = true

        for _, column in ipairs(options.columns) do
            if column.filterable and column_filters[column.key] ~= "" then
                local value = row[column.key] or ""
                local display_value = column.format and column.format(value, row) or tostring(value)
                local filter_text = string.lower(column_filters[column.key])
                local search_text = string.lower(display_value)

                if not string.find(search_text, filter_text, 1, true) then
                    include_row = false
                    break
                end
            end
        end

        if include_row then
            table.insert(display_data, { data = row, original_index = i })
        end
    end

    if sort_column >= 0 and sort_column < #options.columns then
        local sort_key = options.columns[sort_column + 1].key
        table.sort(display_data, function(a, b)
            local val_a, val_b = a.data[sort_key], b.data[sort_key]

            if val_a == nil and val_b == nil then
                return false
            elseif val_a == nil then
                return not sort_ascending
            elseif val_b == nil then
                return sort_ascending
            end

            local num_a, num_b = tonumber(val_a), tonumber(val_b)
            if num_a and num_b then
                if sort_ascending then
                    return num_a < num_b
                else
                    return num_a > num_b
                end
            end

            local str_a, str_b = tostring(val_a):lower(), tostring(val_b):lower()
            if sort_ascending then
                return str_a < str_b
            else
                return str_a > str_b
            end
        end)
    end

    local page_size = options.page_size or 10
    local total_pages = math.ceil(#display_data / page_size)

    local table_flags = imgui.TableFlags.RowBg + imgui.TableFlags.Resizable + imgui.TableFlags.ScrollY
    if options.sortable ~= false then
        table_flags = table_flags + imgui.TableFlags.Sortable
    end

    local column_count = #options.columns
    if options.buttons and #options.buttons > 0 then
        column_count = column_count + 1
    end

    local table_height = imgui.GetFrameHeight() * (page_size + 2)

    if imgui.BeginTable(id .. "_table", column_count, table_flags, imgui.ImVec2(0, table_height)) then
        for _, column in ipairs(options.columns) do
            local column_flags = imgui.TableColumnFlags.WidthStretch
            if not column.sortable then
                column_flags = column_flags + imgui.TableColumnFlags.NoSort
            end

            local column_weight = column.width or 1.0
            imgui.TableSetupColumn(column.label, column_flags, column_weight)
        end

        if options.buttons and #options.buttons > 0 then
            local action_width = math.max(#options.buttons * 35 + 20, 100)
            imgui.TableSetupColumn("Actions", imgui.TableColumnFlags.WidthFixed + imgui.TableColumnFlags.NoSort,
                action_width)
        end

        imgui.TableHeadersRow()

        local sort_specs = imgui.TableGetSortSpecs()
        if sort_specs and sort_specs.SpecsDirty then
            if sort_specs.SpecsCount > 0 then
                local spec = sort_specs.Specs[0]
                local col = spec.ColumnIndex
                local sort_dir = spec.SortDirection or 1

                sort_column = col
                sort_ascending = sort_dir == 1
                storage:SetInt(sort_column_key, sort_column)
                storage:SetInt(sort_ascending_key, sort_ascending and 1 or 0)
            else
                sort_column = -1
                storage:SetInt(sort_column_key, sort_column)
            end
            sort_specs.SpecsDirty = false
        end

        if current_page > total_pages then
            current_page = math.max(1, total_pages)
            storage:SetInt(current_page_key, current_page)
        end

        local start_idx = (current_page - 1) * page_size + 1
        local end_idx = math.min(start_idx + page_size - 1, #display_data)

        if #display_data > 0 and start_idx <= #display_data then
            for idx = start_idx, end_idx do
                local row_entry = display_data[idx]
                if not row_entry then break end

                local original_idx = row_entry.original_index
                local row_data = row_entry.data

                imgui.TableNextRow()

                for i, column in ipairs(options.columns) do
                    imgui.TableNextColumn()
                    local value = row_data[column.key] or ""
                    local display_value = column.format and column.format(value, row_data) or tostring(value)
                    imgui.Text(display_value)
                end

                if options.buttons and #options.buttons > 0 then
                    imgui.TableNextColumn()

                    for j, button in ipairs(options.buttons) do
                        local visible = not button.visible or button.visible(row_data, original_idx)

                        if visible then
                            if j > 1 then imgui.SameLine() end

                            if button.color then
                                imgui.PushStyleColor(imgui.Col.Button, button.color)
                                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
                                    button.color.x * 1.1, button.color.y * 1.1, button.color.z * 1.1, button.color.w
                                ))
                                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(
                                    button.color.x * 0.9, button.color.y * 0.9, button.color.z * 0.9, button.color.w
                                ))
                            end

                            local button_text = button.label
                            if button.icon then
                                button_text = button.icon
                                if button.label and button.label ~= "" then
                                    button_text = button_text .. " " .. button.label
                                end
                            end

                            local default_button_size = imgui.ImVec2(imgui.GetFontSize() * 1.5, 0)
                            local button_size = button.size or default_button_size
                            local button_id = button_text .. "##" .. id .. "_btn_" .. j .. "_" .. original_idx

                            if imgui.AnimButton(button_id, button_size) then
                                button.callback(row_data, original_idx)
                                data_changed = true
                            end

                            if button.color then
                                imgui.PopStyleColor(3)
                            end
                        end
                    end
                end
            end
        end

        imgui.EndTable()
    end

    if total_pages > 0 then
        imgui.Separator()
        imgui.AlignTextToFramePadding()
        imgui.TextColored(imgui.ImVec4(0.4, 0.7, 1.0, 1.0),
            string.format("Page %d of %d (%d total rows)", current_page, total_pages, #display_data))
    end

    if total_pages > 1 then
        imgui.SameLine()

        local pagination_buttons = {
            { "<<", 1,                current_page > 1 },
            { "<",  current_page - 1, current_page > 1 },
            { ">",  current_page + 1, current_page < total_pages },
            { ">>", total_pages,      current_page < total_pages }
        }

        local pagination_button_size = imgui.ImVec2(imgui.GetFontSize() * 2, 0)

        for i, btn in ipairs(pagination_buttons) do
            local label, target_page, enabled = btn[1], btn[2], btn[3]

            if enabled and imgui.AnimButton(label .. "##" .. id, pagination_button_size) then
                current_page = target_page
                storage:SetInt(current_page_key, current_page)
            elseif not enabled then
                imgui.PushStyleVar(imgui.StyleVar.Alpha, 0.5)
                imgui.AnimButton(label .. "##" .. id .. "_disabled", pagination_button_size)
                imgui.PopStyleVar()
            end

            if i < #pagination_buttons then
                imgui.SameLine()
            end
        end
    end
    return data_changed
end

function imgui.AnimButton(label, size)
    local duration = { 1.0, 0.3 }

    local cols = {
        default = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.Button]),
        hovered = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered]),
        active  = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive])
    }

    local storage = imgui.GetStateStorage()
    local color_x_key = imgui.GetID(label .. "_current_angle")
    local color_y_key = imgui.GetID(label .. "_current_angle_y")
    local color_z_key = imgui.GetID(label .. "_current_angle_z")
    local color_w_key = imgui.GetID(label .. "_current_angle_w")
    local clicked_start_key = imgui.GetID(label .. "_clicked_start")
    local clicked_end_key = imgui.GetID(label .. "_clicked_end")
    local hovered_cur_key = imgui.GetID(label .. "_hovered_cur")
    local hovered_old_key = imgui.GetID(label .. "_hovered_old")
    local hovered_clock_key = imgui.GetID(label .. "_hovered_clock")

    local color = imgui.ImVec4(
        storage:GetFloat(color_x_key, cols.default.x),
        storage:GetFloat(color_y_key, cols.default.y),
        storage:GetFloat(color_z_key, cols.default.z),
        storage:GetFloat(color_w_key, cols.default.w)
    )

    local clicked_start = storage:GetFloat(clicked_start_key, -1)
    local clicked_end = storage:GetFloat(clicked_end_key, -1)
    local hovered_cur = storage:GetInt(hovered_cur_key, 0) == 1
    local hovered_old = storage:GetInt(hovered_old_key, 0) == 1
    local hovered_clock = storage:GetFloat(hovered_clock_key, -1)

    if clicked_start ~= -1 and clicked_end ~= -1 then
        if os.clock() - clicked_start <= duration[2] then
            local t = math.min((os.clock() - clicked_start) / duration[2], 1.0)
            color = imgui.ImLerp(color, cols.active, t)
        elseif os.clock() - clicked_end <= duration[2] then
            local t = math.min((os.clock() - clicked_end) / duration[2], 1.0)
            local target = hovered_cur and cols.hovered or cols.default
            color = imgui.ImLerp(color, target, t)
        else

            storage:SetFloat(clicked_start_key, -1)
            storage:SetFloat(clicked_end_key, -1)
        end
    else

        if hovered_clock ~= -1 then
            if os.clock() - hovered_clock <= duration[1] then
                local t = math.min((os.clock() - hovered_clock) / duration[1], 1.0)
                local target = hovered_cur and cols.hovered or cols.default
                color = imgui.ImLerp(color, target, t)
            else
                color = hovered_cur and cols.hovered or cols.default
            end
        end
    end

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(color))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(color))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(color))
    local result = imgui.Button(label, size or imgui.ImVec2(0, 0))
    imgui.PopStyleColor(3)

    if result then
        storage:SetFloat(clicked_start_key, os.clock())
        storage:SetFloat(clicked_end_key, os.clock() + duration[2])
    end

    local new_hovered_cur = imgui.IsItemHovered()
    if hovered_old ~= new_hovered_cur then
        storage:SetInt(hovered_old_key, new_hovered_cur and 1 or 0)
        storage:SetFloat(hovered_clock_key, os.clock())
    end
    storage:SetInt(hovered_cur_key, new_hovered_cur and 1 or 0)

    storage:SetFloat(color_x_key, color.x)
    storage:SetFloat(color_y_key, color.y)
    storage:SetFloat(color_z_key, color.z)
    storage:SetFloat(color_w_key, color.w)

    return result
end
