local ffi = require('ffi')
local WM_SETFOCUS, WM_ACTIVATEAPP = 0x0007, 0x001C
local TEST_COOPERATIVE_LEVEL = 3 -- IDirect3DDevice9 vtable index.
local test_cooperative_level = ffi.typeof('long (__stdcall*)(void*)')

local function device_ready(renderer)
    local device = renderer.d3ddevice
    local methods = ffi.cast('void***', device)[0]
    return ffi.cast(test_cooperative_level, methods[TEST_COOPERATIVE_LEVEL])(device) == 0
end

return function(imgui)
    local renderer = package.loaded['leone.upmimgui.dx9']
    if not renderer then return end

    local lib = imgui.lib
    local invalidate = renderer.InvalidateDeviceObjects
    local new_frame = renderer.NewFrame
    local focus_generation = 0

    addEventHandler('onWindowMessage', function(message, wparam)
        if message == WM_SETFOCUS or (message == WM_ACTIVATEAPP and wparam ~= 0) then
            focus_generation = focus_generation + 1
        end
    end)

    function renderer:InvalidateDeviceObjects()
        if self.resources_invalidated or not self:SwitchContext() then return end
        invalidate(self)
        self.resources_invalidated = true

        -- ImGui 1.92 can discard the font atlas if invalidation leaves an
        -- already released texture marked WantDestroy instead of Destroyed.
        local textures = imgui.GetPlatformIO().Textures
        for i = 0, textures.Size - 1 do
            local texture = textures.Data[i]
            if texture.Status == lib.ImTextureStatus_WantDestroy and texture.TexID == 0
                and texture.BackendUserData == nil then
                texture:SetStatus(lib.ImTextureStatus_Destroyed)
            end
        end
    end

    function renderer:NewFrame()
        if self.destroyed then return end
        local regained_focus = self.focus_generation ~= nil and self.focus_generation ~= focus_generation
        self.focus_generation = focus_generation
        self.recover_resources = self.recover_resources or regained_focus
        self.skip_render = not device_ready(self)
        if self.skip_render then
            self.recover_resources = true
        elseif self.recover_resources then
            self:InvalidateDeviceObjects()
            self.recover_resources = false
        end
        return new_frame(self)
    end

    function renderer:EndFrame()
        if not self:SwitchContext() then return end
        imgui.Render()
        -- A lost D3D9 device can report successful uploads into dummy memory.
        if self.skip_render or not device_ready(self) then
            self.recover_resources = true
            return
        end
        lib.ImGui_ImplDX9_RenderDrawData(imgui.GetDrawData())
        self.resources_invalidated = false
    end

    jit.off(renderer.EndFrame)
end
