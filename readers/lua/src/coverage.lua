-- Chapter 2: the coverage buffer, magnify, and paint_through.
local canvas_mod = require("canvas")
local color_mod = require("color")
local canvas = canvas_mod.canvas
local write_pixel = canvas_mod.write_pixel
local pixel_at = canvas_mod.pixel_at
local mix = color_mod.mix

local function coverage_buffer(w, h)
  local data = {}
  for i = 1, w * h do data[i] = 0 end
  return { width = w, height = h, data = data }
end

local function cidx(cov, x, y) return y * cov.width + x + 1 end

local function coverage_at(cov, x, y)
  if x < 0 or x >= cov.width or y < 0 or y >= cov.height then return 0 end
  return cov.data[cidx(cov, x, y)]
end

local function set_coverage(cov, x, y, v)
  if x < 0 or x >= cov.width or y < 0 or y >= cov.height then return end
  cov.data[cidx(cov, x, y)] = v
end

local function ink(cov)
  local s = 0
  for i = 1, cov.width * cov.height do s = s + cov.data[i] end
  return s
end

local function magnify(c, k)
  local out = canvas(c.width * k, c.height * k)
  for y = 0, c.height - 1 do
    for x = 0, c.width - 1 do
      local p = pixel_at(c, x, y)
      for dy = 0, k - 1 do
        for dx = 0, k - 1 do
          write_pixel(out, x * k + dx, y * k + dy, p)
        end
      end
    end
  end
  return out
end

local function paint_through(c, cov, col)
  for y = 0, c.height - 1 do
    for x = 0, c.width - 1 do
      local cv = coverage_at(cov, x, y)
      if cv > 0 then
        local p = pixel_at(c, x, y)
        write_pixel(c, x, y, mix(p, col, cv, true))
      end
    end
  end
end

-- chapter 6's helper, chapter 1's max_channel_difference for coverage buffers
local function max_coverage_difference(a, b)
  if a.width ~= b.width or a.height ~= b.height then return 1 end
  local m = 0
  for i = 1, a.width * a.height do
    local d = math.abs(a.data[i] - b.data[i])
    if d > m then m = d end
  end
  return m
end

return {
  coverage_buffer = coverage_buffer,
  coverage_at = coverage_at,
  set_coverage = set_coverage,
  ink = ink,
  magnify = magnify,
  paint_through = paint_through,
  max_coverage_difference = max_coverage_difference,
}
