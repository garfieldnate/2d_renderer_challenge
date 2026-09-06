#!/usr/bin/env lua
-- Runs the whole test suite. Run from the repository root:
--   lua run_tests.lua
package.path = "src/?.lua;spec/?.lua;" .. package.path

local T = require("helpers")

require("chapter01_spec")
require("chapter02_spec")
require("chapter03_spec")
require("chapter04_spec")
require("chapter05_spec")
require("chapter06_spec")

local ok = T.run()
os.exit(ok and 0 or 1)
