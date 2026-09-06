#!/usr/bin/env ruby

require_relative 'renderer'
require 'time'

puts "Rendering Chapter 5 outputs..."

Dir.mkdir("out") unless Dir.exist?("out")

def render_and_report(name, &block)
  puts "Rendering #{name}..."
  start_time = Time.now
  c = block.call
  elapsed = Time.now - start_time
  puts "  #{name} rendered in #{elapsed.round(2)} seconds"
  p6 = canvas_to_p6(c)
  File.open("out/#{name}.ppm", "wb") { |f| f.write(p6) }
  puts "  Wrote out/#{name}.ppm"

  ref_path = "reference/chapter-05/#{name}.ppm"
  if File.exist?(ref_path)
    ref = read_file(ref_path)
    diff = max_channel_difference(p6, ref)
    puts "  max_channel_difference vs reference: #{diff}"
  end
end

render_and_report("star-centers") { star_centers }
render_and_report("star-coverage") { star_coverage }
render_and_report("plate-05") { plate_05 }

puts "Done!"
