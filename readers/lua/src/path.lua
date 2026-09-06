-- Chapter 5: a path is a list of subpaths, each a list of points and a
-- closed flag.
local tuple_mod = require("tuple")
local point = tuple_mod.point

local function path()
  return { subpaths = {} }
end

local function move_to(p, pt)
  table.insert(p.subpaths, { points = { pt }, closed = false })
end

local function line_to(p, pt)
  if #p.subpaths == 0 then
    move_to(p, pt)
    return
  end
  local last = p.subpaths[#p.subpaths]
  if last.closed then
    move_to(p, last.points[1])
    line_to(p, pt)
    return
  end
  table.insert(last.points, pt)
end

local function close(p)
  if #p.subpaths == 0 then return end
  p.subpaths[#p.subpaths].closed = true
end

local function subpaths(p) return p.subpaths end

local function edges(p)
  local out = {}
  for _, sp in ipairs(p.subpaths) do
    local n = #sp.points
    if n >= 2 then
      for i = 1, n do
        local a = sp.points[i]
        local b = sp.points[(i % n) + 1]
        out[#out + 1] = { a, b }
      end
    end
  end
  return out
end

local function bounds(p)
  local minx, miny, maxx, maxy = nil, nil, nil, nil
  for _, sp in ipairs(p.subpaths) do
    for _, pt in ipairs(sp.points) do
      if minx == nil or pt.x < minx then minx = pt.x end
      if maxx == nil or pt.x > maxx then maxx = pt.x end
      if miny == nil or pt.y < miny then miny = pt.y end
      if maxy == nil or pt.y > maxy then maxy = pt.y end
    end
  end
  if minx == nil then return { minx = 0, miny = 0, maxx = 0, maxy = 0 } end
  return { minx = minx, miny = miny, maxx = maxx, maxy = maxy }
end

local function polygon(...)
  local pts = { ... }
  local p = path()
  for i, pt in ipairs(pts) do
    if i == 1 then move_to(p, pt) else line_to(p, pt) end
  end
  close(p)
  return p
end

-- first point at angle 0 (on the right), going clockwise on the screen
local function circle_path(cx, cy, r, n)
  local p = path()
  for k = 0, n - 1 do
    local a = (2 * math.pi * k) / n
    local pt = point(cx + r * math.cos(a), cy + r * math.sin(a))
    if k == 0 then move_to(p, pt) else line_to(p, pt) end
  end
  close(p)
  return p
end

return {
  path = path,
  move_to = move_to,
  line_to = line_to,
  close = close,
  subpaths = subpaths,
  edges = edges,
  bounds = bounds,
  polygon = polygon,
  circle_path = circle_path,
}
