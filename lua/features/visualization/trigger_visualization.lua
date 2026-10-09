if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/core/visual_shared.lua")
end

local STATE_VERSION = 21
local visual_shared = rawget(_G, "DrawTriggerVisualShared")
local state = rawget(_G, "_trigger_vis_state")
local shared_settings = visual_shared and visual_shared.settings or rawget(_G, "_trigger_vis_settings")

if type(shared_settings) ~= "table" then
    shared_settings = {}
    _G._trigger_vis_settings = shared_settings
end

local function L(string_id, macros)
    if visual_shared and type(visual_shared.Text) == "function" then
        return visual_shared:Text(string_id, macros)
    end

    return tostring(string_id or "")
end

if visual_shared and type(visual_shared.Load) == "function" then
    visual_shared:Load()
    shared_settings = visual_shared.settings
else
    if shared_settings.show_all_zones == nil then
        shared_settings.show_all_zones = false
    end

    if shared_settings.trigger_vis_chat_mode == nil then
        if shared_settings.chat_debug_enabled == false then
            shared_settings.trigger_vis_chat_mode = 1
        else
            shared_settings.trigger_vis_chat_mode = 2
        end
    end

    if shared_settings.chat_debug_enabled == nil then
        shared_settings.chat_debug_enabled = shared_settings.trigger_vis_chat_mode ~= 1
    end

    if shared_settings.trigger_vis_color_choice == nil then
        shared_settings.trigger_vis_color_choice = 2
    end
end

if state and state.version ~= STATE_VERSION then
    _G._trigger_vis_state = nil
    state = nil
end

