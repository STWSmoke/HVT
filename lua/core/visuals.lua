local Shared = rawget(_G, "DrawTriggerVisualShared")

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

