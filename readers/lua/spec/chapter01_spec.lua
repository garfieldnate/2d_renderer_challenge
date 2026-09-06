-- features/chapter01-*.feature, translated one scenario at a time.
local T = require("helpers")
local color_mod = require("color")
local canvas_mod = require("canvas")
local ppm_mod = require("ppm")
local renders = require("renders")

local color = color_mod.color
local encode, decode = color_mod.encode, color_mod.decode
local mix = color_mod.mix
local round = color_mod.round
local canvas, write_pixel, pixel_at, fill = canvas_mod.canvas, canvas_mod.write_pixel, canvas_mod.pixel_at, canvas_mod.fill
local canvas_to_ppm, ppm_pixel, distinct_values, max_channel_difference, read_file, ppm_lines =
    ppm_mod.canvas_to_ppm, ppm_mod.ppm_pixel, ppm_mod.distinct_values, ppm_mod.max_channel_difference, ppm_mod.read_file, ppm_mod.ppm_lines

-- ---- chapter01-equality.feature -------------------------------------------

T.test("Two numbers that differ by less than the tolerance are equal", function()
  T.assert_eq(1.0, 1.0000001, 0.00001)
end)

T.test("Two numbers that differ by more than the tolerance are not", function()
  T.assert_ne(1.0, 1.001, 0.00001)
end)

T.test("The default tolerance is 0.0001", function()
  T.assert_eq(0.1 + 0.2, 0.3)
  T.assert_eq(1.0, 1.00009)
  T.assert_ne(1.0, 1.0002)
end)

-- ---- chapter01-colors.feature ----------------------------------------------

T.test("A color is a red, green, blue tuple", function()
  local c = color(-0.5, 0.4, 1.7)
  T.assert_eq(c.r, -0.5)
  T.assert_eq(c.g, 0.4)
  T.assert_eq(c.b, 1.7)
end)

T.test("Adding colors", function()
  local c1, c2 = color(0.9, 0.6, 0.75), color(0.7, 0.1, 0.25)
  T.assert_color_eq(c1 + c2, color(1.6, 0.7, 1.0))
end)

T.test("Subtracting colors", function()
  local c1, c2 = color(0.9, 0.6, 0.75), color(0.7, 0.1, 0.25)
  T.assert_color_eq(c1 - c2, color(0.2, 0.5, 0.5))
end)

T.test("Scaling a color by a number", function()
  local c = color(0.2, 0.3, 0.4)
  T.assert_color_eq(c * 2, color(0.4, 0.6, 0.8))
  T.assert_color_eq(c * 0.5, color(0.1, 0.15, 0.2))
end)

T.test("Multiplying two colors filters one through the other", function()
  local c1, c2 = color(1, 0.2, 0.4), color(0.9, 1, 0.1)
  T.assert_color_eq(c1 * c2, color(0.9, 0.2, 0.04))
end)

T.test("Colors compare component by component, with the usual tolerance", function()
  local c1, c2 = color(0.1, 0.5, 1), color(0.2, 0, 0)
  T.assert_color_eq(c1 + c2, color(0.3, 0.5, 1))
  T.assert_color_ne(c1 + c2, color(0.3, 0.5, 1.001))
end)

-- ---- chapter01-canvas.feature ----------------------------------------------

T.test("A new canvas is black", function()
  local c = canvas(10, 20)
  T.assert_exact(c.width, 10)
  T.assert_exact(c.height, 20)
  T.assert_true(T.every_pixel_is(c, color(0, 0, 0)))
end)

T.test("Writing a pixel", function()
  local c = canvas(10, 20)
  local red = color(1, 0, 0)
  write_pixel(c, 2, 3, red)
  T.assert_color_eq(pixel_at(c, 2, 3), red)
end)

T.test("x is the column and y is the row", function()
  local c = canvas(10, 20)
  write_pixel(c, 2, 3, color(1, 0, 0))
  T.assert_color_eq(pixel_at(c, 3, 2), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 2, 3), color(1, 0, 0))
