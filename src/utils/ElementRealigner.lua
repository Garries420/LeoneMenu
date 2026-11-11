-- Module: F:\2025\EDrive\dev\luapack\src\utils\ElementRealigner.lua

local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")

local _realigner_state = {
    is_realigning = imgui.new.bool(false),
    update_callback = nil,
    frame = nil,
    preview = nil,
    started = 0,
    options = nil,
    wheel = 0,
    cancel = false,
}

local function _get_normalized_cursor()
    local cursor = imgui.GetMousePos()
    local display_size = imgui.GetIO().DisplaySize
    if display_size.x<=0 or display_size.y<=0 then return nil end
    return math.max(0,math.min(0.98,cursor.x / display_size.x)), math.max(0,math.min(0.98,cursor.y / display_size.y))
end

local function _complete_realignment(commit)
    local options=_realigner_state.options
    _realigner_state.is_realigning[0] = false
    _realigner_state.update_callback = nil
    _realigner_state.preview = nil
    _realigner_state.options=nil
    _realigner_state.wheel=0
    _realigner_state.cancel=false
    if not commit and options and options.on_cancel then options.on_cancel() end
    MainWindow:show()
    if commit then save_config() end
end

local function _initialize_frame()
    if _realigner_state.frame then return end

    _realigner_state.frame = imgui.OnFrame(
        function() return _realigner_state.is_realigning[0] end,
        function()
            if _realigner_state.cancel then _complete_realignment(false);return end
            local options=_realigner_state.options
            local wheel=_realigner_state.wheel
            local steps=wheel>=0 and math.floor(wheel) or math.ceil(wheel)
            _realigner_state.wheel=wheel-steps
            if steps~=0 and options and options.on_resize then options.on_resize(steps) end
            local normalized_x, normalized_y = _get_normalized_cursor()

            if normalized_x and _realigner_state.update_callback then
                _realigner_state.update_callback(normalized_x, normalized_y)
            end

            if os.clock()-_realigner_state.started>0.15 and imgui.IsMouseClicked(0, false) then
                _complete_realignment(true)
            end
        end
    )
    _realigner_state.frame.LockPlayer = true
end

_initialize_frame()

-- Match alist's wheel accumulation and consume both Escape transitions.
local escape_down=false
addEventHandler('onWindowMessage',function(message,key)
    if message==0x20A and _realigner_state.is_realigning[0]
        and _realigner_state.options and _realigner_state.options.on_resize then
        local delta=math.floor(key/65536)%65536
        if delta>=32768 then delta=delta-65536 end
        _realigner_state.wheel=_realigner_state.wheel+delta/120
        consumeWindowMessage(true,true)
    elseif key==0x1B then
        if (message==0x100 or message==0x104) and (_realigner_state.is_realigning[0] or escape_down) then
            _realigner_state.cancel=true;escape_down=true
            consumeWindowMessage(true,true)
        elseif (message==0x101 or message==0x105) and escape_down then
            escape_down=false;consumeWindowMessage(true,true)
        end
    end
end)

local ElementRealigner = {}

function ElementRealigner:realign_element(on_update, options)
    if _realigner_state.is_realigning[0] then
        _complete_realignment(false)
    end

    _realigner_state.started = os.clock()
    _realigner_state.preview = options and options.preview
    _realigner_state.options=options
    _realigner_state.wheel=0
    _realigner_state.cancel=false
    _realigner_state.update_callback = on_update
    _realigner_state.is_realigning[0] = true
    MainWindow:hide()
end

function ElementRealigner:is_preview(tag)
    return _realigner_state.is_realigning[0] and _realigner_state.preview==tag
end
function ElementRealigner:is_active()return _realigner_state.is_realigning[0] end
return ElementRealigner
