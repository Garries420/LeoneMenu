# Leone private GUI fork

Based directly on the supplied upmimgui 1.92.0 Lua files and native DLL.
Original MIT notices remain in the source. No native binary edits are made.

Changes: own-context initialization; strong, explicit COM texture ownership;
idempotent renderer destruction; private platform allocator cleanup; early and
active script-unload handling; callbacks stopped before native state is freed.
Config output stays in moonloader/config/Leone Menu.

The supplied 32-bit DLL SHA-256 is:
8e00117fca5dc8f7b8e2f90996533f65ddcc3435671e0bb1e6502b9319345141

That binary identifies itself as ImGui 1.92.0 and has Win32 Init/NewFrame/WndProc
exports but no Win32 Shutdown export. win32.lua matches the upstream 1.92.0
backend data and Shutdown code, with runtime version/name/window checks. It uses
igMemFree from this same DLL. Native D3D teardown tests verify the result without
suppression of ImGui diagnostics.

Reference: https://raw.githubusercontent.com/ocornut/imgui/v1.92.0/backends/imgui_impl_win32.cpp
