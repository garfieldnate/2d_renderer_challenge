#!/usr/bin/env lua
-- Regenerates every named render into out/ (using the reference filenames)
-- and reports max_channel_difference against reference/chapter-0N/*.ppm.
-- Run from the repository root:  lua render_all.lua
package.path = "src/?.lua;" .. package.path

local renders = require("renders")
local ppm_mod = require("ppm")

local function write_file(path, data)
  local f = assert(io.open(path, "wb"))
  f:write(data)
  f:close()
end

os.execute("mkdir -p out")

local jobs = {
  { chapter = "chapter-01", name = "gray-match", fn = renders.gray_match, format = "p3" },
  { chapter = "chapter-01", name = "quarter-match", fn = renders.quarter_match, format = "p3" },
  { chapter = "chapter-01", name = "ramp", fn = renders.ramp, format = "p3" },
  { chapter = "chapter-01", name = "clamp-pair", fn = renders.clamp_pair, format = "p3" },
  { chapter = "chapter-01", name = "plate-01", fn = renders.plate_01, format = "p3" },

  { chapter = "chapter-02", name = "disc-centers", fn = renders.disc_centers, format = "p6" },
  { chapter = "chapter-02", name = "disc-coverage", fn = renders.disc_coverage, format = "p6" },
  { chapter = "chapter-02", name = "painted-twice", fn = renders.painted_twice, format = "p6" },
  { chapter = "chapter-02", name = "plate-02", fn = renders.plate_02, format = "p6" },

  { chapter = "chapter-03", name = "fan-bresenham", fn = renders.fan_bresenham, format = "p6" },
  { chapter = "chapter-03", name = "fan-wu", fn = renders.fan_wu, format = "p6" },
  { chapter = "chapter-03", name = "fan-coverage", fn = renders.fan_coverage, format = "p6" },
  { chapter = "chapter-03", name = "plate-03", fn = renders.plate_03, format = "p6" },

  { chapter = "chapter-04", name = "fan-both-orders", fn = renders.fan_both_orders, format = "p6" },
  { chapter = "chapter-04", name = "plate-04", fn = renders.plate_04, format = "p6" },

  { chapter = "chapter-05", name = "star-centers", fn = renders.star_centers, format = "p6" },
  { chapter = "chapter-05", name = "star-coverage", fn = renders.star_coverage, format = "p6" },
  { chapter = "chapter-05", name = "plate-05", fn = renders.plate_05, format = "p6" },

  { chapter = "chapter-06", name = "spiral", fn = renders.spiral, format = "p6" },
  { chapter = "chapter-06", name = "plate-06", fn = renders.plate_06, format = "p6" },
}

local all_ok = true
for _, job in ipairs(jobs) do
  local t0 = os.clock()
  local c = job.fn()
  local data
  if job.format == "p3" then data = ppm_mod.canvas_to_ppm(c) else data = ppm_mod.canvas_to_p6(c) end
  local out_path = "out/" .. job.name .. ".ppm"
  write_file(out_path, data)
  local elapsed = os.clock() - t0
  local ref_path = "reference/" .. job.chapter .. "/" .. job.name .. ".ppm"
  local ref_f = io.open(ref_path, "rb")
  local diff = "no reference"
  if ref_f then
    local ref = ref_f:read("a")
    ref_f:close()
    diff = tostring(ppm_mod.max_channel_difference(data, ref))
  end
  if diff ~= "no reference" and tonumber(diff) and tonumber(diff) > 1 then all_ok = false end
  io.write(string.format("%-10s %-16s max_channel_difference=%-4s (%.2fs)\n", job.chapter, job.name, diff, elapsed))
end

if not all_ok then
  io.write("\nSome renders differ from the reference by more than 1.\n")
  os.exit(1)
end
