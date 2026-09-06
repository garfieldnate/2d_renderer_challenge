-- Chapter 1: color, the sRGB transfer functions, and mix.
local Color = {}
Color.__index = Color

local function color(r, g, b)
  return setmetatable({ r = r, g = g, b = b }, Color)
end

function Color.__add(a, b) return color(a.r + b.r, a.g + b.g, a.b + b.b) end
function Color.__sub(a, b) return color(a.r - b.r, a.g - b.g, a.b - b.b) end
function Color.__mul(a, b)
  if type(b) == "number" then return color(a.r * b, a.g * b, a.b * b) end
  if type(a) == "number" then return color(a * b.r, a * b.g, a * b.b) end
  return color(a.r * b.r, a.g * b.g, a.b * b.b) -- Hadamard product
end
function Color.__tostring(c)
  return string.format("color(%.6g, %.6g, %.6g)", c.r, c.g, c.b)
end

local function decode(v)
  if v <= 0.04045 then return v / 12.92 else return ((v + 0.055) / 1.055) ^ 2.4 end
end

local function encode(l)
  if l <= 0.0031308 then return l * 12.92 else return 1.055 * l ^ (1 / 2.4) - 0.055 end
end

local function decode_color(c) return color(decode(c.r), decode(c.g), decode(c.b)) end
local function encode_color(c) return color(encode(c.r), encode(c.g), encode(c.b)) end

local function clamp01(x)
  if x < 0 then return 0 elseif x > 1 then return 1 else return x end
end

local function round(x) return math.floor(x + 0.5) end

-- the global linear-blending switch, defaulting on
local linear_blending = true
local function set_linear_blending(b) linear_blending = b end
local function get_linear_blending() return linear_blending end

local function mix(a, b, t, linear)
  if linear == nil then linear = linear_blending end
  if linear then
    return color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
  else
    local ac = color(clamp01(a.r), clamp01(a.g), clamp01(a.b))
    local bc = color(clamp01(b.r), clamp01(b.g), clamp01(b.b))
    local ae, be = encode_color(ac), encode_color(bc)
    local m = color(ae.r + (be.r - ae.r) * t, ae.g + (be.g - ae.g) * t, ae.b + (be.b - ae.b) * t)
    return decode_color(m)
  end
end

return {
  color = color,
  decode = decode,
  encode = encode,
  decode_color = decode_color,
  encode_color = encode_color,
  clamp01 = clamp01,
  round = round,
  mix = mix,
  set_linear_blending = set_linear_blending,
  get_linear_blending = get_linear_blending,
}
