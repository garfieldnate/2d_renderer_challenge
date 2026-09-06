-- Chapter 5: is this point inside? crossings, winding_at, and the two rules.
local path_mod = require("path")
local tuple_mod = require("tuple")
local edges = path_mod.edges
local point = tuple_mod.point
local cross = tuple_mod.cross

local function crossings(p, x, y)
  local count = 0
  for _, e in ipairs(edges(p)) do
    local a, b = e[1], e[2]
    local crosses = false
    if a.y <= y and y < b.y then crosses = true
    elseif b.y <= y and y < a.y then crosses = true end
    if crosses then
      local t = (y - a.y) / (b.y - a.y)
      local cx = a.x + t * (b.x - a.x)
      if cx > x then count = count + 1 end
    end
  end
  return count
end

local function winding_at(p, x, y)
  local w = 0
  local q = point(x, y)
  for _, e in ipairs(edges(p)) do
    local a, b = e[1], e[2]
    if a.y <= y then
      if b.y > y and cross(b - a, q - a) > 0 then w = w + 1 end
    else
      if b.y <= y and cross(b - a, q - a) < 0 then w = w - 1 end
    end
  end
  return w
end

local function inside_nonzero(p, x, y) return winding_at(p, x, y) ~= 0 end
local function inside_evenodd(p, x, y) return winding_at(p, x, y) % 2 ~= 0 end

local function filled(p, rule)
  local check = (rule == "nonzero") and inside_nonzero or inside_evenodd
  return { inside = function(x, y) return check(p, x, y) end }
end

return {
  crossings = crossings,
  winding_at = winding_at,
  inside_nonzero = inside_nonzero,
  inside_evenodd = inside_evenodd,
  filled = filled,
}
