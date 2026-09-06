-- The book's named render functions, one section per chapter, exactly as
-- printed in the chapter's pseudo-code.
local canvas_mod = require("canvas")
local color_mod = require("color")
local coverage_mod = require("coverage")
local shapes_mod = require("shapes")
local tuple_mod = require("tuple")
local matrix_mod = require("matrix")
local path_mod = require("path")
local sweep_mod = require("sweep")
local lines_mod = require("lines")

local canvas = canvas_mod.canvas
local write_pixel = canvas_mod.write_pixel
local pixel_at = canvas_mod.pixel_at
local fill = canvas_mod.fill
local copy_canvas = canvas_mod.copy_canvas

local color = color_mod.color
local decode = color_mod.decode
local mix = color_mod.mix
local round = color_mod.round

local magnify = coverage_mod.magnify
local paint_through = coverage_mod.paint_through

local circle = shapes_mod.circle
local rasterize_centers = shapes_mod.rasterize_centers
local rasterize = shapes_mod.rasterize
local thick_line = shapes_mod.thick_line
local segment = shapes_mod.segment
local shape_union = shapes_mod.union
local rasterize_within = shapes_mod.rasterize_within

local point = tuple_mod.point

local translation = matrix_mod.translation
local rotation = matrix_mod.rotation
local scaling = matrix_mod.scaling

local path = path_mod.path
local move_to = path_mod.move_to
local line_to = path_mod.line_to
local close = path_mod.close
local bounds = path_mod.bounds

local edge_table = sweep_mod.edge_table -- unused here, kept for completeness
local fill_path_aliased = sweep_mod.fill_path_aliased
local transform_path = sweep_mod.transform_path

local line_bresenham = lines_mod.line_bresenham
local line_wu = lines_mod.line_wu

local M = {}

--------------------------------------------------------------------------
-- Chapter 1
--------------------------------------------------------------------------

function M.gray_match()
  local c = canvas(300, 100)
  for y = 0, 99 do
    for x = 0, 99 do
      write_pixel(c, x, y, ((x + y) % 2 == 0) and color(1, 1, 1) or color(0, 0, 0))
    end
  end
  local g = decode(128 / 255)
  for y = 0, 99 do
    for x = 100, 199 do
      write_pixel(c, x, y, color(g, g, g))
    end
  end
  for y = 0, 99 do
    for x = 200, 299 do
      write_pixel(c, x, y, color(0.5, 0.5, 0.5))
    end
  end
  return c
end

function M.quarter_match()
  local c = canvas(200, 100)
  for y = 0, 99 do
    for x = 0, 99 do
      write_pixel(c, x, y, ((x + y) % 4 == 0) and color(1, 1, 1) or color(0, 0, 0))
    end
  end
  for y = 0, 99 do
    for x = 100, 199 do
      write_pixel(c, x, y, color(0.25, 0.25, 0.25))
    end
  end
  return c
end

function M.ramp()
  local c = canvas(256, 32)
  for x = 0, 255 do
    local g = x / 255
    for y = 0, 31 do
      write_pixel(c, x, y, color(g, g, g))
    end
  end
  return c
end

function M.clamp_pair()
  local c = canvas(200, 100)
  for y = 0, 99 do
    for x = 0, 99 do write_pixel(c, x, y, color(2, 0.5, 0.5)) end
    for x = 100, 199 do write_pixel(c, x, y, color(1, 0.25, 0.25)) end
  end
  return c
end

function M.ramp_pair(c, top, a, b)
  for x = 0, 399 do
    local t = x / 399
    local naive = mix(a, b, t, false)
    local light = mix(a, b, t, true)
    for y = top, top + 39 do write_pixel(c, x, y, naive) end
    for y = top + 45, top + 84 do write_pixel(c, x, y, light) end
  end
end

function M.plate_01()
  local c = canvas(400, 180)
  M.ramp_pair(c, 0, color(0, 0, 0), color(1, 1, 1))
  M.ramp_pair(c, 90, color(0.7, 0, 0), color(0, 0.3, 0.02))
  return c
end

--------------------------------------------------------------------------
-- Chapter 2
--------------------------------------------------------------------------

function M.disc_centers()
  local c = canvas(40, 40)
  fill(c, color(0.02, 0.02, 0.025))
  local cov = rasterize_centers(circle(20, 20, 16), 40, 40)
  paint_through(c, cov, color(0.9, 0.55, 0.1))
  return magnify(c, 8)
