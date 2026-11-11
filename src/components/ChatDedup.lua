local R=require('src.core.Rules')
local D={}
local LAST_CHAT_ROW=99
local CHAT_REDRAW=0x63DA
-- PE entry points and CChat references for SA-MP 0.3.7 R1, R3-1 and R5-1.
local chat_refs={[0x31DF13]=0x21A0E4,[0xCC4D0]=0x26E8C8,[0xCBC90]=0x26EB80}
local enabled,last

function D.configure(setting)
    enabled=setting
    last=nil
end

local function chat_address()
    if not (sampGetBase and sampGetChatInfoPtr and readMemory and writeMemory) then return end
    local base,chat=sampGetBase(),sampGetChatInfoPtr()
    if not base or base==0 or not chat or chat==0 or readMemory(base,2,false)~=0x5A4D then return end
    local header=readMemory(base+0x3C,4,false)
    if not header or header<0x40 or header>0x1000 or readMemory(base+header,4,false)~=0x4550 then return end
    local ref=chat_refs[readMemory(base+header+0x28,4,false)]
    if ref and readMemory(base+ref,4,false)==chat then return chat end
end

local function replace_last(previous,updated)
    if #updated>143 or not (sampGetChatString and sampSetChatString) then return false end
    local chat=chat_address()
    if not chat then return false end
    local text,prefix,color,prefix_color=sampGetChatString(LAST_CHAT_ROW)
    if text~=previous.rendered or type(prefix)~='string' then return false end
    local name=R.trim(R.strip(prefix)):gsub(':$','')
    if name~=previous.prefix then return false end
    sampSetChatString(LAST_CHAT_ROW,updated,prefix,color,prefix_color)
    writeMemory(chat+CHAT_REDRAW,4,1,false)
    return true
end

local function combine(source,sender,raw,visible,prefix)
    if not enabled or not enabled[0] then last=nil;return end
    if last and last.source==source and last.sender==sender and last.prefix==prefix and last.raw==raw and last.visible==visible then
        local count=last.count+1
        local updated=('%s [x%d]'):format(visible,count)
        local ok,replaced=pcall(replace_last,last,updated)
        if ok and replaced then
            last.count=count
            last.rendered=updated
            return false
        end
    end
    last={source=source,sender=sender,raw=raw,visible=visible,rendered=visible,prefix=prefix,count=1}
end

function D.server(color,text,result)
    if result==false then return false end
    local visible=type(result)=='table' and result[2] or text
    if combine('server',color,text,visible,'')==false then return false end
    return result
end

function D.player(id,text)
    if not enabled or not enabled[0] then last=nil;return end
    if not sampIsPlayerConnected(id) then last=nil;return end
    return combine('player',id,text,text,sampGetPlayerNickname(id))
end

return D
