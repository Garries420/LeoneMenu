-- This file is part of mimgui project
-- Licensed under the MIT License
-- Copyright (c) 2018, FYP <https://github.com/THE-FYP>

local imgui = require 'leone.upmimgui.imgui'
local win32 = require 'leone.upmimgui.win32'
local lib = imgui.lib
local ffi = require 'ffi'

ffi.cdef [[
typedef struct IDirect3DDevice9 *LPDIRECT3DDEVICE9, *PDIRECT3DDEVICE9;
typedef struct IDirect3DVertexBuffer9 *LPDIRECT3DVERTEXBUFFER9, *PDIRECT3DVERTEXBUFFER9;
typedef struct IDirect3DIndexBuffer9 *LPDIRECT3DINDEXBUFFER9, *PDIRECT3DINDEXBUFFER9;
typedef struct IDirect3DTexture9 *LPDIRECT3DTEXTURE9, *PDIRECT3DTEXTURE9;
typedef struct ImGui_ImplDX9_Context
{
	LPDIRECT3DDEVICE9        pd3dDevice;
	LPDIRECT3DVERTEXBUFFER9  pVB;
	LPDIRECT3DINDEXBUFFER9   pIB;
	LPDIRECT3DTEXTURE9       FontTexture;
	int                      VertexBufferSize;
	int                      IndexBufferSize;
} ImGui_ImplDX9_Context;

bool ImGui_ImplWin32_Init(HWND hwnd, INT64* ticksPerSecond, INT64* time);
void ImGui_ImplWin32_NewFrame(HWND hwnd, INT64 ticksPerSecond, INT64* time);
LRESULT ImGui_ImplWin32_WndProcHandler(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

void ImGui_ImplDX9_Init(LPDIRECT3DDEVICE9 device);
void ImGui_ImplDX9_Shutdown();
void ImGui_ImplDX9_NewFrame();
void ImGui_ImplDX9_RenderDrawData(ImDrawData* draw_data);
void ImGui_ImplDX9_InvalidateDeviceObjects();

LPDIRECT3DTEXTURE9 ImGui_ImplDX9_CreateTextureFromFile(LPDIRECT3DDEVICE9 device, LPCTSTR path);
LPDIRECT3DTEXTURE9 ImGui_ImplDX9_CreateTextureFromFileInMemory(LPDIRECT3DDEVICE9 device, LPCVOID src, UINT size);
void ImGui_ImplDX9_ReleaseTexture(LPDIRECT3DTEXTURE9 tex);

int __stdcall MultiByteToWideChar(UINT CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
]]

local ImplDX9 = {}
function ImplDX9.new(device, hwnd)
    -- ImGui_ImplDX9_Context* ImGui_ImplDX9_Init(LPDIRECT3DDEVICE9 device);
    local obj = {}
    local context = imgui.CreateContext()
    imgui.SetCurrentContext(context)
    lib.ImGui_ImplDX9_Init(device)
    obj.ticksPerSecond = ffi.new('INT64[1]', 0)
    obj.time = ffi.new('INT64[1]', 0)
    imgui.SetCurrentContext(context)
    local imio = imgui.GetIO()
    imio.BackendRendererName = 'imgui_impl_dx9_lua'
    imio.BackendFlags = bit.bor(imio.BackendFlags, lib.ImGuiBackendFlags_RendererHasVtxOffset) -- We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
    -- bool ImGui_ImplWin32_Init(HWND hwnd, INT64* ticksPerSecond, INT64* time);
    if not lib.ImGui_ImplWin32_Init(hwnd, obj.ticksPerSecond, obj.time) then
        -- void ImGui_ImplDX9_Shutdown(ImGui_ImplDX9_Context* context);
        lib.ImGui_ImplDX9_Shutdown()
        imgui.DestroyContext(context)
        return nil
    end
    obj.context = context
    obj.d3ddevice = device
    obj.hwnd = hwnd
    obj.dpiscale = win32.GetDpiScaleForWindow(hwnd)

    obj.textures = {}
    obj.destroyed = false

    return setmetatable(obj, {__index = ImplDX9})
end

function ImplDX9:SwitchContext()
    if self.destroyed or self.context == nil then return false end
    imgui.SetCurrentContext(self.context)
    return true
end

-- Explicit ownership: ImTextureRef stores an ID, not the COM texture's lifetime.
function ImplDX9:_OwnTexture(tex)
    if tex == nil then return nil end
    local ref = ffi.new('ImTextureRef[1]')
    ref[0]._TexID = ffi.cast('uintptr_t', tex)
    local key = tostring(tonumber(ref[0]._TexID))
    self.textures[key] = {pointer=tex, ref=ref}
    return ref[0]
end

function ImplDX9:Destroy()
    if self.destroyed then return false end
    local context = self.context
    local previous = imgui.GetCurrentContext()
    self.destroyed = true
    imgui.SetCurrentContext(context)
    for key, owner in pairs(self.textures) do
        lib.ImGui_ImplDX9_ReleaseTexture(owner.pointer)
        self.textures[key] = nil
    end
    lib.ImGui_ImplDX9_Shutdown()
    if win32.Shutdown then win32.Shutdown(imgui, self.hwnd) end
    imgui.DestroyContext(context)
    self.context = nil
    imgui.SetCurrentContext(previous ~= context and previous or nil)
    return true
end

function ImplDX9:NewFrame()
    if not self:SwitchContext() then return end
    -- void ImGui_ImplDX9_NewFrame(ImGui_ImplDX9_Context* context);
    lib.ImGui_ImplDX9_NewFrame()
    -- void ImGui_ImplWin32_NewFrame(HWND hwnd, INT64 ticksPerSecond, INT64* time);
    lib.ImGui_ImplWin32_NewFrame(self.hwnd, self.ticksPerSecond[0], self.time)
    imgui.NewFrame()
end

function ImplDX9:EndFrame()
    if not self:SwitchContext() then return end
    imgui.Render()
    -- void ImGui_ImplDX9_RenderDrawData(ImGui_ImplDX9_Context* context, ImDrawData* draw_data);
    lib.ImGui_ImplDX9_RenderDrawData(imgui.GetDrawData())
end

jit.off(ImplDX9.EndFrame)

function ImplDX9:WindowMessage(msg, wparam, lparam)
    if not self:SwitchContext() then return end
    if msg == 0x0102 then -- WM_CHAR
        if wparam < 256 then
            local char = ffi.new('char[1]', wparam)
            local wchar = ffi.new('wchar_t[1]', 0)
            if ffi.C.MultiByteToWideChar(0, 0, char, 1, wchar, 1) > 0 then
                wparam = wchar[0]
            end
        end
    end
    -- LRESULT ImGui_ImplWin32_WndProcHandler(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
    return lib.ImGui_ImplWin32_WndProcHandler(self.hwnd, msg, wparam, lparam)
end

function ImplDX9:InvalidateDeviceObjects()
    if not self:SwitchContext() then return end
    -- void ImGui_ImplDX9_InvalidateDeviceObjects(ImGui_ImplDX9_Context* context);
    lib.ImGui_ImplDX9_InvalidateDeviceObjects()
end

function ImplDX9:CreateTextureFromFile(path)
    if not self:SwitchContext() then return nil end
    return self:_OwnTexture(lib.ImGui_ImplDX9_CreateTextureFromFile(self.d3ddevice, path))
end

function ImplDX9:CreateTextureFromFileInMemory(src, size)
    if not self:SwitchContext() then return nil end
    if type(src) == 'number' then src = ffi.cast('LPCVOID', src) end
    return self:_OwnTexture(lib.ImGui_ImplDX9_CreateTextureFromFileInMemory(self.d3ddevice, src, size))
end

function ImplDX9:ReleaseTexture(ref)
    if self.destroyed or ref == nil then return false end
    local key
    if ffi.istype('ImTextureRef', ref) then key = tostring(tonumber(ref._TexID))
    else key = tostring(tonumber(ffi.cast('uintptr_t', ref))) end
    local owner = self.textures[key]
    if not owner then return false end
    self.textures[key] = nil
    lib.ImGui_ImplDX9_ReleaseTexture(owner.pointer)
    return true
end

function ImplDX9:InvalidateFontsTexture()
    if not self:SwitchContext() then return end
    -- void ImGui_ImplDX9_InvalidateFontsTexture(ImGui_ImplDX9_Context* context);
    lib.ImGui_ImplDX9_InvalidateFontsTexture()
end

return ImplDX9
