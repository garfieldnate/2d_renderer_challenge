-- Chapter 6: the edge table, spans, and the scanline sweep.
local path_mod = require("path")
local coverage_mod = require("coverage")
local edges = path_mod.edges
local coverage_buffer = coverage_mod.coverage_buffer
local set_coverage = coverage_mod.set_coverage

local function edge_table(p)
  local t = {}
  for _, e in ipairs(edges(p)) do
    local a, b = e[1], e[2]
    if a.y ~= b.y then
      local entry
      if a.y < b.y then
        entry = { y_top = a.y, y_bottom = b.y, x_top = a.x, slope = (b.x - a.x) / (b.y - a.y), direction = 1 }
      else
        entry = { y_top = b.y, y_bottom = a.y, x_top = b.x, slope = (a.x - b.x) / (a.y - b.y), direction = -1 }
      end
      t[#t + 1] = entry
    end
  end
  table.sort(t, function(e1, e2)
    if e1.y_top ~= e2.y_top then return e1.y_top < e2.y_top end
    return e1.x_top < e2.x_top
  end)
  return t
end

local function x_at(edge, y) return edge.x_top + (y - edge.y_top) * edge.slope end

local function crossings_on_row(table_, y)
  local out = {}
  for _, e in ipairs(table_) do
    if e.y_top <= y and y < e.y_bottom then
      out[#out + 1] = { x_at(e, y), e.direction }
    end
  end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

local function spans_from_crossings(xs, rule)
  local out = {}
  local w = 0
  local start = nil
  for _, xd in ipairs(xs) do
    local x, d = xd[1], xd[2]
    w = w + d
    local ins
    if rule == "nonzero" then ins = (w ~= 0) else ins = (w % 2 ~= 0) end
    if ins and start == nil then start = x end
    if not ins and start ~= nil then
      out[#out + 1] = { start, x }
      start = nil
    end
  end
  return out
end

local function spans(p, rule, row)
  local y = row + 0.5
  return spans_from_crossings(crossings_on_row(edge_table(p), y), rule)
end

local function fill_span(cov, row, x0, x1)
  local first = math.max(math.ceil(x0 - 0.5), 0)
  local last = math.min(math.ceil(x1 - 0.5) - 1, cov.width - 1)
  for x = first, last do set_coverage(cov, x, row, 1) end
end

local function fill_path_aliased(p, rule, w, h)
  local cov = coverage_buffer(w, h)
  local table_ = edge_table(p)
  local active = {}
  local next_i = 1
  for row = 0, h - 1 do
    local y = row + 0.5
    while next_i <= #table_ and table_[next_i].y_top <= y do
      active[#active + 1] = table_[next_i]
      next_i = next_i + 1
    end
    local kept = {}
    for _, e in ipairs(active) do
      if e.y_bottom > y then kept[#kept + 1] = e end
    end
    active = kept
    local xs = {}
    for _, e in ipairs(active) do xs[#xs + 1] = { x_at(e, y), e.direction } end
    table.sort(xs, function(a, b) return a[1] < b[1] end)
    for _, span in ipairs(spans_from_crossings(xs, rule)) do
      fill_span(cov, row, span[1], span[2])
    end
  end
  return cov
end

local function transform_path(p, m)
  local out = { subpaths = {} }
  for _, sp in ipairs(p.subpaths) do
    local newpts = {}
    for i, pt in ipairs(sp.points) do newpts[i] = m * pt end
    out.subpaths[#out.subpaths + 1] = { points = newpts, closed = sp.closed }
  end
  return out
end

return {
  edge_table = edge_table,
  x_at = x_at,
  crossings_on_row = crossings_on_row,
  spans_from_crossings = spans_from_crossings,
  spans = spans,
  fill_span = fill_span,
  fill_path_aliased = fill_path_aliased,
  transform_path = transform_path,
}
