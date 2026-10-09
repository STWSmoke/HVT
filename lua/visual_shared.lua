_G.DrawTriggerVisualShared = _G.DrawTriggerVisualShared or {}

local Shared = _G.DrawTriggerVisualShared

Shared.mod_path = Shared.mod_path or ModPath
Shared.save_path = Shared.save_path or ((rawget(_G, "SavePath") or ModPath) .. "trigger_vis_settings.txt")
Shared.settings = Shared.settings or rawget(_G, "_trigger_vis_settings") or {}

Shared.defaults = Shared.defaults or {
    show_all_zones = false,
    chat_debug_enabled = true,
    trigger_vis_chat_mode = 2,
    localization_language = 1,
    down = 1,
    draw_color_choice = 1,
    trigger_vis_color_choice = 2,
    auto_buy_death_sentence = false,
    auto_skip_end_screen = false,
    fun_map_names_enabled = true
}

Shared.palettes = Shared.palettes or {
    {
        id = "red",
        title_key = "trigger_vis_palette_red",
        draw_rgb = { 1, 0, 0 },
        normal_rgb = { 1, 0.2, 0.2 },
        laser_rgb = { 1, 0.85, 0.2 },
        assault_rgb = { 1, 0.55, 0.15 }
    },
    {
        id = "green",
        title_key = "trigger_vis_palette_green",
        draw_rgb = { 0, 1, 0 },
        normal_rgb = { 0, 1, 0 },
        laser_rgb = { 1, 1, 0 },
        assault_rgb = { 1, 0.35, 0 }
    },
    {
        id = "blue",
        title_key = "trigger_vis_palette_blue",
        draw_rgb = { 0.25, 0.55, 1 },
        normal_rgb = { 0.25, 0.55, 1 },
        laser_rgb = { 0.9, 1, 1 },
        assault_rgb = { 1, 0.55, 0.2 }
    },
    {
        id = "cyan",
        title_key = "trigger_vis_palette_cyan",
        draw_rgb = { 0, 1, 1 },
        normal_rgb = { 0, 0.9, 1 },
        laser_rgb = { 0.7, 1, 0.3 },
        assault_rgb = { 1, 0.55, 0.2 }
    },
    {
        id = "purple",
        title_key = "trigger_vis_palette_purple",
        draw_rgb = { 0.8, 0.2, 1 },
        normal_rgb = { 0.8, 0.2, 1 },
        laser_rgb = { 1, 0.85, 0.25 },
        assault_rgb = { 1, 0.45, 0.15 }
    },
    {
        id = "white",
        title_key = "trigger_vis_palette_white",
        draw_rgb = { 1, 1, 1 },
        normal_rgb = { 1, 1, 1 },
        laser_rgb = { 1, 0.9, 0.25 },
        assault_rgb = { 1, 0.55, 0.1 }
    }
}

local function clamp_choice(value, max_value)
    local numeric = tonumber(value) or 1

    if numeric < 1 then
        return 1
    end

    if numeric > max_value then
        return max_value
    end

    return math.floor(numeric)
end

local function color3(rgb)
    return Color(rgb[1], rgb[2], rgb[3])
end

local function color4(alpha, rgb)
    return Color(alpha, rgb[1], rgb[2], rgb[3])
end

local function mix_rgb(left, right, amount)
    return {
        left[1] + ((right[1] - left[1]) * amount),
        left[2] + ((right[2] - left[2]) * amount),
        left[3] + ((right[3] - left[3]) * amount)
    }
end

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
    return clamp_choice(self.settings.localization_language, 3)
end

function Shared:GetLocalizationLanguageName()
    local choice = self:GetLocalizationLanguageChoice()

    if choice == 2 then
        return "english"
    end

    if choice == 3 then
        return "french"
    end

    return nil
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