end)

T.test("Writing outside the canvas is ignored", function()
  local c = canvas(10, 20)
  write_pixel(c, -1, 5, color(1, 0, 0))
  write_pixel(c, 10, 5, color(1, 0, 0))
  write_pixel(c, 5, -1, color(1, 0, 0))
  write_pixel(c, 5, 20, color(1, 0, 0))
  T.assert_true(T.every_pixel_is(c, color(0, 0, 0)))
end)

T.test("A pixel can be written more than once", function()
  local c = canvas(10, 20)
  write_pixel(c, 2, 3, color(1, 0, 0))
  write_pixel(c, 2, 3, color(0, 1, 0))
  T.assert_color_eq(pixel_at(c, 2, 3), color(0, 1, 0))
end)

T.test("Filling a canvas", function()
  local c = canvas(10, 20)
  fill(c, color(0.1, 0.2, 0.3))
  T.assert_true(T.every_pixel_is(c, color(0.1, 0.2, 0.3)))
end)

-- ---- chapter01-srgb.feature -------------------------------------------------

local encode_cases = {
  { 0.0, 0.0 }, { 0.0025, 0.0323 }, { 0.01, 0.0999 }, { 0.1, 0.3492 },
  { 0.216, 0.5021 }, { 0.25, 0.5371 }, { 0.5, 0.7354 }, { 0.75, 0.8808 }, { 1.0, 1.0 },
}
for _, row in ipairs(encode_cases) do
  T.test("Encoding light into a file value: " .. row[1], function()
    T.assert_eq(encode(row[1]), row[2])
  end)
end

local decode_cases = {
  { 0.0, 0.0 }, { 0.04, 0.0031 }, { 0.05, 0.0039 }, { 0.1, 0.0100 },
  { 0.5, 0.2140 }, { 0.75, 0.5225 }, { 1.0, 1.0 },
}
for _, row in ipairs(decode_cases) do
  T.test("Decoding a file value into light: " .. row[1], function()
    T.assert_eq(decode(row[1]), row[2])
  end)
end

T.test("Decode undoes encode", function()
  T.assert_eq(decode(encode(0.2)), 0.2, 0.000000001)
end)

T.test("Encode undoes decode", function()
  T.assert_eq(encode(decode(0.7)), 0.7, 0.000000001)
end)

T.test("The half gray that isn't 128", function()
  T.assert_exact(round(encode(0.5) * 255), 188)
end)

T.test("What 128 actually is", function()
  T.assert_eq(decode(128 / 255), 0.2159)
end)

-- ---- chapter01-gray-match.feature -------------------------------------------

T.test("The gray match", function()
  local c = renders.gray_match()
  T.assert_exact(c.width, 300)
  T.assert_exact(c.height, 100)
  T.assert_color_eq(pixel_at(c, 0, 0), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 0), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 0, 1), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 1, 1), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 150, 50), color(0.2159, 0.2159, 0.2159))
  T.assert_color_eq(pixel_at(c, 250, 50), color(0.5, 0.5, 0.5))
  T.assert_exact(T.count_pixels_of(c, color(1, 1, 1)), 5000)
end)

T.test("The gray match, as a file", function()
  local c = renders.gray_match()
  local ref = read_file("reference/chapter-01/gray-match.ppm")
  local ppm = canvas_to_ppm(c)
  local r, g, b = ppm_pixel(ppm, 0, 0)
  T.assert_eq(r, 255, 1); T.assert_eq(g, 255, 1); T.assert_eq(b, 255, 1)
  r, g, b = ppm_pixel(ppm, 1, 0)
  T.assert_eq(r, 0, 1); T.assert_eq(g, 0, 1); T.assert_eq(b, 0, 1)
  r, g, b = ppm_pixel(ppm, 150, 50)
  T.assert_eq(r, 128, 1); T.assert_eq(g, 128, 1); T.assert_eq(b, 128, 1)
  r, g, b = ppm_pixel(ppm, 250, 50)
  T.assert_eq(r, 188, 1); T.assert_eq(g, 188, 1); T.assert_eq(b, 188, 1)
  T.assert_true(max_channel_difference(ppm, ref) <= 1)
end)

