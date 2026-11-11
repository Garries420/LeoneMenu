-- Pure parsing/selection rules shared by runtime and local tests.
local R={}
function R.strip(s) return (s:gsub('{%x%x%x%x%x%x}',''):gsub('~%a~','')) end
function R.trim(s) return s:match('^%s*(.-)%s*$') end
function R.skins(text)
    local out,seen={},{}
    if type(text)~='string' or text:find('[^%d,%s]') then return nil end
    for n in text:gmatch('%d+') do
        n=tonumber(n)
        if n>311 or n==74 then return nil end
        if not seen[n] then out[#out+1]=n;seen[n]=true end
    end
    if #out==0 then return nil end
    return out
end
function R.alliance(html)
    local version=tonumber(html:match('<meta%s+name="leone%-skins%-version"%s+content="(%d+)"%s*/?>'))
    local ids=html:match('<pre%s+id="alliance%-skins">%s*([^<]+)</pre>')
    local skins=ids and R.skins(R.trim(ids))
    if not version or not skins then return nil end
    local date=html:match('<meta%s+name="leone%-skins%-date"%s+content="([^"]+)"%s*/?>')
    if date and not date:match('^%d%d/%d%d/%d%d%d%d %d%d:%d%d[AP]M CES?T$') then return nil end
    return {version=version,skins=skins,date=date}
end
function R.html_skins(html)
    if type(html)~='string' or #html>131072 then return nil end
    local document=html:lower():gsub('^\239\187\191',''):gsub('<!%-%-.-%-%->',' ')
    local content=document:match('<pre%s[^>]-id%s*=%s*"alliance%-skins"[^>]*>(.-)</pre%s*>')
        or document:match('<pre%s*>(.-)</pre%s*>') or document:match('<pre%s[^>]*>(.-)</pre%s*>')
        or document:match('<body%s*>(.-)</body%s*>') or document:match('<body%s[^>]*>(.-)</body%s*>') or document
    local list_tags={br=true,p=true,div=true,ul=true,ol=true,li=true,code=true,span=true}
    content=content:gsub('&nbsp;',' '):gsub('</?([%a]+)[^>]*>',function(tag)
        return list_tags[tag] and ' ' or '?'
    end)
    return R.skins(content)
end
function R.frequency(text)
    text=R.strip(text)
    local body=text:match('Family MOTD:%s*(.+)')
    if not body then return nil end
    local n=body:match('[Ff]:%s*(%-?%d+)') or body:match('^%s*(%-?%d+)')
    if n and #n:gsub('^-','')<=8 then return tonumber(n) end
end
function R.in_box(x,y,b)
    return x>=b.min_x and x<=b.max_x and y>=b.min_y and y<=b.max_y
end
function R.matches(query,players)
    local exact,partial={},{}
    query=query:lower():gsub(' ','_')
    for _,p in ipairs(players) do
        local name=p.name:lower()
        if (query:match('^%d+$') and p.id==tonumber(query)) or name==query then exact[#exact+1]=p
        elseif not query:match('^%d+$') and name:find(query,1,true) then partial[#partial+1]=p end
    end
    return #exact>0 and exact or partial
end
function R.gang(text,color)
    local plain=R.strip(text)
    local name=plain:match('^%s*%*%s*%d+%.%s*(.-)%s*|')
    if not name or not plain:match('|%s*Leader:') or not plain:match('|%s*Online:%s*%d+') then return nil end
    local prefix=text:match('^(.-)|') or ''
    local hex
    for tag,rest in prefix:gmatch('{(%x%x%x%x%x%x)}([^{}]*)') do
        if rest:find(name,1,true) then hex=tag end
    end
    return {name=R.trim(name),hex=(hex or string.format('%08X',color%4294967296):sub(1,6)):upper()}
end
function R.short_turf(name)
    name=R.trim(R.strip(name or ''))
    local short={['Pershing Square']='Pershing Sq.',['East Los Santos East']='East LS (E)',
        ['East Los Santos West']='East LS (W)',['Downtown Los Santos']='Downtown LS',
        ['Mulholland Intersection']='Mulholland Int.',['North Willowfield']='N. Willowfield',
        ['South Willowfield']='S. Willowfield',['Santa Maria Beach']='Santa Maria',
        ['Playa del Seville']='Playa Seville'}
    return short[name] or name
end
function R.newer(a,b)
    local function parts(v)
        local x,y,z,suffix=v:match('^v?(%d+)%.(%d+)%.(%d+)(.*)$')
        if not x or (suffix~='' and not suffix:match('^[-+][%w.+%-]+$')) then return nil end
        local pre=suffix:match('^%-([^+]+)')
        return {tonumber(x),tonumber(y),tonumber(z)},pre
    end
    local pa,pre_a=parts(a);local pb,pre_b=parts(b)
    if not pa or not pb then return false end
    for i=1,3 do if pa[i]~=pb[i] then return pa[i]>pb[i] end end
    if not pre_a or not pre_b then return not pre_a and pre_b~=nil end
    local aa,bb={},{}
    for v in pre_a:gmatch('[^.]+') do aa[#aa+1]=v end
    for v in pre_b:gmatch('[^.]+') do bb[#bb+1]=v end
    for i=1,math.max(#aa,#bb) do
        if not aa[i] then return false elseif not bb[i] then return true end
        if aa[i]~=bb[i] then
            local na,nb=tonumber(aa[i]),tonumber(bb[i])
            if na and nb then return na>nb elseif na then return false elseif nb then return true end
            return aa[i]>bb[i]
        end
    end
    return false
end
return R
