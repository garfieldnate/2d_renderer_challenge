-- Chapter 4: points and vectors, both (x, y, w).
local Tuple = {}
Tuple.__index = Tuple

local function make(x, y, w) return setmetatable({ x = x, y = y, w = w }, Tuple) end
local function point(x, y) return make(x, y, 1) end
local function vector(x, y) return make(x, y, 0) end

function Tuple.__add(a, b) return make(a.x + b.x, a.y + b.y, a.w + b.w) end
function Tuple.__sub(a, b) return make(a.x - b.x, a.y - b.y, a.w - b.w) end
function Tuple.__unm(a) return make(-a.x, -a.y, -a.w) end
function Tuple.__mul(a, b)
  if type(b) == "number" then return make(a.x * b, a.y * b, a.w * b) end
  if type(a) == "number" then return make(a * b.x, a * b.y, a * b.w) end
  error("tuple * tuple is not defined")
end
function Tuple.__div(a, b) return make(a.x / b, a.y / b, a.w / b) end
function Tuple.__tostring(t)
  return string.format("(%.6g, %.6g, w=%.6g)", t.x, t.y, t.w)
end

local function magnitude(v) return math.sqrt(v.x * v.x + v.y * v.y) end
local function normalize(v)
  local m = magnitude(v)
  return vector(v.x / m, v.y / m)
end
local function dot(a, b) return a.x * b.x + a.y * b.y end
local function cross(a, b) return a.x * b.y - a.y * b.x end

return {
  Tuple = Tuple,
  make = make,
  point = point,
  vector = vector,
  magnitude = magnitude,
  normalize = normalize,
  dot = dot,
  cross = cross,
}
