local ffi = require('ffi')
local Files = {}

function Files.path(p)
    if p:match('^%a:[/\\]') then return p end
    return getWorkingDirectory() .. '/' .. p
end
function Files.write(path, text)
    path=Files.path(path)
    local tmp=path..'.tmp'
    local f,err=io.open(tmp,'wb'); if not f then return false,err end
    local ok,why=f:write(text); f:close()
    if not ok then return false,why end
    local check=io.open(tmp,'rb'); if not check then return false,'Cannot verify temporary file' end
    local same=check:read('*a')==text; check:close()
    if not same then return false,'Temporary file differs' end
    -- Windows atomic replacement with write-through; old file remains intact on failure.
    pcall(ffi.cdef,'int __stdcall MoveFileExA(const char*,const char*,unsigned long);')
    if ffi.load('kernel32').MoveFileExA(tmp,path,9)==0 then return false,'Atomic replacement failed' end
    return true
end
function Files.read(path)
    local f=io.open(Files.path(path),'rb'); if not f then return nil end
    local s=f:read('*a');f:close();return s
end

function Files.sha256(text)
    pcall(ffi.cdef,[[
        int __stdcall CryptAcquireContextA(uintptr_t*,const char*,const char*,unsigned long,unsigned long);
        int __stdcall CryptCreateHash(uintptr_t,unsigned int,uintptr_t,unsigned long,uintptr_t*);
        int __stdcall CryptHashData(uintptr_t,const unsigned char*,unsigned long,unsigned long);
        int __stdcall CryptGetHashParam(uintptr_t,unsigned long,unsigned char*,unsigned long*,unsigned long);
        int __stdcall CryptDestroyHash(uintptr_t);
        int __stdcall CryptReleaseContext(uintptr_t,unsigned long);
    ]])
    local a=ffi.load('advapi32');local ctx=ffi.new('uintptr_t[1]');local hash=ffi.new('uintptr_t[1]')
    if a.CryptAcquireContextA(ctx,nil,nil,24,0xF0000000)==0 then return nil end
    if a.CryptCreateHash(ctx[0],0x800c,0,0,hash)==0 then a.CryptReleaseContext(ctx[0],0);return nil end
    local digest=ffi.new('unsigned char[32]');local size=ffi.new('unsigned long[1]',32)
    local ok=a.CryptHashData(hash[0],ffi.cast('const unsigned char*',text),#text,0)~=0 and a.CryptGetHashParam(hash[0],2,digest,size,0)~=0
    a.CryptDestroyHash(hash[0]);a.CryptReleaseContext(ctx[0],0)
    if not ok then return nil end
    local out={};for i=0,31 do out[#out+1]=string.format('%02x',digest[i]) end
    return table.concat(out)
end

return Files
