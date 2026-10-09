if ModPath and not rawget(_G, "HVTFPSCapShared") then
    pcall(dofile, ModPath .. "lua/fps_cap_shared.lua")
end

local FPSCap = rawget(_G, "HVTFPSCapShared")
local fps_limit = 15

if FPSCap and type(FPSCap.ApplyLimit) == "function" then
    FPSCap:ApplyLimit(fps_limit)
end