end

function M.disc_coverage()
  local c = canvas(40, 40)
  fill(c, color(0.02, 0.02, 0.025))
  local cov = rasterize(circle(20, 20, 16), 40, 40)
  paint_through(c, cov, color(0.9, 0.55, 0.1))
  return magnify(c, 8)
end

function M.painted_twice()
  local c = canvas(80, 40)
  fill(c, color(0.02, 0.02, 0.025))
  local cov = rasterize(circle(20, 20, 16), 40, 40)
  local coverage_mod_ = require("coverage")
  local once = coverage_mod_.coverage_buffer(80, 40)
  for y = 0, 39 do
    for x = 0, 39 do
      coverage_mod_.set_coverage(once, x, y, coverage_mod_.coverage_at(cov, x, y))
      coverage_mod_.set_coverage(once, x + 40, y, coverage_mod_.coverage_at(cov, x, y))
    end
  end
  paint_through(c, once, color(0.9, 0.55, 0.1))
  local twice = coverage_mod_.coverage_buffer(80, 40)
  for y = 0, 39 do
    for x = 0, 39 do
      coverage_mod_.set_coverage(twice, x + 40, y, coverage_mod_.coverage_at(cov, x, y))
    end
  end
  paint_through(c, twice, color(0.9, 0.55, 0.1))
  return magnify(c, 6)
end

function M.plate_02()
  local c = canvas(80, 40)
  fill(c, color(0.02, 0.02, 0.025))
  local shape = circle(20, 20, 16)
  local left = rasterize_centers(shape, 40, 40)
  local right = rasterize(shape, 40, 40)
  local coverage_mod_ = require("coverage")
  local both = coverage_mod_.coverage_buffer(80, 40)
  for y = 0, 39 do
    for x = 0, 39 do
      coverage_mod_.set_coverage(both, x, y, coverage_mod_.coverage_at(left, x, y))
      coverage_mod_.set_coverage(both, x + 40, y, coverage_mod_.coverage_at(right, x, y))
    end
  end
  paint_through(c, both, color(0.9, 0.55, 0.1))
  return magnify(c, 6)
end

--------------------------------------------------------------------------
-- Chapter 3
--------------------------------------------------------------------------

