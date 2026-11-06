-- Sputnik asynchronous request API, using Windows' certificate-validated HTTPS.
local effil=require('effil')
local A={};A.__index=A
function A:new(method,url,args,timeout)
    local self=setmetatable({resolve=function() end,reject=function() end,finish=function() end},A)
    local task=effil.thread(function(url)
        local ffi=require('ffi')
        ffi.cdef[[
        int __stdcall MultiByteToWideChar(unsigned int,unsigned long,const char*,int,unsigned short*,int);
        void* __stdcall WinHttpOpen(const unsigned short*,unsigned long,const unsigned short*,const unsigned short*,unsigned long);
        void* __stdcall WinHttpConnect(void*,const unsigned short*,unsigned short,unsigned long);
        void* __stdcall WinHttpOpenRequest(void*,const unsigned short*,const unsigned short*,const unsigned short*,const unsigned short*,const unsigned short**,unsigned long);
        int __stdcall WinHttpSetTimeouts(void*,int,int,int,int);
        int __stdcall WinHttpSendRequest(void*,const unsigned short*,unsigned long,void*,unsigned long,unsigned long,uintptr_t);
        int __stdcall WinHttpReceiveResponse(void*,void*);
        int __stdcall WinHttpQueryHeaders(void*,unsigned long,const unsigned short*,void*,unsigned long*,unsigned long*);
        int __stdcall WinHttpReadData(void*,void*,unsigned long,unsigned long*);
        int __stdcall WinHttpCloseHandle(void*);
        ]]
        local w=ffi.load('winhttp');local k=ffi.load('kernel32')
        local function wide(s) local n=k.MultiByteToWideChar(65001,0,s,#s,nil,0);local b=ffi.new('unsigned short[?]',n+1);k.MultiByteToWideChar(65001,0,s,#s,b,n);return b end
        local host,route=url:match('^https://([^/]+)(/.*)$')
        if not host or host:find('[^%w.%-]') then return false,'Invalid HTTPS URL' end
        local handles={}
        local function close() for i=#handles,1,-1 do w.WinHttpCloseHandle(handles[i]) end end
        local ok,result=pcall(function()
            local session=w.WinHttpOpen(wide('LeoneMenu/1.0'),0,nil,nil,0);assert(session~=nil,'WinHTTP unavailable');handles[#handles+1]=session
            w.WinHttpSetTimeouts(session,5000,5000,10000,10000)
            local conn=w.WinHttpConnect(session,wide(host),443,0);assert(conn~=nil,'Connection failed');handles[#handles+1]=conn
            local req=w.WinHttpOpenRequest(conn,wide('GET'),wide(route),nil,nil,nil,0x00800000);assert(req~=nil,'Request failed');handles[#handles+1]=req
            assert(w.WinHttpSendRequest(req,nil,0,nil,0,0,0)~=0,'HTTPS send failed')
            assert(w.WinHttpReceiveResponse(req,nil)~=0,'HTTPS receive failed')
            local status=ffi.new('unsigned long[1]');local size=ffi.new('unsigned long[1]',4)
            assert(w.WinHttpQueryHeaders(req,0x20000013,nil,status,size,nil)~=0,'No HTTP status')
            local buf=ffi.new('char[32768]');local read=ffi.new('unsigned long[1]');local chunks={};local total=0
            repeat
                assert(w.WinHttpReadData(req,buf,32768,read)~=0,'HTTPS read failed')
                total=total+tonumber(read[0]);assert(total<=4194304,'Response exceeds 4 MB')
                chunks[#chunks+1]=ffi.string(buf,read[0])
            until read[0]==0
            return {status_code=tonumber(status[0]),text=table.concat(chunks)}
        end)
        close();return ok,result
    end)(url)
    lua_thread.create(function()
        local started=os.time()
        while true do
            local status=task:status()
            if status=='completed' then
                local ok,success,response=pcall(task.get,task)
                if ok and success then self.resolve(response) else self.reject(tostring(response or success)) end
                self.finish();break
            elseif status=='failed' or status=='canceled' or os.time()-started>(timeout or 20) then
                task:cancel();self.reject('HTTPS request failed or timed out');self.finish();break
            end
            wait(20)
        end
    end)
    return self
end
function A:then_(f) self.resolve=f;return self end
function A:catch(f) self.reject=f;return self end
function A:finally(f) self.finish=f;return self end
return A
