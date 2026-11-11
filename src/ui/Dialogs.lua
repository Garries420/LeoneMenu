-- Client-only SA-MP dialogs. Never submits a locally-owned dialog to HZG.
local D={queue={},active=nil,id=32760}
function D.show(title,text,style,button,callback,required,eligible,tag,allow_escape)
    D.queue[#D.queue+1]={title=title,text=text,style=style,button=button,callback=callback,required=required,eligible=eligible,tag=tag,allow_escape=allow_escape}
end
function D.cancel(tag)
    for i=#D.queue,1,-1 do if D.queue[i].tag==tag then table.remove(D.queue,i) end end
    if D.active and D.active.tag==tag then
        D.active=nil
        if sampIsDialogActive() and sampGetCurrentDialogId()==D.id then sampCloseCurrentDialogWithButton(0) end
    end
end
function D.start(recovery)
    if recovery then
        -- RPC 62 is DialogResponse. This path works before loading SAMP.Lua.
        addEventHandler('onSendRpc',function(id,stream)
            if id~=62 then return end
            local offset=raknetBitStreamGetReadOffset(stream)
            raknetBitStreamSetReadOffset(stream,0)
            local dialog_id=raknetBitStreamReadInt16(stream)
            raknetBitStreamSetReadOffset(stream,offset)
            if dialog_id==D.id then return false end
        end)
    else
        require('src.shared').event_handler:register('SEND_DIALOG_RESPONSE',function(id) return id==D.id end,function() return false end)
    end
    lua_thread.create(function()
        while true do
            if not D.active and #D.queue>0 and not sampIsDialogActive() then
                D.active=table.remove(D.queue,1)
                if D.active.eligible and not D.active.eligible() then D.active=nil
                else sampShowDialog(D.id,D.active.title,D.active.text,D.active.button,D.active.required and '' or 'Cancel',D.active.style) end
            elseif D.active then
                local result,button,list,input=sampHasDialogRespond(D.id)
                if result then
                    local item=D.active;D.active=nil
                    if button~=1 and item.required and not item.allow_escape then table.insert(D.queue,1,item)
                    elseif button==1 and item.callback then item.callback(list,input) end
                elseif sampIsDialogActive() and sampGetCurrentDialogId()~=D.id then
                    table.insert(D.queue,1,D.active);D.active=nil
                end
            end
            wait(20)
        end
    end)
end
return D
