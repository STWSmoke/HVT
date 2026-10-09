if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and type(Shared.Load) == "function" then
    Shared:Load()
end

_G._hitbox_drawing_enabled = not _G._hitbox_drawing_enabled
_G._hitbox_mask = World:make_slot_mask(1, 14, 25, 39)

if Shared and type(Shared.GetDrawPenColor) == "function" then
    _G._hitbox_pen = Draw:pen(Shared:GetDrawPenColor())
else
    _G._hitbox_pen = Draw:pen(Color(1, 1, 1, 0.4))
end

Hooks:PostHook(GameSetup, "update", "update_test", function()
    local cam = managers.viewport:get_current_camera()
    if not _G._hitbox_drawing_enabled or not alive(cam) then
        return
    end

    for _, body in ipairs(World:find_bodies("intersect", "sphere", cam:position(), 1000, _G._hitbox_mask)) do
        _G._hitbox_pen:body(body)
    end
end)

managers.chat:_receive_message(
    1,
    "SYSTEM",
    Shared and type(Shared.Text) == "function"
        and Shared:Text(_G._hitbox_drawing_enabled and "hvt_hitbox_drawing_enabled" or "hvt_hitbox_drawing_disabled")
        or "",
    tweak_data.system_chat_color
)