T.test("One pixel in four", function()
  local c = renders.quarter_match()
  local ref = read_file("reference/chapter-01/quarter-match.ppm")
  local ppm = canvas_to_ppm(c)
  T.assert_exact(c.width, 200)
  T.assert_exact(c.height, 100)
  T.assert_color_eq(pixel_at(c, 0, 0), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 1, 0), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 2, 2), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 3, 1), color(1, 1, 1))
  T.assert_color_eq(pixel_at(c, 150, 50), color(0.25, 0.25, 0.25))
  T.assert_exact(T.count_pixels_of(c, color(1, 1, 1)), 2500)
  local r, g, b = ppm_pixel(ppm, 150, 50)
  T.assert_eq(r, 137, 1); T.assert_eq(g, 137, 1); T.assert_eq(b, 137, 1)
  T.assert_true(max_channel_difference(ppm, ref) <= 1)
end)

-- ---- chapter01-limits.feature -----------------------------------------------

T.test("A 256-step ramp", function()
  local c = renders.ramp()
  T.assert_exact(c.width, 256)
  T.assert_exact(c.height, 32)
  T.assert_color_eq(pixel_at(c, 0, 0), color(0, 0, 0))
  T.assert_color_eq(pixel_at(c, 128, 0), color(0.5020, 0.5020, 0.5020))
  T.assert_color_eq(pixel_at(c, 255, 31), color(1, 1, 1))
end)

T.test("Encoding stretches the dark end and squeezes the bright end", function()
  local c = renders.ramp()
  local ref = read_file("reference/chapter-01/ramp.ppm")
  local ppm = canvas_to_ppm(c)
  local lines = ppm_lines(ppm)
  T.assert_exact(lines[4], "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46")
  local r = ({ ppm_pixel(ppm, 75, 0) })[1]
  T.assert_eq(r, 148, 1)
  r = ({ ppm_pixel(ppm, 76, 0) })[1]
  T.assert_eq(r, 148, 1)
  r = ({ ppm_pixel(ppm, 254, 0) })[1]
  T.assert_eq(r, 255, 1)
  T.assert_exact(distinct_values(ppm), 183)
  T.assert_true(max_channel_difference(ppm, ref) <= 1)
end)

T.test("Clamping changes the color, not only the brightness", function()
  local c = renders.clamp_pair()
  local ref = read_file("reference/chapter-01/clamp-pair.ppm")
  local ppm = canvas_to_ppm(c)
  T.assert_exact(c.width, 200)
  T.assert_exact(c.height, 100)
  T.assert_color_eq(pixel_at(c, 50, 50), color(2, 0.5, 0.5))
  T.assert_color_eq(pixel_at(c, 150, 50), color(1, 0.25, 0.25))
  local r, g, b = ppm_pixel(ppm, 50, 50)
  T.assert_eq(r, 255, 1); T.assert_eq(g, 188, 1); T.assert_eq(b, 188, 1)
  r, g, b = ppm_pixel(ppm, 150, 50)
  T.assert_eq(r, 255, 1); T.assert_eq(g, 137, 1); T.assert_eq(b, 137, 1)
  T.assert_true(max_channel_difference(ppm, ref) <= 1)
end)

-- ---- chapter01-mix.feature ---------------------------------------------------

T.test("Halfway between black and white", function()
  local a, b = color(0, 0, 0), color(1, 1, 1)
  T.assert_color_eq(mix(a, b, 0.5), color(0.5, 0.5, 0.5))
end)

