-- Module: F:\2025\EDrive\dev\luapack\src\core\Colors.lua

local function to_signed(hex)
    if hex >= 0x80000000 then
        return hex - 0x100000000
    end
    return hex
end

local Colors          = {}

Colors.ALLDEPT        = to_signed(0xFF8282AA)
Colors.DBLUE          = to_signed(0x2641FEAA)
Colors.TEAM_BLUE      = to_signed(0x2641FE00)
Colors.TEAM_MED_COLOR = to_signed(0xFF828200)
Colors.DEPTRADIO      = to_signed(0xFFD7004A)
Colors.RADIO          = to_signed(0x8D8DFFFF)
Colors.FREQUENCY      = to_signed(0x6DFB6DFF)
Colors.NEWS           = to_signed(0xFFA500AA)

Colors.WHITE          = to_signed(0xFFFFFFAA)
Colors.GREY           = to_signed(0xAFAFAFAA)
Colors.GRAD1          = to_signed(0xB4B5B7FF)
Colors.GRAD2          = to_signed(0xBFC0C2FF)
Colors.ORANGE         = to_signed(0xFF8000FF)
Colors.LIGHTBLUE      = to_signed(0x33CCFFAA)
Colors.YELLOW         = to_signed(0xFFFF00AA)
Colors.YELLOW2        = to_signed(0xE8E82EFF)
Colors.LIGHTRED       = to_signed(0xFF6347AA)
Colors.GREEN          = to_signed(0x049C71AA)

return Colors
