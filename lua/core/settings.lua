local Shared = rawget(_G, "DrawTriggerVisualShared")

Shared.defaults = Shared.defaults or {
    show_all_zones = false,
    chat_debug_enabled = true,
    trigger_vis_chat_mode = 2,
    localization_language = 1,
    localization_language_version = 2,
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

Shared.ClampChoice = clamp_choice

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
    self.settings.localization_language = clamp_choice(self.settings.localization_language, 2)

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
            if (tonumber(decoded.localization_language_version) or 0) < 2 then
                local previous_choice = tonumber(decoded.localization_language) or 1
                decoded.localization_language = previous_choice == 3 and 2 or 1
                decoded.localization_language_version = 2
            end

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

