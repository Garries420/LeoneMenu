-- Module: F:\2025\EDrive\dev\luapack\src\ui\MainWindow.lua

local fa = require("fAwesome7")
local imgui = require("upmimgui")
local vk = require("vkeys")
local Search = require("src.ui.SettingsSearch")

local WINDOW = {
    SIZE = imgui.ImVec2(85, 40),
    SIDEBAR_WIDTH = 12,
    FLAGS = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize,
}

-- Crop the nearly transparent top and bottom rows of leone-logo.png in place.
-- A matching change to the drawn height keeps the icon and title at their original scale.
local LOGO_TOP = 96 / 1312
local LOGO_BOTTOM = 1176 / 1312
local LOGO_HEIGHT_RATIO = LOGO_BOTTOM - LOGO_TOP

local _main_window = {
    is_open = imgui.new.bool(false),
    pages = {},
    ordered_ids = {},
    shortcuts = {},
    current_page = nil,
    query = "",
    search_id = 0,
}

local function _rebuild_order()
    _main_window.ordered_ids = {}
    local pages = {}

    for id, data in pairs(_main_window.pages) do
        table.insert(pages, { id = id, title = data.title or "", order = data.order or (id == "phone" and 999 or 10) })
    end

    table.sort(pages, function(a, b) if a.order ~= b.order then return a.order < b.order end
        return a.title < b.title end)

    for _, p in ipairs(pages) do
        table.insert(_main_window.ordered_ids, p.id)
    end

    if not _main_window.current_page and #_main_window.ordered_ids > 0 then
        _main_window.current_page = _main_window.ordered_ids[1]
    end
end

local function _clear_search()
    if _main_window.query=='' then return end
    _main_window.query=''
    -- ImGui retains an active edit buffer by widget ID. Discard it on an external clear.
    _main_window.search_id=_main_window.search_id+1
end

local function _select_page(id,anchor)
    local page=_main_window.pages[id]
    if not page then return end
    _clear_search()
    _main_window.current_page=id
    _main_window.jump=anchor
    _main_window.jump_layout=anchor~=nil
    if anchor and page.prepare_search then page.prepare_search() end
end

local function _render_sidebar(sidebar_width, content_width)
    local style = imgui.GetStyle()
    local window_padding = style.WindowPadding

    imgui.BeginChild(
        "sidebar_area",
        imgui.ImVec2(sidebar_width, 0),
        false,
        imgui.WindowFlags.NoScrollbar
    )

    imgui.SetCursorPosY(window_padding.y / 2)
    if not _main_window.logo_tried then
        _main_window.logo_tried=true
        local ok,texture=pcall(imgui.CreateTextureFromFile,getWorkingDirectory()..'/resource/Leone Menu/leone-logo.png')
        if ok then _main_window.logo=texture end
    end
    if _main_window.logo then
        imgui.SetCursorPosX(window_padding.x)
        imgui.Image(_main_window.logo, imgui.ImVec2(content_width, content_width * LOGO_HEIGHT_RATIO),
            imgui.ImVec2(0, LOGO_TOP), imgui.ImVec2(1, LOGO_BOTTOM))
    else
        imgui.TextColored(imgui.ImVec4(30/255,51/255,72/255,1),'Leone Menu')
    end
    imgui.SetCursorPosX(window_padding.x)
    local clear_width=_main_window.query~='' and imgui.GetFrameHeight()+imgui.GetStyle().ItemSpacing.x or 0
    _main_window.query=imgui.StyledInputText('##settings_search'.._main_window.search_id,_main_window.query,'Search settings',
        imgui.ImVec2(content_width-clear_width,0),128)
    if clear_width>0 then
        imgui.SameLine()
        if imgui.AnimButton('x##clear_search',imgui.ImVec2(imgui.GetFrameHeight(),imgui.GetFrameHeight())) then
            _clear_search()
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Clear search') end
    end
    -- Tighten the gaps only if the screen height caps the window.
    local page_count = #_main_window.ordered_ids
    local sidebar_bottom = imgui.GetWindowPos().y + imgui.GetWindowSize().y
    local first_row_y = imgui.GetCursorScreenPos().y + imgui.GetScrollY()
    local available_height = sidebar_bottom - first_row_y
    local row_spacing = math.floor((available_height - page_count * imgui.PageButtonHeight()) / math.max(1, page_count - 1))
    row_spacing = math.max(0, math.min(style.ItemSpacing.y, row_spacing))
    imgui.PushStyleVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(style.ItemSpacing.x, row_spacing))

    for _, id in ipairs(_main_window.ordered_ids) do
        local page = _main_window.pages[id]
        imgui.SetCursorPosX(window_padding.x)

        if imgui.PageButton(_main_window.current_page == id, page.icon, page.title, content_width, nil, page.icon_box_color) then
            _select_page(id)
        end
    end

    imgui.PopStyleVar()
    imgui.EndChild()
end

local function _render_results(query)
    local results=Search.find(query,_main_window.pages)
    imgui.Heading('Search results')
    if #results==0 then
        imgui.TextDisabled('No settings match your search.')
        return
    end
    for i,result in ipairs(results) do
        imgui.PushID(i)
        imgui.TextColored(imgui.ImVec4(0.58,0.68,0.77,1),result.heading)
        for _,label in ipairs(result.items) do
            local clipped=imgui.CalcTextSize(label).x>imgui.GetContentRegionAvail().x
            if imgui.Selectable(label,false) then _select_page(result.page,result.anchor) end
            if clipped and imgui.IsItemHovered() then imgui.SetTooltip(label) end
        end
        imgui.PopID()
        imgui.Separator()
    end
