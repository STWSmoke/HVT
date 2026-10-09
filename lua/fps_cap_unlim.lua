if ModPath and not rawget(_G, "HVTFPSCapShared") then
    pcall(dofile, ModPath .. "lua/fps_cap_shared.lua")
end

local FPSCap = rawget(_G, "HVTFPSCapShared")

if FPSCap and type(FPSCap.SetUnlimited) == "function" then
    FPSCap:SetUnlimited()
end
