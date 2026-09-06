-- features/chapter03-*.feature, translated one scenario at a time.
local T = require("helpers")
local color_mod = require("color")
local canvas_mod = require("canvas")
local ppm_mod = require("ppm")
local shapes_mod = require("shapes")
local lines_mod = require("lines")
local renders = require("renders")

local color = color_mod.color
local canvas, write_pixel, pixel_at = canvas_mod.canvas, canvas_mod.write_pixel, canvas_mod.pixel_at
local canvas_to_p6, ppm_pixel, max_channel_difference, read_file =
    ppm_mod.canvas_to_p6, ppm_mod.ppm_pixel, ppm_mod.max_channel_difference, ppm_mod.read_file
local thick_line, inside, rasterize, ink_shape = shapes_mod.thick_line, shapes_mod.inside, shapes_mod.rasterize, nil
local coverage_mod = require("coverage")
local ink = coverage_mod.ink

local line_bresenham, line_wu, total_ink = lines_mod.line_bresenham, lines_mod.line_wu, lines_mod.total_ink

-- ---- chapter03-bresenham.feature -----------------------------------------------

T.test("lit_pixels reads like a page", function()
  local c = canvas(10, 10)
  write_pixel(c, 5, 0, color(1, 1, 1))
  write_pixel(c, 0, 2, color(1, 1, 1))
  write_pixel(c, 2, 2, color(0.5, 0, 0))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c), { { 5, 0 }, { 0, 2 }, { 2, 2 } })
end)

T.test("A diagonal", function()
  local c = canvas(10, 10)
  line_bresenham(c, 0, 0, 5, 5, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c), { { 0, 0 }, { 1, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4 }, { 5, 5 } })
end)

T.test("A horizontal line lights one row and nothing else", function()
  local c = canvas(10, 10)
  line_bresenham(c, 0, 3, 7, 3, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c),
    { { 0, 3 }, { 1, 3 }, { 2, 3 }, { 3, 3 }, { 4, 3 }, { 5, 3 }, { 6, 3 }, { 7, 3 } })
end)

T.test("A shallow line steps along x", function()
  local c = canvas(10, 10)
  line_bresenham(c, 0, 0, 7, 3, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c),
    { { 0, 0 }, { 1, 0 }, { 2, 1 }, { 3, 1 }, { 4, 2 }, { 5, 2 }, { 6, 3 }, { 7, 3 } })
end)

T.test("A steep line steps along y", function()
  local c = canvas(10, 10)
  line_bresenham(c, 1, 1, 3, 7, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c),
    { { 1, 1 }, { 1, 2 }, { 2, 3 }, { 2, 4 }, { 2, 5 }, { 3, 6 }, { 3, 7 } })
end)

T.test("The pixels don't depend on which end you start from (bresenham)", function()
  local c1, c2 = canvas(10, 10), canvas(10, 10)
  line_bresenham(c1, 1, 1, 3, 7, color(1, 1, 1))
  line_bresenham(c2, 3, 7, 1, 1, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c1), T.lit_pixels(c2))
  T.assert_exact(max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0)
end)

T.test("A line going up and to the right", function()
  local c = canvas(10, 10)
  line_bresenham(c, 0, 6, 7, 3, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c),
    { { 6, 3 }, { 7, 3 }, { 4, 4 }, { 5, 4 }, { 2, 5 }, { 3, 5 }, { 0, 6 }, { 1, 6 } })
end)

T.test("At an exact half the line stays on its row one step longer", function()
  local c = canvas(10, 10)
  line_bresenham(c, 0, 0, 4, 2, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c), { { 0, 0 }, { 1, 0 }, { 2, 1 }, { 3, 1 }, { 4, 2 } })
end)

T.test("A line of one point (bresenham)", function()
  local c = canvas(10, 10)
  line_bresenham(c, 3, 3, 3, 3, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c), { { 3, 3 } })
end)