if not state then
    state = {
        version = STATE_VERSION,
        enabled = false,
        zones = {},
        distance = 8000,
        fill_distance = 1800,
        box_wall_distance = 4200,
        refresh_requested = true,
        last_level_id = nil,
        last_signature = nil,
        last_debug_signature = nil,
        debug_dump_limit = 18,
        max_dimension = 100000,
        max_fill_dimension = 6000,
        box_fill_step = 180,
        box_wall_step = 130,
        box_fill_radius = 60,
        box_fill_max_points = 96,
        box_wall_max_lines = 160,
        max_filled_zones = 4,
        fill_refresh_interval_frames = 6,
        box_wall_mid_distance = 2400,
        box_wall_far_distance = 3400,
        box_wall_mid_stride = 2,
        box_wall_far_stride = 4,
        show_all_zones = shared_settings.show_all_zones == true,
        default_show_only_loud = true,
        default_show_only_assault = true,
        show_only_loud = shared_settings.show_all_zones ~= true,
        show_only_assault = shared_settings.show_all_zones ~= true,
        assault_explicit_only = true,
        loud_min_score = 10,
        loud_graph_depth = 12,
        loud_graph_limit = 512,
        use_core_shape_render = false,
        debug_on_enter = true,
        chat_mode = tonumber(shared_settings.trigger_vis_chat_mode) or 2,
        chat_debug_enabled = shared_settings.chat_debug_enabled ~= false,
        debug_enter_cooldown_frames = 90,
        zone_presence = {},
        zone_enter_time = {},
        zone_last_report_frame = {},
        zone_last_warn_frame = {},
        laser_segments = {},
        frame_index = 0,
        pen = Draw:pen(Color(0, 1, 0)),
        fill_pen = Draw:pen(Color(0.1, 0, 1, 0)),
        laser_pen = Draw:pen(Color(1, 1, 0)),
        brush = Draw:brush(Color(0.08, 0, 1, 0)),
        assault_pen = Draw:pen(Color(1, 0.35, 0)),
        assault_fill_pen = Draw:pen(Color(0.16, 1, 0.35, 0)),
        assault_laser_pen = Draw:pen(Color(1, 0.6, 0)),
        assault_brush = Draw:brush(Color(0.12, 1, 0.35, 0))
    }

    _G._trigger_vis_state = state

    if type(core) == "table" and type(core.import) == "function" then
        pcall(function()
            core:import("CoreShapeManager")
        end)
    end

    state.use_core_shape_render = type(CoreShapeManager) == "table"
        and type(CoreShapeManager.ShapeBoxMiddle) == "table"
        and type(CoreShapeManager.ShapeCylinderMiddle) == "table"
        and type(CoreShapeManager.ShapeSphere) == "table"

    local BOX_EDGE_INDICES = {
        { 1, 2 }, { 1, 3 }, { 1, 5 },
        { 2, 4 }, { 2, 6 },
        { 3, 4 }, { 3, 7 },
        { 4, 8 },
        { 5, 6 }, { 5, 7 },
        { 6, 8 },
        { 7, 8 }
    }

    local GRAPH_LINK_KEYS = {
        elements = true,
        element = true,
        element_id = true,
        element_ids = true,
        targets = true,
        target = true,
        target_id = true,
        target_ids = true,
        execute_id = true,
        execute_ids = true,
        on_executed = true,
        onexecuted = true
    }
    local GRAPH_LINK_KEYWORDS = {
        "element",
        "target",
        "execute",
        "operator",
        "instigator",
        "trigger"
    }
    local SEARCH_TEXT_VALUE_KEYS = {
        operation = true,
        state = true,
        mode = true,
        event = true,
        preset = true,
        enemy = true,
        team = true,
        sequence = true,
        sound_event = true,
        music_event = true,
        track = true,
        task = true,
        trigger_type = true,
        spawn_action = true,
        whisper_mode = true,
        enabled = true,
        set_enabled = true
    }
    local SEARCH_TEXT_KEYWORDS = {
        "alarm",
        "assault",
        "enemy",
        "spawn",
        "music",
        "police",
        "reinforce",
        "reenforce"
    }
    local KEYWORDS_DISABLED_STATES = {
        "false",
        "disabled",
        "disable",
        "off"
    }
    local KEYWORDS_ENEMY_SPAWN = {
        "spawn enemy group",
        "spawnenemygroup",
        "spawn_enemy_group",
        "spawn enemy dummy",
        "spawnenemydummy",
        "spawn_enemy_dummy"
    }
    local KEYWORDS_STEALTH_STATE = {
        "whisperstate",
        "whisper_state",
        "whisper mode"
    }
    local KEYWORDS_ALARM = {
        "alarm",
        "raise_alarm",
        "trip_alarm",
        "sound_alarm",
        "alarm_pager"
    }
    local KEYWORDS_POLICE_RESPONSE = {
        "on_police_called",
        "police_called",
        "on enemy weapons hot",
        "enemy weapons hot",
        "on_police_weapons_hot",
        "police_weapons_hot",
        "call the police",
        "weapons_hot"
    }
    local KEYWORDS_ASSAULT_STATE = {
        "assault",
        "anticipation",
        "combat",
        "point_of_no_return",
        "ponr"
    }
    local KEYWORDS_COMBAT_LOGIC = {
        "reinforce",
        "reenforce",
        "reinforcement",
        "wave",
        "hunt",
        "groupai",
        "group ai",
        "ai_group"
    }
    local KEYWORDS_MUSIC_STATE = {
        "assault",
        "anticipation",
        "control",
        "alarm",
        "combat"
    }
    local KEYWORDS_EXPLICIT_ASSAULT = {
        "start_assault",
        "start assault",
        "begin_assault",
        "begin assault",
        "start_anticipation",
        "start anticipation",
        "anticipation_start",
        "introduce_assault",
        "police_called",
        "on_police_called",
        "police called",
        "enemy weapons hot",
        "on enemy weapons hot",
        "weapons_hot",
        "police_weapons_hot",
        "on_police_weapons_hot",
        "point_of_no_return",
        "ponr"
    }
    local KEYWORDS_EXPLICIT_HARD_TRANSITION = {
        "police_called",
        "on_police_called",
        "police called",
        "enemy weapons hot",
        "on enemy weapons hot",
        "weapons_hot",
        "police_weapons_hot",
        "on_police_weapons_hot",
        "point_of_no_return",
        "ponr"
    }
    local KEYWORDS_NAMED_ASSAULT_STAGE = {
        "introduce_assault",
        "assault_in_",
        "_assault",
        "assault_",
        "_anticipation",
        "anticipation_",
        "point_of_no_return",
        "ponr"
    }
    local KEYWORDS_ASSAULT_ACTION = {
        "start",
        "begin",
        "introduce",
        "trigger",
        "launch",
        "enable",
        "set",
        "go"
    }
    local KEYWORDS_ASSAULT_START_IDENTITY = {
        "assault",
        "anticipation"
    }
    local KEYWORDS_LOGIC_IDENTITY = {
        "logic_filter",
        "logic chance",
        "logic_chance",
        "logicchance",
        "counter",
        "random",
        "operator",
        "instigator",
        "rule"
    }
    local KEYWORDS_MUSIC_IDENTITY = {
        "music",
        "track",
        "control_music",
        "music_event",
        "sound_event"
    }

    -- Chat reporting and display state
    local function push_chat(prefix, message)
        if managers and managers.chat and tweak_data and tweak_data.system_chat_color then
            managers.chat:_receive_message(1, prefix, message, tweak_data.system_chat_color)
        end
    end

    local function get_chat_mode()
        local mode = tonumber(state.chat_mode)

        if mode == nil then
            mode = state.chat_debug_enabled == false and 1 or 2
        end

        if mode < 1 then
            return 1
        end

        if mode > 3 then
            return 3
        end

        return math.floor(mode)
    end

    local function get_chat_mode_label(mode)
        mode = tonumber(mode) or get_chat_mode()

        if mode <= 1 then
            return L("hvt_trigger_vis_chat_off")
        end

        if mode == 2 then
            return L("hvt_trigger_vis_chat_useful")
        end

        return L("hvt_trigger_vis_chat_verbose")
    end

    local function chat_mode_enabled(required_mode)
        return get_chat_mode() >= (required_mode or 2)
    end

    local function push_debug_chat(prefix, message, required_mode)
        if not chat_mode_enabled(required_mode) then
            return
        end

        push_chat(prefix, message)
    end

    local function current_runtime_time()
        if TimerManager and type(TimerManager.game) == "function" then
            local ok, timer = pcall(function()
                return TimerManager:game()
            end)

            if ok and timer and type(timer.time) == "function" then
                local ok_time, value = pcall(function()
                    return timer:time()
                end)

                if ok_time and type(value) == "number" then
                    return value
                end
            end
        end

        if Application and type(Application.time) == "function" then
            local ok, value = pcall(Application.time)

            if ok and type(value) == "number" then
                return value
            end
        end

        return (state.frame_index or 0) / 30
    end

    local function has_method(object, method_name)
        local ok, member = pcall(function()
            return object and object[method_name]
        end)

        return ok and type(member) == "function"
    end

    local function get_trigger_vis_style()
        if visual_shared and type(visual_shared.GetTriggerVisStyle) == "function" then
            return visual_shared:GetTriggerVisStyle(shared_settings.trigger_vis_color_choice)
        end

        return {
            pen_color = Color(0, 1, 0),
            fill_pen_color = Color(0.1, 0, 1, 0),
            laser_pen_color = Color(1, 1, 0),
            brush_color = Color(0.08, 0, 1, 0),
            assault_pen_color = Color(1, 0.35, 0),
            assault_fill_pen_color = Color(0.16, 1, 0.35, 0),
            assault_laser_pen_color = Color(1, 0.6, 0),
            assault_brush_color = Color(0.12, 1, 0.35, 0)
        }
    end

    local function refresh_state_draw_tools()
        state.pen_has_box = has_method(state.pen, "box")
        state.pen_has_line = has_method(state.pen, "line")
        state.pen_has_sphere = has_method(state.pen, "sphere")
        state.pen_has_cylinder = has_method(state.pen, "cylinder")
        state.fill_pen_has_line = has_method(state.fill_pen, "line")
        state.brush_has_sphere = has_method(state.brush, "sphere")
        state.brush_has_cylinder = has_method(state.brush, "cylinder")
        state.laser_pen_has_line = has_method(state.laser_pen, "line")
        state.laser_pen_has_sphere = has_method(state.laser_pen, "sphere")
        state.assault_pen_has_box = has_method(state.assault_pen, "box")
        state.assault_pen_has_line = has_method(state.assault_pen, "line")
        state.assault_pen_has_sphere = has_method(state.assault_pen, "sphere")
        state.assault_pen_has_cylinder = has_method(state.assault_pen, "cylinder")
        state.assault_fill_pen_has_line = has_method(state.assault_fill_pen, "line")
        state.assault_brush_has_sphere = has_method(state.assault_brush, "sphere")
        state.assault_brush_has_cylinder = has_method(state.assault_brush, "cylinder")
        state.assault_laser_pen_has_line = has_method(state.assault_laser_pen, "line")
        state.assault_laser_pen_has_sphere = has_method(state.assault_laser_pen, "sphere")
        state.visible_zone_refs = state.visible_zone_refs or {}
        state.fill_candidates = state.fill_candidates or {}
        state.fill_candidate_count = state.fill_candidate_count or 0
        state.last_fill_refresh_frame = state.last_fill_refresh_frame or -999999
        state.normal_zone_draw_tools = {
            pen = state.pen,
            fill_pen = state.fill_pen,
            has_box = state.pen_has_box,
            has_line = state.pen_has_line,
            fill_has_line = state.fill_pen_has_line,
            has_sphere = state.pen_has_sphere,
            has_cylinder = state.pen_has_cylinder,
            brush = state.brush,
            brush_has_sphere = state.brush_has_sphere,
            brush_has_cylinder = state.brush_has_cylinder
        }
        state.assault_zone_draw_tools = {
            pen = state.assault_pen,
            fill_pen = state.assault_fill_pen,
            has_box = state.assault_pen_has_box,
            has_line = state.assault_pen_has_line,
            fill_has_line = state.assault_fill_pen_has_line,
            has_sphere = state.assault_pen_has_sphere,
            has_cylinder = state.assault_pen_has_cylinder,
            brush = state.assault_brush,
            brush_has_sphere = state.assault_brush_has_sphere,
            brush_has_cylinder = state.assault_brush_has_cylinder
        }
        state.normal_laser_draw_tools = {
            pen = state.laser_pen,
            has_line = state.laser_pen_has_line,
            has_sphere = state.laser_pen_has_sphere
        }
        state.assault_laser_draw_tools = {
            pen = state.assault_laser_pen,
            has_line = state.assault_laser_pen_has_line,
            has_sphere = state.assault_laser_pen_has_sphere
        }
    end

    local function apply_visual_palette()
        local style = get_trigger_vis_style()

        state.pen = Draw:pen(style.pen_color)
        state.fill_pen = Draw:pen(style.fill_pen_color)
        state.laser_pen = Draw:pen(style.laser_pen_color)
        state.brush = Draw:brush(style.brush_color)
        state.assault_pen = Draw:pen(style.assault_pen_color)
        state.assault_fill_pen = Draw:pen(style.assault_fill_pen_color)
        state.assault_laser_pen = Draw:pen(style.assault_laser_pen_color)
        state.assault_brush = Draw:brush(style.assault_brush_color)
        state.normal_shape_draw_info = {
            r = style.pen_color.r or 0,
            g = style.pen_color.g or 1,
            b = style.pen_color.b or 0,
            alpha = 0.2
        }
        state.assault_shape_draw_info = {
            r = style.assault_pen_color.r or 1,
            g = style.assault_pen_color.g or 0.35,
            b = style.assault_pen_color.b or 0,
            alpha = 0.24
        }

        refresh_state_draw_tools()
    end

    state.apply_visual_palette = apply_visual_palette

    local function sync_state_settings()
        local show_all_zones = shared_settings.show_all_zones == true

        state.show_all_zones = show_all_zones
        state.show_only_loud = not show_all_zones and (state.default_show_only_loud ~= false)
        state.show_only_assault = not show_all_zones and (state.default_show_only_assault ~= false)
        state.chat_mode = tonumber(shared_settings.trigger_vis_chat_mode) or 2
        state.chat_debug_enabled = state.chat_mode ~= 1
        apply_visual_palette()
    end

    sync_state_settings()

    -- Mission element and geometry helpers
    local function copy_array(list)
        local result = {}

        if type(list) ~= "table" then
            return result
        end

        for index, value in ipairs(list) do
            result[index] = value
        end

        return result
    end

    local function clear_array(list)
        for index = #list, 1, -1 do
            list[index] = nil
        end
    end

    local function first_non_nil(...)
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if value ~= nil then
                return value
            end
        end
    end

    local function lower_text(value)
        if value == nil then
            return ""
        end

        return string.lower(tostring(value))
    end

    local function join_blob(...)
        local parts = {}

        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if value ~= nil and value ~= "" then
                parts[#parts + 1] = lower_text(value)
            end
        end

        return table.concat(parts, " ")
    end

    local function read_element_value(element, ...)
        if not element then
            return nil
        end

        local values = rawget(element, "_values")

        for index = 1, select("#", ...) do
            local key = select(index, ...)

            if values and values[key] ~= nil then
                return values[key]
            end

            local direct = rawget(element, key)
            if direct ~= nil then
                return direct
            end

            if type(element.value) == "function" then
                local ok, result = pcall(element.value, element, key)
                if ok and result ~= nil then
                    return result
                end
            end
        end

        return nil
    end

    local function read_value_with_fallback(primary, fallback, ...)
        return first_non_nil(
            read_element_value(primary, ...),
            read_element_value(fallback, ...)
        )
    end

    local function normalize_number(value)
        if type(value) == "string" then
            value = tonumber(value)
        end

        if type(value) ~= "number" then
            return nil
        end

        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end

        return value
    end

    local function read_yaw_pitch_roll(value)
        if value == nil then
            return nil
        end

        if type(value) == "number" then
            local yaw = normalize_number(value)

            if yaw then
                return yaw, 0, 0
            end

            return nil
        end

        if type(value) == "userdata" then
            local ok_yaw, yaw = pcall(function()
                return value:yaw()
            end)
            local ok_pitch, pitch = pcall(function()
                return value:pitch()
            end)
            local ok_roll, roll = pcall(function()
                return value:roll()
            end)

            yaw = ok_yaw and normalize_number(yaw) or nil
            pitch = ok_pitch and normalize_number(pitch) or nil
            roll = ok_roll and normalize_number(roll) or nil

            if yaw and pitch and roll then
                return yaw, pitch, roll
            end
        end

        if type(value) == "table" then
            local yaw = normalize_number(first_non_nil(value.yaw, value.Yaw, value[1], value.x, value.X))
            local pitch = normalize_number(first_non_nil(value.pitch, value.Pitch, value[2], value.y, value.Y))
            local roll = normalize_number(first_non_nil(value.roll, value.Roll, value[3], value.z, value.Z))

            if yaw and pitch and roll then
                return yaw, pitch, roll
            end
        end

        return nil
    end

    local function sanitize_rotation(value)
        local yaw, pitch, roll = read_yaw_pitch_roll(value)

        if yaw and pitch and roll then
            return Rotation(yaw, pitch, roll)
        end

        return nil
    end

    local function read_number(primary, fallback, ...)
        local value = read_value_with_fallback(primary, fallback, ...)

        return normalize_number(value)
    end

    local function read_xyz(value)
        if value == nil then
            return nil
        end

        if type(value) == "userdata" then
            local x = normalize_number(value.x)
            local y = normalize_number(value.y)
            local z = normalize_number(value.z)

            if x and y and z then
                return x, y, z
            end
        end

        if type(value) == "table" and value.x and value.y and value.z then
            local x = normalize_number(value.x)
            local y = normalize_number(value.y)
            local z = normalize_number(value.z)

            if x and y and z then
                return x, y, z
            end
        end

        return nil
    end

    local function clone_vector3(value)
        local x, y, z = read_xyz(value)
        if x and y and z then
            return Vector3(x, y, z)
        end

        return nil
    end

    local function sanitize_position(value)
        local x, y, z = read_xyz(value)
        if not x or not y or not z then
            return nil
        end

        return Vector3(x, y, z)
    end

    local function sanitize_size(value, max_dimension)
        local x, y, z = read_xyz(value)
        if not x or not y or not z then
            return nil
        end

        x = math.abs(x)
        y = math.abs(y)
        z = math.abs(z)

        if x < 1 or y < 1 or z < 1 then
            return nil
        end

        if x > max_dimension or y > max_dimension or z > max_dimension then
            return nil
        end

        return Vector3(x, y, z)
    end

    local function read_vector3(primary, fallback, ...)
        return sanitize_position(read_value_with_fallback(primary, fallback, ...))
    end

    local function read_draw_rotation(primary, fallback)
        local raw_rotation = read_value_with_fallback(
            primary,
            fallback,
            "rotation",
            "Rotation",
            "rot",
            "Rot"
        )

        return sanitize_rotation(raw_rotation) or Rotation()
    end

    local function rotation_signature(rotation)
        local yaw, pitch, roll = read_yaw_pitch_roll(rotation)

        if not yaw or not pitch or not roll then
            return "0.00:0.00:0.00"
        end

        return string.format("%.2f:%.2f:%.2f", yaw, pitch, roll)
    end

    local function local_to_world_point(position, rotation, point)
        local world_point = Vector3(point.x, point.y, point.z)

        if rotation then
            mvector3.rotate_with(world_point, rotation)
        end

        mvector3.add(world_point, position)

        return world_point
    end

    local function get_inverse_rotation(zone)
        if zone._inverse_rotation then
            return zone._inverse_rotation
        end

        zone._inverse_rotation = mrotation.copy(zone.rotation or Rotation())
        mrotation.invert(zone._inverse_rotation)

        return zone._inverse_rotation
    end

    local function world_to_local_point(zone, point)
        local local_point = Vector3(
            point.x - zone.position.x,
            point.y - zone.position.y,
            point.z - zone.position.z
        )

        mvector3.rotate_with(local_point, get_inverse_rotation(zone))

        return local_point
    end

    local function distance_squared(from, to)
        local dx = from.x - to.x
        local dy = from.y - to.y
        local dz = from.z - to.z

        return (dx * dx) + (dy * dy) + (dz * dz)
    end

    local function can_fill_zone(zone)
        if zone.shape == "box" and zone.size then
            return zone.size.x <= state.max_fill_dimension
                and zone.size.y <= state.max_fill_dimension
                and zone.size.z <= state.max_fill_dimension
        end

        if zone.shape == "sphere" and zone.radius then
            return zone.radius <= state.max_fill_dimension
        end

        if zone.shape == "cylinder" and zone.radius and zone.height then
            return zone.radius <= state.max_fill_dimension
                and zone.height <= state.max_fill_dimension
        end

        return false
    end

    local function build_axis_samples(half_extent, step)
        local samples = {}

        if half_extent <= 0 then
            samples[1] = 0
            return samples
        end

        local count = math.max(1, math.ceil((half_extent * 2) / step))
        local spacing = (half_extent * 2) / count
        local start_value = -half_extent + (spacing * 0.5)

        for index = 0, count - 1 do
            samples[#samples + 1] = start_value + (index * spacing)
        end

        return samples
    end

    local function build_surface_axis_samples(half_extent, step)
        if half_extent <= 0 then
            return { 0 }
        end

        local samples = build_axis_samples(half_extent, step)
        local surface_samples = {}

        surface_samples[1] = -half_extent

        for _, sample in ipairs(samples) do
            if math.abs(sample) < (half_extent - 1) then
                surface_samples[#surface_samples + 1] = sample
            end
        end

        surface_samples[#surface_samples + 1] = half_extent

        return surface_samples
    end

    local function append_unique_point(points, seen, x, y, z)
        local key = string.format(
            "%d:%d:%d",
            math.floor((x * 10) + 0.5),
            math.floor((y * 10) + 0.5),
            math.floor((z * 10) + 0.5)
        )

        if seen[key] then
            return
        end

        seen[key] = true
        points[#points + 1] = Vector3(x, y, z)
    end

    local function append_unique_segment(segments, seen, from_x, from_y, from_z, to_x, to_y, to_z)
        local key = string.format(
            "%d:%d:%d:%d:%d:%d",
            math.floor((from_x * 10) + 0.5),
            math.floor((from_y * 10) + 0.5),
            math.floor((from_z * 10) + 0.5),
            math.floor((to_x * 10) + 0.5),
            math.floor((to_y * 10) + 0.5),
            math.floor((to_z * 10) + 0.5)
        )
        local reverse_key = string.format(
            "%d:%d:%d:%d:%d:%d",
            math.floor((to_x * 10) + 0.5),
            math.floor((to_y * 10) + 0.5),
            math.floor((to_z * 10) + 0.5),
            math.floor((from_x * 10) + 0.5),
            math.floor((from_y * 10) + 0.5),
            math.floor((from_z * 10) + 0.5)
        )

        if seen[key] or seen[reverse_key] then
            return
        end

        seen[key] = true
        segments[#segments + 1] = {
            from = Vector3(from_x, from_y, from_z),
            to = Vector3(to_x, to_y, to_z)
        }
    end

    local function build_box_fill_cache(zone)
        local cache_key = string.format(
            "%.1f:%.1f:%.1f:%s:%.1f:%.1f:%.1f:%d:%d",
            zone.size.x,
            zone.size.y,
            zone.size.z,
            rotation_signature(zone.rotation),
            zone.position.x,
            zone.position.y,
            zone.position.z,
            state.box_fill_step,
            state.box_fill_max_points
        )

        if zone._fill_cache and zone._fill_cache.key == cache_key then
            return zone._fill_cache
        end

        local half_x = zone.size.x * 0.5
        local half_y = zone.size.y * 0.5
        local half_z = zone.size.z * 0.5
        local step = math.max(90, state.box_fill_step)
        local xs = build_surface_axis_samples(half_x, step)
        local ys = build_surface_axis_samples(half_y, step)
        local zs = build_surface_axis_samples(half_z, step)
        local points = {}
        local seen = {}

        for _, x in ipairs({ -half_x, half_x }) do
            for _, y in ipairs(ys) do
                for _, z in ipairs(zs) do
                    append_unique_point(points, seen, x, y, z)
                end
            end
        end

        for _, y in ipairs({ -half_y, half_y }) do
            for _, x in ipairs(xs) do
                for _, z in ipairs(zs) do
                    append_unique_point(points, seen, x, y, z)
                end
            end
        end

        for _, z in ipairs({ -half_z, half_z }) do
            for _, x in ipairs(xs) do
                for _, y in ipairs(ys) do
                    append_unique_point(points, seen, x, y, z)
                end
            end
        end

        if #points > state.box_fill_max_points then
            local reduced = {}
            local stride = math.max(1, math.ceil(#points / state.box_fill_max_points))

            for index = 1, #points, stride do
                reduced[#reduced + 1] = points[index]
            end

            points = reduced
        end

        local world_points = {}

        for _, point in ipairs(points) do
            world_points[#world_points + 1] = local_to_world_point(zone.position, zone.rotation, point)
        end

        zone._fill_cache = {
            key = cache_key,
            points = world_points,
            radius = math.max(
                10,
                math.min(state.box_fill_radius, step * 0.35, half_x, half_y, half_z)
            )
        }

        return zone._fill_cache
    end

    local function build_box_wall_cache(zone)
        local cache_key = string.format(
            "%.1f:%.1f:%.1f:%s:%.1f:%.1f:%.1f:%d:%d",
            zone.size.x,
            zone.size.y,
            zone.size.z,
            rotation_signature(zone.rotation),
            zone.position.x,
            zone.position.y,
            zone.position.z,
            state.box_wall_step,
            state.box_wall_max_lines
        )

        if zone._wall_cache and zone._wall_cache.key == cache_key then
            return zone._wall_cache
        end

        local half_x = zone.size.x * 0.5
        local half_y = zone.size.y * 0.5
        local half_z = zone.size.z * 0.5
        local step = math.max(70, state.box_wall_step or state.box_fill_step)
        local xs = build_surface_axis_samples(half_x, step)
        local ys = build_surface_axis_samples(half_y, step)
        local zs = build_surface_axis_samples(half_z, step)
        local segments = {}
        local seen = {}

        for _, x in ipairs({ -half_x, half_x }) do
            for _, y in ipairs(ys) do
                append_unique_segment(segments, seen, x, y, -half_z, x, y, half_z)
            end

            for _, z in ipairs(zs) do
                append_unique_segment(segments, seen, x, -half_y, z, x, half_y, z)
            end
        end

        for _, y in ipairs({ -half_y, half_y }) do
            for _, x in ipairs(xs) do
                append_unique_segment(segments, seen, x, y, -half_z, x, y, half_z)
            end

            for _, z in ipairs(zs) do
                append_unique_segment(segments, seen, -half_x, y, z, half_x, y, z)
            end
        end

        for _, z in ipairs({ -half_z, half_z }) do
            for _, x in ipairs(xs) do
                append_unique_segment(segments, seen, x, -half_y, z, x, half_y, z)
            end

            for _, y in ipairs(ys) do
                append_unique_segment(segments, seen, -half_x, y, z, half_x, y, z)
            end
        end

        if #segments > state.box_wall_max_lines then
            local reduced = {}
            local stride = math.max(1, math.ceil(#segments / state.box_wall_max_lines))

            for index = 1, #segments, stride do
                reduced[#reduced + 1] = segments[index]
            end

            segments = reduced
        end

        local world_segments = {}

        for _, segment in ipairs(segments) do
            world_segments[#world_segments + 1] = {
                from = local_to_world_point(zone.position, zone.rotation, segment.from),
                to = local_to_world_point(zone.position, zone.rotation, segment.to)
            }
        end

        zone._wall_cache = {
            key = cache_key,
            segments = world_segments
        }

        return zone._wall_cache
    end

    local function fill_box_with_brush(zone, brush, can_draw_sphere)
        if not can_draw_sphere then
            return
        end

        local fill_cache = build_box_fill_cache(zone)

        for _, point in ipairs(fill_cache.points) do
            brush:sphere(point, fill_cache.radius)
        end
    end

    local function build_box_corners(zone)
        local half_x = zone.size.x * 0.5
        local half_y = zone.size.y * 0.5
        local half_z = zone.size.z * 0.5

        return {
            local_to_world_point(zone.position, zone.rotation, Vector3(-half_x, -half_y, -half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(half_x, -half_y, -half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(-half_x, half_y, -half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(half_x, half_y, -half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(-half_x, -half_y, half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(half_x, -half_y, half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(-half_x, half_y, half_z)),
            local_to_world_point(zone.position, zone.rotation, Vector3(half_x, half_y, half_z))
        }
    end

    local function destroy_zone_shape(zone)
        if zone and zone._draw_shape and type(zone._draw_shape.destroy) == "function" then
            pcall(function()
                zone._draw_shape:destroy()
            end)
        end

        if zone then
            zone._draw_shape = nil
            zone._draw_shape_key = nil
            zone._inverse_rotation = nil
        end
    end

    local function destroy_zone_shapes(zones)
        if type(zones) ~= "table" then
            return
        end

        for _, zone in ipairs(zones) do
            destroy_zone_shape(zone)
        end
    end

    state.destroy_zone_shapes = destroy_zone_shapes

    local function get_zone_shape(zone)
        if not state.use_core_shape_render then
            return nil
        end

        local shape_key = table.concat({
            zone.shape or "unknown",
            string.format("%.1f", zone.position.x),
            string.format("%.1f", zone.position.y),
            string.format("%.1f", zone.position.z),
            rotation_signature(zone.rotation)
        }, ":")
        local params = {
            position = zone.position,
            rotation = zone.rotation
        }
        local class_ref = nil

        if zone.shape == "box" and zone.size then
            shape_key = shape_key .. string.format(":%.1f:%.1f:%.1f", zone.size.x, zone.size.y, zone.size.z)
            params.width = zone.size.x
            params.depth = zone.size.y
            params.height = zone.size.z
            class_ref = CoreShapeManager.ShapeBoxMiddle
        elseif zone.shape == "cylinder" and zone.radius and zone.height then
            shape_key = shape_key .. string.format(":%.1f:%.1f", zone.radius, zone.height)
            params.radius = zone.radius
            params.height = zone.height
            class_ref = CoreShapeManager.ShapeCylinderMiddle
        elseif zone.shape == "sphere" and zone.radius then
            shape_key = shape_key .. string.format(":%.1f", zone.radius)
            params.radius = zone.radius
            params.height = zone.radius
            class_ref = CoreShapeManager.ShapeSphere
        else
            return nil
        end

        if zone._draw_shape and zone._draw_shape_key == shape_key then
            return zone._draw_shape
        end

        destroy_zone_shape(zone)

        local ok, shape = pcall(function()
            return class_ref:new(params)
        end)

        if ok and shape then
            zone._draw_shape = shape
            zone._draw_shape_key = shape_key

            return shape
        end

        return nil
    end

    local function draw_zone_with_core_shape(zone)
        local shape = get_zone_shape(zone)
        local draw_info = zone.assault and state.assault_shape_draw_info or state.normal_shape_draw_info

        if not shape or type(shape.draw) ~= "function" or type(draw_info) ~= "table" then
            return false
        end

        local ok = pcall(function()
            shape:draw(0, 0, draw_info.r, draw_info.g, draw_info.b, draw_info.alpha)
        end)

        if not ok then
            destroy_zone_shape(zone)
            return false
        end

        return true
    end

    local function draw_box_outline(zone, pen, has_box, has_line, has_sphere)
        if has_box then
            pen:box(zone.position, zone.rotation, zone.size)
            return
        end

        local corners = build_box_corners(zone)

        if has_line then
            for _, edge in ipairs(BOX_EDGE_INDICES) do
                pen:line(corners[edge[1]], corners[edge[2]])
            end
            return
        end

        if has_sphere then
            local radius = math.max(8, math.min(24, zone.size.x, zone.size.y, zone.size.z) * 0.08)

            for _, corner in ipairs(corners) do
                pen:sphere(corner, radius)
            end
        end
    end

    local function draw_sphere_outline(zone, pen, has_sphere)
        if has_sphere then
            pen:sphere(zone.position, zone.radius)
        end
    end

    local function draw_cylinder_outline(zone, pen, has_cylinder)
        if has_cylinder then
            pen:cylinder(zone.position, zone.rotation, zone.radius, zone.height)
        end
    end

    local function draw_laser_segment(segment, pen, has_line, has_sphere)
        if has_line then
            pen:line(segment.from, segment.to)
        elseif has_sphere then
            local sample_count = math.max(2, math.min(10, math.floor(segment.length / 120)))

            for index = 0, sample_count do
                local t = sample_count == 0 and 0 or (index / sample_count)
                local point = Vector3(
                    segment.from.x + ((segment.to.x - segment.from.x) * t),
                    segment.from.y + ((segment.to.y - segment.from.y) * t),
                    segment.from.z + ((segment.to.z - segment.from.z) * t)
                )

                pen:sphere(point, 10)
            end

            pen:sphere(segment.from, 14)
            pen:sphere(segment.to, 14)
        end
    end

    local function get_zone_draw_tools(zone)
        if zone.assault then
            return state.assault_zone_draw_tools
        end

        return state.normal_zone_draw_tools
    end

    local function get_laser_draw_tools(segment)
        if segment.assault then
            return state.assault_laser_draw_tools
        end

        return state.normal_laser_draw_tools
    end

    local function draw_zone_fill(zone, draw_tools, distance_sq)
        if state.use_core_shape_render then
            return
        end

        if zone.shape == "box" and zone.size then
            if draw_tools.fill_has_line and can_fill_zone(zone) then
                local wall_cache = build_box_wall_cache(zone)
                local stride = 1

                if distance_sq then
                    local far_distance = state.box_wall_far_distance or state.box_wall_distance
                    local mid_distance = state.box_wall_mid_distance or state.fill_distance
                    local far_distance_sq = far_distance * far_distance
                    local mid_distance_sq = mid_distance * mid_distance

                    if distance_sq > far_distance_sq then
                        stride = math.max(1, state.box_wall_far_stride or 4)
                    elseif distance_sq > mid_distance_sq then
                        stride = math.max(1, state.box_wall_mid_stride or 2)
                    end
                end

                for index = 1, #wall_cache.segments, stride do
                    local segment = wall_cache.segments[index]
                    draw_tools.fill_pen:line(segment.from, segment.to)
                end
            elseif draw_tools.brush_has_sphere and can_fill_zone(zone) then
                fill_box_with_brush(zone, draw_tools.brush, draw_tools.brush_has_sphere)
            end
            return
        end

        -- Keep sphere/cylinder zones outline-only for readability.
    end

    local function draw_zone_outline(zone, draw_tools)
        if draw_zone_with_core_shape(zone) then
            return
        end

        if zone.shape == "box" and zone.size then
            draw_box_outline(zone, draw_tools.pen, draw_tools.has_box, draw_tools.has_line, draw_tools.has_sphere)
            return
        end

        if zone.shape == "sphere" and zone.radius then
            draw_sphere_outline(zone, draw_tools.pen, draw_tools.has_sphere)
            return
        end

        if zone.shape == "cylinder" and zone.radius and zone.height then
            draw_cylinder_outline(zone, draw_tools.pen, draw_tools.has_cylinder)
        end
    end

    -- Mission element discovery and trigger analysis
    local function get_editor_name(element)
        if not element then
            return "unnamed"
        end

        local value = read_element_value(element, "editor_name", "EditorName", "name", "Name")
        if value ~= nil then
            return tostring(value)
        end

        if type(element.editor_name) == "function" then
            local ok, result = pcall(element.editor_name, element)
            if ok and result ~= nil then
                return tostring(result)
            end
        end

        return "unnamed"
    end

    local function get_element_id(element)
        return first_non_nil(
            read_element_value(element, "_id", "id", "Id", "element_id", "ElementId"),
            "?"
        )
    end

    local function get_class_name(element)
        local value = first_non_nil(
            read_element_value(element, "class", "Class", "_class", "_type", "type", "Type")
        )

        if type(value) == "string" then
            return value
        end

        return ""
    end

    local function collect_element_identity_text(element)
        return join_blob(
            get_editor_name(element),
            get_class_name(element),
            read_element_value(element, "module", "Module")
        )
    end

    local function current_level_id()
        if managers and managers.job and type(managers.job.current_level_id) == "function" then
            local ok, result = pcall(managers.job.current_level_id, managers.job)
            if ok and result then
                return tostring(result)
            end
        end

        if Global and Global.level_data and Global.level_data.level_id then
            return tostring(Global.level_data.level_id)
        end

        return "unknown_level"
    end

    local function normalize_shape_name(value)
        local text = lower_text(value)

        if text == "" then
            return nil
        end

        if string.find(text, "cylinder", 1, true) then
            return "cylinder"
        end

        if string.find(text, "sphere", 1, true) then
            return "sphere"
        end

        if string.find(text, "box", 1, true) or string.find(text, "cube", 1, true) then
            return "box"
        end

        return nil
    end

    local function read_box_size(primary, fallback)
        local size = sanitize_size(
            read_value_with_fallback(primary, fallback, "size", "Size"),
            state.max_dimension
        )
        if size then
            return size
        end

        local width = read_number(primary, fallback, "width", "Width")
        local depth = read_number(primary, fallback, "depth", "Depth")
        local height = read_number(primary, fallback, "height", "Height")

        if width and depth and height then
            return sanitize_size(Vector3(width, depth, height), state.max_dimension)
        end

        return nil
    end

    local function read_radius(primary, fallback)
        local radius = normalize_number(read_number(primary, fallback, "radius", "Radius"))
        if not radius then
            return nil
        end

        radius = math.abs(radius)

        if radius < 1 or radius > state.max_dimension then
            return nil
        end

        return radius
    end

    local function read_height(primary, fallback)
        local height = normalize_number(read_number(primary, fallback, "height", "Height"))
        if not height then
            return nil
        end

        height = math.abs(height)

        if height < 1 or height > state.max_dimension then
            return nil
        end

        return height
    end

    local function guess_shape(primary, fallback)
        local explicit_shape = normalize_shape_name(
            read_value_with_fallback(
                primary,
                fallback,
                "shape_type",
                "ShapeType",
                "shape",
                "Shape",
                "trigger_shape",
                "TriggerShape"
            )
        )

        if explicit_shape then
            return explicit_shape
        end

        if read_box_size(primary, fallback) then
            return "box"
        end

        local radius = read_radius(primary, fallback)
        local height = read_height(primary, fallback)

        if radius and height then
            return "cylinder"
        end

        if radius then
            return "sphere"
        end

        return nil
    end

    local function read_shape_refs(element)
        return read_element_value(
            element,
            "use_shape_elements",
            "UseShapeElements",
            "use_shape_element_ids",
            "UseShapeElementIds",
            "use_shape_element",
            "UseShapeElement",
            "shape_elements",
            "ShapeElements"
        )
    end

    local function is_laser_trigger(element)
        local text = collect_element_identity_text(element)

        return string.find(text, "lasertrigger", 1, true)
            or (string.find(text, "laser", 1, true) and string.find(text, "trigger", 1, true))
    end

    local function read_nested_vector3(value)
        if not value then
            return nil
        end

        return first_non_nil(
            clone_vector3(value),
            type(value) == "table" and clone_vector3(value.position) or nil,
            type(value) == "table" and clone_vector3(value.pos) or nil,
            type(value) == "table" and clone_vector3(value.Position) or nil,
            type(value) == "table" and clone_vector3(value.Pos) or nil
        )
    end

    local function read_connection_vector(connection, ...)
        if type(connection) ~= "table" then
            return nil
        end

        for index = 1, select("#", ...) do
            local key = select(index, ...)
            local vector = read_nested_vector3(connection[key])

            if vector then
                return vector
            end
        end

        return nil
    end

    local function build_laser_segments(element, script_name)
        local connections = read_element_value(element, "connections", "Connections")

        if type(connections) ~= "table" then
            return {}
        end

        local segments = {}
        local element_id = tostring(get_element_id(element))
        local editor_name = get_editor_name(element)

        for index, connection in pairs(connections) do
            if type(connection) == "table" then
                local from = read_connection_vector(
                    connection,
                    "from",
                    "from_pos",
                    "from_position",
                    "From",
                    "FromPos",
                    "FromPosition",
                    "start",
                    "start_pos",
                    "start_position",
                    "ray_from",
                    "ray_start"
                )
                local to = read_connection_vector(
                    connection,
                    "to",
                    "to_pos",
                    "to_position",
                    "To",
                    "ToPos",
                    "ToPosition",
                    "stop",
                    "end",
                    "end_pos",
                    "end_position",
                    "ray_to",
                    "ray_end"
                )

                if (not from) and type(connection[1]) == "table" then
                    from = read_nested_vector3(connection[1])
                end

                if (not to) and type(connection[2]) == "table" then
                    to = read_nested_vector3(connection[2])
                end

                if from and to then
                    local midpoint = Vector3(
                        (from.x + to.x) * 0.5,
                        (from.y + to.y) * 0.5,
                        (from.z + to.z) * 0.5
                    )

                    segments[#segments + 1] = {
                        key = table.concat({
                            script_name,
                            element_id,
                            tostring(index),
                            "laser"
                        }, ":"),
                        script_name = script_name,
                        element_id = element_id,
                        editor_name = editor_name,
                        class_name = get_class_name(element),
                        from = from,
                        to = to,
                        midpoint = midpoint,
                        length = mvector3.distance(from, to)
                    }
                end
            end
        end

        return segments
    end

    local function normalize_shape_refs(shape_refs)
        if shape_refs == nil then
            return nil
        end

        if type(shape_refs) == "table" then
            return shape_refs
        end

        return { shape_refs }
    end

    local function get_script_name(script, fallback_name)
        if script and type(script.name) == "function" then
            local ok, result = pcall(script.name, script)
            if ok and result then
                return tostring(result)
            end
        end

        if script and rawget(script, "_name") then
            return tostring(rawget(script, "_name"))
        end

        return tostring(fallback_name or "unknown_script")
    end

    local function gather_scripts()
        if not managers or not managers.mission or type(managers.mission.scripts) ~= "function" then
            return {}
        end

        local ok, scripts = pcall(managers.mission.scripts, managers.mission)
        if not ok or type(scripts) ~= "table" then
            return {}
        end

        local list = {}

        for key, script in pairs(scripts) do
            if script and type(rawget(script, "_elements")) == "table" then
                list[#list + 1] = {
                    name = get_script_name(script, key),
                    script = script,
                    elements = rawget(script, "_elements")
                }
            end
        end

        return list
    end

    local function resolve_element_by_id(script_entry, global_lookup, element_id)
        if element_id == nil then
            return nil
        end

        local candidates = {
            element_id,
            tostring(element_id),
            tonumber(element_id)
        }

        if script_entry and script_entry.elements then
            for _, candidate in ipairs(candidates) do
                if candidate ~= nil and script_entry.elements[candidate] then
                    return script_entry.elements[candidate]
                end
            end
        end

        for _, candidate in ipairs(candidates) do
            if candidate ~= nil and global_lookup[candidate] then
                return global_lookup[candidate]
            end
        end

        return nil
    end

    local function append_search_value(parts, key, value)
        local value_type = type(value)

        if value_type == "string" or value_type == "number" or value_type == "boolean" then
            parts[#parts + 1] = lower_text(key)
            parts[#parts + 1] = lower_text(value)
            return
        end

        if value_type == "table" then
            local count = 0

            for _, nested in pairs(value) do
                if type(nested) == "string" or type(nested) == "number" or type(nested) == "boolean" then
                    parts[#parts + 1] = lower_text(nested)
                    count = count + 1
                end

                if count >= 6 then
                    break
                end
            end
        end
    end

    local function contains_any_keyword(text, keywords)
        for _, keyword in ipairs(keywords) do
            if string.find(text, keyword, 1, true) then
                return keyword
            end
        end

        return nil
    end

    local function collect_element_search_text(element)
        local parts = { collect_element_identity_text(element) }

        local values = rawget(element, "_values")

        if values then
            for key, value in pairs(values) do
                local key_text = lower_text(key)

                if SEARCH_TEXT_VALUE_KEYS[key_text] or contains_any_keyword(key_text, SEARCH_TEXT_KEYWORDS) then
                    append_search_value(parts, key, value)
                end
            end
        end

        return join_blob(unpack(parts))
    end

    local function collect_graph_target_ids(element)
        local target_ids = {}
        local seen = {}

        local function append_target_id(value)
            if value == nil then
                return
            end

            local key = tostring(value)
            if seen[key] then
                return
            end

            seen[key] = true
            target_ids[#target_ids + 1] = value
        end

        local function append_target_value(value)
            if value == nil then
                return
            end

            if type(value) ~= "table" then
                append_target_id(value)
                return
            end

            for _, entry in pairs(value) do
                local target_id = entry

                if type(entry) == "table" then
                    target_id = first_non_nil(
                        entry.id,
                        entry.element_id,
                        entry.ElementId,
                        entry.target,
                        entry.target_id,
                        entry.execute_id
                    )
                end

                if target_id ~= nil then
                    append_target_id(target_id)
                end
            end
        end

        append_target_value(read_element_value(element, "on_executed", "OnExecuted"))

        local values = rawget(element, "_values")
        if values then
            for key, value in pairs(values) do
                local key_text = lower_text(key)
                local is_exact_link_key = GRAPH_LINK_KEYS[key_text]
                local is_generic_link_table = type(value) == "table"
                    and contains_any_keyword(key_text, GRAPH_LINK_KEYWORDS)

                if (is_exact_link_key or is_generic_link_table)
                    and not string.find(key_text, "shape", 1, true)
                    and key_text ~= "instigator"
                    and key_text ~= "trigger_type"
                then
                    append_target_value(value)
                end
            end
        end

        return target_ids
    end

    local function format_element_ref(element)
        return string.format(
            "%s[%s]",
            get_editor_name(element),
            tostring(get_element_id(element))
        )
    end

    local function collect_graph_target_refs(source_context, global_lookup)
        local refs = {}
        local seen = {}

        if not source_context or not source_context.element then
            return refs
        end

        for _, target_id in ipairs(collect_graph_target_ids(source_context.element)) do
            local target_element = resolve_element_by_id(source_context.script_entry, global_lookup, target_id)
            local ref = target_element and format_element_ref(target_element) or ("id[" .. tostring(target_id) .. "]")

            if ref and not seen[ref] then
                seen[ref] = true
                refs[#refs + 1] = ref
            end
        end

        return refs
    end

    local function analyze_loud_sink(element)
        local result = {
            is_sink = false,
            score = 0,
            reasons = {},
            sink_ref = format_element_ref(element),
            is_assault = false,
            assault_hints = {}
        }

        local reason_seen = {}
        local assault_hint_seen = {}
        local search_text = collect_element_search_text(element)
        local identity_text = collect_element_identity_text(element)

        local function add_reason(reason, score)
            if not reason_seen[reason] then
                reason_seen[reason] = true
                result.score = result.score + score
                result.reasons[#result.reasons + 1] = reason
            end
        end

        local function add_assault_hint(hint)
            if hint and not assault_hint_seen[hint] then
                assault_hint_seen[hint] = true
                result.assault_hints[#result.assault_hints + 1] = hint
            end
        end

        if contains_any_keyword(search_text, KEYWORDS_ENEMY_SPAWN) then
            add_reason("enemy_spawn", 14)
        end

        if contains_any_keyword(search_text, KEYWORDS_STEALTH_STATE)
            and contains_any_keyword(search_text, KEYWORDS_DISABLED_STATES)
        then
            add_reason("stealth_off", 14)
        end

        if contains_any_keyword(search_text, KEYWORDS_ALARM) then
            add_reason("alarm", 12)
        end

        if contains_any_keyword(search_text, KEYWORDS_POLICE_RESPONSE) then
            add_reason("police_response", 12)
        end

        if contains_any_keyword(search_text, KEYWORDS_ASSAULT_STATE) then
            add_reason("assault_state", 10)
        end

        if contains_any_keyword(search_text, KEYWORDS_COMBAT_LOGIC) then
            add_reason("combat_logic", 8)
        end

        if string.find(search_text, "music", 1, true)
            and contains_any_keyword(search_text, KEYWORDS_MUSIC_STATE)
        then
            add_reason("music_state", 8)
        end

        local explicit_assault_match = contains_any_keyword(identity_text, KEYWORDS_EXPLICIT_ASSAULT)
        local explicit_hard_match = contains_any_keyword(identity_text, KEYWORDS_EXPLICIT_HARD_TRANSITION)
        local named_assault_stage = contains_any_keyword(identity_text, KEYWORDS_NAMED_ASSAULT_STAGE)
        local scripted_assault_start = contains_any_keyword(identity_text, KEYWORDS_ASSAULT_START_IDENTITY)
            and contains_any_keyword(identity_text, KEYWORDS_ASSAULT_ACTION)
        local identity_is_logic = contains_any_keyword(identity_text, KEYWORDS_LOGIC_IDENTITY)
        local identity_is_music = contains_any_keyword(identity_text, KEYWORDS_MUSIC_IDENTITY) or (
            string.find(search_text, "music", 1, true)
            and not contains_any_keyword(identity_text, KEYWORDS_EXPLICIT_HARD_TRANSITION)
        )
        local direct_loud_transition = reason_seen.police_response
            or reason_seen.stealth_off
            or reason_seen.alarm
        local hard_assault_transition = direct_loud_transition or explicit_hard_match ~= nil
        local identity_assault = explicit_assault_match ~= nil and not identity_is_music

        if not identity_is_logic and not identity_is_music and (named_assault_stage ~= nil or scripted_assault_start ~= nil) then
            identity_assault = true
        end

        if identity_is_music and not hard_assault_transition then
            identity_assault = false
        end

        if explicit_assault_match then
            add_assault_hint(explicit_assault_match)
        end

        if named_assault_stage and not identity_is_logic and not identity_is_music then
            add_assault_hint(named_assault_stage)
        end

        if scripted_assault_start and not identity_is_music then
            add_assault_hint("scripted_assault_start")
        end

        if reason_seen.police_response then
            add_assault_hint("police_response")
        end

        if reason_seen.stealth_off then
            add_assault_hint("stealth_off")
        end

        if reason_seen.alarm then
            add_assault_hint("alarm")
        end

        if state.assault_explicit_only then
            result.is_assault = identity_assault or direct_loud_transition
        else
            result.is_assault = identity_assault
                or direct_loud_transition
                or reason_seen.assault_state
        end

        result.is_sink = result.score >= state.loud_min_score

        return result
    end

    local function build_lookat_zone(element, script_name)
        local text = collect_element_identity_text(element)

        if not string.find(text, "lookat", 1, true) then
            return nil
        end

        local position = read_vector3(element, nil, "position", "Position", "pos", "Pos")
        local radius = read_number(element, nil, "distance", "Distance", "range", "Range", "radius", "Radius")

        if not position or not radius then
            return nil
        end

        radius = math.abs(radius)

        if radius < 1 or radius > state.max_dimension then
            return nil
        end

        return {
            script_name = script_name,
            editor_name = get_editor_name(element),
            class_name = get_class_name(element),
            element_id = tostring(get_element_id(element)),
            source_id = tostring(get_element_id(element)),
            source_name = nil,
            shape = "sphere",
            position = position,
            radius = radius,
            rotation = read_draw_rotation(element, nil),
            key = table.concat({
                script_name,
                tostring(get_element_id(element)),
                "lookat"
            }, ":")
        }
    end

    local function is_spatial_source(element)
        if is_laser_trigger(element) then
            return true
        end

        if build_lookat_zone(element, "spatial_probe") then
            return true
        end

        if guess_shape(element, nil) or normalize_shape_refs(read_shape_refs(element)) ~= nil then
            return true
        end

        return false
    end

    -- Zone labels and event messages
    local function friendly_reason(reason)
        if reason == "enemy_spawn" then
            return L("hvt_trigger_vis_reason_enemy_spawn")
        end

        if reason == "alarm" then
            return L("hvt_trigger_vis_reason_alarm")
        end

        if reason == "assault_state" then
            return L("hvt_trigger_vis_reason_assault_state")
        end

        if reason == "combat_logic" then
            return L("hvt_trigger_vis_reason_combat_logic")
        end

        if reason == "enemy_faction" then
            return L("hvt_trigger_vis_reason_enemy_faction")
        end

        if reason == "music_state" then
            return L("hvt_trigger_vis_reason_music_state")
        end

        if reason == "stealth_off" then
            return L("hvt_trigger_vis_reason_stealth_off")
        end

        if reason == "police_response" then
            return L("hvt_trigger_vis_reason_police_response")
        end

        return reason
    end

    local function friendly_assault_hint(hint)
        if hint == "police_response" then
            return L("hvt_trigger_vis_hint_police_response")
        end

        if hint == "stealth_off" then
            return L("hvt_trigger_vis_hint_stealth_off")
        end

        if hint == "alarm" then
            return L("hvt_trigger_vis_hint_alarm")
        end

        if hint == "scripted_assault_start" then
            return L("hvt_trigger_vis_hint_scripted_assault_start")
        end

        if string.find(hint, "assault", 1, true) or string.find(hint, "anticipation", 1, true) then
            return L("hvt_trigger_vis_hint_assault_start")
        end

        if string.find(hint, "point_of_no_return", 1, true) or hint == "ponr" then
            return L("hvt_trigger_vis_hint_point_of_no_return")
        end

        return hint
    end

    local function format_named_ref(name, id)
        return string.format("%s[%s]", tostring(name or L("hvt_trigger_vis_unnamed")), tostring(id or "?"))
    end

    local function format_zone_ref(zone)
        return format_named_ref(zone.editor_name, zone.element_id)
    end

    local function format_zone_source_ref(zone)
        if not zone.source_name then
            return nil
        end

        if tostring(zone.source_id) == tostring(zone.element_id)
            and tostring(zone.source_name) == tostring(zone.editor_name)
        then
            return nil
        end

        return format_named_ref(zone.source_name, zone.source_id)
    end

    local function format_shape_summary(zone)
        if zone.shape == "box" and zone.size then
            return L("hvt_trigger_vis_shape_box", {
                WIDTH = string.format("%.0f", zone.size.x),
                HEIGHT = string.format("%.0f", zone.size.y),
                DEPTH = string.format("%.0f", zone.size.z)
            })
        end

        if zone.shape == "sphere" and zone.radius then
            return L("hvt_trigger_vis_shape_sphere", {
                RADIUS = string.format("%.0f", zone.radius)
            })
        end

        if zone.shape == "cylinder" and zone.radius and zone.height then
            return L("hvt_trigger_vis_shape_cylinder", {
                RADIUS = string.format("%.0f", zone.radius),
                HEIGHT = string.format("%.0f", zone.height)
            })
        end

        return L("hvt_trigger_vis_shape_unknown")
    end

    local function format_readable_list(values, formatter, limit)
        if type(values) ~= "table" or #values == 0 then
            return nil
        end

        local formatted = {}
        local max_count = limit or #values

        for index, value in ipairs(values) do
            if index > max_count then
                break
            end

            formatted[#formatted + 1] = formatter and formatter(value) or tostring(value)
        end

        return table.concat(formatted, ", ")
    end

    local function get_zone_role(zone)
        if zone.assault then
            return L("hvt_trigger_vis_role_assault")
        end

        if zone.loud then
            return L("hvt_trigger_vis_role_loud")
        end

        return L("hvt_trigger_vis_role_safe")
    end

    local function get_zone_cause_text(zone, limit)
        if zone.assault_hints and #zone.assault_hints > 0 then
            return format_readable_list(zone.assault_hints, friendly_assault_hint, limit or 2)
        end

        if zone.loud_reasons and #zone.loud_reasons > 0 then
            return format_readable_list(zone.loud_reasons, friendly_reason, limit or 2)
        end

        return nil
    end

    local function get_zone_best_target(zone)
        if zone.direct_targets and #zone.direct_targets > 0 then
            return zone.direct_targets[1]
        end

        if zone.raw_graph_targets and #zone.raw_graph_targets > 0 then
            return zone.raw_graph_targets[1]
        end

        return nil
    end

    local function get_zone_config_text(zone)
        local parts = {}

        if zone.trigger_on and tostring(zone.trigger_on) ~= "" then
            parts[#parts + 1] = tostring(zone.trigger_on)
        end

        if zone.instigator and tostring(zone.instigator) ~= "" then
            parts[#parts + 1] = L("hvt_trigger_vis_config_inst_label") .. "=" .. tostring(zone.instigator)
        end

        if zone.amount and tostring(zone.amount) ~= "" then
            parts[#parts + 1] = L("hvt_trigger_vis_config_amt_label") .. "=" .. tostring(zone.amount)
        end

        if #parts == 0 then
            return nil
        end

        return table.concat(parts, " / ")
    end

    local function get_zone_warning_text(zone)
        if zone.assault and (not zone.assault_hints or #zone.assault_hints == 0) then
            return L("hvt_trigger_vis_assault_without_hint")
        end

        if zone.loud and (not zone.direct_targets or #zone.direct_targets == 0) then
            return L("hvt_trigger_vis_loud_without_final_target")
        end

        if zone.loud and (zone.loud_score or 0) <= (state.loud_min_score + 1) then
            return L("hvt_trigger_vis_loud_fragile", {
                SCORE = tostring(zone.loud_score or 0)
            })
        end

        return nil
    end

    local function build_zone_purpose_text(zone)
        local parts = {
            L("hvt_trigger_vis_script_label", { VALUE = tostring(zone.script_name or L("hvt_trigger_vis_unnamed")) }),
            L("hvt_trigger_vis_role_label", { VALUE = get_zone_role(zone) }),
            L("hvt_trigger_vis_shape_label", { VALUE = format_shape_summary(zone) })
        }
        local source_ref = format_zone_source_ref(zone)
        local cause_text = get_zone_cause_text(zone, 4)
        local target_text = zone.direct_targets and #zone.direct_targets > 0 and table.concat(zone.direct_targets, ", ") or nil
        local raw_link_text = zone.raw_graph_targets and #zone.raw_graph_targets > 0 and table.concat(zone.raw_graph_targets, ", ") or nil
        local config_text = get_zone_config_text(zone)

        if source_ref then
            parts[#parts + 1] = L("hvt_trigger_vis_source_shape_label", { VALUE = source_ref })
        end

        if cause_text then
            parts[#parts + 1] = L("hvt_trigger_vis_causes_label", { VALUE = cause_text })
        elseif raw_link_text then
            parts[#parts + 1] = L("hvt_trigger_vis_causes_no_loud_signature")
        else
            parts[#parts + 1] = L("hvt_trigger_vis_causes_unknown")
        end

        if zone.loud_reasons and #zone.loud_reasons > 0 then
            parts[#parts + 1] = L("hvt_trigger_vis_raw_loud_label", { VALUE = table.concat(zone.loud_reasons, ", ") })
        end

        if zone.assault_hints and #zone.assault_hints > 0 then
            parts[#parts + 1] = L("hvt_trigger_vis_raw_assault_label", { VALUE = table.concat(zone.assault_hints, ", ") })
        end

        if target_text then
            parts[#parts + 1] = L("hvt_trigger_vis_targets_label", { VALUE = target_text })
        elseif raw_link_text then
            parts[#parts + 1] = L("hvt_trigger_vis_raw_links_label", { VALUE = raw_link_text })
        end

        if config_text then
            parts[#parts + 1] = L("hvt_trigger_vis_config_label", { VALUE = config_text })
        end

        return table.concat(parts, " | ")
    end

    local function build_zone_enter_text(zone)
        local parts = {
            format_zone_ref(zone),
            format_shape_summary(zone),
            L("hvt_trigger_vis_role_label", { VALUE = get_zone_role(zone) })
        }
        local cause_text = get_zone_cause_text(zone, 2)
        local best_target = get_zone_best_target(zone)

        if cause_text then
            parts[#parts + 1] = L("hvt_trigger_vis_cause_label", { VALUE = cause_text })
        end

        if best_target then
            parts[#parts + 1] = zone.direct_targets and #zone.direct_targets > 0
                and L("hvt_trigger_vis_target_label", { VALUE = best_target })
                or L("hvt_trigger_vis_link_label", { VALUE = best_target })
        end

        return table.concat(parts, " | ")
    end

    local function build_zone_exit_text(zone, elapsed)
        return string.format("%s | %s", format_zone_ref(zone), L("hvt_trigger_vis_zone_time", {
            SECONDS = string.format("%.1f", math.max(0, elapsed or 0))
        }))
    end

    local function is_point_inside_zone(zone, point)
        if zone.shape == "box" and zone.size then
            local half_x = zone.size.x * 0.5
            local half_y = zone.size.y * 0.5
            local half_z = zone.size.z * 0.5
            local local_point = world_to_local_point(zone, point)

            return math.abs(local_point.x) <= half_x
                and math.abs(local_point.y) <= half_y
                and math.abs(local_point.z) <= half_z
        end

        if zone.shape == "sphere" and zone.radius then
            local dx = point.x - zone.position.x
            local dy = point.y - zone.position.y
            local dz = point.z - zone.position.z

            return (dx * dx) + (dy * dy) + (dz * dz) <= (zone.radius * zone.radius)
        end

        if zone.shape == "cylinder" and zone.radius and zone.height then
            local local_point = world_to_local_point(zone, point)
            local dx = local_point.x
            local dy = local_point.y
            local dz = math.abs(local_point.z)

            return (dx * dx) + (dy * dy) <= (zone.radius * zone.radius)
                and dz <= (zone.height * 0.5)
        end

        return false
    end

    local function report_zone_enter(zone)
        local now = state.frame_index or 0
        local last_report = state.zone_last_report_frame[zone.key] or -999999

        if now - last_report < state.debug_enter_cooldown_frames then
            return
        end

        state.zone_last_report_frame[zone.key] = now
        state.zone_enter_time[zone.key] = current_runtime_time()

        push_debug_chat(L("hvt_trigger_vis_prefix_enter"), build_zone_enter_text(zone), 2)

        local warning_text = get_zone_warning_text(zone)
        local last_warn = state.zone_last_warn_frame[zone.key] or -999999

        if warning_text and (now - last_warn >= state.debug_enter_cooldown_frames) then
            state.zone_last_warn_frame[zone.key] = now
            push_debug_chat(L("hvt_trigger_vis_prefix_warn"), format_zone_ref(zone) .. " | " .. warning_text, 2)
        end

        push_debug_chat(L("hvt_trigger_vis_prefix_info"), build_zone_purpose_text(zone), 3)
    end

    local function report_zone_exit(zone)
        local enter_time = state.zone_enter_time[zone.key]

        state.zone_enter_time[zone.key] = nil

        if enter_time == nil then
            return
        end

        push_debug_chat(L("hvt_trigger_vis_prefix_exit"), build_zone_exit_text(zone, current_runtime_time() - enter_time), 2)
    end

    local function build_zone(trigger_element, source_element, script_name)
        local primary = source_element or trigger_element
        local shape = guess_shape(primary, trigger_element)
        local position = read_vector3(primary, trigger_element, "position", "Position", "pos", "Pos")

        if not shape or not position then
            return nil
        end

        local zone = {
            script_name = script_name,
            editor_name = get_editor_name(trigger_element),
            class_name = get_class_name(trigger_element),
            element_id = tostring(get_element_id(trigger_element)),
            source_id = tostring(get_element_id(primary)),
            source_name = source_element and get_editor_name(source_element) or nil,
            shape = shape,
            position = position,
            rotation = read_draw_rotation(primary, trigger_element),
            trigger_on = read_element_value(trigger_element, "trigger_on", "TriggerOn", "event", "Event"),
            instigator = read_element_value(trigger_element, "instigator", "Instigator"),
            amount = read_element_value(trigger_element, "amount", "Amount")
        }

        if shape == "box" then
            zone.size = read_box_size(primary, trigger_element)
            if not zone.size then
                return nil
            end
        elseif shape == "sphere" then
            zone.radius = read_radius(primary, trigger_element)
            if not zone.radius then
                return nil
            end
        elseif shape == "cylinder" then
            zone.radius = read_radius(primary, trigger_element)
            zone.height = read_height(primary, trigger_element)

            if not zone.radius or not zone.height then
                return nil
            end
        end

        zone.key = table.concat({
            zone.script_name,
            zone.element_id,
            zone.source_id,
            zone.shape
        }, ":")

        return zone
    end

    local function zone_summary(zone)
        local parts = {
            tostring(zone.script_name or "unknown"),
            build_zone_enter_text(zone)
        }
        local warning_text = get_zone_warning_text(zone)

        if warning_text then
            parts[#parts + 1] = "warn: " .. warning_text
        end

        return table.concat(parts, " | ")
    end

    -- Build and refresh the zone cache
    local function append_unique_string(list, seen, value)
        if not value or seen[value] then
            return
        end

        seen[value] = true
        list[#list + 1] = value
    end

    local function append_missing_string(list, value)
        if not value then
            return
        end

        local seen = {}

        for _, existing_value in ipairs(list) do
            seen[existing_value] = true
        end

        append_unique_string(list, seen, value)
    end

    local function append_missing_strings(list, values)
        if type(values) ~= "table" then
            return
        end

        local seen = {}

        for _, existing_value in ipairs(list) do
            seen[existing_value] = true
        end

        for _, value in ipairs(values) do
            append_unique_string(list, seen, value)
        end
    end

    local function assign_sink_metadata(target, sink_result)
        target.loud = true
        target.assault = sink_result.is_assault and true or false
        target.loud_score = sink_result.score or 0
        target.loud_reasons = copy_array(sink_result.reasons)
        target.assault_hints = copy_array(sink_result.assault_hints)
        target.direct_targets = sink_result.sink_ref and { sink_result.sink_ref } or {}
    end

    local function assign_non_loud_metadata(target)
        target.loud = false
        target.assault = false
        target.loud_score = 0
        target.loud_reasons = {}
        target.assault_hints = {}
        target.direct_targets = {}
    end

    local function merge_sink_metadata(target, sink_result)
        target.loud = true
        target.loud_score = math.max(target.loud_score or 0, sink_result.score or 0)
        target.loud_reasons = target.loud_reasons or {}
        target.assault_hints = target.assault_hints or {}
        target.direct_targets = target.direct_targets or {}

        append_missing_strings(target.loud_reasons, sink_result.reasons)
        append_missing_strings(target.assault_hints, sink_result.assault_hints)
        append_missing_string(target.direct_targets, sink_result.sink_ref)

        if sink_result.is_assault and not target.assault then
            target.assault = true
            return true
        end

        return false
    end

    local function extract_spatial_zones(source_context, global_lookup)
        local element = source_context.element
        local zones = {}
        local seen = {}
        local raw_target_refs = collect_graph_target_refs(source_context, global_lookup)
        local shape_refs = normalize_shape_refs(read_shape_refs(element))
        local lookat_zone = build_lookat_zone(element, source_context.script_name)
        local added_shape_zone = false

        local function add_zone(zone)
            if zone and not seen[zone.key] then
                zone.raw_graph_targets = copy_array(raw_target_refs)
                seen[zone.key] = true
                zones[#zones + 1] = zone
            end
        end

        if lookat_zone then
            add_zone(lookat_zone)
        end

        if shape_refs then
            for _, shape_ref in pairs(shape_refs) do
                local lookup_id = shape_ref

                if type(shape_ref) == "table" then
                    lookup_id = first_non_nil(
                        shape_ref.id,
                        shape_ref.element_id,
                        shape_ref.Id,
                        shape_ref.ElementId
                    )
                end

                local shape_element = resolve_element_by_id(source_context.script_entry, global_lookup, lookup_id)
                local shape_zone = build_zone(element, shape_element, source_context.script_name)

                if shape_zone then
                    added_shape_zone = true
                    add_zone(shape_zone)
                end
            end
        end

        if not added_shape_zone then
            add_zone(build_zone(element, nil, source_context.script_name))
        end

        return zones
    end

    local function scan_zones()
        local scripts = gather_scripts()
        local zones = {}
        local global_lookup = {}
        local element_contexts = {}
        local reverse_links = {}
        local signature_parts = {}
        local laser_segments = {}
        local zone_seen = {}
        local laser_seen = {}
        local script_count = 0
        local element_count = 0
        local candidate_zone_count = 0
        local loud_zone_count = 0
        local loud_sink_count = 0
        local assault_zone_count = 0
        local assault_sink_count = 0
        local assault_laser_count = 0
        local warning_zone_count = 0
        local laser_trigger_cache = {}
        local spatial_source_cache = {}
        local spatial_zone_cache = {}
        local laser_segment_cache = {}

        local function add_reverse_link(target_element, source_context)
            if not target_element or not source_context then
                return
            end

            local links = reverse_links[target_element]
            if not links then
                links = {
                    list = {},
                    seen = {}
                }
                reverse_links[target_element] = links
            end

            if not links.seen[source_context.element] then
                links.seen[source_context.element] = true
                links.list[#links.list + 1] = source_context
            end
        end

        local function is_cached_spatial_source(source_context)
            local element = source_context.element
            local cached = spatial_source_cache[element]

            if cached == nil then
                cached = is_spatial_source(element) and true or false
                spatial_source_cache[element] = cached
            end

            return cached
        end

        local function is_cached_laser_trigger(source_context)
            local element = source_context.element
            local cached = laser_trigger_cache[element]

            if cached == nil then
                cached = is_laser_trigger(element) and true or false
                laser_trigger_cache[element] = cached
            end

            return cached
        end

        local function get_cached_spatial_zones(source_context)
            local element = source_context.element
            local cached = spatial_zone_cache[element]

            if cached == nil then
                cached = extract_spatial_zones(source_context, global_lookup)
                spatial_zone_cache[element] = cached
            end

            return cached
        end

        local function get_cached_laser_segments(source_context)
            local element = source_context.element
            local cached = laser_segment_cache[element]

            if cached == nil then
                cached = build_laser_segments(element, source_context.script_name)
                laser_segment_cache[element] = cached
            end

            return cached
        end

        local function register_zone(zone, sink_result)
            local existing_zone = zone_seen[zone.key]

            if not existing_zone then
                assign_sink_metadata(zone, sink_result)
                zone_seen[zone.key] = zone
                zones[#zones + 1] = zone
                candidate_zone_count = candidate_zone_count + 1
                loud_zone_count = loud_zone_count + 1

                if zone.assault then
                    assault_zone_count = assault_zone_count + 1
                end

                return
            end

            if merge_sink_metadata(existing_zone, sink_result) then
                assault_zone_count = assault_zone_count + 1
            end
        end

        local function register_non_loud_zone(zone)
            if zone_seen[zone.key] then
                return
            end

            assign_non_loud_metadata(zone)
            zone_seen[zone.key] = zone
            zones[#zones + 1] = zone
            candidate_zone_count = candidate_zone_count + 1
        end

        local function register_laser_segment(segment, sink_result)
            local existing_segment = laser_seen[segment.key]

            if not existing_segment then
                assign_sink_metadata(segment, sink_result)
                laser_seen[segment.key] = segment
                laser_segments[#laser_segments + 1] = segment

                if segment.assault then
                    assault_laser_count = assault_laser_count + 1
                end

                return
            end

            if merge_sink_metadata(existing_segment, sink_result) then
                assault_laser_count = assault_laser_count + 1
            end
        end

        local function register_non_loud_laser_segment(segment)
            if laser_seen[segment.key] then
                return
            end

            assign_non_loud_metadata(segment)
            laser_seen[segment.key] = segment
            laser_segments[#laser_segments + 1] = segment
        end

        for _, script_entry in ipairs(scripts) do
            script_count = script_count + 1

            for element_id, element in pairs(script_entry.elements) do
                element_count = element_count + 1
                global_lookup[element_id] = element
                global_lookup[tostring(element_id)] = element

                local numeric_id = tonumber(element_id)
                if numeric_id ~= nil then
                    global_lookup[numeric_id] = element
                end

                element_contexts[#element_contexts + 1] = {
                    element = element,
                    script_entry = script_entry,
                    script_name = script_entry.name
                }
            end
        end

        for _, source_context in ipairs(element_contexts) do
            for _, target_id in ipairs(collect_graph_target_ids(source_context.element)) do
                local target_element = resolve_element_by_id(source_context.script_entry, global_lookup, target_id)
                if target_element then
                    add_reverse_link(target_element, source_context)
                end
            end
        end

        for _, sink_context in ipairs(element_contexts) do
            local sink_result = analyze_loud_sink(sink_context.element)

            if sink_result.is_sink then
                loud_sink_count = loud_sink_count + 1

                if sink_result.is_assault then
                    assault_sink_count = assault_sink_count + 1
                end

                if not state.show_only_assault or sink_result.is_assault then
                    local queue = {
                        {
                            context = sink_context,
                            depth = 0
                        }
                    }
                    local queue_index = 1
                    local visited = {
                        [sink_context.element] = true
                    }
                    local visited_count = 0

                    while queue_index <= #queue and visited_count < state.loud_graph_limit do
                        local node = queue[queue_index]
                        queue_index = queue_index + 1
                        visited_count = visited_count + 1

                        local incoming = reverse_links[node.context.element]
                        if incoming then
                            for _, source_context in ipairs(incoming.list) do
                                if not visited[source_context.element] then
                                    visited[source_context.element] = true

                                    if is_cached_spatial_source(source_context) then
                                        for _, zone in ipairs(get_cached_spatial_zones(source_context)) do
                                            register_zone(zone, sink_result)
                                        end

                                        if is_cached_laser_trigger(source_context) then
                                            for _, segment in ipairs(get_cached_laser_segments(source_context)) do
                                                register_laser_segment(segment, sink_result)
                                            end
                                        end
                                    elseif node.depth < state.loud_graph_depth then
                                        queue[#queue + 1] = {
                                            context = source_context,
                                            depth = node.depth + 1
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if state.show_all_zones then
            for _, source_context in ipairs(element_contexts) do
                if is_cached_spatial_source(source_context) then
                    for _, zone in ipairs(get_cached_spatial_zones(source_context)) do
                        register_non_loud_zone(zone)
                    end

                    if is_cached_laser_trigger(source_context) then
                        for _, segment in ipairs(get_cached_laser_segments(source_context)) do
                            register_non_loud_laser_segment(segment)
                        end
                    end
                end
            end
        end

        table.sort(zones, function(left, right)
            return left.key < right.key
        end)

        table.sort(laser_segments, function(left, right)
            return left.key < right.key
        end)

        for _, zone in ipairs(zones) do
            if get_zone_warning_text(zone) then
                warning_zone_count = warning_zone_count + 1
            end
        end

        signature_parts = {}

        for _, zone in ipairs(zones) do
            signature_parts[#signature_parts + 1] = string.format(
                "%s:%s:%d:%s:%s",
                zone.key,
                table.concat(zone.loud_reasons or {}, ","),
                zone.loud_score or 0,
                table.concat(zone.direct_targets or {}, ","),
                table.concat(zone.raw_graph_targets or {}, ",")
            )

            if zone.assault then
                signature_parts[#signature_parts] = signature_parts[#signature_parts] .. ":assault"
            end
        end

        for _, segment in ipairs(laser_segments) do
            signature_parts[#signature_parts + 1] = string.format(
                "%s:%s:%d:%s",
                segment.key,
                table.concat(segment.loud_reasons or {}, ","),
                segment.loud_score or 0,
                table.concat(segment.direct_targets or {}, ",")
            )

            if segment.assault then
                signature_parts[#signature_parts] = signature_parts[#signature_parts] .. ":assault"
            end
        end

        table.sort(signature_parts)

        return {
            zones = zones,
            laser_segments = laser_segments,
            script_count = script_count,
            element_count = element_count,
            candidate_zone_count = candidate_zone_count,
            loud_zone_count = loud_zone_count,
            loud_sink_count = loud_sink_count,
            assault_zone_count = assault_zone_count,
            assault_sink_count = assault_sink_count,
            assault_laser_count = assault_laser_count,
            warning_zone_count = warning_zone_count,
            signature = table.concat({
                current_level_id(),
                tostring(script_count),
                tostring(element_count),
                tostring(candidate_zone_count),
                tostring(loud_zone_count),
                tostring(loud_sink_count),
                tostring(#laser_segments),
                tostring(#zones),
                table.concat(signature_parts, ";")
            }, "|")
        }
    end

    local function build_scan_summary(scan)
        local show_all_zones = state.show_all_zones
        local filter_key = show_all_zones and "hvt_trigger_vis_mode_all_zones"
            or (state.show_only_assault and "hvt_trigger_vis_mode_assault" or "hvt_trigger_vis_mode_filtered_loud")
        local warn = (scan.warning_zone_count or 0) > 0
            and (" | " .. L("hvt_trigger_vis_warn_label") .. "=" .. tostring(scan.warning_zone_count))
            or ""

        return L("hvt_trigger_vis_scan_summary", {
            COUNT_LABEL = show_all_zones and L("hvt_trigger_vis_total_label") or L("hvt_trigger_vis_shown_label"),
            COUNT_VALUE = tostring(#(scan.zones or {})),
            FILTER_LABEL = L("hvt_trigger_vis_filter_label"),
            FILTER = L(filter_key),
            LOUD_LABEL = L("hvt_trigger_vis_loud_label"),
            LOUD = tostring(scan.loud_zone_count or 0),
            ASSAULT_LABEL = L("hvt_trigger_vis_assault_label"),
            ASSAULT = tostring(scan.assault_zone_count or 0),
            LASERS_LABEL = L("hvt_trigger_vis_lasers_label"),
            LASERS = tostring(#(scan.laser_segments or {})),
            SINKS_LABEL = L("hvt_trigger_vis_sinks_label"),
            SINKS = tostring(
                state.show_only_assault and (scan.assault_sink_count or 0)
                    or (scan.loud_sink_count or 0)
            ),
            WARN = warn
        })
    end

    local function refresh_zones(force_chat)
        local scan = scan_zones()
        local changed = scan.signature ~= state.last_signature

        destroy_zone_shapes(state.zones)
        state.zones = scan.zones
        state.laser_segments = scan.laser_segments or {}
        state.last_signature = scan.signature
        state.refresh_requested = false

        if changed then
            state.zone_presence = {}
            state.zone_enter_time = {}
            state.zone_last_report_frame = {}
            state.zone_last_warn_frame = {}
            clear_array(state.visible_zone_refs)
            clear_array(state.fill_candidates)
            state.fill_candidate_count = 0
            state.last_fill_refresh_frame = -999999
        end

        if force_chat or changed then
            push_debug_chat(L("hvt_trigger_vis_prefix_scan"), build_scan_summary(scan), 2)
        end

        if changed and state.last_debug_signature ~= scan.signature then
            state.last_debug_signature = scan.signature
            push_debug_chat(L("hvt_trigger_vis_prefix_scan"), L("hvt_trigger_vis_detail_begin"), 3)

            local limit = math.min(#scan.zones, state.debug_dump_limit)
            for index = 1, limit do
                push_debug_chat(L("hvt_trigger_vis_prefix_zone"), string.format("[%d] %s", index, zone_summary(scan.zones[index])), 3)
                push_debug_chat(L("hvt_trigger_vis_prefix_info"), build_zone_purpose_text(scan.zones[index]), 3)
            end

            if #scan.zones > limit then
                push_debug_chat(L("hvt_trigger_vis_prefix_zone"), L("hvt_trigger_vis_more_zones", {
                    COUNT = tostring(#scan.zones - limit)
                }), 3)
            end

            push_debug_chat(L("hvt_trigger_vis_prefix_scan"), L("hvt_trigger_vis_detail_end"), 3)
        end
    end

    Hooks:PostHook(GameSetup, "update", "trigger_vis_draw_zones", function()
        if not state.enabled then
            return
        end

        state.frame_index = (state.frame_index or 0) + 1

        local player = managers and managers.player and managers.player:player_unit()
        if not alive(player) then
            return
        end

        local level_id = current_level_id()
        if state.last_level_id ~= level_id then
            state.last_level_id = level_id
            state.refresh_requested = true
            state.last_signature = nil
        end

        if state.refresh_requested then
            refresh_zones(false)
        end

        local player_pos = player:position()
        local visible_zones = state.visible_zone_refs
        local fill_candidates = state.fill_candidates
        local visible_count = 0
        local should_refresh_fill = state.fill_candidate_count <= 0
            or (state.frame_index - (state.last_fill_refresh_frame or -999999))
                >= math.max(1, state.fill_refresh_interval_frames or 1)
        local draw_distance_sq = state.distance * state.distance

        clear_array(visible_zones)

        if should_refresh_fill then
            clear_array(fill_candidates)
        end

        local fill_count = 0

        for _, zone in ipairs(state.zones) do
            local inside_zone = is_point_inside_zone(zone, player_pos)
            local was_inside_zone = state.zone_presence[zone.key]

            if inside_zone then
                if state.debug_on_enter and not was_inside_zone then
                    report_zone_enter(zone)
                end

                state.zone_presence[zone.key] = true
            elseif was_inside_zone then
                state.zone_presence[zone.key] = nil
                report_zone_exit(zone)
            end

            local distance_sq = distance_squared(player_pos, zone.position)

            if distance_sq <= draw_distance_sq then
                visible_count = visible_count + 1
                visible_zones[visible_count] = zone

                if should_refresh_fill then
                    local fill_distance_limit = zone.shape == "box"
                        and (state.box_wall_distance or state.fill_distance)
                        or state.fill_distance
                    local fill_distance_sq = fill_distance_limit * fill_distance_limit

                    if distance_sq <= fill_distance_sq and can_fill_zone(zone) then
                        fill_count = fill_count + 1

                        local entry = fill_candidates[fill_count]
                        if not entry then
                            entry = {}
                            fill_candidates[fill_count] = entry
                        end

                        entry.zone = zone
                        entry.draw_tools = get_zone_draw_tools(zone)
                        entry.distance_sq = distance_sq
                        entry.inside = inside_zone and true or false
                    end
                end
            end
        end

        if should_refresh_fill then
            for index = fill_count + 1, #fill_candidates do
                fill_candidates[index] = nil
            end
        end

        if should_refresh_fill and fill_count > 1 then
            table.sort(fill_candidates, function(left, right)
                if left.inside ~= right.inside then
                    return left.inside
                end

                return left.distance_sq < right.distance_sq
            end)
        end

        if should_refresh_fill then
            state.fill_candidate_count = math.min(fill_count, state.max_filled_zones or fill_count)
            state.last_fill_refresh_frame = state.frame_index
        end

        for index = 1, state.fill_candidate_count do
            local entry = fill_candidates[index]
            draw_zone_fill(entry.zone, entry.draw_tools, entry.distance_sq)
        end

        for index = 1, visible_count do
            local zone = visible_zones[index]
            draw_zone_outline(zone, get_zone_draw_tools(zone))
        end

        for _, segment in ipairs(state.laser_segments or {}) do
            local midpoint_distance_sq = distance_squared(player_pos, segment.midpoint)
            local draw_tools = get_laser_draw_tools(segment)
            local laser_limit = state.distance + (segment.length * 0.5)

            if midpoint_distance_sq <= (laser_limit * laser_limit) then
                draw_laser_segment(segment, draw_tools.pen, draw_tools.has_line, draw_tools.has_sphere)
            end
        end
    end)
end

shared_settings = visual_shared and visual_shared.settings or shared_settings
state.show_all_zones = shared_settings.show_all_zones == true
state.show_only_loud = not state.show_all_zones and (state.default_show_only_loud ~= false)
state.show_only_assault = not state.show_all_zones and (state.default_show_only_assault ~= false)
state.chat_mode = tonumber(shared_settings.trigger_vis_chat_mode) or (shared_settings.chat_debug_enabled == false and 1 or 2)
state.chat_debug_enabled = state.chat_mode ~= 1

if type(state.apply_visual_palette) == "function" then
    state.apply_visual_palette()
end

state.enabled = not state.enabled

if state.enabled then
    state.refresh_requested = true
else
    if type(state.destroy_zone_shapes) == "function" then
        state.destroy_zone_shapes(state.zones)
    end
    state.zone_presence = {}
    state.zone_enter_time = {}
end

if managers and managers.chat and tweak_data and tweak_data.system_chat_color then
    local chat_mode_key = state.chat_mode <= 1 and "hvt_trigger_vis_chat_off"
        or (state.chat_mode == 2 and "hvt_trigger_vis_chat_useful" or "hvt_trigger_vis_chat_verbose")
    local mode_key = state.show_all_zones and "hvt_trigger_vis_mode_all_zones"
        or (state.show_only_assault and "hvt_trigger_vis_mode_assault" or "hvt_trigger_vis_mode_filtered_loud")

    managers.chat:_receive_message(
        1,
        "SYSTEM",
        state.enabled
            and L("hvt_trigger_vis_enabled", {
                MODE = L(mode_key),
                CHAT = L(chat_mode_key)
            })
            or L("hvt_trigger_vis_disabled"),
        tweak_data.system_chat_color
    )
end
