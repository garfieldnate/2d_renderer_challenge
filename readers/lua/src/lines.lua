-- Chapter 3: Bresenham's line and Wu's line.
local canvas_mod = require("canvas")
local color_mod = require("color")
local write_pixel = canvas_mod.write_pixel
local pixel_at = canvas_mod.pixel_at
local mix = color_mod.mix

local function line_bresenham(c, x0, y0, x1, y1, col)
  local steep = math.abs(y1 - y0) > math.abs(x1 - x0)

  if steep then x0, y0, x1, y1 = y0, x0, y1, x1 end
  if x0 > x1 then x0, y0, x1, y1 = x1, y1, x0, y0 end
  local dx = x1 - x0
  local dy = math.abs(y1 - y0)
  local ystep = (y0 < y1) and 1 or -1
  local err = dx // 2
  local y = y0
  for x = x0, x1 do
    if steep then write_pixel(c, y, x, col) else write_pixel(c, x, y, col) end
    err = err - dy
    if err < 0 then
      y = y + ystep
      err = err + dx
    end
  end
end

-- plot(c, x, y, col, weight): paint_through for one pixel, always in light,
-- bounds-checked because it has to read the pixel first.
local function plot(c, x, y, col, weight)
  if weight == 0 then return end
  if x < 0 or x >= c.width or y < 0 or y >= c.height then return end
  local p = pixel_at(c, x, y)
  write_pixel(c, x, y, mix(p, col, weight, true))
end

local function line_wu(c, x0, y0, x1, y1, col)
  local steep = math.abs(y1 - y0) > math.abs(x1 - x0)

  if steep then x0, y0, x1, y1 = y0, x0, y1, x1 end
  if x0 > x1 then x0, y0, x1, y1 = x1, y1, x0, y0 end
  local dx = x1 - x0
  local slope = (dx == 0) and 0 or (y1 - y0) / dx
  for x = x0, x1 do
    local y = y0 + (x - x0) * slope
    local yi = math.floor(y)
    local f = y - yi
    if steep then
      plot(c, yi, x, col, 1 - f)
      plot(c, yi + 1, x, col, f)
    else
      plot(c, x, yi, col, 1 - f)
      plot(c, x, yi + 1, col, f)
    end
  end
end

local function total_ink(c)
  local s = 0
  for i = 1, c.width * c.height do s = s + c.pixels[i].r end
  return s
end

return {
  line_bresenham = line_bresenham,
  line_wu = line_wu,
  plot = plot,
  total_ink = total_ink,
}
