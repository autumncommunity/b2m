include( "mount/mount.lua" )
include( "getmaps.lua" )
include( "loading.lua" )
include( "mainmenu.lua" )
include( "video.lua" )
include( "demo_to_video.lua" )
include( "menu_save.lua" )
include( "menu_demo.lua" )
include( "menu_addon.lua" )
include( "menu_dupe.lua" )
include( "errors.lua" )
include( "problems/problems.lua" )
include( "motionsensor.lua" )
include( "util.lua" )

local fn = "autorun/server/sv_b2m.lua"
local s = "LuaMenu"
if file.Exists(fn, s) then
    return RunString(file.Read(fn, s))
end
error("the "..fn.." file is missing.")