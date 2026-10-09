if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if not Shared then
    return
end

_G.TriggerVisMenu = _G.TriggerVisMenu or {}

local TriggerVisMenu = _G.TriggerVisMenu

TriggerVisMenu.mod_path = ModPath
TriggerVisMenu.settings = Shared.settings
TriggerVisMenu.palette_keys = Shared:GetPaletteLocalizationKeys()

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_TriggerVisMenu", function()
    Shared:Load()

    MenuCallbackHandler.trigger_vis_options_toggle_all_zones = function(this, item)
        Shared.settings.show_all_zones = item:value() == "on"
        Shared:ApplyRuntimeVisuals()
    end

    MenuCallbackHandler.trigger_vis_options_set_chat_mode = function(this, item)
        Shared.settings.trigger_vis_chat_mode = tonumber(item:value()) or Shared.defaults.trigger_vis_chat_mode
        Shared.settings.chat_debug_enabled = Shared.settings.trigger_vis_chat_mode ~= 1
        Shared:ApplyRuntimeVisuals()
    end

    MenuCallbackHandler.trigger_vis_options_set_slowmotion = function(this, item)
        Shared.settings.down = tonumber(item:value()) or Shared.defaults.down
        Shared:ApplyRuntimeVisuals()
    end

    MenuCallbackHandler.hvt_options_set_language = function(this, item)
        local previous_value = Shared.settings.localization_language
        Shared.settings.localization_language = tonumber(item:value()) or Shared.defaults.localization_language
        Shared:Save()

        if previous_value ~= Shared.settings.localization_language then
            Shared:ShowRestartRequiredNotice()
        end
    end

    MenuCallbackHandler.hvt_options_toggle_auto_buy_death_sentence = function(this, item)
        Shared.settings.auto_buy_death_sentence = item:value() == "on"
    end

    MenuCallbackHandler.hvt_options_toggle_auto_skip_end_screen = function(this, item)
        Shared.settings.auto_skip_end_screen = item:value() == "on"
    end

    MenuCallbackHandler.hvt_options_toggle_fun_map_names = function(this, item)
        Shared.settings.fun_map_names_enabled = item:value() == "on"

        if type(rawget(_G, "HVTApplyCarShopNameOverride")) == "function" then
            _G.HVTApplyCarShopNameOverride()
        end

        if type(rawget(_G, "HVTApplyBigBankNameOverride")) == "function" then
            _G.HVTApplyBigBankNameOverride()
        end
    end

    MenuCallbackHandler.trigger_vis_options_set_draw_color = function(this, item)
        Shared.settings.draw_color_choice = tonumber(item:value()) or Shared.defaults.draw_color_choice
        Shared:ApplyRuntimeVisuals()
    end

    MenuCallbackHandler.trigger_vis_options_set_trigger_color = function(this, item)
        Shared.settings.trigger_vis_color_choice = tonumber(item:value()) or Shared.defaults.trigger_vis_color_choice
        Shared:ApplyRuntimeVisuals()
    end

    MenuCallbackHandler.trigger_vis_options_save = function()
        Shared:Save()
    end

    MenuHelper:LoadFromJsonFile(TriggerVisMenu.mod_path .. "options.txt", TriggerVisMenu, Shared.settings)
end)
