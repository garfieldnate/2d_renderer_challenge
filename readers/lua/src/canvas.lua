-- Chapter 1: the canvas. Origin top left, x the column, y the row.
local color_mod = require("color")
local color = color_mod.color

local function canvas(w, h)
  local pixels = {}
  for i = 1, w * h do pixels[i] = color(0, 0, 0) end
  return { width = w, height = h, pixels = pixels }
end

local function idx(c, x, y) return y * c.width + x + 1 end

local function write_pixel(c, x, y, col)
  if x < 0 or x >= c.width or y < 0 or y >= c.height then return end
  c.pixels[idx(c, x, y)] = color(col.r, col.g, col.b)
end

local function pixel_at(c, x, y)
  return c.pixels[idx(c, x, y)]
end

local function fill(c, col)
  for i = 1, c.width * c.height do c.pixels[i] = color(col.r, col.g, col.b) end
end

-- not a book function: a plain copy, used by chapter 4's f_both_orders
local function copy_canvas(c)
  local out = canvas(c.width, c.height)
  for i = 1, c.width * c.height do out.pixels[i] = color(c.pixels[i].r, c.pixels[i].g, c.pixels[i].b) end
  return out
end

return {
  canvas = canvas,
  write_pixel = write_pixel,
  pixel_at = pixel_at,
  fill = fill,
  copy_canvas = copy_canvas,
}
