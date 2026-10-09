if FPSCap_MenuManager_Hooked then
    return
else
    FPSCap_MenuManager_Hooked = true
end

local limits = {
    3, 6, 8, 9, 10, 15,
    30, 45, 60, 75, 90, 105, 120, 135,
    150, 175, 200, 225, 250, 275, 300
}

local modify_adv_video_actual = MenuOptionInitiator.modify_adv_video

function MenuOptionInitiator:modify_adv_video(node, ...)
    if limits then
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
    end

    return modify_adv_video_actual(self, node, ...)
end
