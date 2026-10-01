-- Reference: input overrides for CachyOS.
--
-- Copy to ~/.config/hypr/input.lua after installing. The installer does not
-- create this file, because Omarchy ships its own and overwriting it would
-- throw away the documented upstream options.
--
-- Why this file has to exist
-- --------------------------
-- Omarchy 4.x sets, in /usr/share/omarchy/default/hypr/input.lua:
--
--     local kb_options = "compose:caps,shift:both_capslock_cancel"
--
-- `compose:caps` reassigns the Caps Lock key to Compose. Compose does not
-- toggle a caps state, it waits for a compose sequence, so Caps Lock stops
-- producing uppercase and the keyboard's caps LED never lights. This is
-- upstream's deliberate choice, not a CachyOS bug and not something the
-- installer patches.
--
-- Set kb_options = "" below to make Caps Lock toggle uppercase again. You give
-- up the Compose key, which almost nobody uses on a daily desktop.
--
-- Do NOT edit /usr/share/omarchy/default/hypr/input.lua. That file is owned by
-- the omarchy package and is regenerated on every `omarchy update`, so the
-- change would be silently reverted.
--
-- Why the override in ~/.config wins
-- ---------------------------------
-- hyprland.lua dofiles /usr/share/omarchy/default/hypr/bootstrap.lua, which sets
--
--     package.path = ~/.local/state/?.lua; ~/.config/?.lua; $OMARCHY_PATH/?.lua; ...
--
-- so a module under ~/.config/hypr/ is found before the packaged default. The
-- shipped ~/.config/hypr/input.lua is entirely commented out, which is why an
-- unedited install still gets the packaged `compose:caps` behaviour: the file
-- exists and therefore wins the lookup, but overrides nothing.
--
-- Layout
-- ------
-- Do not set kb_layout here. Omarchy's default input.lua reads XKBLAYOUT from
-- /etc/vconsole.conf, so a CachyOS install that already declares `es` needs no
-- override at all. Setting kb_layout would only duplicate that and risk
-- diverging from the console layout.
--
-- Applied on: Tiger Lake Iris Xe, Hyprland 0.56.2, Omarchy 4.0.4.

hl.config({
  input = {
    kb_options = "",
  },
})
