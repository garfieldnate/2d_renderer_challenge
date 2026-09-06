-- Shared test helpers and a tiny hand-rolled test runner.
local canvas_mod = require("canvas")

local T = {}
local tests = {}     -- { {name=, fn=}, ... }
local results = {}   -- filled in by T.run()

function T.test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local DEFAULT_EPS = 0.0001

function T.approx(a, b, eps)
  eps = eps or DEFAULT_EPS
  return math.abs(a - b) <= eps
end

function T.assert_eq(actual, expected, eps, msg)
  eps = eps or DEFAULT_EPS
  if not T.approx(actual, expected, eps) then
    error(string.format("%s: expected %s, got %s (eps %s)", msg or "assert_eq", tostring(expected), tostring(actual), tostring(eps)), 2)
  end
end

function T.assert_ne(actual, expected, eps, msg)
  eps = eps or DEFAULT_EPS
  if T.approx(actual, expected, eps) then
    error(string.format("%s: expected NOT %s, got %s", msg or "assert_ne", tostring(expected), tostring(actual)), 2)
  end
end

function T.assert_exact(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected exactly %s, got %s", msg or "assert_exact", tostring(expected), tostring(actual)), 2)
  end
end

function T.assert_true(cond, msg)
  if not cond then error(msg or "expected true, got false", 2) end
end

function T.assert_false(cond, msg)
  if cond then error(msg or "expected false, got true", 2) end
end

function T.color_eq(a, b, eps)
  return T.approx(a.r, b.r, eps) and T.approx(a.g, b.g, eps) and T.approx(a.b, b.b, eps)
end

function T.assert_color_eq(actual, expected, eps, msg)
  if not T.color_eq(actual, expected, eps) then
    error(string.format("%s: expected color(%.6g,%.6g,%.6g), got color(%.6g,%.6g,%.6g)",
      msg or "assert_color_eq", expected.r, expected.g, expected.b, actual.r, actual.g, actual.b), 2)
  end
end

function T.assert_color_ne(actual, expected, eps, msg)
  if T.color_eq(actual, expected, eps) then
    error(msg or "expected colors to differ", 2)
  end
end

function T.tuple_eq(a, b, eps)
  return T.approx(a.x, b.x, eps) and T.approx(a.y, b.y, eps) and T.approx(a.w, b.w, eps)
end

function T.assert_tuple_eq(actual, expected, eps, msg)
  if not T.tuple_eq(actual, expected, eps) then
    error(string.format("%s: expected (%.6g,%.6g,w=%.6g), got (%.6g,%.6g,w=%.6g)",
      msg or "assert_tuple_eq", expected.x, expected.y, expected.w, actual.x, actual.y, actual.w), 2)
  end
end

function T.assert_point_list_eq(actual, expected, eps, msg)
  T.assert_exact(#actual, #expected, (msg or "point list") .. " length")
  for i = 1, #expected do
    T.assert_tuple_eq(actual[i], expected[i], eps, (msg or "point list") .. " [" .. i .. "]")
  end
end

function T.assert_pixel_pair_list_eq(actual, expected, msg)
  T.assert_exact(#actual, #expected, (msg or "pixel list") .. " length")
  for i = 1, #expected do
    T.assert_exact(actual[i][1], expected[i][1], (msg or "pixel list") .. " [" .. i .. "].x")
    T.assert_exact(actual[i][2], expected[i][2], (msg or "pixel list") .. " [" .. i .. "].y")
  end
end

function T.mat_eq(A, B, eps)
  for i = 1, 9 do
    if not T.approx(A.v[i], B.v[i], eps) then return false end
  end
  return true
end

function T.assert_mat_eq(actual, expected, eps, msg)
  if not T.mat_eq(actual, expected, eps) then
    error(msg or "matrices differ", 2)
  end
end

function T.assert_span_list_eq(actual, expected, eps, msg)
  T.assert_exact(#actual, #expected, (msg or "span list") .. " length")
  for i = 1, #expected do
    T.assert_eq(actual[i][1], expected[i][1], eps, (msg or "span list") .. " [" .. i .. "].x0")
    T.assert_eq(actual[i][2], expected[i][2], eps, (msg or "span list") .. " [" .. i .. "].x1")
  end
end

function T.assert_crossing_list_eq(actual, expected, eps, msg)
  T.assert_exact(#actual, #expected, (msg or "crossing list") .. " length")
  for i = 1, #expected do
    T.assert_eq(actual[i][1], expected[i][1], eps, (msg or "crossing list") .. " [" .. i .. "].x")
    T.assert_exact(actual[i][2], expected[i][2], (msg or "crossing list") .. " [" .. i .. "].direction")
  end
end

-- lit_pixels(c): every pixel that isn't black, reading order, with tolerance.
-- Test helper, not a renderer function (the book says so explicitly).
function T.lit_pixels(c)
  local black = { r = 0, g = 0, b = 0 }
  local out = {}
  for y = 0, c.height - 1 do
    for x = 0, c.width - 1 do
      local p = canvas_mod.pixel_at(c, x, y)
      if not T.color_eq(p, black, DEFAULT_EPS) then
        out[#out + 1] = { x, y }
      end
    end
  end
  return out
end

function T.every_pixel_is(c, col, eps)
  for i = 1, c.width * c.height do
    if not T.color_eq(c.pixels[i], col, eps) then return false end
  end
  return true
end

function T.count_pixels_of(c, col, eps)
  local n = 0
  for i = 1, c.width * c.height do
    if T.color_eq(c.pixels[i], col, eps) then n = n + 1 end
  end
  return n
end

function T.assert_bounds_eq(actual, expected, eps, msg)
  eps = eps or DEFAULT_EPS
  T.assert_eq(actual.minx, expected[1], eps, (msg or "bounds") .. ".minx")
  T.assert_eq(actual.miny, expected[2], eps, (msg or "bounds") .. ".miny")
  T.assert_eq(actual.maxx, expected[3], eps, (msg or "bounds") .. ".maxx")
  T.assert_eq(actual.maxy, expected[4], eps, (msg or "bounds") .. ".maxy")
end

-- Runs fn with the global linear-blending switch set to `value`, then
-- restores whatever it was before, even if fn errors (a scenario that turns
-- it off must not leak into the next one).
function T.with_linear_blending(value, fn)
  local color_mod = require("color")
  local prev = color_mod.get_linear_blending()
  color_mod.set_linear_blending(value)
  local ok, err = pcall(fn)
  color_mod.set_linear_blending(prev)
  if not ok then error(err, 0) end
end

-- ---- runner --------------------------------------------------------------

function T.run()
  local pass, fail = 0, 0
  local failures = {}
  for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
      pass = pass + 1
      -- io.write(".")
    else
      fail = fail + 1
      failures[#failures + 1] = { name = t.name, err = err }
      io.write("FAIL: " .. t.name .. "\n      " .. tostring(err) .. "\n")
    end
  end
  io.write(string.format("\n%d passed, %d failed, %d total\n", pass, fail, pass + fail))
  return fail == 0, pass, fail, failures
end

function T.reset()
  tests = {}
end

function T.count()
  return #tests
end

return T
