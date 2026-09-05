#!/usr/bin/env ruby

require_relative 'renderer'

# Generate Chapter 2 output images

# Create out directory if it doesn't exist
Dir.mkdir('out') unless Dir.exist?('out')

# disc-centers.ppm
puts "Generating disc-centers.ppm..."
c = disc_centers()
File.write('out/disc-centers.ppm', canvas_to_p6(c), mode: 'wb')
puts "  Size: #{c.width}x#{c.height}"

# disc-coverage.ppm
puts "Generating disc-coverage.ppm..."
c = disc_coverage()
File.write('out/disc-coverage.ppm', canvas_to_p6(c), mode: 'wb')
puts "  Size: #{c.width}x#{c.height}"

# painted-twice.ppm
puts "Generating painted-twice.ppm..."
c = painted_twice()
File.write('out/painted-twice.ppm', canvas_to_p6(c), mode: 'wb')
puts "  Size: #{c.width}x#{c.height}"

# plate-02.ppm
puts "Generating plate-02.ppm..."
c = plate_02()
File.write('out/plate-02.ppm', canvas_to_p6(c), mode: 'wb')
puts "  Size: #{c.width}x#{c.height}"

puts "\nAll outputs generated successfully!"
