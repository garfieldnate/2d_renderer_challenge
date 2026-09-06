-- Chapter 1/2: PPM output, P3 (text) and P6 (binary), and the file readers
-- the tests use to compare against the book's reference images.
local color_mod = require("color")
local canvas_mod = require("canvas")
local clamp01 = color_mod.clamp01
local encode = color_mod.encode
local pixel_at = canvas_mod.pixel_at

local function to_byte(light)
  local e = encode(clamp01(light))
  return math.floor(e * 255 + 0.5)
end

local function canvas_to_ppm(c)
  local lines = { "P3", c.width .. " " .. c.height, "255" }
  for y = 0, c.height - 1 do
    local line = ""
    for x = 0, c.width - 1 do
      local p = pixel_at(c, x, y)
      local vals = { to_byte(p.r), to_byte(p.g), to_byte(p.b) }
      for _, v in ipairs(vals) do
        local s = tostring(v)
        if line == "" then
          line = s
        elseif #line + 1 + #s > 70 then
          lines[#lines + 1] = line
          line = s
        else
          line = line .. " " .. s
        end
      end
    end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n") .. "\n"
end

local function canvas_to_p6(c)
  local parts = { "P6\n" .. c.width .. " " .. c.height .. "\n255\n" }
  for y = 0, c.height - 1 do
    for x = 0, c.width - 1 do
      local p = pixel_at(c, x, y)
      parts[#parts + 1] = string.char(to_byte(p.r), to_byte(p.g), to_byte(p.b))
    end
  end
  return table.concat(parts)
end

-- Parses either format into {width, height, channels} where channels is a
-- flat 1-indexed array of numbers 0..255, row major, r g b r g b ...
local function parse_ppm(s)
  if s:sub(1, 2) == "P6" then
    local pos = 3
    local function next_token()
      while true do
        local b = s:byte(pos)
        if b == 32 or b == 9 or b == 10 or b == 13 then pos = pos + 1 else break end
      end
      local start = pos
      while true do
        local b = s:byte(pos)
        if b == nil or b == 32 or b == 9 or b == 10 or b == 13 then break end
        pos = pos + 1
      end
      return s:sub(start, pos - 1)
    end
    local w = tonumber(next_token())
    local h = tonumber(next_token())
    local _maxv = next_token()
    pos = pos + 1 -- exactly one whitespace byte after maxval
    local channels = {}
    local n = w * h * 3
    for i = 1, n do
      channels[i] = s:byte(pos + i - 1)
    end
    return { width = w, height = h, channels = channels }
  else
    local tokens = {}
    for tok in s:gmatch("%S+") do tokens[#tokens + 1] = tok end
    local w = tonumber(tokens[2])
    local h = tonumber(tokens[3])
    local channels = {}
    local n = w * h * 3
    for i = 1, n do
      channels[i] = tonumber(tokens[4 + i])
    end
    return { width = w, height = h, channels = channels }
  end
end

local function ppm_pixel(ppm, x, y)
  local parsed = parse_ppm(ppm)
  local base = (y * parsed.width + x) * 3
  return parsed.channels[base + 1], parsed.channels[base + 2], parsed.channels[base + 3]
end

local function distinct_values(ppm)
  local parsed = parse_ppm(ppm)
  local seen = {}
  local count = 0
  for _, v in ipairs(parsed.channels) do
    if not seen[v] then
      seen[v] = true
      count = count + 1
    end
  end
  return count
end

local function max_channel_difference(a, b)
  local pa, pb = parse_ppm(a), parse_ppm(b)
  if pa.width ~= pb.width or pa.height ~= pb.height then return 255 end
  local m = 0
  for i = 1, #pa.channels do
    local d = math.abs(pa.channels[i] - pb.channels[i])
    if d > m then m = d end
  end
  return m
end

local function read_file(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path)
  local data = f:read("a")
  f:close()
  return data
end

-- test helpers for line-based P3 assertions -------------------------------
local function ppm_lines(ppm)
  local lines = {}
  for line in (ppm .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  return lines
end

return {
  to_byte = to_byte,
  canvas_to_ppm = canvas_to_ppm,
  canvas_to_p6 = canvas_to_p6,
  parse_ppm = parse_ppm,
  ppm_pixel = ppm_pixel,
  distinct_values = distinct_values,
  max_channel_difference = max_channel_difference,
  read_file = read_file,
  ppm_lines = ppm_lines,
}