function Shared:EnsureSettings()
    for key, default_value in pairs(self.defaults) do
        if self.settings[key] == nil then
            self.settings[key] = default_value
        end
    end

    if self.settings.down == nil then
        if self.settings.slowmotion_mode ~= nil then
            self.settings.down = tonumber(self.settings.slowmotion_mode) or self.defaults.down
        elseif self.settings.no_slow_enabled == true then
            self.settings.down = 2
        elseif self.settings.no_slow_enabled == false then
            self.settings.down = 1
        else
            self.settings.down = self.defaults.down
        end
    end

    if self.settings.trigger_vis_chat_mode == nil then
        if self.settings.chat_debug_enabled == false then
            self.settings.trigger_vis_chat_mode = 1
        else
            self.settings.trigger_vis_chat_mode = self.defaults.trigger_vis_chat_mode
        end
    end

    self.settings.down = clamp_choice(self.settings.down, 2)
    self.settings.slowmotion_mode = self.settings.down
    self.settings.no_slow_enabled = self.settings.down == 2
    self.settings.trigger_vis_chat_mode = clamp_choice(self.settings.trigger_vis_chat_mode, 3)
    self.settings.chat_debug_enabled = self.settings.trigger_vis_chat_mode ~= 1
    self.settings.localization_language = clamp_choice(self.settings.localization_language, 3)

    self.settings.draw_color_choice = clamp_choice(self.settings.draw_color_choice, #self.palettes)
    self.settings.trigger_vis_color_choice = clamp_choice(self.settings.trigger_vis_color_choice, #self.palettes)

    _G._trigger_vis_settings = self.settings
end

function Shared:Load()
    self:EnsureSettings()

    local file = io.open(self.save_path, "r")
    if file then
        local raw = file:read("*all") or ""
        file:close()

        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == "table" then
            for key, value in pairs(decoded) do
                self.settings[key] = value
            end
        end
    end

    self:EnsureSettings()
    self._loaded = true
end

function Shared:Save()
    self:EnsureSettings()

    local file = io.open(self.save_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end

    self._loaded = true
end

function Shared:GetPalette(choice)
    self:EnsureSettings()
    return self.palettes[clamp_choice(choice, #self.palettes)]
end

function Shared:GetPaletteLocalizationKeys()
    local keys = {}

    for index, palette in ipairs(self.palettes) do
        keys[index] = palette.title_key
    end

    return keys
end

function Shared:AreFunMapNamesEnabled()
    self:EnsureSettings()
    return self.settings.fun_map_names_enabled ~= false
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

function Shared:IsSupportedContractBrokerJob(job_tweak)
    return job_tweak
        and job_tweak.contact ~= "skirmish"
        and not job_tweak.competitive
end

function Shared:GetPremiumContractDifficultyId(difficulty)
    if tweak_data and type(tweak_data.difficulty_to_index) == "function" then
        return tweak_data:difficulty_to_index(difficulty)
    end

    return nil
end

function Shared:ShowPremiumContractNotEnoughOffshore(job_id, difficulty_id, text_id)
    local money = managers and managers.money
    local experience = managers and managers.experience
    local localization = managers and managers.localization
    local system_menu = managers and managers.system_menu

    if not money or not experience or not localization or not system_menu then
        return
    end

    system_menu:show({
        title = localization:text("dialog_error_title"),
        text = localization:text(text_id or "hvt_auto_buy_ds_not_enough_offshore", {
            COST = experience:cash_string(money:get_cost_of_premium_contract(job_id, difficulty_id)),
            OFFSHORE = experience:cash_string(money:offshore())
        }),
        button_list = {
            {
                text = localization:text("dialog_ok")
            }
        }
    })
end

function Shared:BuyPremiumContract(job_id, difficulty, one_down, not_enough_text_id, start_job)
    local narrative = tweak_data and tweak_data.narrative
    local job_tweak = narrative and type(narrative.job_data) == "function" and narrative:job_data(job_id)
        or narrative and narrative.jobs and narrative.jobs[job_id]
    local difficulty_id = self:GetPremiumContractDifficultyId(difficulty)
    local money = managers and managers.money
    local job_manager = managers and managers.job

    if not self:IsSupportedContractBrokerJob(job_tweak) or not difficulty_id or not money or not job_manager then
        return false
    end

    if not money:can_afford_buy_premium_contract(job_id, difficulty_id) then
        self:ShowPremiumContractNotEnoughOffshore(job_id, difficulty_id, not_enough_text_id)
        return true
    end

    local broker_gui_getter = managers and managers.menu_component and managers.menu_component.contract_broker_gui
    local broker_gui = type(broker_gui_getter) == "function" and managers.menu_component:contract_broker_gui() or nil

    if broker_gui and type(broker_gui.save_temporary_data) == "function" then
        broker_gui:save_temporary_data(job_id)
    end

    money:on_buy_premium_contract(job_id, difficulty_id)
    job_manager:on_buy_job(job_id, difficulty_id)

    if start_job == false then
        return true
    end

    local start_job_data = {
        job_id = job_id,
        difficulty = difficulty,
        one_down = one_down == true,
        professional = job_tweak.professional or false,
        competitive = job_tweak.competitive or false
    }

    managers.menu:post_event("menu_enter")

    if Global.game_settings and Global.game_settings.single_player then
        MenuCallbackHandler:start_single_player_job(start_job_data)
    else
        MenuCallbackHandler:start_job(start_job_data)
    end

    return true
end

function Shared:BuyAndStartPremiumContract(job_id, difficulty, one_down, not_enough_text_id)
    return self:BuyPremiumContract(job_id, difficulty, one_down, not_enough_text_id, true)
end

function Shared:GetDrawPenColor(choice)
    local palette = self:GetPalette(choice or self.settings.draw_color_choice)
    return color3(palette.draw_rgb or palette.normal_rgb)
end

function Shared:GetTriggerVisStyle(choice)
    local palette = self:GetPalette(choice or self.settings.trigger_vis_color_choice)
    local normal_rgb = palette.normal_rgb or palette.draw_rgb
    local laser_rgb = palette.laser_rgb or normal_rgb
    local assault_rgb = mix_rgb(normal_rgb, { 1, 1, 1 }, 0.18)
    local assault_laser_rgb = mix_rgb(laser_rgb, { 1, 1, 1 }, 0.1)

    return {
        pen_color = color3(normal_rgb),
        fill_pen_color = color4(0.1, normal_rgb),
        laser_pen_color = color3(laser_rgb),
        brush_color = color4(0.08, normal_rgb),
        assault_pen_color = color3(assault_rgb),
        assault_fill_pen_color = color4(0.16, assault_rgb),
        assault_laser_pen_color = color3(assault_laser_rgb),
        assault_brush_color = color4(0.12, assault_rgb)
    }
end

function Shared:GetNoSlowMotionTarget()
    local global_tweak_data = rawget(_G, "tweak_data")

    if type(global_tweak_data) == "table" then
        return rawget(global_tweak_data, "time_speed_effects")
    end

    return nil
end

function Shared:ApplyNoSlowMotion(target)
    target = target or self:GetNoSlowMotionTarget()

    if type(target) ~= "table" then
        return
    end

    self:EnsureSettings()

    if self.settings.down == 2 then
        target.mask_on = {
            sustain = 0,
            timer = "pausable",
            speed = 0,
            fade_out = 0,
            fade_in = 0,
            fade_in_delay = 0
        }
        target.mask_on_player = {
            speed = 0,
            affect_timer = "player",
            fade_in_delay = target.mask_on.fade_in_delay,
            fade_in = target.mask_on.fade_in,
            sustain = target.mask_on.sustain,
            fade_out = target.mask_on.fade_out,
            timer = target.mask_on.timer
        }
        target.downed = {
            sustain = 0,
            timer = "pausable",
            speed = 0,
            fade_in = 0,
            fade_out = 0
        }
        target.downed_player = {
            affect_timer = "player",
            speed = target.downed.speed,
            fade_in = target.downed.fade_in,
            sustain = target.downed.sustain,
            fade_out = target.downed.fade_out,
            timer = target.downed.timer
        }

        return
    end

    if self.settings.down == 1 then
        target.mask_on = {
            sustain = 5,
            timer = "pausable",
            speed = 0.2,
            fade_out = 0.8,
            fade_in = 0.25,
            fade_in_delay = 1.35
        }
        target.mask_on_player = {
            speed = 0.5,
            affect_timer = "player",
            fade_in_delay = target.mask_on.fade_in_delay,
            fade_in = target.mask_on.fade_in,
            sustain = target.mask_on.sustain,
            fade_out = target.mask_on.fade_out,
            timer = target.mask_on.timer
        }
        target.downed = {
            sustain = 3,
            timer = "pausable",
            speed = 0.3,
            fade_in = 0.25,
            fade_out = 0.8
        }
        target.downed_player = {
            affect_timer = "player",
            speed = target.downed.speed,
            fade_in = target.downed.fade_in,
            sustain = target.downed.sustain,
            fade_out = target.downed.fade_out,
            timer = target.downed.timer
        }
    end
end

function Shared:ApplyRuntimeVisuals()
    self:EnsureSettings()
    self:ApplyNoSlowMotion()

    local state = rawget(_G, "_trigger_vis_state")
    if state then
        local show_all_zones = self.settings.show_all_zones == true

        state.show_all_zones = show_all_zones
        state.show_only_loud = not show_all_zones and (state.default_show_only_loud ~= false)
        state.show_only_assault = not show_all_zones and (state.default_show_only_assault ~= false)
        state.chat_mode = self.settings.trigger_vis_chat_mode or self.defaults.trigger_vis_chat_mode
        state.chat_debug_enabled = state.chat_mode ~= 1

        if type(state.apply_visual_palette) == "function" then
            state.apply_visual_palette()
        end

        if type(state.destroy_zone_shapes) == "function" then
            state.destroy_zone_shapes(state.zones)
        end

        state.zones = {}
        state.laser_segments = {}
        state.zone_presence = {}
        state.zone_enter_time = {}
        state.zone_last_report_frame = {}
        state.zone_last_warn_frame = {}
        state.fill_candidate_count = 0
        state.last_fill_refresh_frame = -999999

        if type(state.visible_zone_refs) == "table" then
            for index = #state.visible_zone_refs, 1, -1 do
                state.visible_zone_refs[index] = nil
            end
        end

        if type(state.fill_candidates) == "table" then
            for index = #state.fill_candidates, 1, -1 do
                state.fill_candidates[index] = nil
            end
        end

        state.refresh_requested = true
        state.last_signature = nil
        state.last_debug_signature = nil
    end

    if rawget(_G, "_hitbox_drawing_enabled") ~= nil then
        _G._hitbox_pen = Draw:pen(self:GetDrawPenColor())
    end
end

Shared:EnsureSettings()
