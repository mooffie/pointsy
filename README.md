Pointsy
=======

Pointsy is a simple GUI app for marking **points** on an image (or two
images, displayed side by side).

Pointsy can be used for marking **rectangles** and **paths** too, since
points are displayed with horizontal and vertical rulers, or with lines
connecting them.

You can then feed these points to some other tools.

(A very similar app is [panopoints](http://panopoints.sourceforge.net/),
which unfortunately uses the deprecated Gtk 1.2.)

Examples
--------

Pointsy is provided with a few example scripts (which all use
ImageMagick's `convert`):

- **crop**: Crops an image.

- **join-on-point**: Stitches two images based on a point they have in
  common (e.g., useful for joining two halves of a big newspaper page
  scanned with a common A4 scanner).

- **levels**: Like the similar tool in GIMP. You're shown a histogram and
  you need to mark two points in it (for "black" and "white").

- **balance**: If your scanner produces reddish or bluish images, this
  tool lets you fix them by marking a rectangle that's supposed to be white
  (or grey).

When dealing with many images these scripts are easier to work with than
a full-blown image editor (as GIMP or Photoshop) because you doesn't need
to mess with menus and dialog boxes. You just need to select a couple of
points, press Enter, and you're done.

Requirements
------------

- Lua modules: lgi, Penlight, LuaFileSystem (because of Penlight). Tip:
  if you're on a Debian-based system, do
  `apt-get install lua-lgi lua-penlight lua-filesystem`

- Lua 5.1 or 5.2 (there's going to an issue with Lua 5.3 as the
  point coordinates are float values and the example scripts use "%d").

- Gtk 3
