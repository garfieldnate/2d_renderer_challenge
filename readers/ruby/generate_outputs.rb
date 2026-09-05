require_relative 'renderer'

# Generate all five output files
outputs = {
  'out/gray-match.ppm' => gray_match,
  'out/quarter-match.ppm' => quarter_match,
  'out/ramp.ppm' => ramp,
  'out/clamp-pair.ppm' => clamp_pair,
  'out/plate-01.ppm' => plate_01
}

outputs.each do |filename, canvas|
  ppm = canvas_to_ppm(canvas)
  File.write(filename, ppm)
  puts "Generated #{filename} (#{File.size(filename)} bytes)"
end