T.test("A line may run off the canvas", function()
  local c = canvas(10, 10)
  line_bresenham(c, 0, 0, 12, 6, color(1, 1, 1))
  T.assert_exact(#T.lit_pixels(c), 10)
end)

-- ---- chapter03-wu.feature -----------------------------------------------

T.test("A half step lights two pixels equally", function()
  local c = canvas(10, 10)
  line_wu(c, 0, 0, 4, 2, color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 0, 0), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 0), color(0.5, 0.5, 0.5))
  T.assert_color_eq(pixel_at(c, 1, 1), color(0.5, 0.5, 0.5))
  T.assert_color_eq(pixel_at(c, 2, 1), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 2, 2), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 4, 2), color(1, 1, 1))
  T.assert_eq(total_ink(c), 5)
end)

T.test("The weights are applied in light, whatever the switch says", function()
  T.with_linear_blending(false, function()
    local c = canvas(10, 10)
    line_wu(c, 0, 0, 4, 2, color(1, 1, 1))
    T.assert_color_eq(pixel_at(c, 1, 0), color(0.5, 0.5, 0.5))
    T.assert_color_eq(pixel_at(c, 1, 1), color(0.5, 0.5, 0.5))
  end)
end)

T.test("A diagonal has uniform weights", function()
  local c = canvas(10, 10)
  line_wu(c, 0, 0, 5, 5, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c), { { 0, 0 }, { 1, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4 }, { 5, 5 } })
  T.assert_color_eq(pixel_at(c, 3, 3), color(1, 1, 1))
  T.assert_eq(total_ink(c), 6)
end)

T.test("A horizontal line has weight 1 on its row and 0 on the neighbors", function()
  local c = canvas(10, 10)
  line_wu(c, 0, 3, 7, 3, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c),
    { { 0, 3 }, { 1, 3 }, { 2, 3 }, { 3, 3 }, { 4, 3 }, { 5, 3 }, { 6, 3 }, { 7, 3 } })
  T.assert_color_eq(pixel_at(c, 3, 3), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 3, 2), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 3, 4), color(0, 0, 0))
  T.assert_eq(total_ink(c), 8)
end)

T.test("A steep line weights across columns", function()
  local c = canvas(10, 10)
  line_wu(c, 1, 1, 3, 7, color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 1), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 2), color(0.6667, 0.6667, 0.6667))
  T.assert_color_eq(pixel_at(c, 2, 2), color(0.3333, 0.3333, 0.3333))
  T.assert_color_eq(pixel_at(c, 2, 4), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 3, 7), color(1, 1, 1))
  T.assert_eq(total_ink(c), 7)
end)

T.test("The weights don't depend on which end you start from", function()
  local c1, c2 = canvas(10, 10), canvas(10, 10)
  line_wu(c1, 1, 1, 3, 7, color(1, 1, 1))
  line_wu(c2, 3, 7, 1, 1, color(1, 1, 1))
  T.assert_exact(max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0)
end)

T.test("A line that starts above the canvas", function()
  local c = canvas(10, 10)
  line_wu(c, 0, -1, 8, 3, color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 0), color(0.5, 0.5, 0.5))
  T.assert_color_eq(pixel_at(c, 2, 0), color(1, 1, 1))
  T.assert_eq(total_ink(c), 7.5)
end)

T.test("A Wu line of one point", function()
  local c = canvas(10, 10)
  line_wu(c, 3, 3, 3, 3, color(1, 1, 1))
  T.assert_pixel_pair_list_eq(T.lit_pixels(c), { { 3, 3 } })
  T.assert_color_eq(pixel_at(c, 3, 3), color(1, 1, 1))
end)

T.test("Sevenths", function()
  local c = canvas(10, 10)
  line_wu(c, 0, 0, 7, 3, color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 0), color(0.5714, 0.5714, 0.5714))
  T.assert_color_eq(pixel_at(c, 1, 1), color(0.4286, 0.4286, 0.4286))
  T.assert_color_eq(pixel_at(c, 2, 0), color(0.1429, 0.1429, 0.1429))
  T.assert_color_eq(pixel_at(c, 2, 1), color(0.8571, 0.8571, 0.8571))
  T.assert_eq(total_ink(c), 8)
