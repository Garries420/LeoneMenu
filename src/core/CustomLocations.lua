local Rules = require('src.core.Rules')

local locations = {
    {name="All Saints Hospital",min_x=1133.3644,max_x=1199.4504,min_y=-1400.8804,max_y=-1273.7079,point=false},
    {name="County General Hospital",min_x=1981.6985,max_x=2112.8921,min_y=-1473.1101,max_y=-1341.7203,point=false},
    {name="Maximus Club",min_x=1813.8079,max_x=1944.1582,min_y=-1760.2096,max_y=-1606.4039,point=false},
    {name="Pizza Stacks",min_x=2098.3291,max_x=2134.1362,min_y=-1831.5007,max_y=-1759.5227,point=false},
    {name="Downtown LS Bank",min_x=1371.334,max_x=1531.8296,min_y=-1039.7273,max_y=-933.7825,point=false},
    {name="Rodeo Bank",min_x=500.8312,max_x=633.2853,min_y=-1358.8105,max_y=-1201.9067,point=false},
    {name="Dice Casino",min_x=747.7726,max_x=788.3983,min_y=-1595.5197,max_y=-1516.7189,point=false},
    {name="Star Tower",min_x=1499.6473,max_x=1596.3043,min_y=-1402.3785,max_y=-1302.6461,point=false},
    {name="East Beach Stadium",min_x=2635.2527,max_x=2844.8594,min_y=-1898.3109,max_y=-1647.9591,point=false},
    {name="Glen Park BM",min_x=1961.808,max_x=2080.8647,min_y=-1321.8481,max_y=-1253.4957,point=false},
    {name="LSPD HQ",min_x=1522.7148,max_x=1612.5985,min_y=-1739.2374,max_y=-1584.5906,point=false},
    {name="FBI HQ",min_x=232.9287,max_x=427.3033,min_y=-1571.7903,max_y=-1485.9653,point=false},
    {name="ARES HQ",min_x=2762.7317,max_x=2852.2761,min_y=-1156.9515,max_y=-1040.8756,point=false},
    {name="MP1",min_x=1333.1392,max_x=1464.0436,min_y=-1439.5022,max_y=-1231.2352,point=true},
    {name="FFC",min_x=2423.988,max_x=2714.2747,min_y=-2158.8818,max_y=-2062.1416,point=true},
    {name="Drug Factory",min_x=17.9806,max_x=204.9483,min_y=-345.4443,max_y=-198.3929,point=true},
    {name="Blueberry Hospital",min_x=88.0542,max_x=142.472,min_y=-200.4079,max_y=-148.0842,point=false},
    {name="MF1",min_x=2056.9868,max_x=2306.6816,min_y=-2318.6392,max_y=-2271.5701,point=true},
    {name="MP2",min_x=2312.9573,max_x=2548.6943,min_y=-2054.2615,max_y=-1972.2751,point=true},
    {name="Drug House",min_x=2100.1726,max_x=2208.9001,min_y=-1728.1006,max_y=-1635.2883,point=true},
    {name="Crack Lab",min_x=2298.4644,max_x=2373.3162,min_y=-1208.7295,max_y=-1117.1232,point=true},
    {name="MF2",min_x=2238.957,max_x=2294.7288,min_y=-1139.167,max_y=-1027.7941,point=true},
    {name="AEC",min_x=2610.1086,max_x=2867.8977,min_y=-2581.8206,max_y=-2330.5796,point=true},
    {name="Sprunk Factory",min_x=1313.7975,max_x=1341.3224,min_y=215.729,max_y=327.1318,point=true},
    {name="MP3",min_x=2117.3782,max_x=2251.2034,min_y=-145.1033,max_y=37.5504,point=true},
    {name="MF3",min_x=-656.5953,max_x=-446.9016,min_y=-595.3939,max_y=-442.6551,point=true},
}

-- Interiors reuse the exterior location names and point flags. GTA shares
-- interior IDs across different maps, so the ID alone is never a match.
local interiors = {
    ["Drug House"] = {
        id=5, x=321.4866, y=1121.5527, radius=60,
        min_z=1073.8828, max_z=1093.8828,
    },
    ["Crack Lab"] = {
        id=5,
        -- One unit of XY margin also includes the known interior entry.
        min_x=2318.0588, max_x=2350.8315, min_y=-1189.2571, max_y=-1170.6425,
        min_z=1022.9766, max_z=1036.9766,
        entrance={id=5,x=2352.2275,y=-1180.7423,radius=5,min_z=1021.9766,max_z=1033.9766},
    },
    ["Drug Factory"] = {
        id=1, min_z=997.9554, max_z=1010.7222,
        polygon={
            {2204.3997,1555.9644}, {2204.3997,1547.3065},
            {2218.9817,1547.3325}, {2224.5552,1554.9347},
            {2225.6265,1573.1626}, {2231.1577,1573.1626},
            {2233.5505,1578.0958}, {2233.5510,1592.4717},
            {2231.1499,1597.7941}, {2226.5596,1621.1069},
            {2195.7124,1627.6812}, {2169.1184,1627.6812},
            {2168.6919,1593.8151}, {2168.7085,1581.6128},
            {2171.2827,1576.2745}, {2195.3899,1576.2628},
            {2214.3999,1579.7954}, {2215.3623,1566.9266},
            {2214.2354,1557.1410}, {2204.3997,1555.9750},
        },
    },
}

local function in_polygon(x, y, vertices)
    local inside = false
    local previous = vertices[#vertices]
    for _, vertex in ipairs(vertices) do
        local ax, ay = previous[1], previous[2]
        local bx, by = vertex[1], vertex[2]
        local dx, dy = bx - ax, by - ay
        -- Include corners and edges to account for saved coordinate rounding.
        local epsilon = 0.005
        if x >= math.min(ax, bx) - epsilon and x <= math.max(ax, bx) + epsilon
            and y >= math.min(ay, by) - epsilon and y <= math.max(ay, by) + epsilon
            and math.abs(dx * (y - ay) - dy * (x - ax)) <= epsilon * (math.abs(dx) + math.abs(dy)) then
            return true
        end
        if (ay > y) ~= (by > y) and x < ax + dx * (y - ay) / dy then
            inside = not inside
        end
        previous = vertex
    end
    return inside
end

local function in_interior(x, y, z, id, shape)
    if not shape or shape.id ~= id or z < shape.min_z or z > shape.max_z then return false end
    if shape.radius then
        local dx, dy = x - shape.x, y - shape.y
        return dx * dx + dy * dy <= shape.radius * shape.radius
    end
    if shape.polygon then return in_polygon(x, y, shape.polygon) end
    return Rules.in_box(x, y, shape)
end

function locations.find(x, y, z, interior, point_only)
    for _, location in ipairs(locations) do
        if not point_only or location.point then
            if interior == 0 and Rules.in_box(x, y, location) then return location end
            local shape=interiors[location.name]
            if shape and (in_interior(x,y,z,interior,shape) or in_interior(x,y,z,interior,shape.entrance)) then
                return location
            end
        end
    end
end

function locations.has_interior(name)
    return interiors[name]~=nil
end

return locations
