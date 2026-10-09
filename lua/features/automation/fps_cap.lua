local FPS_CAP_BY_KEYBIND = {
    fps_cap_6 = 6,
    fps_cap_10 = 10,
    fps_cap_15 = 15,
    fps_cap_30 = 30,
    fps_cap_45 = 45,
    fps_cap_60 = 60,
    fps_cap_144 = 144,
    fps_cap_unlim = "unlimited"
}

-- The dispatch hook passes the keybind ID through this shared entry point.
local pending_keybind_id = rawget(_G, "HVTFPSCapPendingKeybindId")
if pending_keybind_id then
    rawset(_G, "HVTFPSCapPendingKeybindId", nil)

    local fps_cap = rawget(_G, "HVTFPSCapShared")
    local limit = FPS_CAP_BY_KEYBIND[pending_keybind_id]

    if fps_cap and limit == "unlimited" and type(fps_cap.SetUnlimited) == "function" then
        fps_cap:SetUnlimited()
    elseif fps_cap and type(limit) == "number" and type(fps_cap.ApplyLimit) == "function" then
        fps_cap:ApplyLimit(limit)
    end

    return
end

if rawget(_G, "HVTFPSCapModuleLoaded") then
    return
end

_G.HVTFPSCapModuleLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/core/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and not Shared._loaded then
    Shared:Load()
end

local function is_in_active_heist()
    local state_filter = BaseNetworkHandler
        and BaseNetworkHandler._gamestate_filter
        and BaseNetworkHandler._gamestate_filter.any_ingame_playing
    local queued_state = game_state_machine
        and game_state_machine.last_queued_state_name
        and game_state_machine:last_queued_state_name()

    if not (state_filter and queued_state and state_filter[queued_state]) then
        return false
    end

    local player_unit = managers and managers.player and managers.player:player_unit()

    if type(alive) == "function" then
        return alive(player_unit)
    end

    return player_unit ~= nil
end

local function get_current_cap()
    local user = managers and managers.user

    if not user or type(user.get_setting) ~= "function" then
        return nil
    end

    local ok, value = pcall(user.get_setting, user, "fps_cap")
    if not ok then
        return nil
    end

    return tonumber(value)
end

local function set_current_cap(value)
    local user = managers and managers.user

    if not user or type(user.set_setting) ~= "function" then
        return false
    end

    return pcall(user.set_setting, user, "fps_cap", value)
end

local function send_feedback(message_id, macros)
    local chat = managers and managers.chat
    local chat_color = tweak_data and tweak_data.system_chat_color

    if chat and chat_color then
        local message = Shared and type(Shared.Text) == "function"
            and Shared:Text(message_id, macros)
            or tostring(message_id)
        chat:_receive_message(1, "SYSTEM", message, chat_color)
    end
end

local FPSCap = {}
_G.HVTFPSCapShared = FPSCap

function FPSCap:ApplyLimit(limit)
    limit = tonumber(limit)

    if not limit then
        return
    end

    local current_cap = get_current_cap()

    if is_in_active_heist() then
        if current_cap == limit then
            if set_current_cap(0) then
                send_feedback("hvt_fps_limit_removed")
            end
        elseif set_current_cap(limit) then
            send_feedback("hvt_fps_limit_set", { VALUE = tostring(limit) })
        end

        return
    end

    if current_cap ~= 0 and set_current_cap(0) then
        send_feedback("hvt_fps_limit_removed")
    end
end

function FPSCap:SetUnlimited()
    if set_current_cap(0) then
        send_feedback("hvt_fps_limit_set_unlimited")
    end
end

function FPSCap:IsInActiveHeist()
    return is_in_active_heist()
end

local limits = {
    3, 6, 8, 9, 10, 15,
    30, 45, 60, 75, 90, 105, 120, 135,
    150, 175, 200, 225, 250, 275, 300
}

if not rawget(_G, "FPSCap_MenuManager_Hooked")
    and MenuOptionInitiator
    and type(MenuOptionInitiator.modify_adv_video) == "function" then
    _G.FPSCap_MenuManager_Hooked = true

    local modify_adv_video_actual = MenuOptionInitiator.modify_adv_video

    function MenuOptionInitiator:modify_adv_video(node, ...)
        local fpslimit = node:item("choose_fps_cap")
        if fpslimit then
            fpslimit:clear_options()

            for _, limit in ipairs(limits) do
                fpslimit:add_option(CoreMenuItemOption.ItemOption:new({
                    _meta = "option",
                    text_id = tostring(limit),
                    value = limit,
                    localize = false
                }))
            end

            fpslimit:_show_options(nil)
        end

        return modify_adv_video_actual(self, node, ...)
    end
end

if Hooks and BLTKeybind and type(BLTKeybind.Execute) == "function" then
    Hooks:PreHook(BLTKeybind, "Execute", "HVT_FPSCap_KeybindDispatch", function(keybind)
        local keybind_id = keybind and type(keybind.Id) == "function" and keybind:Id()

        if keybind_id and FPS_CAP_BY_KEYBIND[keybind_id] ~= nil then
            rawset(_G, "HVTFPSCapPendingKeybindId", keybind_id)
        end
    end)
end
