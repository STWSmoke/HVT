if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if not Shared then
    return
end

_G.DrawReworkNoSlowAnnouncement = _G.DrawReworkNoSlowAnnouncement or {
    message_sent = false
}

local Announcement = _G.DrawReworkNoSlowAnnouncement

local function is_in_active_heist()
    local state_filter = BaseNetworkHandler
        and BaseNetworkHandler._gamestate_filter
        and BaseNetworkHandler._gamestate_filter.any_ingame_playing
    local queued_state = game_state_machine and game_state_machine:last_queued_state_name()

    if not (state_filter and queued_state and state_filter[queued_state]) then
        return false
    end

    local player_unit = managers and managers.player and managers.player:player_unit()
    return alive(player_unit)
end

local function get_local_player_name()
    local account = managers and managers.network and managers.network.account

    if account and type(account.username) == "function" then
        local ok, username = pcall(account.username, account)
        if ok and username and username ~= "" then
            return username
        end
    end

    return Shared:Text("hvt_offline")
end

function Announcement:SendToLobby(message)
    local session = managers and managers.network and managers.network:session()
    local local_peer = session and session.local_peer and session:local_peer()

    if session and local_peer and type(session.send_to_peers) == "function" then
        session:send_to_peers("send_chat_message", ChatManager.GAME, message, local_peer:id())
    end

    if managers and managers.chat and tweak_data and tweak_data.system_chat_color then
        managers.chat:_receive_message(1, "SYSTEM", message, tweak_data.system_chat_color)
    end
end

Hooks:PostHook(MenuManager, "update", "DrawRework_NoSlowAnnouncement_Update", function(self, t, dt)
    if is_in_active_heist() then
        if Announcement.message_sent then
            return
        end

        Shared:Load()

        local player_name = get_local_player_name()
        local status_id = (tonumber(Shared.settings.down) or Shared.defaults.down) == 1
            and "hvt_slowmotion_on"
            or "hvt_slowmotion_off"
        local message = Shared:Text("hvt_slowmotion_message", {
            STATUS = Shared:Text(status_id),
            PLAYER = player_name
        })

        -- Announcement:SendToLobby(message)
        Announcement.message_sent = true
    else
        Announcement.message_sent = false
    end
end)
