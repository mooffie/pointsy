
local lgi = require 'lgi'
local Gtk = lgi.Gtk
local Gdk = lgi.Gdk
local GdkPixbuf = lgi.GdkPixbuf
local tablex = require 'pl.tablex'

local utils = require 'utils'  -- our own module.

------------------------------------------------------------------------------

local Pointsy = lgi.package 'Pointsy'

Pointsy:class('Canvas', Gtk.DrawingArea)

------------------------------------------------------------------------------

local slow_computer = true

local DEFAULTS = {
  -- The viewport (scaling and panning)
  scale = 1.0,
  xoffs = 0,
  yoffs = 0,

  -- The points
  points = nil,  -- array
  current_point = 0,

  show_as_path = false,  -- whether to connect the dot.

  -- Image data
  img_pixbuf = nil,
  img_width = nil,
  img_height = nil,
  filepath = nil,

  -- Misc state
  drag_start_x = nil,
  drag_start_y = nil,
}

------------------------------------------------------------------------------
--
-- Utils.
--

function Pointsy.Canvas:image_coords_from_widget(wx, wy)
  local g = self.priv
  return (wx / g.scale - g.xoffs), (wy / g.scale - g.yoffs)
end

function Pointsy.Canvas:widget_coords_from_image(ix, iy)
  local g = self.priv
  return (ix + g.xoffs) * g.scale, (iy + g.yoffs) * g.scale
end

------------------------------------------------------------------------------
--
-- Scaling (zooming).
--

--
-- Scale, and also adjust xoffs/yoffs so that the spot under the mouse remains at the same place.
--
function Pointsy.Canvas:scale_around_widget_point(wx, wy, new_scale)
  local g = self.priv
  local ix, iy = self:image_coords_from_widget(wx, wy)
  g.scale = new_scale
  g.xoffs = -( ix - (wx / new_scale) )
  g.yoffs = -( iy - (wy / new_scale) )
end

-- Nice logarithmic scales borrowed from Gimp.
local scales = { 0.0312, 0.0435, 0.0625, 0.0909, 0.125, 0.182, 0.25, 0.333, 0.50, 0.667,
                 1.0, 1.5, 2.0, 3.0, 4.0, 5.5, 8.0, 11.0, 16.0, 23.0, 32.0, 45.0, 64.0 }

--
-- Scale in or out ('direction' is either 1 or -1).
--
function Pointsy.Canvas:do_scale(direction, wx, wy)
  local g = self.priv

  local idx = utils.array_num_find_nearest(scales, g.scale)
  local new_scale = idx and scales[idx + direction] or g.scale

  self:scale_around_widget_point(wx, wy, new_scale)
end

------------------------------------------------------------------------------
--
-- Mouse handling
--

local function on_button_press_event(self, ev)

  local g = self.priv

  self:grab_focus()

  g.drag_start_x = ev.x
  g.drag_start_y = ev.y

  --
  -- Ctrl+click: create a point.
  --
  if ev.state.CONTROL_MASK then
    local ix, iy = self:image_coords_from_widget(ev.x, ev.y)
    self:point_new(ix, iy)
    self:queue_draw()
  end

end

local function on_scroll_event(self, ev)
  if ev.direction == 'UP' then
    self:do_scale(1, ev.x, ev.y)
  else
    self:do_scale(-1, ev.x, ev.y)
  end
  self:queue_draw()
end

local function on_motion_notify_event(self, ev)
  local g = self.priv

  local dx = (ev.x - g.drag_start_x) / g.scale
  local dy = (ev.y - g.drag_start_y) / g.scale

  g.xoffs = g.xoffs + dx
  g.yoffs = g.yoffs + dy

  -- For next motion:
  g.drag_start_x = ev.x
  g.drag_start_y = ev.y

  self:delayed_refresh()
end

------------------------------------------------------------------------------
--
-- Points manipulation.
--

function Pointsy.Canvas:point_prev()
  -- Not implemented.
end

