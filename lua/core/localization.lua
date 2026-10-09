local Shared = rawget(_G, "DrawTriggerVisualShared")

local function clone_value(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, nested_value in pairs(value) do
        copy[key] = clone_value(nested_value)
    end

    return copy
end

function Shared:GetLocalization()
    local localization = managers and managers.localization

    if type(localization) == "table" and type(localization.text) == "function" then
        return localization
    end

    return nil
end

function Shared:Text(string_id, macros)
    local localization = self:GetLocalization()

    if localization then
        local ok, text = pcall(localization.text, localization, string_id, macros)

        if ok and type(text) == "string" then
            return text
        end
    end

    return tostring(string_id or "")
end

function Shared:UpperText(string_id, macros)
    local text = self:Text(string_id, macros)

    if utf8 and type(utf8.to_upper) == "function" then
        return utf8.to_upper(text)
    end

    return string.upper(text)
end

function Shared:GetLocalizationLanguageChoice()
    self:EnsureSettings()
    return self.ClampChoice(self.settings.localization_language, 2)
end

function Shared:GetLocalizationLanguageName()
    local choice = self:GetLocalizationLanguageChoice()

    if choice == 2 then
        return "french"
    end

    return "english"
end

function Shared:ShowRestartRequiredNotice()
    local localization = managers and managers.localization
    local system_menu = managers and managers.system_menu
    local chat = managers and managers.chat
    local chat_color = tweak_data and tweak_data.system_chat_color

    if system_menu and localization and type(system_menu.show) == "function" then
        system_menu:show({
            title = self:Text("hvt_language_restart_title"),
            text = self:Text("hvt_language_restart_desc"),
            button_list = {
                {
                    text = localization:text("dialog_ok")
                }
            }
        })

        return true
    end

    if chat and chat_color then
        chat:_receive_message(1, "SYSTEM", self:Text("hvt_language_restart_desc"), chat_color)
        return true
    end

    return false
end

function Shared:ApplyLocalizationMacros(text, macros)
    if type(text) ~= "string" or type(macros) ~= "table" then
        return text
    end

    for key, value in pairs(macros) do
        text = text:gsub("%$" .. tostring(key), tostring(value))
    end

    return text
end

function Shared:GetCustomLocalizationOverride(string_id)
    if type(string_id) ~= "string" then
        return nil
    end

    local registry = self._custom_localization_override_registry

    if type(registry) ~= "table" then
        return nil
    end

    for _, override in pairs(registry) do
        if override.enabled ~= false and type(override.entries) == "table" then
            local value = override.entries[string_id]

            if value ~= nil then
                return value
            end
        end
    end

    return nil
end

function Shared:EnsureLocalizationTextHook()
    local localization_class = rawget(_G, "LocalizationManager")

    if type(localization_class) ~= "table" then
        return false
    end

    if localization_class.text == self._localization_text_override_wrapper then
        self._localization_text_hooked = true
        return true
    end

    local current_text = rawget(localization_class, "text")

    if type(current_text) ~= "function" then
        return
    end

    if self._localization_text_hooked and self._original_localization_text then
        localization_class.text = self._localization_text_override_wrapper
        return true
    end

    local shared = self

    self._original_localization_text = current_text
    self._localization_text_override_wrapper = function(localization_self, string_id, macros)
        local override = shared:GetCustomLocalizationOverride(string_id)

        if override ~= nil then
            return shared:ApplyLocalizationMacros(tostring(override), macros)
        end

        return shared._original_localization_text(localization_self, string_id, macros)
    end

    localization_class.text = self._localization_text_override_wrapper
    self._localization_text_hooked = true

    return true
end

function Shared:ApplyCustomLocalizationEntries(owner_id, entries, enabled)
    if type(owner_id) ~= "string" or type(entries) ~= "table" then
        return
    end

    self:EnsureLocalizationTextHook()

    self._custom_localization_override_registry = self._custom_localization_override_registry or {}
    self._custom_localization_override_registry[owner_id] = {
        enabled = enabled ~= false,
        entries = clone_value(entries)
    }
end

