local REQUIRED_SCRIPT = RequiredScript

if REQUIRED_SCRIPT ~= "core/lib/managers/mission/coreelementarea"
    or rawget(_G, "HVTFirstWorldBankVentAreaCounterHookLoaded")
    or not Hooks
    or not ElementAreaTrigger then
    return
end

_G.HVTFirstWorldBankVentAreaCounterHookLoaded = true

local AREA_NAME = "area_secure_loot"
local MAX_BAGS = 8
local REQUEST_MESSAGE = "HVT_FWBVentAreaCounter_Request"
local SYNC_MESSAGE = "HVT_FWBVentAreaCounter_Value"
local NETWORK_HOOK_PREFIX = "HVT_FirstWorldBankVentAreaCounter"
local COUNTER_KEY = "HVTFirstWorldBankVentCounter"
local counter = rawget(_G, COUNTER_KEY)

if not counter then
    counter = {
        count = 0,
        last_announced_count = nil,
        area_element = nil
    }

    rawset(_G, COUNTER_KEY, counter)
end

local function editor_name(element)
    if not element then
        return nil
    end

    if type(element.editor_name) == "function" then
        local ok, name = pcall(element.editor_name, element)

        if ok and name ~= nil then
            return tostring(name)
        end
    end

    return element._editor_name and tostring(element._editor_name) or nil
end

local function localize_count(count)
    local message = "Bags sent through the vent: " .. tostring(count) .. "/" .. tostring(MAX_BAGS)
    local localization = managers and managers.localization

    if localization and type(localization.text) == "function" then
        local ok, localized_message = pcall(localization.text, localization, "hvt_first_world_bank_vent_count", {
            COUNT = count
        })

        if ok and type(localized_message) == "string" then
            message = localized_message
        end
    end

    return message
end

local function show_count(count)
    local chat = managers and managers.chat
    local chat_color = tweak_data and tweak_data.system_chat_color

    if not chat or not chat_color or type(chat._receive_message) ~= "function"
        or counter.last_announced_count == count then
        return
    end

    chat:_receive_message(1, "SYSTEM", localize_count(count), chat_color)
    counter.last_announced_count = count
end

local function get_networking()
    local networking = rawget(_G, "LuaNetworking")

    if networking and type(networking.IsMultiplayer) == "function" and networking:IsMultiplayer() then
        return networking
    end
end

local function send_counter_value(peer_id, count)
    local networking = get_networking()

    if networking and type(networking.SendToPeer) == "function" then
        networking:SendToPeer(peer_id, SYNC_MESSAGE, tostring(count))
    end
end

local function broadcast_counter_value(count)
    local networking = get_networking()

    if networking and type(networking.IsHost) == "function" and networking:IsHost()
        and type(networking.SendToPeers) == "function" then
        networking:SendToPeers(SYNC_MESSAGE, tostring(count))
    end
end

local function request_counter_value()
    local networking = get_networking()
    local session = managers and managers.network and managers.network:session()
    local host_peer = session and type(session.server_peer) == "function" and session:server_peer()

    if networking and type(networking.IsHost) == "function" and not networking:IsHost()
        and host_peer and type(host_peer.id) == "function" and type(networking.SendToPeer) == "function" then
        networking:SendToPeer(host_peer:id(), REQUEST_MESSAGE, "current")
    end
end

local function set_count(count, broadcast)
    count = math.max(0, math.min(MAX_BAGS, tonumber(count) or 0))

    if counter.count == count then
        return
    end

    counter.count = count
    show_count(count)

    if broadcast then
        broadcast_counter_value(count)
    end
end

Hooks:PostHook(ElementAreaTrigger, "on_script_activated", "HVT_FirstWorldBankVentAreaCounter_Register", function(element)
    if editor_name(element) ~= AREA_NAME then
        return
    end

    counter.area_element = element
    counter.count = 0
    counter.last_announced_count = nil

    local is_client = Network and type(Network.is_client) == "function" and Network:is_client()

    if not is_client then
        show_count(0)
    end

    request_counter_value()
end)

Hooks:PostHook(ElementAreaTrigger, "on_executed", "HVT_FirstWorldBankVentAreaCounter_Count", function(element)
    if editor_name(element) ~= AREA_NAME then
        return
    end

    if Network and type(Network.is_client) == "function" and Network:is_client() then
        return
    end

    if counter.count >= MAX_BAGS then
        return
    end

    set_count(counter.count + 1, true)
end)

local networking = rawget(_G, "LuaNetworking")

if networking and type(networking.AddReceiveHook) == "function" then
    networking:AddReceiveHook(REQUEST_MESSAGE, NETWORK_HOOK_PREFIX .. "_Request", function(_, sender_peer_id)
        if not networking:IsHost() then
            return
        end

        local session = managers and managers.network and managers.network:session()
        local peer = session and type(session.peer) == "function" and session:peer(sender_peer_id)

        if peer and editor_name(counter.area_element) == AREA_NAME then
            send_counter_value(sender_peer_id, counter.count)
        end
    end)

    networking:AddReceiveHook(SYNC_MESSAGE, NETWORK_HOOK_PREFIX .. "_Sync", function(data, sender_peer_id)
        if networking:IsHost() then
            return
        end

        local session = managers and managers.network and managers.network:session()
        local host_peer = session and type(session.server_peer) == "function" and session:server_peer()
        local count = tonumber(data)

        if not host_peer or type(host_peer.id) ~= "function" or sender_peer_id ~= host_peer:id()
            or not count or count < 0 then
            return
        end

        counter.count = math.min(MAX_BAGS, count)
        show_count(counter.count)
    end)
end
