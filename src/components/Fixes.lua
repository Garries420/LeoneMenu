-- Module: F:\2025\EDrive\dev\luapack\src\components\Fixes.lua

local ffi = require("ffi")
local memory = require("memory")
local vk = require("vkeys")
local shared = require("src.shared")

local function _apply_rendering_fixes()

    memory.write(0x6E1D4F, 2, 1, false)

    memory.write(0x6FB9A0, 0x1C, 1, false)

    memory.write(0x7069F5, 0xEB, 1, false)

    memory.fill(0x70A83B, 0x90, 6, false)

    memory.fill(0x70A4CB, 0x90, 6, false)

    memory.write(0x6E1425, 1, 1, false)

    memory.write(0x884984, 0, 4, false)
end

local function _apply_framerate_fixes()

    memory.write(0x53E94C, 0x00, 1, false)

    memory.write(0xC2B9CC, 0x3EB3B675, 4, false)

    memory.fill(0x524FD7, 0x90, 0x1B, false)

    memory.write(0x736F88, 0, 4, false)
end

local function _apply_general_fixes()

    memory.write(0x745BC9, 0x9090, 2, false)

    memory.write(0x7459E1, 0x9090, 2, false)

    memory.fill(0x6D6517, 0x90, 2, false)
    memory.fill(0x6D0E43, 0x90, 2, false)

    memory.write(0x63F576, 0xEB, 1, false)

    memory.fill(0x460773, 0x90, 7, false)

    memory.copy(0x4EB9A0, memory.strptr('\xC2\x04\x00'), 3, true)

    memory.write(sampGetBase() + 0x2D3C45, 0, 2, true)
end

local function _preload_animations()
    ffi.cdef [[
        typedef void (__cdecl *AddAnimBlockRef_t)(int index);
    ]]

    local AddAnimBlockRef = ffi.cast("AddAnimBlockRef_t", 0x4D3FB0)
    local animBlocksIdStart = memory.read(0x48C36B + 2, 4, true)
    local ms_numAnimBlocks = memory.read(0xB4EA30, 4, true)

    for id = 1, ms_numAnimBlocks - 1 do
        local modelId = animBlocksIdStart + id
        requestModel(modelId)
        AddAnimBlockRef(id)
    end

    loadAllModelsNow()
end

local function _register_event_handlers()

    shared.event_handler:register(
        "PED_TICK_IN_CAR",
        function(x, y, z, vehicle_handle, is_driver)
            if is_driver then
                return { vehicle_handle }
            end
            return false
        end,
        function(vehicle_handle)

            if isKeyJustPressed(vk.VK_H) and not is_cursor_active() then
                switchCarSiren(vehicle_handle, not isCarSirenOn(vehicle_handle))
            end
        end
    )
end

local Fixes = {}

function Fixes:register()
    _apply_rendering_fixes()
    _apply_framerate_fixes()
    _apply_general_fixes()

    _preload_animations()
    _register_event_handlers()
end

return Fixes
