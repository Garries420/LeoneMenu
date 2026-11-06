local imgui=require('upmimgui')
local fa=require('fAwesome7')
local H=require('src.ui.Helpers')
local U=require('src.core.Updates')
local MainWindow=require('src.ui.MainWindow')
local Home={reload_requested=false,update_check_requested=false}
function Home:register()
    MainWindow:add_page('home',{title='Home',icon=fa('HOUSE'),order=0,render_function=function()
        imgui.Heading('Leone Menu')
        imgui.Text('Leone Menu V'..U.version)
        imgui.DrawChild('Credits',function()
            imgui.TextWrapped('Built on Sputnik, created by Kev and Futurestunt. Thank you for the original menu and its systems.')
            if imgui.AnimButton('Kev - forum profile') then H.open('https://forums.hzgaming.net/member.php/49614-Kev') end
            if imgui.AnimButton('Sputnik - original forum thread') then H.open('https://forums.hzgaming.net/showthread.php/639069-sputnik-the-non-shady-alternative-to-PEMENU') end
            imgui.Separator()
            imgui.Text('Leone Menu by Garry')
            if imgui.AnimButton('Garry - forum profile') then H.open('https://forums.hzgaming.net/member.php/25596-Garry') end
            if imgui.AnimButton('Discord: garries - click to copy') then setClipboardText('garries');msg('Discord username copied: {1E3348}garries{FFFFFF}.') end
        end)
        if imgui.AnimButton(fa('ROTATE')..' Reload Leone Menu') then
            Home.reload_requested=true
        end
        imgui.SameLine()
        if imgui.AnimButton('Check for updates') then Home.update_check_requested=true end
        imgui.TextWrapped(U.status)
        imgui.TextWrapped(U.skins_status)
        imgui.Text('Version Date: '..(U.alliance.date or 'Unavailable'))
        if imgui.IsItemHovered() then imgui.SetTooltip('Day/Month/year - Swedish Timezone') end
    end})
    MainWindow:select_page('home')
end
return Home