end

local function _render_content()
    local query=_main_window.query:match('^%s*(.-)%s*$')
    local searching=query~=''
    local key=searching and 'settings_search' or _main_window.current_page
    imgui.BeginChild("content_area##" .. tostring(key),imgui.ImVec2(0,0),false,imgui.WindowFlags.NoBackground)
    local page = _main_window.pages[_main_window.current_page]

    if searching then
        if _main_window.previous_query~=query then imgui.SetScrollY(0) end
        _render_results(query)
    elseif page then
        if page.render_function then
            local target=_main_window.jump
            if target and not _main_window.jump_layout then
                imgui.BeforeSettingsSection=function(name)
                    if name==target then
                        imgui.SetScrollFromPosY(imgui.GetCursorPosY()-imgui.GetScrollY(),0)
                        _main_window.jump=nil
                    end
                end
            end
            page.render_function()
            imgui.BeforeSettingsSection=nil
            if _main_window.jump_layout then
                -- Auto-sized cards have their measured heights on the next frame.
                _main_window.jump_layout=false
            elseif _main_window.jump then
                imgui.SetScrollY(0)
                _main_window.jump=nil
            end
        else
            imgui.Text("No render function for: " .. page.title)
        end
    else
        imgui.Text("No content")
    end

    -- A stale active control must not leave the page unable to consume wheel input.
    local wheel=imgui.GetIO().MouseWheel
    local y=imgui.GetScrollY()
    _main_window.previous_query=searching and query or nil
    local any_popup=imgui.IsPopupOpen('',imgui.PopupFlags.AnyPopupId+imgui.PopupFlags.AnyPopupLevel)
    if wheel~=0 and not any_popup and imgui.IsWindowHovered(imgui.HoveredFlags.ChildWindows) then
        local previous=_main_window.scroll_sample
        if previous and previous.page==key and math.abs(previous.y-y)<0.1 then
            imgui.SetScrollY(math.max(0,math.min(imgui.GetScrollMaxY(),y-wheel*imgui.GetFontSize()*5)))
        end
    end
    _main_window.scroll_sample={page=key,y=y}
    imgui.EndChild()
end

local function _render_window()
    require("src.shared").hotkey_manager:flush_ui_input()
    local display = imgui.GetIO().DisplaySize
    local style = imgui.GetStyle()
    local sidebar_width = imgui.ScaleValue(WINDOW.SIDEBAR_WIDTH)
    local content_width = sidebar_width - style.WindowPadding.x * 2
    local page_count = #_main_window.ordered_ids
    local sidebar_height = style.WindowPadding.y / 2 + content_width * LOGO_HEIGHT_RATIO + imgui.GetFrameHeight()
        + page_count * math.ceil(imgui.PageButtonHeight()) + (page_count + 1) * style.ItemSpacing.y
    local needed_height = math.ceil(sidebar_height + style.WindowPadding.y * 2)
    local window_height = math.min(display.y - 32, math.max(imgui.ScaleValue(WINDOW.SIZE.y), needed_height))

    imgui.SetNextWindowPos(imgui.ImVec2(display.x / 2, display.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(math.min(display.x - 32, imgui.ScaleValue(WINDOW.SIZE.x)), window_height))

    if imgui.Begin("##main_window", _main_window.is_open, WINDOW.FLAGS) then
        _render_sidebar(sidebar_width, content_width)
        imgui.SameLine()
        _render_content()
    end
    imgui.End()
end

local function _register()
    imgui.OnFrame(function() return _main_window.is_open[0] end, _render_window)

    addEventHandler("onWindowMessage", function(msg, wparam)
        if msg == 0x0100 and wparam == vk.VK_ESCAPE and _main_window.is_open[0] then
            if _main_window.query~='' then
                _main_window.query=''
            else
                _main_window.is_open[0] = false
                save_config()
            end
            consumeWindowMessage(true, false)
        end
    end)

    addEventHandler('onScriptTerminate', function(scr)
        if scr == thisScript() then
            _main_window.is_open[0] = false
            save_config()
        end
    end)

end

local MainWindow = {}

function MainWindow:add_page(id, cfg)
    if not id or not cfg or not cfg.render_function then return false end

    cfg.title = cfg.title or "No title"
    cfg.icon = cfg.icon or fa("CIRCLE")
    cfg.icon_box_color = imgui.ImVec4(30/255,51/255,72/255,1)

    _main_window.pages[id] = cfg
    _rebuild_order()

    if cfg.shortcut then
        _main_window.shortcuts[cfg.shortcut] = id
        sampRegisterChatCommand(cfg.shortcut, function()
            _main_window.current_page = id
            _main_window.is_open[0] = true
        end)
    end

    return true
end

function MainWindow:select_page(id)
    _select_page(id)
end

function MainWindow:is_open()
    return _main_window.is_open[0]
end

function MainWindow:show(shortcut)
    if shortcut then
        local target = _main_window.shortcuts[shortcut]
        if _main_window.pages[target] then
            _select_page(target)
        end
    end
    _main_window.is_open[0] = true
end

function MainWindow:hide(persist)
    _main_window.is_open[0] = false
    if persist~=false then save_config() end
end

_register()

return MainWindow
