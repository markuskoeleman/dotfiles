-- The last link picked for preview, with the view it was picked in.
local preview = nil

lektra.cmd.register("link_hint_open_preview", function()
    local view = lektra.view.current()
    if not view then
        return
    end

    view:link_hints("pick", function(link)
        -- link is nil when the user cancels with Escape
        if not link then
            return
        end
        preview = { view = view, link = link }
        view:preview(link)
    end)
end, "Preview a link hint in the current view")

lektra.cmd.register("preview_jump_to_location", function()
    if not preview then
        return
    end

    -- Follow in the view the link was picked in, not whichever is current now.
    -- follow_link returns false for a bad link, and nothing if the view is gone.
    local ok = preview.view:follow_link(preview.link)
    if ok then
        preview = nil
    end
end, "Jump to the location currently in preview")

lektra.keymap.set("link_hint_open_preview", {"Shift+U"})
lektra.keymap.set("preview_jump_to_location", {"Shift+Return"})
