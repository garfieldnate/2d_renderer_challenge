#!/usr/bin/env ruby

require_relative 'renderer'
require 'time'

puts "Rendering Chapter 3 outputs..."

# Render fan-coverage (this is slow)
puts "Rendering fan-coverage... (this will take a minute or more)"
start_time = Time.now
c = fan_coverage
elapsed = Time.now - start_time
puts "  fan-coverage rendered in #{elapsed.round(2)} seconds"

# Write fan-coverage
p6 = canvas_to_p6(c)
File.open("out/fan-coverage.ppm", "wb") do |f|
  f.write(p6)
end
puts "  Wrote out/fan-coverage.ppm"

# Render plate-03
puts "Rendering plate-03..."
start_time = Time.now
c = plate_03
elapsed = Time.now - start_time
puts "  plate-03 rendered in #{elapsed.round(2)} seconds"

# Write plate-03
p6 = canvas_to_p6(c)
File.open("out/plate-03.ppm", "wb") do |f|
  f.write(p6)
end
puts "  Wrote out/plate-03.ppm"

puts "Done!"
