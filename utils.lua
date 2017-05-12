
local lgi = require 'lgi'
local GLib = lgi.GLib
local Gtk = lgi.Gtk

local M = {}

------------------------------------------------------------------------------

local debounce_ids = {}

--
--
-- See explanation for debounce on the internet:
--
--   https://www.google.co.il/search?q=debounce+javascript
--
function M.debounce(id, fn, ms)
  -- Remove the pending timeout (if exists).
  if debounce_ids[id] then
    GLib.source_remove(debounce_ids[id])
  end
  -- Install a new one.
  debounce_ids[id] = GLib.timeout_add(
    GLib.PRIORITY_DEFAULT, ms, function()
      debounce_ids[id] = nil
      fn()
      return false  -- don't repeat.
    end
  )
end

------------------------------------------------------------------------------

local eps = 0.01

--
-- Finds a number in an array.
--
function M.array_num_find(arr, val)
  for i = 1, #arr do
    if arr[i] > val - eps and arr[i] < val + eps then
      return i
    end
  end
end

--
-- Finds nearest number in an array.
--
function M.array_num_find_nearest(arr, val)
  local smallest_diff = nil
  local smallest_diff_idx = nil

  for i = 1, #arr do
    local diff = math.abs(val - arr[i])
    if not smallest_diff or diff < smallest_diff then
      smallest_diff = diff
      smallest_diff_idx = i
    end
  end

  return smallest_diff_idx
end

------------------------------------------------------------------------------

function M.message_box(wnd, title, text)
  local message = Gtk.MessageDialog {
    text = title,
    secondary_text = text,
    secondary_use_markup = true,
    message_type = Gtk.MessageType.INFO,
    buttons = Gtk.ButtonsType.CLOSE,
    transient_for = wnd,
  }
  message:run()
  message:destroy()
end

------------------------------------------------------------------------------

--
-- A hack to trigger code to run when the app is shown fully for the 1st time.
--
-- (for some reason GLib.idle_add() doesn't work as expected: it's triggered
-- before the sizes are allocated.)
--

local on_first_run_done = {}

function M.on_first_run(wgt, fn)
  wgt.on_draw = function()
    if not on_first_run_done[wgt] then
      on_first_run_done[wgt] = true
      fn()
    end
  end
end

------------------------------------------------------------------------------

return M