end)

local wu_ink_cases = { { 12, 2, 11 }, { 10, 8, 9 }, { 8, 10, 9 }, { 2, 12, 11 } }
for _, row in ipairs(wu_ink_cases) do
  T.test("The ink depends on the angle: " .. row[1] .. "," .. row[2], function()
    local c = canvas(20, 20)
    line_wu(c, 2, 2, row[1], row[2], color(1, 1, 1))
    T.assert_eq(total_ink(c), row[3])
  end)
end

-- ---- chapter03-quad.feature -----------------------------------------------

T.test("Inside a thick line", function()
  local s = thick_line(0, 0, 4, 0, 1)
  T.assert_true(inside(s, 2.5, 0.5))
  T.assert_true(inside(s, 2.5, 1.0))
  T.assert_false(inside(s, 2.5, 1.01))
  T.assert_true(inside(s, 0.5, 0.5))
  T.assert_false(inside(s, 0.4, 0.5))
  T.assert_true(inside(s, 4.5, 0.5))
  T.assert_false(inside(s, 4.6, 0.5))
end)

T.test("A horizontal thick line covers its row, with half pixels at the ends", function()
  local s = thick_line(0, 3, 7, 3, 1)
  local cov = rasterize(s, 10, 10)
  T.assert_eq(coverage_mod.coverage_at(cov, 0, 3), 0.5)
  T.assert_eq(coverage_mod.coverage_at(cov, 1, 3), 1)
  T.assert_eq(coverage_mod.coverage_at(cov, 6, 3), 1)
  T.assert_eq(coverage_mod.coverage_at(cov, 7, 3), 0.5)
  T.assert_eq(coverage_mod.coverage_at(cov, 8, 3), 0)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 2), 0)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 4), 0)
  T.assert_eq(ink(cov), 7)
end)

T.test("A line of no length is a square", function()
  local s = thick_line(3, 3, 3, 3, 1)
  local cov = rasterize(s, 8, 8)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 3), 1)
  T.assert_eq(ink(cov), 1)
end)

T.test("A wider line", function()
  local s = thick_line(0, 3, 7, 3, 3)
  local cov = rasterize(s, 10, 10)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 2), 1)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 3), 1)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 4), 1)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 1), 0)
  T.assert_eq(coverage_mod.coverage_at(cov, 3, 5), 0)
  T.assert_eq(coverage_mod.coverage_at(cov, 0, 3), 0.5)
  T.assert_eq(ink(cov), 21)
end)

T.test("An off-axis line runs through pixel centers, not corners", function()
  local s = thick_line(2, 2, 11, 5, 1)
  local cov = rasterize(s, 16, 10)
  T.assert_eq(coverage_mod.coverage_at(cov, 2, 2), 0.484375)
  T.assert_eq(coverage_mod.coverage_at(cov, 11, 5), 0.484375)
  T.assert_eq(coverage_mod.coverage_at(cov, 6, 3), 0.6875)
  T.assert_eq(coverage_mod.coverage_at(cov, 7, 3), 0.359375)
  T.assert_eq(coverage_mod.coverage_at(cov, 2, 1), 0)
  T.assert_eq(ink(cov), 9.4063)
end)

local ink_angle_cases = { { 12, 2 }, { 10, 8 }, { 8, 10 }, { 2, 12 } }
for _, row in ipairs(ink_angle_cases) do
  T.test("The ink is the length, whatever the angle: " .. row[1] .. "," .. row[2], function()
    local s = thick_line(2, 2, row[1], row[2], 1)
    local cov = rasterize(s, 20, 20)
    T.assert_eq(ink(cov), 10)
  end)
end

T.test("Except that the grid is blind along the diagonal", function()
  local s = thick_line(2, 2, 9, 9, 1)
  local cov = rasterize(s, 20, 20)
  T.assert_eq(ink(cov), 9.71875)
  T.assert_eq(ink(cov), 9.8995, 0.25)
end)

