-- Search uses section names from the settings pages so results can jump to the rendered cards.
local S={}
local sections={
    {'home','Credits','Sputnik credits','Kev and Futurestunt','Garry forum and Discord'},
    {'home',false,'Reload Leone Menu','Check for updates','Alliance skins revision'},
    {'auto_vest','Auto Vest','Automatically vest nearby players - /avest','Aim and vest',
        'Command mode - /avmode to swap between Normal and DD','Alliance skins to be vested','Add gang and Auto import /gangs','HTML skin list URL',
        'Vest interval (seconds)','Offer if vest is below','Show offered-to overlay'},
    {'auto_vest','Accept Vest','Automatically accept vest offers priced at $200 - /av',
        'Accept if vest is below','Manual Accept','Manually accept vest',
        'Automatically stop accepting vest offers upon point completion','Show offered-by overlay'},
    {'auto_vest','Position##vesting','Vest overlay position and scroll wheel size','Overlay Style - Stacked and Vertical','Reset size of vest overlays'},
    {'backup','Backup','Show active backup requests','Faction backup keybind','All custom locations','Mention wanted level'},
    {'backup','Portable Radio','Show frequency in chat messages','Checks /fmotd for alliance frequency and changes freq'},
    {'backup','Position & Appearance##backup','Backup overlay position','Draw a background','Draw a border'},
    {'backup','Style Properties##backup','Font size','Padding','Border Thickness','Rounding'},
    {'blackmarket','Blackmarket','Select mode - /bms','Purchase keybind','Current Mode','Purchase gap (ms)',
        'Deagle + Health & Vest','Deagle + Sniper + Health & Vest',
        'Deagle + Spas12 + Health & Vest','Deagle + Sniper + Spas12 + Health & Vest'},
    {'find','Autofind','Find Player - /af','Cohort Player - /afco','Adjust Cooldown - /afcd','Suggested Cooldown'},
    {'find','Display##autofind','Hide Redmarker Message'},
    {'keybinds',false,'Custom command keybinds','Add a keybind'},
    {'miscellaneous','Font Selector','Change font for on-screen elements'},
    {'miscellaneous','Automatization','Automatically eject all players from vehicle when it catches fire',
        'Automatically accept $1 repair offers from players','Offer $1 repair to nearest driver or passenger',
        'Automatically accept lawyer offered at $200',
        'Automatically retry picking a vehicle lock after a failed attempt','Spam LMB while holding a Sprunk can to quickly recover health'},
    {'miscellaneous','Beacon Resolver','Resolve player IDs when written as "B20" to their actual name instead'},
    {'miscellaneous','Frisking','Play sound when frisking a player who has a sniper rifle','Aim and frisk a player'},
    {'miscellaneous','Lawyering','Auto Lawyer - /al','Auto Lawyer nearest wanted','Auto Free - /afree','Auto Free nearest prisoner',
        'Cooldown on /afree and /al','Lawyer cooldown overlay position and scroll wheel size','Reset size of lawyer cooldown overlay'},
    {'miscellaneous','Random',"Skips over parachute but it reappears once you're falling - /skippara",'Anti Spam','Sign check - /si','Change insurance location - /ins',
        'Guard nearby players quickly (guardnear) - /v'},
    {'miscellaneous','Vehicles','Vehicle storage and typed slot preview - /vst /fv /vtow','Spawn/Despawn vehicle - /vst',
        'Find Vehicle - /fv','Tow vehicle - /vtow'},
    {'ped_counter','Ped Counter','Show overlay with active ped slot count','Enable overlay outside interiors'},
    {'ped_counter','Position & Appearance##ped_counter','Ped counter overlay position','Draw a background','Draw a border'},
    {'ped_counter','Style Properties##ped_counter','Font size','Padding','Border Thickness','Rounding'},
    {'capture','Turfs','Show upcoming turf war info','Show active turf war info',
        'Automatically capture turfs - /acapt','Run capture command periodically - /spamt','Capture spam interval'},
    {'capture','Points','Show upcoming point war info','Show active point war info','Automatically capture points - /acapp'},
    {'capture','Regroup checker','Checks the surrounding area for our own members','Quick usage - /rgcheck','RGCHECK'},
    {'capture','Position##capture','Turf and point overlay position and scroll wheel size','Overlay Style - Stacked and Vertical','Reset size of turf and point overlays'},
    {'phone','Phone','Show Player ID','Colorize Name','Hide Extra Lines'},
    {'phone','SMS Players','Send SMS - /pm'}
}
function S.find(query,pages)
    local terms={}
    for term in query:lower():gmatch('%S+') do terms[#terms+1]=term end
    if #terms==0 then return {} end
    local results={}
    for _,section in ipairs(sections) do
        local id,anchor=section[1],section[2]
        local page=pages[id]
        if page then
            local group=anchor and anchor:gsub('##.*$','') or page.title
            local function matches(text)
                text=text:lower()
                for _,term in ipairs(terms) do
                    if not text:find(term,1,true) then return false end
                end
                return true
            end
            if anchor=='Capture##turfs' then group='Turf Capture' end
            if anchor=='Capture##points' then group='Point Capture' end
            local group_result={page=id,anchor=anchor,heading=group==page.title and page.title or page.title..'  /  '..group,items={}}
            local group_matches=matches(group)
            for i=3,#section do
                local label=section[i]
                if matches(label) or (not group_matches and matches(group..' '..label)) then
                    group_result.items[#group_result.items+1]=label
                end
            end
            if #group_result.items==0 and group_matches then group_result.items[1]=group end
            if #group_result.items>0 then results[#results+1]=group_result end
        end
    end
    return results
end
return S
