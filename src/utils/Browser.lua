local ffi=require('ffi')

return function(url)
    pcall(ffi.cdef,'void* __stdcall ShellExecuteA(void*,const char*,const char*,const char*,const char*,int);')
    local result=ffi.load('shell32').ShellExecuteA(nil,'open',url,nil,nil,1)
    return tonumber(ffi.cast('intptr_t',result))>32
end
