-- Chapter 4: the 3x3 matrix, the four transforms, and approx_scale.
local tuple_mod = require("tuple")
local Tuple = tuple_mod.Tuple
local make_tuple = tuple_mod.make

local Matrix = {}
Matrix.__index = Matrix

local function matrix3(...)
  local v = { ... }
  assert(#v == 9, "matrix3 takes nine numbers")
  return setmetatable({ v = v }, Matrix)
end

local function mat_get(M, r, c) return M.v[r * 3 + c + 1] end

local function identity() return matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1) end

function Matrix.__eq(A, B)
  for i = 1, 9 do
    if math.abs(A.v[i] - B.v[i]) > 0.0001 then return false end
  end
  return true
end

function Matrix.__mul(A, B)
  if getmetatable(B) == Matrix then
    local v = {}
    for r = 0, 2 do
      for c = 0, 2 do
        local s = 0
        for k = 0, 2 do s = s + mat_get(A, r, k) * mat_get(B, k, c) end
        v[r * 3 + c + 1] = s
      end
    end
    return setmetatable({ v = v }, Matrix)
  elseif getmetatable(B) == Tuple then
    local x = mat_get(A, 0, 0) * B.x + mat_get(A, 0, 1) * B.y + mat_get(A, 0, 2) * B.w
    local y = mat_get(A, 1, 0) * B.x + mat_get(A, 1, 1) * B.y + mat_get(A, 1, 2) * B.w
    local w = mat_get(A, 2, 0) * B.x + mat_get(A, 2, 1) * B.y + mat_get(A, 2, 2) * B.w
    return make_tuple(x, y, w)
  else
    error("matrix * unsupported operand")
  end
end

local function transpose(M)
  local v = {}
  for r = 0, 2 do
    for c = 0, 2 do
      v[r * 3 + c + 1] = mat_get(M, c, r)
    end
  end
  return setmetatable({ v = v }, Matrix)
end

local function minor(M, r, c)
  local rows, cols = {}, {}
  for i = 0, 2 do if i ~= r then rows[#rows + 1] = i end end
  for i = 0, 2 do if i ~= c then cols[#cols + 1] = i end end
  return mat_get(M, rows[1], cols[1]) * mat_get(M, rows[2], cols[2])
       - mat_get(M, rows[1], cols[2]) * mat_get(M, rows[2], cols[1])
end

local function cofactor(M, r, c)
  local m = minor(M, r, c)
  if (r + c) % 2 == 1 then return -m else return m end
end

local function determinant(M)
  return mat_get(M, 0, 0) * cofactor(M, 0, 0)
       + mat_get(M, 0, 1) * cofactor(M, 0, 1)
       + mat_get(M, 0, 2) * cofactor(M, 0, 2)
end

local function is_invertible(M) return determinant(M) ~= 0 end

local function inverse(M)
  local d = determinant(M)
  local v = {}
  for r = 0, 2 do
    for c = 0, 2 do
      v[c * 3 + r + 1] = cofactor(M, r, c) / d -- [c, r]: the transpose happens here
    end
  end
  return setmetatable({ v = v }, Matrix)
end

local function translation(tx, ty) return matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1) end
local function scaling(sx, sy) return matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1) end
local function rotation(r)
  return matrix3(math.cos(r), -math.sin(r), 0,
                 math.sin(r), math.cos(r), 0,
                 0, 0, 1)
end
local function shearing(xy, yx) return matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1) end

local function approx_scale(m)
  local a, b, c, d = mat_get(m, 0, 0), mat_get(m, 0, 1), mat_get(m, 1, 0), mat_get(m, 1, 1)
  return math.sqrt(math.abs(a * d - b * c))
end

local function transform_points(points, m)
  local out = {}
  for i, p in ipairs(points) do out[i] = m * p end
  return out
end

return {
  Matrix = Matrix,
  matrix3 = matrix3,
  mat_get = mat_get,
  identity = identity,
  transpose = transpose,
  minor = minor,
  cofactor = cofactor,
  determinant = determinant,
  is_invertible = is_invertible,
  inverse = inverse,
  translation = translation,
  scaling = scaling,
  rotation = rotation,
  shearing = shearing,
  approx_scale = approx_scale,
  transform_points = transform_points,
}
