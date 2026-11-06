-- Sputnik phonebook lookup, with a scoped request and the requested SMS UI.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local bit=require('bit')
local Colors=require('src.core.Colors')
local Config=require('src.core.Config')
local H=require('src.ui.Helpers')
local Player=require('src.utils.Player')
local R=require('src.core.Rules')
local shared=require('src.shared')
local P={}
local cfg={show_id=imgui.new.bool(true),colorize=imgui.new.bool(true),hide_extra=imgui.new.bool(true)}
local pending
local last_sms_at=-math.huge
local function normalized(name) return name:lower():gsub(" ","_") end
local function bad_player() msg("Player isn't logged in or ID/name is wrong, try again") end
function P:register()
    Config.load('config/Leone Menu/phone.json',cfg)
    sampRegisterChatCommand('pm',function(args)
        local recipient,message=args:match('^(%S+)%s+(.+)$')
        if not recipient then return msg('USAGE: /pm [Player ID / Name] [Message]') end
        if pending then return msg('Please wait for the current phone lookup.') end
        local id=Player:resolve_player_id(recipient);if not id then return end
        pending={id=id,name=sampGetPlayerNickname(id),message=message,deadline=os.clock()+6}
        samp_send_hidden_command('number',tostring(id))
    end)
    shared.event_handler:register('SEND_COMMAND',function(command)
        return command:lower():match('^/sms%s+%-?%d+%s+%S')~=nil
    end,function() last_sms_at=os.clock() end)
    shared.event_handler:register('SERVER_MESSAGE',function(color,text) return {color,text} end,function(color,text)
        local plain=R.strip(text)
        if pending then
            local p=pending
            local name,number=plain:match('^%* (.-) %((%-?%d+)%)$')
            if name and name:gsub(' ','_')==p.name then
                pending=nil
                if sampIsPlayerConnected(p.id) and sampGetPlayerNickname(p.id)==p.name then
                    last_sms_at=os.clock()
                    sampSendChat('/sms '..number..' '..p.message)
                else bad_player() end
                return false
            elseif plain=='Invalid player specified.' then pending=nil;bad_player();return false
            elseif plain:match('^%* You cannot find .- in the phonebook!$') then
                local who=plain:match('^%* You cannot find (.-) in the phonebook!$')
                if who:gsub(' ','_')==p.name then pending=nil;msg(string.format("%s ({1E3348}%d{FFFFFF}) doesn't own a phone",who,p.id));return false end
            end
        end
        if cfg.hide_extra[0] then
            if color==Colors.WHITE and plain=='Text message delivered.' then return false end
            local actor=plain:match('^%* (.+) takes out a cellphone%.$')
            if actor and os.clock()-last_sms_at<=2 then
                local ok,local_id=sampGetPlayerIdByCharHandle(PLAYER_PED)
                local own_name=ok and sampGetPlayerNickname(local_id)
                if own_name and normalized(actor)==normalized(own_name) then return false end
            end
        end
        if color~=Colors.YELLOW and color~=Colors.YELLOW2 then return end
        if not cfg.show_id[0] and not cfg.colorize[0] then return end
        local message,name,number=plain:match('^SMS: (.+), Sender: (.-) %((%-?%d+)%)$')
        if not message or (name=='MOLE' and number=='555') or name:find('[automated response]',1,true) then return end
        local id=Player:get_player_id_by_name(name:gsub(' ','_'))
        if not id or id<0 then return end

        local sender=name..' ('..number..')'
        local suffix=cfg.show_id[0] and (' [%d]'):format(id) or ''
        local add_id=suffix~='' and #plain+#suffix<=128
        local text_color=string.format('{%06X}',bit.rshift(color,8))
        local player_color=sampGetPlayerColor(id)
        local rgb=bit.band(player_color,0xFFFFFF)
        local add_color=cfg.colorize[0] and rgb~=0xFFFFFF and rgb~=0xFCFCFC
            and #plain+(add_id and #suffix or 0)+8<=128
        if not add_id and not add_color then return end
        if add_color then
            local tag=bit.tobit(player_color)==bit.tobit(0xAAFFF000) and '{FFD800}' or ('{%06X}'):format(rgb)
            sender=tag..sender
        end
        if add_id then sender=sender..' '..text_color..suffix:sub(2) end
        return {color,('SMS: %s, Sender: %s'):format(message,sender)}
    end)
    shared.event_handler:register('PED_TICK',function() return pending and os.clock()>pending.deadline end,function() pending=nil;msg('Phone lookup timed out. Please try again.') end)
    shared.event_handler:register('PLAYER_QUIT',function(id) return pending and pending.id==id end,function() pending=nil;bad_player() end)
    require('src.ui.MainWindow'):add_page('phone',{title='Phone',icon=fa('MOBILE_SCREEN_BUTTON'),order=999,render_function=function() P:render_ui_settings() end})
end
function P:save_config() return Config.save('config/Leone Menu/phone.json',cfg) end
function P:render_ui_settings()
    imgui.DrawChild('Phone',function(width)
        H.toggle('Show Player ID','sms_id',cfg.show_id,width)
        H.toggle('Colorize Name','sms_color',cfg.colorize,width)
        H.toggle('Hide Extra Lines','sms_extra',cfg.hide_extra,width,'Removes cellphone emotes, text message delivered and other extra phone lines from chat.')
    end)
    imgui.DrawChild('SMS Players',function()
        imgui.Text('CMD: /pm [Player ID / Name] [Message]')
        imgui.TextWrapped("You can use part of the player's name. If several players match, the menu lists their names and IDs before sending anything.")
    end)
end
return P