function M.ray_ends()
  local ends = {}
  for k = 0, 11 do
    local a = math.rad(k * 30)
    ends[#ends + 1] = { round(80 + 72 * math.cos(a)), round(80 + 72 * math.sin(a)) }
  end
  return ends
end

function M.fan_bresenham()
  local c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  for _, e in ipairs(M.ray_ends()) do
    line_bresenham(c, 80, 80, e[1], e[2], color(0.92, 0.92, 0.88))
  end
  return c
end

function M.fan_wu()
  local c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  for _, e in ipairs(M.ray_ends()) do
    line_wu(c, 80, 80, e[1], e[2], color(0.92, 0.92, 0.88))
  end
  return c
end

function M.fan_coverage()
  local c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  for _, e in ipairs(M.ray_ends()) do
    local cov = rasterize(thick_line(80, 80, e[1], e[2], 1), 160, 160)
    paint_through(c, cov, color(0.92, 0.92, 0.88))
  end
  return magnify(c, 2)
end

function M.plate_03()
  local both = canvas(320, 160)
  local a = M.fan_bresenham()
  local b = M.fan_wu()
  for y = 0, 159 do
    for x = 0, 159 do
      write_pixel(both, x, y, pixel_at(a, x, y))
      write_pixel(both, x + 160, y, pixel_at(b, x, y))
    end
  end
  return magnify(both, 2)
end

--------------------------------------------------------------------------
-- Chapter 4
--------------------------------------------------------------------------

function M.side_by_side(a, b)
  local c = canvas(a.width + b.width, math.max(a.height, b.height))
  for y = 0, a.height - 1 do
    for x = 0, a.width - 1 do write_pixel(c, x, y, pixel_at(a, x, y)) end
  end
  for y = 0, b.height - 1 do
    for x = 0, b.width - 1 do write_pixel(c, a.width + x, y, pixel_at(b, x, y)) end
  end
  return c
end

function M.fan_points()
  local pts = { point(0, 0) }
  for k = 0, 11 do
    local a = math.rad(k * 30)
    pts[#pts + 1] = point(36 * math.cos(a), 36 * math.sin(a))
  end
  return pts
end

function M.fan_transformed(m)
  local c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  local pts = matrix_mod.transform_points(M.fan_points(), m)
  local segs = {}
  for k = 2, 13 do
    segs[#segs + 1] = segment(pts[1], pts[k], 1)
  end
  local rays = shape_union(segs)
  paint_through(c, rasterize(rays, 160, 160), color(0.92, 0.92, 0.88))
  return c
end

function M.fan_both_orders()
  local turn = rotation(math.pi / 6)
  local move = translation(104.5, 76.5)
  return M.side_by_side(M.fan_transformed(move * turn), M.fan_transformed(turn * move))
end

function M.letter_f()
  return {
    point(-20, -30), point(20, -30), point(20, -20), point(-10, -20),
    point(-10, -5), point(12, -5), point(12, 5), point(-10, 5),
    point(-10, 30), point(-20, 30),
  }
end

function M.f_both_orders()
  local turn = rotation(math.pi / 6)
  local move = translation(104.5, 76.5)
  local home = translation(44.5, 44.5)
  local ink_col = color(0.92, 0.92, 0.88)
  local dim = color(0.16, 0.16, 0.17)
  local ghost = canvas(160, 160)
  fill(ghost, color(0.02, 0.02, 0.025))
  paint_through(ghost, rasterize(shapes_mod.outline(M.letter_f(), home, 1), 160, 160), dim)
  local a = copy_canvas(ghost)
  local b = copy_canvas(ghost)
  paint_through(a, rasterize(shapes_mod.outline(M.letter_f(), move * turn, 1), 160, 160), ink_col)
  paint_through(b, rasterize(shapes_mod.outline(M.letter_f(), turn * move, 1), 160, 160), ink_col)
  return M.side_by_side(a, b)
end

function M.plate_04()
  return magnify(M.f_both_orders(), 2)
end

--------------------------------------------------------------------------
-- Chapter 5
--------------------------------------------------------------------------

function M.star()
  local p = path()
  for k = 0, 4 do
    local a = math.rad(-90 + 144 * k)
    local q = point(80.5 + 70 * math.cos(a), 80.5 + 70 * math.sin(a))
    if k == 0 then move_to(p, q) else line_to(p, q) end
  end
  close(p)
  return p
end

function M.star_panel(rule, method)
  local c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  local s = require("winding").filled(M.star(), rule)
  local cov
  if method == "centers" then
    cov = rasterize_centers(s, 160, 160)
  else
    cov = rasterize_within(s, bounds(M.star()), 160, 160)
  end
  paint_through(c, cov, color(0.9, 0.55, 0.1))
  return c
end

function M.star_centers()
  return M.side_by_side(M.star_panel("nonzero", "centers"), M.star_panel("evenodd", "centers"))
end

function M.star_coverage()
  return M.side_by_side(M.star_panel("nonzero", "coverage"), M.star_panel("evenodd", "coverage"))
end

function M.plate_05()
  local top = M.star_centers()
  local bottom = M.star_coverage()
  local both = canvas(320, 320)
  for y = 0, 159 do
    for x = 0, 319 do
      write_pixel(both, x, y, pixel_at(top, x, y))
      write_pixel(both, x, y + 160, pixel_at(bottom, x, y))
    end
  end
  return magnify(both, 2)
end

--------------------------------------------------------------------------
-- Chapter 6
--------------------------------------------------------------------------

function M.unit_star()
  return transform_path(M.star(), scaling(1 / 70, 1 / 70) * translation(-80.5, -80.5))
end

function M.spiral()
  local c = canvas(320, 320)
  fill(c, color(0.02, 0.02, 0.025))
  local inks = { color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3) }
  local unit = M.unit_star()
  for k = 0, 23 do
    local a = math.rad(k * 25)
    local r = 20 + 5 * k
    local m = translation(160.5 + r * math.cos(a), 160.5 + r * math.sin(a)) * rotation(a) * scaling(6 + 1.25 * k, 6 + 1.25 * k)
    local cov = fill_path_aliased(transform_path(unit, m), "nonzero", 320, 320)
    paint_through(c, cov, inks[(k % 3) + 1])
  end
  return c
end

function M.plate_06()
  return magnify(M.spiral(), 2)
end

return M
