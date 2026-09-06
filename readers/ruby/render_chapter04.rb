#!/usr/bin/env ruby

require_relative 'renderer'
require 'time'

puts "Rendering Chapter 4 outputs..."

Dir.mkdir("out") unless Dir.exist?("out")

# Render fan-both-orders
puts "Rendering fan-both-orders..."
start_time = Time.now
c = fan_both_orders
elapsed = Time.now - start_time
puts "  fan-both-orders rendered in #{elapsed.round(2)} seconds"
p6 = canvas_to_p6(c)
File.open("out/fan-both-orders.ppm", "wb") do |f|
  f.write(p6)
end
puts "  Wrote out/fan-both-orders.ppm"

# Render plate-04
puts "Rendering plate-04..."
start_time = Time.now
c = plate_04
elapsed = Time.now - start_time
puts "  plate-04 rendered in #{elapsed.round(2)} seconds"
p6 = canvas_to_p6(c)
File.open("out/plate-04.ppm", "wb") do |f|
  f.write(p6)
end
puts "  Wrote out/plate-04.ppm"

puts "Done!"