-- ---- chapter03-plate.feature -----------------------------------------------

T.test("The ray endpoints", function()
  local expected = { { 152, 80 }, { 142, 116 }, { 116, 142 }, { 80, 152 }, { 44, 142 }, { 18, 116 },
    { 8, 80 }, { 18, 44 }, { 44, 18 }, { 80, 8 }, { 116, 18 }, { 142, 44 } }
  T.assert_pixel_pair_list_eq(renders.ray_ends(), expected)
end)

T.test("Bresenham's fan", function()
  local c = renders.fan_bresenham()
  local ref = read_file("reference/chapter-03/fan-bresenham.ppm")
  local p6 = canvas_to_p6(c)
  T.assert_exact(c.width, 160)
  T.assert_exact(c.height, 160)
  local function check(x, y, rr, gg, bb)
    local r, g, b = ppm_pixel(p6, x, y)
    T.assert_eq(r, rr, 1); T.assert_eq(g, gg, 1); T.assert_eq(b, bb, 1)
  end
  check(80, 80, 246, 246, 241)
  check(120, 80, 246, 246, 241)
  check(10, 10, 39, 39, 44)
  check(100, 91, 39, 39, 44)
  check(100, 92, 246, 246, 241)
  check(103, 120, 246, 246, 241)
  check(102, 120, 39, 39, 44)
  check(104, 120, 39, 39, 44)
  T.assert_true(max_channel_difference(p6, ref) <= 1)
end)

T.test("Wu's fan", function()
  local c = renders.fan_wu()
  local ref = read_file("reference/chapter-03/fan-wu.ppm")
  local p6 = canvas_to_p6(c)
  local function check(x, y, rr, gg, bb)
    local r, g, b = ppm_pixel(p6, x, y)
    T.assert_eq(r, rr, 1); T.assert_eq(g, gg, 1); T.assert_eq(b, bb, 1)
  end
  check(80, 80, 246, 246, 241)
  check(120, 80, 246, 246, 241)
  check(100, 91, 163, 163, 161)
  check(100, 92, 199, 199, 196)
  check(103, 120, 220, 220, 216)
  check(104, 120, 130, 130, 129)
  T.assert_true(max_channel_difference(p6, ref) <= 1)
end)

T.test("The fan as twelve thin rectangles", function()
  local c = renders.fan_coverage()
  local ref = read_file("reference/chapter-03/fan-coverage.ppm")
  local p6 = canvas_to_p6(c)
  T.assert_exact(c.width, 320)
  T.assert_exact(c.height, 320)
  local function check(x, y, rr, gg, bb)
    local r, g, b = ppm_pixel(p6, x, y)
    T.assert_eq(r, rr, 1); T.assert_eq(g, gg, 1); T.assert_eq(b, bb, 1)
  end
  check(160, 160, 246, 246, 241)
  check(10, 10, 39, 39, 44)
  check(240, 160, 246, 246, 241)
  check(240, 158, 39, 39, 44)
  check(200, 183, 177, 177, 174)
  check(200, 185, 209, 209, 205)
  T.assert_true(max_channel_difference(p6, ref) <= 1)
end)

T.test("Plate 3", function()
  local c = renders.plate_03()
  local ref = read_file("reference/chapter-03/plate-03.ppm")
  local p6 = canvas_to_p6(c)
  T.assert_exact(c.width, 640)
  T.assert_exact(c.height, 320)
  local function check(x, y, rr, gg, bb)
    local r, g, b = ppm_pixel(p6, x, y)
    T.assert_eq(r, rr, 1); T.assert_eq(g, gg, 1); T.assert_eq(b, bb, 1)
  end
  check(160, 160, 246, 246, 241)
  check(480, 160, 246, 246, 241)
  check(10, 10, 39, 39, 44)
  check(200, 183, 39, 39, 44)
  check(200, 185, 246, 246, 241)
  check(520, 183, 163, 163, 161)
  check(520, 185, 199, 199, 196)
  T.assert_true(max_channel_difference(p6, ref) <= 1)
end)
