-- Chapters 2, 3, 4: shapes are questions. circle, rectangle, half_plane,
-- union, intersection (for thick_line), transformed, thick_line, segment,
-- outline, and the two rasterizers.
local coverage_mod = require("coverage")
local matrix_mod = require("matrix")
local coverage_buffer = coverage_mod.coverage_buffer
local set_coverage = coverage_mod.set_coverage
local is_invertible = matrix_mod.is_invertible
local inverse = matrix_mod.inverse

local function inside(shape, x, y) return shape.inside(x, y) end

local function circle(cx, cy, r)
  local r2 = r * r
  return { inside = function(x, y) return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2 end }
end

local function rectangle(x0, y0, x1, y1)
  return { inside = function(x, y) return x >= x0 and x <= x1 and y >= y0 and y <= y1 end }
end

local function half_plane(px, py, nx, ny)
  return { inside = function(x, y) return (x - px) * nx + (y - py) * ny >= 0 end }
end

local function shape_union(shapes)
  return { inside = function(x, y)
    for _, s in ipairs(shapes) do
      if s.inside(x, y) then return true end
    end
    return false
  end }
end

local function shape_intersection(shapes)
  return { inside = function(x, y)
    for _, s in ipairs(shapes) do
      if not s.inside(x, y) then return false end
    end
    return true
  end }
end

local function transformed(shape, m)
  if not is_invertible(m) then
    return { inside = function(_, _) return false end }
  end
  local minv = inverse(m)
  local a, b, c, d, e, f =
      matrix_mod.mat_get(minv, 0, 0), matrix_mod.mat_get(minv, 0, 1), matrix_mod.mat_get(minv, 0, 2),
      matrix_mod.mat_get(minv, 1, 0), matrix_mod.mat_get(minv, 1, 1), matrix_mod.mat_get(minv, 1, 2)
  return { inside = function(x, y)
    local px = a * x + b * y + c
    local py = d * x + e * y + f
    return shape.inside(px, py)
  end }
end

local function center_inside(shape, x, y)
  if shape.inside(x + 0.5, y + 0.5) then return 1 else return 0 end
end

local function coverage(shape, x, y)
  local count = 0
  for j = 0, 7 do
    for i = 0, 7 do
      local sx = x + (i + 0.5) / 8
      local sy = y + (j + 0.5) / 8
      if shape.inside(sx, sy) then count = count + 1 end
    end
  end
  return count / 64
end

local function rasterize_centers(shape, w, h)
  local cov = coverage_buffer(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      set_coverage(cov, x, y, center_inside(shape, x, y))
    end
  end
  return cov
end

local function rasterize(shape, w, h)
  local cov = coverage_buffer(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      set_coverage(cov, x, y, coverage(shape, x, y))
    end
  end
  return cov
end

local function rasterize_within(shape, box, w, h)
  local cov = coverage_buffer(w, h)
  local x0 = math.max(0, math.floor(box.minx))
  local x1 = math.min(w - 1, math.ceil(box.maxx) - 1)
  local y0 = math.max(0, math.floor(box.miny))
  local y1 = math.min(h - 1, math.ceil(box.maxy) - 1)
  for y = y0, y1 do
    for x = x0, x1 do
      set_coverage(cov, x, y, coverage(shape, x, y))
    end
  end
  return cov
end

-- Chapter 3/4: a line is a thin rectangle, built from four half-planes.
local function build_thick_line(ax, ay, bx, by, width)
  local h = width / 2
  local length = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
  local dx, dy
  if length == 0 then
    dx, dy = 1, 0
    ax = ax - h
    bx = bx + h
  else
    dx, dy = (bx - ax) / length, (by - ay) / length
  end
  local nx, ny = -dy, dx
  return shape_intersection({
    half_plane(ax, ay, dx, dy),
    half_plane(bx, by, -dx, -dy),
    half_plane(ax + nx * h, ay + ny * h, -nx, -ny),
    half_plane(ax - nx * h, ay - ny * h, nx, ny),
  })
end

local function thick_line(x0, y0, x1, y1, width)
  return build_thick_line(x0 + 0.5, y0 + 0.5, x1 + 0.5, y1 + 0.5, width)
end

-- Chapter 4: segment is thick_line with real endpoints (points, not pixels).
local function segment(a, b, width)
  return build_thick_line(a.x, a.y, b.x, b.y, width)
end

local function outline(points, m, width)
  local tpts = {}
  for i, p in ipairs(points) do tpts[i] = m * p end
  local segs = {}
  local n = #tpts
  for i = 1, n do
    local a = tpts[i]
    local b = tpts[(i % n) + 1]
    segs[#segs + 1] = build_thick_line(a.x, a.y, b.x, b.y, width)
  end
  return shape_union(segs)
end

return {
  inside = inside,
  circle = circle,
  rectangle = rectangle,
  half_plane = half_plane,
  union = shape_union,
  intersection = shape_intersection,
  transformed = transformed,
  center_inside = center_inside,
  coverage = coverage,
  rasterize_centers = rasterize_centers,
  rasterize = rasterize,
  rasterize_within = rasterize_within,
  thick_line = thick_line,
  segment = segment,
  outline = outline,
}
