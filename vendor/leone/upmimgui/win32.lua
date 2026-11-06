-- This file is part of mimgui project
-- Licensed under the MIT License
-- Copyright (c) 2024, FYP <https://github.com/THE-FYP>

local mod = {}
local ffi = require 'ffi'

ffi.cdef [[
    typedef unsigned long DWORD;
    typedef void *HWND, *HMONITOR, *HDC;
    typedef unsigned int UINT;
    typedef long HRESULT;
    typedef const char *LPCTSTR;
    typedef const void *LPCVOID;
    typedef signed __int64 INT64, *PINT64;
    typedef unsigned int UINT_PTR, *PUINT_PTR;
    typedef long LONG_PTR, *PLONG_PTR;
    typedef UINT_PTR WPARAM;
    typedef LONG_PTR LPARAM;
    typedef LONG_PTR LRESULT;

    enum {
        LOGPIXELSX = 88,
        LOGPIXELSY = 90,
        MONITOR_DEFAULTTONEAREST = 0x00000002
    };

    typedef enum MONITOR_DPI_TYPE {
        MDT_EFFECTIVE_DPI = 0,
        MDT_ANGULAR_DPI = 1,
        MDT_RAW_DPI = 2,
        MDT_DEFAULT
    } MONITOR_DPI_TYPE;

    /* user32 */
    HMONITOR __stdcall MonitorFromWindow(HWND hwnd, DWORD dwFlags);
    HDC __stdcall GetDC(HWND hWnd);
    int __stdcall ReleaseDC(HWND hWnd, HDC hDC);

    /* gdi32 */
    int __stdcall GetDeviceCaps(HDC hdc, int index);

    /* shcore */
    HRESULT __stdcall GetDpiForMonitor(HMONITOR hmonitor, MONITOR_DPI_TYPE dpiType, UINT *dpiX, UINT *dpiY);
]]

local REFERENCE_DPI = 96
local shcore_dll

local function GetDpiForMonitor(monitor)
    if not shcore_dll then
        shcore_dll = ffi.load('shcore')
    end
    local dpi = ffi.new('UINT[2]', REFERENCE_DPI, REFERENCE_DPI)
    shcore_dll.GetDpiForMonitor(monitor, ffi.C.MDT_EFFECTIVE_DPI, dpi, dpi + 1)
    return dpi[0]
end

local function GetDpiForMonitor_gdi(monitor)
    local dc = ffi.C.GetDC(nil)
    local xdpi = ffi.C.GetDeviceCaps(dc, ffi.C.LOGPIXELSX)
    ffi.C.ReleaseDC(nil, dc)
    return xdpi
end

function mod.GetDpiScaleForMonitor(monitor)
    local ok, dpi = pcall(GetDpiForMonitor, monitor)
    if not ok then
        GetDpiForMonitor = GetDpiForMonitor_gdi
        dpi = GetDpiForMonitor(monitor)
    end
    return dpi / REFERENCE_DPI
end

function mod.GetDpiScaleForWindow(hwnd)
    local monitor = ffi.C.MonitorFromWindow(hwnd, ffi.C.MONITOR_DEFAULTTONEAREST)
    return mod.GetDpiScaleForMonitor(monitor)
end

-- The shipped 1.92.0 DLL exports platform Init/NewFrame/WndProc, but omits
-- Shutdown. Mirror that exact upstream cleanup using its own ImGui allocator.
-- Layout/source: imgui v1.92.0 backends/imgui_impl_win32.cpp (32-bit build).
ffi.cdef [[
    typedef struct {
        void* hWnd; void* MouseHwnd;
        int MouseTrackedArea; int MouseButtonsDown;
        int64_t Time; int64_t TicksPerSecond;
        int LastMouseCursor; uint32_t KeyboardCodePage;
        bool HasGamepad; bool WantUpdateHasGamepad;
        void* XInputDLL; void* XInputGetCapabilities; void* XInputGetState;
    } LeoneImGuiWin32Data192;
    int __stdcall FreeLibrary(void*);
]]
function mod.Shutdown(imgui, hwnd)
    local io = imgui.GetIO()
    local data = io.BackendPlatformUserData
    if data == nil then return end
    assert(ffi.string(imgui.GetVersion()) == '1.92.0', 'Unexpected private ImGui version')
    assert(io.BackendPlatformName ~= nil and ffi.string(io.BackendPlatformName) == 'imgui_impl_win32', 'Unexpected platform backend')
    local bd = ffi.cast('LeoneImGuiWin32Data192*', data)
    assert(bd.hWnd == hwnd and bd.TicksPerSecond > 0, 'Unexpected Win32 backend data')
    if bd.XInputDLL ~= nil then ffi.C.FreeLibrary(bd.XInputDLL) end
    io.BackendPlatformName = nil
    io.BackendPlatformUserData = nil
    io.BackendFlags = require('bit').band(io.BackendFlags, require('bit').bnot(7))
    imgui.lib.igMemFree(data)
end

return mod
