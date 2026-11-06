local Files=require('src.utils.UpdateFiles')
local open_browser=require('src.utils.Browser')
local Package={}

local release_url='https://github.com/Garries420/LeoneMenu/releases/latest'
local title='Leone Menu - Required update'
local body=table.concat({
    '{FF3333}CLOSE GTA BEFORE INSTALLING',
    '',
    '{FFFFFF}This version needs updated Leone Menu files.',
    '{FFFF55}Download the latest RAR from GitHub.',
    '{FFFFFF}Close GTA completely. Extract the moonloader folder into',
    'your GTA folder and choose Replace when asked.',
    '',
    'Press OK to open the release page in your browser.'
},'\n')

function Package.check(files)
    for path,digest in pairs(files) do
        local data=Files.read(path)
        if not data or Files.sha256(data)~=digest then return false,path end
    end
    return true
end

function Package.recover(version,fingerprint,path)
    script_name('Leone Menu')
    script_version(version)
    script_authors('Kev','Futurestunt','Garry')
    print('[Leone Menu] Required package file is missing or differs: '..path)

    function main()
        while not isSampAvailable() do wait(0) end
        local directory='config/Leone Menu'
        for _,folder in ipairs({'config',directory}) do
            local absolute=Files.path(folder)
            if not doesDirectoryExist(absolute) then createDirectory(absolute) end
        end
        local function show_link()
            sampAddChatMessage('{1E3348}[Leone Menu] {FFFFFF}Full package required. Close GTA before installing. '..release_url,-1)
        end
        local function open_release()
            local ok,opened=pcall(open_browser,release_url)
            if not ok or not opened then show_link() end
        end
        sampRegisterChatCommand('leone',open_release)
        local acknowledgement=directory..'/package-warning-'..fingerprint..'.txt'
        if Files.read(acknowledgement)~='acknowledged\n' then
            while not sampIsLocalPlayerSpawned() or not doesCharExist(PLAYER_PED) or isCharInAnyCar(PLAYER_PED) do wait(250) end
            local Dialogs=require('src.ui.Dialogs')
            Dialogs.start(true)
            Dialogs.show(title,body,0,'OK',function()
                Files.write(acknowledgement,'acknowledged\n')
                open_release()
            end,true)
        else
            show_link()
        end
        wait(-1)
    end
end

return Package