function Pointsy.Canvas:point_next()
  local g = self.priv
  g.current_point = (g.current_point % #g.points)  + 1
end

function Pointsy.Canvas:point_delete()
  local g = self.priv
  table.remove(g.points, g.current_point)
  if g.current_point > #g.points then
    g.current_point = #g.points
  end
end

function Pointsy.Canvas:point_move(dx, dy)
  local g = self.priv
  local pt = g.points[g.current_point]
  if pt then
    pt.x, pt.y = pt.x + dx, pt.y + dy
  end
end

function Pointsy.Canvas:point_new(x, y)
  local g = self.priv
  g.current_point = #g.points + 1
  g.points[g.current_point] = { x = x, y = y }
end

------------------------------------------------------------------------------
--
-- Fitting / anchoring.
--

function Pointsy.Canvas:fit_width()
  local g = self.priv
  if g.img_width ~= 0 then
    g.scale = self.width / g.img_width
    g.xoffs, g.yoffs = 0, 0
  end
end

function Pointsy.Canvas:fit_height()
  local g = self.priv
  if g.img_height ~= 0 then
    g.scale = self.height / g.img_height
    g.xoffs, g.yoffs = 0, 0
  end
end

function Pointsy.Canvas:anchor_south()
  local g = self.priv
  if g.img_height ~= 0 then
    local ipixels = self.height / g.scale
    g.yoffs = -(g.img_height - ipixels)
  end
end

function Pointsy.Canvas:anchor_east()
  local g = self.priv
  if g.img_width ~= 0 then
    local ipixels = self.width / g.scale
    g.xoffs = -(g.img_width - ipixels)
  end
end

function Pointsy.Canvas:anchor_north()
  local g = self.priv
  g.yoffs = 0
end

function Pointsy.Canvas:anchor_west()
  local g = self.priv
  g.xoffs = 0
end

function Pointsy.Canvas:shift(screen_pixels_x, screen_pixels_y)
  local g = self.priv
  g.xoffs = g.xoffs - (screen_pixels_x / g.scale)
  g.yoffs = g.yoffs - (screen_pixels_y / g.scale)
end

------------------------------------------------------------------------------
--
-- Keyboard handling
--

local function on_key_press_event(self, ev)

  -- See gdkkeysyms.h

  local speed = (ev.state.CONTROL_MASK and 5 or 1)

  local acts = {
    [Gdk.KEY_space] = self.point_next,
    [Gdk.KEY_w] = self.fit_width,
    [Gdk.KEY_h] = self.fit_height,
    [Gdk.KEY_W] = self.fit_width,  -- uppercase for compatibility with mupdf.
    [Gdk.KEY_H] = self.fit_height, -- ditto.
    [Gdk.KEY_p] = function() self.priv.show_as_path = not self.priv.show_as_path end,
    [Gdk.KEY_Delete] = self.point_delete,
    [Gdk.KEY_KP_Delete] = self.point_delete,
    [Gdk.KEY_BackSpace] = self.point_delete,
    [Gdk.KEY_Up] = function() self:point_move(0, -1*speed) end,
    [Gdk.KEY_Down] = function() self:point_move(0, 1*speed) end,
    [Gdk.KEY_Left] = function() self:point_move(-1*speed, 0) end,
    [Gdk.KEY_Right] = function() self:point_move(1*speed, 0) end,
  }

  if acts[ev.keyval] then
    acts[ev.keyval](self)
    self:queue_draw()
    return true  -- prevent arrows key from switching to other widgets ( http://gtk.10911.n7.nabble.com/keeping-focus-td33579.html )
  end

end

------------------------------------------------------------------------------
--
-- Drawing.
--

function Pointsy.Canvas:enable_image_coords(cr)
  local g = self.priv
  cr:scale(g.scale,g.scale)
  cr:translate(g.xoffs,g.yoffs)

  -- We do this here as a convenience:
  --
  -- Set the line width to that of one image pixel.
  --
  -- We can't just do 'cr.line_width = 1' because if the view is shrunk,
  -- an image pixel may be too small to appear on the "device" (screen).
  local min_visible_line_width = cr:device_to_user_distance(1, 0)
  cr.line_width = math.max(1, min_visible_line_width)
end

function Pointsy.Canvas:disable_image_coords(cr)
  local g = self.priv
  cr:translate(-g.xoffs,-g.yoffs)
  cr:scale(1/g.scale,1/g.scale)
end

function Pointsy.Canvas:draw_rulers(cr)
  local g = self.priv
  local points = g.points

  cr:set_source_rgb(0, 1.0, 0)  -- green

  for _, pt in ipairs(points) do
    cr:move_to(0, pt.y)
    cr:line_to(g.img_width, pt.y)
    cr:move_to(pt.x, 0)
    cr:line_to(pt.x, g.img_height)
    cr:stroke()
  end
end

function Pointsy.Canvas:draw_path(cr)
  local g = self.priv
  local points = g.points

  cr:set_source_rgb(0, 1.0, 0)  -- green

  for i, pt in ipairs(points) do
    if i == 1 then
      cr:move_to(pt.x, pt.y)
    else
      cr:line_to(pt.x, pt.y)
    end
  end
  cr:stroke()
end

function Pointsy.Canvas:draw_points(cr)
  local g = self.priv
  local points = g.points

  self:disable_image_coords(cr)

  if self.is_focus then
    cr.line_width = 2
  else
    cr.line_width = 1
  end

  for pt_idx, pt in ipairs(points) do
    local wx, wy = self:widget_coords_from_image(pt.x, pt.y)
    -- Little red square:
    cr:set_source_rgb(1.0, 0, 0)
    cr:rectangle(wx-2, wy-2, 5, 5)
    cr:fill()
    -- Yellow "target":
    if pt_idx == g.current_point then
      cr:set_source_rgb(1.0, 1.0, 0)
      cr:arc(wx, wy, 10, 0, 2*3.14)
      cr:stroke()
    end
  end
end

local function on_draw(self, cr)
  local g = self.priv

  -- The image is antialiased when zoomed. Perhaps this makes things slow?
  -- But it seems as if we can't turn this feature off.
  --cr.antialias = 'NONE' -- Has no effect on images, alas.

  self:enable_image_coords(cr)

  if g.img_pixbuf then
    cr:set_source_pixbuf(g.img_pixbuf, 0, 0)
    cr:paint()
  end

  if g.show_as_path then
    self:draw_path(cr)
  else
    self:draw_rulers(cr)
  end
  self:draw_points(cr)
end

--
-- :queue_draw() purports to do a good job, but it doesn't. Here's
-- a wrapper that, effectively, compresses multiple draw() requests into one.
--
function Pointsy.Canvas:delayed_refresh()

  if slow_computer then
    utils.debounce('delayed-refresh', function()
      print "----------- delayed refresh -----------"
      self:queue_draw()
    end, 100)
  else
    self:queue_draw()
  end

end

------------------------------------------------------------------------------
--
-- Data.
--

function Pointsy.Canvas:get_data()

  local g = self.priv

  local data = {
    filepath = g.filepath,
    width = g.img_width,
    height = g.img_height,
    points = g.points,
  }

  return data

end

function Pointsy.Canvas:set_points(new_points)
  local g = self.priv
  g.points = new_points
  g.current_point = #g.points
end

function Pointsy.Canvas:get_state()
  return tablex.copy(self.priv)
end

function Pointsy.Canvas:set_state(new_state)
  local old_state = self:get_state()
  tablex.clear(self.priv)
  tablex.update(self.priv, new_state)
  return old_state
end

function Pointsy.Canvas:copy_viewport(other_canvas)
  local g, go = self.priv, other_canvas.priv
  g.scale = go.scale
  g.xoffs = go.xoffs
  g.yoffs = go.yoffs
end

------------------------------------------------------------------------------
--
-- Construction.
--

function Pointsy.Canvas:load_image(filepath)
  local g = self.priv

  if filepath then
    g.img_pixbuf = assert(GdkPixbuf.Pixbuf.new_from_file(filepath), "Cannot load image " .. filepath)
    g.filepath = filepath
    g.img_width = g.img_pixbuf.width
    g.img_height = g.img_pixbuf.height
  else
    g.img_width = 0
    g.img_height = 0
  end
end

function Pointsy.Canvas:_init()

  self.can_focus = true

  -- Register to a few mouse events not normally sent to a widget.
  self:add_events(Gdk.EventMask {
    'BUTTON_PRESS_MASK',
    'BUTTON_RELEASE_MASK',
    'BUTTON1_MOTION_MASK',  -- "receive pointer motion events while 1 button is pressed"
    'SCROLL_MASK',  -- mouse wheel
  })

  self.on_button_press_event = on_button_press_event
  self.on_motion_notify_event = on_motion_notify_event
  self.on_key_press_event = on_key_press_event
  self.on_scroll_event = on_scroll_event
  self.on_draw = on_draw

  self.width, self.height = 100, 100

  for k, v in pairs(DEFAULTS) do
    self.priv[k] = v
  end
  self.priv.points = {}

  self:load_image(nil)

end