T.test("The ends of a mix are its inputs", function()
  local a, b = color(0.7, 0, 0), color(0, 0.3, 0.02)
  T.assert_color_eq(mix(a, b, 0), a)
  T.assert_color_eq(mix(a, b, 1), b)
end)

T.test("Red to green, in light", function()
  local a, b = color(0.7, 0, 0), color(0, 0.3, 0.02)
  T.assert_color_eq(mix(a, b, 0.5), color(0.35, 0.15, 0.01))
  T.assert_color_eq(mix(a, b, 0.25), color(0.525, 0.075, 0.005))
end)

T.test("Halfway between black and white, the way browsers do it", function()
  T.with_linear_blending(false, function()
    local a, b = color(0, 0, 0), color(1, 1, 1)
    T.assert_color_eq(mix(a, b, 0.5), color(0.2140, 0.2140, 0.2140))
  end)
end)

T.test("Red to green, the way browsers do it", function()
  T.with_linear_blending(false, function()
    local a, b = color(0.7, 0, 0), color(0, 0.3, 0.02)
    T.assert_color_eq(mix(a, b, 0.5), color(0.1527, 0.0693, 0.0067))
  end)
end)

T.test("The light's way never clamps", function()
  local a, b = color(1.5, 0.5, -0.2), color(0, 0, 0)
  T.assert_color_eq(mix(a, b, 0), color(1.5, 0.5, -0.2))
  T.assert_color_eq(mix(a, b, 0.5), color(0.75, 0.25, -0.1))
end)

T.test("The switch can be passed instead of set", function()
  local a, b = color(0, 0, 0), color(1, 1, 1)
  T.assert_color_eq(mix(a, b, 0.5, true), color(0.5, 0.5, 0.5))
  T.assert_color_eq(mix(a, b, 0.5, false), color(0.2140, 0.2140, 0.2140))
  T.assert_true(color_mod.get_linear_blending())
end)

T.test("The browser's way clamps each end before encoding it", function()
  T.with_linear_blending(false, function()
    local a, b = color(1.5, 0.5, -0.2), color(0, 0, 0)
    T.assert_color_eq(mix(a, b, 0), color(1, 0.5, 0))
    T.assert_color_eq(mix(a, b, 0.5), color(0.2140, 0.1113, 0.0000))
  end)
end)

T.test("The ends of a mix are its inputs either way, when they're in range", function()
  T.with_linear_blending(false, function()
    local a, b = color(0.7, 0, 0), color(0, 0.3, 0.02)
    T.assert_color_eq(mix(a, b, 0), a)
    T.assert_color_eq(mix(a, b, 1), b)
  end)
end)

-- ---- chapter01-plate.feature --------------------------------------------------

T.test("Plate 1", function()
  local c = renders.plate_01()
  local ref = read_file("reference/chapter-01/plate-01.ppm")
  local ppm = canvas_to_ppm(c)
  T.assert_exact(c.width, 400)
  T.assert_exact(c.height, 180)
  local function check(x, y, rr, gg, bb)
    local r, g, b = ppm_pixel(ppm, x, y)
    T.assert_eq(r, rr, 1, "r@" .. x .. "," .. y)
    T.assert_eq(g, gg, 1, "g@" .. x .. "," .. y)
    T.assert_eq(b, bb, 1, "b@" .. x .. "," .. y)
  end
  check(0, 20, 0, 0, 0)
  check(399, 20, 255, 255, 255)
  check(200, 20, 128, 128, 128)
  check(200, 65, 188, 188, 188)
  check(200, 42, 0, 0, 0)
  check(0, 110, 218, 0, 0)
  check(399, 110, 0, 149, 39)
  check(200, 110, 109, 75, 19)
  check(200, 155, 160, 108, 26)
  check(200, 87, 0, 0, 0)
  check(200, 132, 0, 0, 0)
  check(200, 177, 0, 0, 0)
  T.assert_true(max_channel_difference(ppm, ref) <= 1)
end)
