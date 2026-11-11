local Http=require('src.utils.AsyncHttpRequest')
local R=require('src.core.Rules')
local Feed={}
Feed.__index=Feed

function Feed.new()
    return setmetatable({url='',skins={}},Feed)
end

function Feed:set_url(value)
    local url=R.trim(value)
    if self.url==url then return end
    self.url=url
    self.skins={}
    self.next_check=os.clock()+0.7
    self.status=url~='' and 'Waiting to load skin IDs...' or nil
end

function Feed:tick()
    if self.request and self.request:poll() then self.request=nil end
    if self.request or self.url=='' or not self.next_check or os.clock()<self.next_check then return end

    local url=self.url
    local target=url:gsub('#.*$','')
    local host,path=target:match('^https://([%w.%-]+)(.*)$')
    if not host or (path~='' and path:sub(1,1)~='/') or target:find('[%s%c]') then
        self.status='Enter an HTTPS URL for a skin list.'
        self.next_check=nil
        return
    end

    self.next_check=os.clock()+3600
    self.status='Loading skin IDs...'
    local function failed(status)
        if self.url~=url then return end
        self.status=status..(next(self.skins) and ' Keeping the last list from this URL.' or '')
        self.next_check=os.clock()+60
    end
    local ok,request=pcall(function()
        return Http:new('GET',path=='' and target..'/' or target,nil,20,true):then_(function(response)
            if self.url~=url then return end
            if response.status_code~=200 then return failed('Could not load the skin URL.') end
            local ids=R.html_skins(response.text)
            if not ids then return failed('No valid skin ID list was found.') end
            local skins={}
            for _,id in ipairs(ids) do skins[id]=true end
            self.skins=skins
            self.status=('%d skin IDs loaded.'):format(#ids)
        end):catch(function() failed('Could not load the skin URL.') end)
    end)
    if ok then self.request=request else failed('Could not load the skin URL.') end
end

return Feed
