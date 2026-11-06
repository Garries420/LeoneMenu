-- Module: F:\2025\EDrive\dev\luapack\src\utils\ElementRealigner.lua

local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")

local _realigner_state = {
    is_realigning = imgui.new.bool(false),
    update_callback = nil,
    frame = nil,
    preview = nil,
    started = 0,
}

local function _get_normalized_cursor()
    local cursor = imgui.GetMousePos()
    local display_size = imgui.GetIO().DisplaySize
    if display_size.x<=0 or display_size.y<=0 then return nil end
    return math.max(0,math.min(0.98,cursor.x / display_size.x)), math.max(0,math.min(0.98,cursor.y / display_size.y))
end

local function _complete_realignment()
    MainWindow:show()

    _realigner_state.is_realigning[0] = false
    _realigner_state.update_callback = nil
    _realigner_state.preview = nil
    save_config()
end

local function _initialize_frame()
    if _realigner_state.frame then return end

    _realigner_state.frame = imgui.OnFrame(
        function() return _realigner_state.is_realigning[0] end,
        function()
            local normalized_x, normalized_y = _get_normalized_cursor()

            if normalized_x and _realigner_state.update_callback then
                _realigner_state.update_callback(normalized_x, normalized_y)
            end

            if os.clock()-_realigner_state.started>0.15 and imgui.IsMouseClicked(0, false) then
                _complete_realignment()
            end
        end
    )
    _realigner_state.frame.LockPlayer = true
end

_initialize_frame()

local ElementRealigner = {}

function ElementRealigner:realign_element(on_update, options)
    if _realigner_state.is_realigning[0] then
        _complete_realignment()
    end

    _realigner_state.started = os.clock()
    _realigner_state.preview = options and options.preview
    _realigner_state.update_callback = on_update
    _realigner_state.is_realigning[0] = true
    MainWindow:hide()
end

function ElementRealigner:is_preview(tag)
    return _realigner_state.is_realigning[0] and _realigner_state.preview==tag
end
function ElementRealigner:is_active()return _realigner_state.is_realigning[0] end
return ElementRealigner
