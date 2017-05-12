
local M = {}

------------------------------------------------------------------------------
--
-- Utils
--

local utils = {}

-- Returns a pathname's extension, or '.png' if it finds none.
function utils.get_ext(path)
  return path:match '%.[^.]+$' or '.png'
end

local gen_tmp_file_id = os.time()
local gen_tmp_file_idx = 1
function utils.gen_tmp_file(ext)
  gen_tmp_file_idx = gen_tmp_file_idx + 1
  return ("/tmp/img.%s-%d%s"):format(
    gen_tmp_file_id, gen_tmp_file_idx, ext or ".png")
end

function utils.prepare_command(cmd_tmplt, ...)
  cmd_tmplt = cmd_tmplt:gsub('{{BASEDIR}}', function()
    return (require 'pl.path'.dirname(arg[0]))  -- Where the script is located.
  end)
  return cmd_tmplt:format(...)
end

function utils.run_command(cmd_tmplt, ...)
  local cmd = utils.prepare_command(cmd_tmplt, ...)
  print(cmd)
  return os.execute(cmd)
end

function utils.run_pcommand(cmd_tmplt, ...)
  local cmd = utils.prepare_command(cmd_tmplt, ...)
  print(cmd)
  return io.popen(cmd):read('*all')
end

-- Pretty printer.
function utils.pp(obj)
  print(require 'pl.pretty'.write(obj))
end

M.utils = utils  -- so modules require()'ing us can use this code.

------------------------------------------------------------------------------

local run_command = utils.run_command
local run_pcommand = utils.run_pcommand
local get_ext = utils.get_ext
local gen_tmp_file = utils.gen_tmp_file

------------------------------------------------------------------------------

function M.add_border(img, length, color)
  local output = gen_tmp_file()
  run_command("convert %s -bordercolor %s -border %dx%d %s",
    img, color, length, length, output)
  return output
end

function M.add_border_left(img, length, color)
  local output = gen_tmp_file()
  -- We're doing two thing: adding border (on both side; that's a limitation of -border), then chopping the left side.
  -- see http://www.imagemagick.org/Usage/crop/#chop
  run_command("convert %s -bordercolor %s -border %dx0 -gravity East -chop %dx0 %s",
    img, color, length, length, output)
  return output
end

function M.cut_top(img, length)
  local output = gen_tmp_file()
  run_command("convert %s -chop 0x%d %s",
             img, length, output)
  return output
end

function M.cut_bottom(img, length)
  local output = gen_tmp_file()
  run_command("convert %s -gravity South -chop 0x%d %s",
             img, length, output)
  return output
end

function M.vertical_concat(img1, img2)
  local output = gen_tmp_file()
  run_command("convert -append %s %s %s",
             img1, img2, output)
  return output
end

function M.crop(img, x1, y1, x2, y2)
  local output = gen_tmp_file()
  if x1 > x2 then
    x1, x2 = x2, x1
  end
  if y1 > y2 then
    y1, y2 = y2, y1
  end
  run_command("convert %q -crop %dx%d+%d+%d +repage %q",
             img, x2 - x1, y2 - y1, x1, y1, output)
  return output
end

function M.convert(img1, img2)
  local same_type = (get_ext(img1) == get_ext(img2))
  run_command((same_type and "cp" or "convert") .. " %q %q",
             img1, img2)
end

function M.create_histogram(img, show_value, fast)
  local output = gen_tmp_file()
  local extra = ''

  -- See http://www.imagemagick.org/Usage/files/#histogram
  -- quotes taken from there.

  if fast then
    extra = extra .. " -define histogram:unique-colors=false"
    -- see: "This comment can take a very long time to create. As of IM v6.6.1-5, you can add the [...]"
  end

  if show_value then
    -- We want the histogram to show only the "Value", as in GIMP, not three R/G/B channels.
    -- So we convert the image to grayscale first.
    extra = extra .. " -grayscale Brightness"
    -- There are other types of grayscale (see http://www.imagemagick.org/script/command-line-options.php?#intensity )
    -- but "Brightness" is the one GIMP seems to show in its Level dialog.
  end

  run_command("convert %q %s histogram:%q", img, extra, output)

  if show_value then
    -- Make the graph black on white background. Just for aesthetics.
    local new_output = gen_tmp_file()
    run_command("convert %q -negate %q", output, new_output)
    output = new_output
  end

  return output
end

-- Clamps a value, x, to [min..max].
local function clamp(x, min, max)
  return (x > max and max) or (x < min and min) or x
end

function M.levels(img, v1, v2)
  local output = gen_tmp_file()
  if v1 > v2 then
    v1, v2 = v2, v1
  end
  v1 = clamp(v1, 0, 255)
  v2 = clamp(v2, 0, 255)
  -- The following should work, but the "Substract" gives surprising result.
  --run_command("convert %q -evaluate Subtract %f -evaluate Multiply %f %q",
  --  img, v1, 255 / (v2 - v1), output)
  run_command("convert %q -level %g%%,%g%% %q",
    img, v1 * 100 / 255, v2 * 100 / 255, output)
  return output
end

-- Returns the average pixel value (r,g,b) of an image.
function M.average(img)
  -- google: imagemagick average pixel
  local vals = run_pcommand("convert %q -scale 1x1! -depth 8 " ..
      "-format '%%[fx:int(255*r+.5)],%%[fx:int(255*g+.5)],%%[fx:int(255*b+.5)]' info:-",
    img)
  local r, g, b = vals:match('(%d+),(%d+),(%d+)')
  if not b then
    error("average() error")
  end
  return r,g,b
end

-- Multiply the r/g/b values.
function M.multiply(img, rx, gx, bx)
  local output = gen_tmp_file()
  run_command("convert %q " ..
     "-channel r -evaluate multiply %g " ..
     "-channel g -evaluate multiply %g " ..
     "-channel b -evaluate multiply %g " ..
     "%q",
    img, rx, gx, bx, output)
  return output
end

return M
