# The 2D Renderer Challenge - Chapter 1
# Ruby implementation

# Global state for linear blending mode
$linear_blending = true

# Color class - represents floating point RGB values
class Color
  attr_accessor :red, :green, :blue

  def initialize(red, green, blue)
    @red = red
    @green = green
    @blue = blue
  end

  def +(other)
    Color.new(@red + other.red, @green + other.green, @blue + other.blue)
  end

  def -(other)
    Color.new(@red - other.red, @green - other.green, @blue - other.blue)
  end

  def *(scalar_or_color)
    if scalar_or_color.is_a?(Color)
      # Hadamard product (component-wise multiplication)
      Color.new(@red * scalar_or_color.red, @green * scalar_or_color.green, @blue * scalar_or_color.blue)
    else
      # Scalar multiplication
      Color.new(@red * scalar_or_color, @green * scalar_or_color, @blue * scalar_or_color)
    end
  end

  def ==(other)
    equal_within?(other, 0.0001)
  end

  def !=(other)
    !equal_within?(other, 0.0001)
  end

  def equal_within?(other, tolerance)
    return false unless other.is_a?(Color)
    (@red - other.red).abs <= tolerance &&
      (@green - other.green).abs <= tolerance &&
      (@blue - other.blue).abs <= tolerance
  end

  def to_s
    "Color(#{@red}, #{@green}, #{@blue})"
  end
end

# Canvas class - a rectangle of pixels
class Canvas
  attr_accessor :width, :height

  def initialize(width, height)
    @width = width
    @height = height
    @pixels = Array.new(height) { Array.new(width) { Color.new(0, 0, 0) } }
  end

  def write_pixel(x, y, color)
    return if x < 0 || x >= @width || y < 0 || y >= @height
    @pixels[y][x] = color
  end

  def pixel_at(x, y)
    return nil if x < 0 || x >= @width || y < 0 || y >= @height
    @pixels[y][x]
  end

  def fill(color)
    @height.times do |y|
      @width.times do |x|
        @pixels[y][x] = color
      end
    end
  end

  def to_a
    @pixels
  end
end

# sRGB transfer functions
def encode(light)
  if light <= 0.0031308
    light * 12.92
  else
    1.055 * (light ** (1.0 / 2.4)) - 0.055
  end
end

def decode(value)
  if value <= 0.04045
    value / 12.92
  else
    ((value + 0.055) / 1.055) ** 2.4
  end
end

# Convert floating point light value to byte (0-255)
def to_byte(light)
  v = light > 1 ? 1 : light
  v = 0 if v < 0
  (encode(v) * 255 + 0.5).floor
end

# Mix two colors with optional linear blending
# A fourth argument overrides the global $linear_blending switch for this
# call only, without changing the switch itself.
def mix(a, b, t, linear_blending = nil)
  linear_blending = $linear_blending if linear_blending.nil?
  if linear_blending
    # Linear blending: interpolate in light space
    Color.new(
      a.red + (b.red - a.red) * t,
      a.green + (b.green - a.green) * t,
      a.blue + (b.blue - a.blue) * t
    )
  else
    # Non-linear blending: interpolate in encoded space, then clamp
    encoded_a = Color.new(encode(a.red), encode(a.green), encode(a.blue))
    encoded_b = Color.new(encode(b.red), encode(b.green), encode(b.blue))

    # Clamp a to 0-1 before encoding
    encoded_a = Color.new(
      [0, [1, encoded_a.red].min].max,
      [0, [1, encoded_a.green].min].max,
      [0, [1, encoded_a.blue].min].max
    )

    mixed = Color.new(
      encoded_a.red + (encoded_b.red - encoded_a.red) * t,
      encoded_a.green + (encoded_b.green - encoded_a.green) * t,
      encoded_a.blue + (encoded_b.blue - encoded_a.blue) * t
    )

    Color.new(
      decode(mixed.red),
      decode(mixed.green),
      decode(mixed.blue)
    )
  end
end

# Canvas to PPM text format
def canvas_to_ppm(canvas)
  lines = []
  lines << "P3"
  lines << "#{canvas.width} #{canvas.height}"
  lines << "255"

  pixel_line = ""
  canvas.height.times do |y|
    canvas.width.times do |x|
      color = canvas.pixel_at(x, y)
      r = to_byte(color.red)
      g = to_byte(color.green)
      b = to_byte(color.blue)

      pixel_str = "#{r} #{g} #{b}"

      if pixel_line.empty?
        pixel_line = pixel_str
      else
        # Check if adding this pixel (with space) would exceed 70 chars
        test_line = pixel_line + " " + pixel_str
        if test_line.length <= 70
          pixel_line = test_line
        else
          # Line would be too long, output current line and start new one
          lines << pixel_line
          pixel_line = pixel_str
        end
      end
    end

    # End of row: output any remaining content
    lines << pixel_line unless pixel_line.empty?
    pixel_line = ""
  end

  lines.join("\n") + "\n"
end

# Parse PPM text and extract pixel value at (x, y)
def ppm_pixel(ppm_text, x, y)
  lines = ppm_text.split("\n")

  # Skip header (lines 0-2)
  pixels = []
  (3...lines.length).each do |i|
    line = lines[i].strip
    next if line.empty?

    values = line.split.map(&:to_i)
    pixels.concat(values)
  end

  # Each pixel is 3 values (R, G, B)
  pixel_index = y * 0 + x # Will calculate width from header
  # Actually, we need to know the width to calculate the proper index
  # Let's parse the header
  width = lines[1].split[0].to_i
  height = lines[1].split[1].to_i

  pixel_index = (y * width + x) * 3
  [pixels[pixel_index], pixels[pixel_index + 1], pixels[pixel_index + 2]]
end

# Read file contents (binary safe)
def read_file(path)
  File.read(path, encoding: Encoding::ASCII_8BIT)
end

# Find maximum difference between two PPM files
def max_channel_difference(ppm1, ppm2)
  lines1 = ppm1.split("\n")
  lines2 = ppm2.split("\n")

  # Parse both PPMs
  pixels1 = parse_ppm_pixels(lines1)
  pixels2 = parse_ppm_pixels(lines2)

  # Check dimensions match
  return 255 if lines1[1] != lines2[1] || lines1[2] != lines2[2]

  max_diff = 0
  [pixels1.length, pixels2.length].min.times do |i|
    diff = (pixels1[i] - pixels2[i]).abs
    max_diff = diff if diff > max_diff
  end

  max_diff
end

# Count distinct pixel values in PPM
def distinct_values(ppm_text)
  lines = ppm_text.split("\n")
  pixels = parse_ppm_pixels(lines)

  pixels.uniq.length
end

# Helper to parse pixels from PPM lines
def parse_ppm_pixels(lines)
  pixels = []
  (3...lines.length).each do |i|
    line = lines[i].strip
    next if line.empty?

    values = line.split.map(&:to_i)
    pixels.concat(values)
  end
  pixels
end

# Create the gray match canvas
def gray_match
  c = Canvas.new(300, 100)

  # First 100 pixels wide: checkerboard
  (0...100).each do |x|
    (0...100).each do |y|
      if (x + y) % 2 == 0
        c.write_pixel(x, y, Color.new(1, 1, 1))
      else
        c.write_pixel(x, y, Color.new(0, 0, 0))
      end
    end
  end

  # Next 100 pixels wide: 128 gray (decoded)
  gray_128 = Color.new(decode(128.0 / 255), decode(128.0 / 255), decode(128.0 / 255))
  (100...200).each do |x|
    (0...100).each do |y|
      c.write_pixel(x, y, gray_128)
    end
  end

  # Last 100 pixels wide: 0.5 gray (linear)
  (200...300).each do |x|
    (0...100).each do |y|
      c.write_pixel(x, y, Color.new(0.5, 0.5, 0.5))
    end
  end

  c
end

# Create the quarter match canvas (1 in 4 pixels are white)
def quarter_match
  c = Canvas.new(200, 100)

  # Left half (x=0-99): diagonal stripe pattern where (x+y)%4==0 is white
  # Right half (x=100-199): all gray (0.25)
  (0...200).each do |x|
    (0...100).each do |y|
      if x < 100
        # Diagonal stripes in left half
        if (x + y) % 4 == 0
          c.write_pixel(x, y, Color.new(1, 1, 1))
        else
          c.write_pixel(x, y, Color.new(0, 0, 0))
        end
      else
        # Gray in right half
        c.write_pixel(x, y, Color.new(0.25, 0.25, 0.25))
      end
    end
  end

  c
end

# Create a 256-step ramp
def ramp
  c = Canvas.new(256, 32)

  (0...256).each do |x|
    light = x / 255.0
    color = Color.new(light, light, light)
    (0...32).each do |y|
      c.write_pixel(x, y, color)
    end
  end

  c
end

# Create clamp pair canvas
def clamp_pair
  c = Canvas.new(200, 100)

  color1 = Color.new(2, 0.5, 0.5)
  color2 = Color.new(1, 0.25, 0.25)

  (0...100).each do |x|
    (0...100).each do |y|
      c.write_pixel(x, y, color1)
    end
  end

  (100...200).each do |x|
    (0...100).each do |y|
      c.write_pixel(x, y, color2)
    end
  end

  c
end

# Create plate 01
def plate_01
  c = Canvas.new(400, 180)

  # Two ramps: black-white and red-green
  ramps = [
    [[0, 0, 0], [1, 1, 1]],
    [[0.7, 0, 0], [0, 0.3, 0.02]]
  ]

  ramps.each_with_index do |ramp_colors, ri|
    start_y = ri * 90

    (0...400).each do |x|
      t = x / 399.0

      # Non-linear blend (browser way)
      color_naive = mix_non_linear(
        Color.new(*ramp_colors[0]),
        Color.new(*ramp_colors[1]),
        t
      )

      # Linear blend (light way)
      color_light = mix(
        Color.new(*ramp_colors[0]),
        Color.new(*ramp_colors[1]),
        t
      )

      # Write naive blend (y: start_y to start_y + 39)
      (start_y...start_y + 40).each do |y|
        c.write_pixel(x, y, color_naive)
      end

      # Write light blend (y: start_y + 45 to start_y + 84)
      (start_y + 45...start_y + 85).each do |y|
        c.write_pixel(x, y, color_light)
      end
    end
  end

  c
end

# Helper for non-linear mix (browser way)
def mix_non_linear(a, b, t)
  # Clamp inputs to 0-1 first
  a_clamped = Color.new(
    [0, [1, a.red].min].max,
    [0, [1, a.green].min].max,
    [0, [1, a.blue].min].max
  )

  # Encode both colors
  encoded_a = Color.new(
    encode(a_clamped.red),
    encode(a_clamped.green),
    encode(a_clamped.blue)
  )
  encoded_b = Color.new(
    encode(b.red),
    encode(b.green),
    encode(b.blue)
  )

  # Mix in encoded space
  mixed = Color.new(
    encoded_a.red + (encoded_b.red - encoded_a.red) * t,
    encoded_a.green + (encoded_b.green - encoded_a.green) * t,
    encoded_a.blue + (encoded_b.blue - encoded_a.blue) * t
  )

  # Decode back to light
  Color.new(
    decode(mixed.red),
    decode(mixed.green),
    decode(mixed.blue)
  )
end

# Helper functions for testing
def color(r, g, b)
  Color.new(r, g, b)
end

def canvas(w, h)
  Canvas.new(w, h)
end

def write_pixel(c, x, y, color)
  c.write_pixel(x, y, color)
end

def pixel_at(c, x, y)
  c.pixel_at(x, y)
end

def fill(c, color)
  c.fill(color)
end

# ========================================
# Chapter 2: Coverage
# ========================================

# Shape classes
class Shape
  # Base class for all shapes
end

class Circle < Shape
  attr_accessor :cx, :cy, :radius

  def initialize(cx, cy, radius)
    @cx = cx
    @cy = cy
    @radius = radius
  end

  def inside?(x, y)
    dx = x - @cx
    dy = y - @cy
    (dx * dx + dy * dy) <= (@radius * @radius)
  end
end

class Rectangle < Shape
  attr_accessor :x0, :y0, :x1, :y1

  def initialize(x0, y0, x1, y1)
    @x0 = x0
    @y0 = y0
    @x1 = x1
    @y1 = y1
  end

  def inside?(x, y)
    x >= @x0 && x <= @x1 && y >= @y0 && y <= @y1
  end
end

class HalfPlane < Shape
  attr_accessor :px, :py, :nx, :ny

  def initialize(px, py, nx, ny)
    @px = px
    @py = py
    @nx = nx
    @ny = ny
  end

  def inside?(x, y)
    # Vector from (px, py) to (x, y)
    vx = x - @px
    vy = y - @py
    # Dot product with normal
    dot = vx * @nx + vy * @ny
    dot >= 0
  end
end

# Shape factory functions
def circle(cx, cy, radius)
  Circle.new(cx, cy, radius)
end

def rectangle(x0, y0, x1, y1)
  Rectangle.new(x0, y0, x1, y1)
end

def half_plane(px, py, nx, ny)
  HalfPlane.new(px, py, nx, ny)
end

# Shape test functions
def inside(shape, x, y)
  shape.inside?(x, y)
end

def center_inside(shape, x, y)
  # Center of pixel (x, y) is at (x + 0.5, y + 0.5)
  shape.inside?(x + 0.5, y + 0.5) ? 1 : 0
end

def coverage(shape, x, y)
  # 8x8 grid of samples in pixel (x, y)
  count = 0
  8.times do |i|
    8.times do |j|
      sample_x = x + (i + 0.5) / 8.0
      sample_y = y + (j + 0.5) / 8.0
      count += 1 if shape.inside?(sample_x, sample_y)
    end
  end
  count / 64.0
end

# Coverage buffer class
class CoverageBuffer
  attr_accessor :width, :height

  def initialize(width, height)
    @width = width
    @height = height
    @coverage = Array.new(height) { Array.new(width) { 0.0 } }
  end

  def set(x, y, value)
    return if x < 0 || x >= @width || y < 0 || y >= @height
    @coverage[y][x] = value
  end

  def get(x, y)
    return 0 if x < 0 || x >= @width || y < 0 || y >= @height
    @coverage[y][x]
  end

  def sum
    total = 0.0
    @height.times do |y|
      @width.times do |x|
        total += @coverage[y][x]
      end
    end
    total
  end
end

# Coverage buffer functions
def coverage_buffer(width, height)
  CoverageBuffer.new(width, height)
end

def coverage_at(buffer, x, y)
  buffer.get(x, y)
end

def set_coverage(buffer, x, y, value)
  buffer.set(x, y, value)
end

def ink(buffer)
  buffer.sum
end

# Rasterization functions
def rasterize_centers(shape, width, height)
  cov = CoverageBuffer.new(width, height)
  height.times do |y|
    width.times do |x|
      cov.set(x, y, center_inside(shape, x, y).to_f)
    end
  end
  cov
end

def rasterize(shape, width, height)
  cov = CoverageBuffer.new(width, height)
  height.times do |y|
    width.times do |x|
      cov.set(x, y, coverage(shape, x, y))
    end
  end
  cov
end

# Canvas to P6 format (binary PPM)
def canvas_to_p6(canvas)
  header = "P6\n#{canvas.width} #{canvas.height}\n255\n"

  pixels = ""
  canvas.height.times do |y|
    canvas.width.times do |x|
      color = canvas.pixel_at(x, y)
      r = to_byte(color.red)
      g = to_byte(color.green)
      b = to_byte(color.blue)
      pixels += [r, g, b].pack("C*")
    end
  end

  header + pixels
end

# Updated ppm_pixel to handle both P3 and P6
def ppm_pixel(ppm_data, x, y)
  # Check if it's binary (P6) or text (P3)
  if ppm_data.is_a?(String) && ppm_data.start_with?("P6")
    # Binary P6 format
    header_lines = extract_ppm_header_lines(ppm_data)
    width = header_lines[1].split[0].to_i
    height = header_lines[1].split[1].to_i

    # Find where the pixel data starts (after header and single newline)
    # We need to find the position after the third newline
    newline_count = 0
    data_start = 0
    i = 0
    while i < ppm_data.length && newline_count < 3
      if ppm_data[i] == "\n" || (ppm_data[i].is_a?(Integer) && ppm_data[i] == 10)
        newline_count += 1
        data_start = i + 1
      end
      i += 1
    end

    pixel_index = (y * width + x) * 3
    if ppm_data[data_start].is_a?(Integer)
      # Binary data
      r = ppm_data[data_start + pixel_index]
      g = ppm_data[data_start + pixel_index + 1]
      b = ppm_data[data_start + pixel_index + 2]
    else
      # Text data (shouldn't happen but be safe)
      pixel_bytes = ppm_data[data_start..-1].bytes
      r = pixel_bytes[pixel_index]
      g = pixel_bytes[pixel_index + 1]
      b = pixel_bytes[pixel_index + 2]
    end
    [r, g, b]
  else
    # Text P3 format (original implementation)
    lines = ppm_data.split("\n")
    pixels = []
    (3...lines.length).each do |i|
      line = lines[i].strip
      next if line.empty?
      values = line.split.map(&:to_i)
      pixels.concat(values)
    end

    width = lines[1].split[0].to_i
    height = lines[1].split[1].to_i
    pixel_index = (y * width + x) * 3
    [pixels[pixel_index], pixels[pixel_index + 1], pixels[pixel_index + 2]]
  end
end

# Updated max_channel_difference to handle both P3 and P6
def max_channel_difference(ppm1, ppm2)
  # Determine format and parse accordingly
  is_p6_1 = ppm1.is_a?(String) && ppm1.start_with?("P6")
  is_p6_2 = ppm2.is_a?(String) && ppm2.start_with?("P6")

  # Check dimensions match
  width1 = get_ppm_width(ppm1)
  width2 = get_ppm_width(ppm2)
  height1 = get_ppm_height(ppm1)
  height2 = get_ppm_height(ppm2)

  return 255 if width1 != width2 || height1 != height2

  # Now parse pixels
  if is_p6_1 || is_p6_2
    # For P6 format, we need to read binary data
    pixels1 = parse_p6_or_p3_pixels(ppm1)
    pixels2 = parse_p6_or_p3_pixels(ppm2)
  else
    # Both are P3
    pixels1 = parse_ppm_pixels(ppm1.split("\n"))
    pixels2 = parse_ppm_pixels(ppm2.split("\n"))
  end

  max_diff = 0
  [pixels1.length, pixels2.length].min.times do |i|
    diff = (pixels1[i] - pixels2[i]).abs
    max_diff = diff if diff > max_diff
  end

  max_diff
end

# Updated distinct_values to handle both P3 and P6
def distinct_values(ppm_data)
  if ppm_data.is_a?(String) && ppm_data.start_with?("P6")
    pixels = parse_p6_or_p3_pixels(ppm_data)
  else
    lines = ppm_data.split("\n")
    pixels = parse_ppm_pixels(lines)
  end

  pixels.uniq.length
end

# Helper to parse P6 format
def parse_p6_or_p3_pixels(ppm_data)
  if ppm_data.is_a?(String) && ppm_data.start_with?("P6")
    # P6 binary format
    lines = ppm_data.split("\n", 4)
    pixel_data = lines[3]
    pixel_data.bytes
  else
    # P3 text format
    lines = ppm_data.split("\n")
    parse_ppm_pixels(lines)
  end
end

def get_ppm_width(ppm_data)
  # Extract first line (format) and second line (width height)
  lines = extract_ppm_header_lines(ppm_data)
  lines[1].split[0].to_i
end

def get_ppm_height(ppm_data)
  # Extract first line (format) and second line (width height)
  lines = extract_ppm_header_lines(ppm_data)
  lines[1].split[1].to_i
end

def extract_ppm_header_lines(ppm_data)
  # Handle both text and binary data
  # Split only on the first few lines to avoid issues with binary data
  lines = []
  current_line = ""
  i = 0

  while i < ppm_data.length && lines.length < 3
    byte = ppm_data[i]

    # Handle both text (String) and binary (Encoding::ASCII_8BIT)
    if byte.is_a?(Integer)
      # Binary mode: byte is already an integer
      char = byte.chr(Encoding::ASCII_8BIT)
    else
      # Text mode: byte is a string character
      char = byte
    end

    if char == "\n"
      lines << current_line
      current_line = ""
    else
      current_line += char
    end

    i += 1
  end

  lines << current_line if current_line.length > 0 && lines.length < 3
  lines
end

# Paint through coverage buffer
def paint_through(canvas, coverage_buffer, paint_color)
  coverage_buffer.height.times do |y|
    coverage_buffer.width.times do |x|
      cov = coverage_at(coverage_buffer, x, y)
      if cov > 0
        current = pixel_at(canvas, x, y)
        # Mix current color with paint color based on coverage. The
        # arithmetic is always on light, regardless of the linear-blending
        # switch: this isn't a browser-style color mix, it's a physical
        # blend of photons over the exposed area.
        new_color = mix(current, paint_color, cov, true)
        write_pixel(canvas, x, y, new_color)
      end
    end
  end
end

# Magnify canvas
def magnify(canvas, k)
  result = Canvas.new(canvas.width * k, canvas.height * k)

  canvas.height.times do |y|
    canvas.width.times do |x|
      original_color = pixel_at(canvas, x, y)

      # Replicate into k x k block
      k.times do |dy|
        k.times do |dx|
          write_pixel(result, x * k + dx, y * k + dy, original_color)
        end
      end
    end
  end

  result
end

# Render functions for Chapter 2 tests

def disc_centers
  c = canvas(40, 40)
  fill(c, color(0.02, 0.02, 0.025))
  shape = circle(20, 20, 16)
  cov = rasterize_centers(shape, 40, 40)

  # Create coverage buffer
  full_cov = coverage_buffer(40, 40)
  40.times do |y|
    40.times do |x|
      set_coverage(full_cov, x, y, coverage_at(cov, x, y))
    end
  end

  paint_through(c, full_cov, color(0.9, 0.55, 0.1))
  magnify(c, 8)
end

def disc_coverage
  c = canvas(40, 40)
  fill(c, color(0.02, 0.02, 0.025))
  shape = circle(20, 20, 16)
  cov = rasterize(shape, 40, 40)

  # Create coverage buffer
  full_cov = coverage_buffer(40, 40)
  40.times do |y|
    40.times do |x|
      set_coverage(full_cov, x, y, coverage_at(cov, x, y))
    end
  end

  paint_through(c, full_cov, color(0.9, 0.55, 0.1))
  magnify(c, 8)
end

def painted_twice
  c = canvas(80, 40)
  fill(c, color(0.02, 0.02, 0.025))
  cov = rasterize(circle(20, 20, 16), 40, 40)

  once = coverage_buffer(80, 40)
  40.times do |y|
    40.times do |x|
      set_coverage(once, x, y, coverage_at(cov, x, y))
      set_coverage(once, x + 40, y, coverage_at(cov, x, y))
    end
  end

  paint_through(c, once, color(0.9, 0.55, 0.1))

  twice = coverage_buffer(80, 40)
  40.times do |y|
    40.times do |x|
      set_coverage(twice, x + 40, y, coverage_at(cov, x, y))
    end
  end

  paint_through(c, twice, color(0.9, 0.55, 0.1))

  magnify(c, 6)
end

def plate_02
  c = canvas(80, 40)
  fill(c, color(0.02, 0.02, 0.025))
  shape = circle(20, 20, 16)
  left = rasterize_centers(shape, 40, 40)
  right = rasterize(shape, 40, 40)

  both = coverage_buffer(80, 40)
  40.times do |y|
    40.times do |x|
      set_coverage(both, x, y, coverage_at(left, x, y))
      set_coverage(both, x + 40, y, coverage_at(right, x, y))
    end
  end

  paint_through(c, both, color(0.9, 0.55, 0.1))

  magnify(c, 6)
end

# ========================================
# Chapter 3: Lines
# ========================================

# Return all non-black pixels in reading order (top to bottom, left to right)
def lit_pixels(canvas)
  pixels = []
  canvas.height.times do |y|
    canvas.width.times do |x|
      p = pixel_at(canvas, x, y)
      # Check if pixel is not black (any channel > 0)
      if p.red > 0 || p.green > 0 || p.blue > 0
        pixels << [x, y]
      end
    end
  end
  pixels
end

# Plot a pixel with a given weight (opacity)
def plot(c, x, y, col, weight)
  return if weight == 0
  return if x < 0 || x >= c.width || y < 0 || y >= c.height

  current = pixel_at(c, x, y)
  new_color = mix(current, col, weight)
  write_pixel(c, x, y, new_color)
end

# Sum the red channel of all pixels (total ink)
def total_ink(canvas)
  total = 0.0
  canvas.height.times do |y|
    canvas.width.times do |x|
      p = pixel_at(canvas, x, y)
      total += p.red
    end
  end
  total
end

# Bresenham's line algorithm
def line_bresenham(canvas, x0, y0, x1, y1, col)
  steep = (y1 - y0).abs > (x1 - x0).abs

  # Swap if steep to walk along y instead of x
  if steep
    x0, y0 = y0, x0
    x1, y1 = y1, x1
  end

  # Swap endpoints to walk left to right
  if x0 > x1
    x0, x1 = x1, x0
    y0, y1 = y1, y0
  end

  dx = x1 - x0
  dy = (y1 - y0).abs
  ystep = y0 < y1 ? 1 : -1
  err = dx / 2
  y = y0

  (x0..x1).each do |x|
    if steep
      write_pixel(canvas, y, x, col)
    else
      write_pixel(canvas, x, y, col)
    end

    err = err - dy
    if err < 0
      y = y + ystep
      err = err + dx
    end
  end
end

# Wu's antialiased line algorithm
def line_wu(canvas, x0, y0, x1, y1, col)
  steep = (y1 - y0).abs > (x1 - x0).abs

  # Swap if steep
  if steep
    x0, y0 = y0, x0
    x1, y1 = y1, x1
  end

  # Swap endpoints to walk left to right
  if x0 > x1
    x0, x1 = x1, x0
    y0, y1 = y1, y0
  end

  dx = x1 - x0
  slope = dx == 0 ? 0 : (y1 - y0).to_f / dx

  (x0..x1).each do |x|
    y = y0 + (x - x0) * slope
    yi = y.floor
    f = y - yi

    if steep
      plot(canvas, yi, x, col, 1 - f)
      plot(canvas, yi + 1, x, col, f)
    else
      plot(canvas, x, yi, col, 1 - f)
      plot(canvas, x, yi + 1, col, f)
    end
  end
end

# A segment is a thick line between two real points: the rectangle of that
# width centered on the segment from a to b, square ends, as 4 half-planes.
# (Chapter 4 pulls this out of thick_line so it can take real coordinates,
# not pixel indices; see segment() below.)
class Segment < Shape
  attr_accessor :planes

  def initialize(a, b, width)
    x0_f = a.x
    y0_f = a.y
    x1_f = b.x
    y1_f = b.y

    # Direction vector (from start to end)
    dx = x1_f - x0_f
    dy = y1_f - y0_f
    len = Math.sqrt(dx * dx + dy * dy)

    # Unit direction vector
    if len == 0
      dir_x = 1
      dir_y = 0
    else
      dir_x = dx / len
      dir_y = dy / len
    end

    # Unit normal vector (perpendicular, pointing to the right)
    norm_x = -dir_y
    norm_y = dir_x

    # Half-width offset
    half_width = width / 2.0

    # A zero-length line has no direction to be flush against, so the two
    # end caps back off by half_width too, turning the "rectangle" into a
    # width-by-width square centered on the single point.
    cap_offset = len == 0 ? half_width : 0

    # Four half-planes:
    # 1. Start point, facing along direction
    plane1 = HalfPlane.new(x0_f - dir_x * cap_offset, y0_f - dir_y * cap_offset, dir_x, dir_y)

    # 2. End point, facing back along -direction
    plane2 = HalfPlane.new(x1_f + dir_x * cap_offset, y1_f + dir_y * cap_offset, -dir_x, -dir_y)

    # 3. Side 1: offset by +half_width along normal, facing inward (-normal)
    side1_x = x0_f + norm_x * half_width
    side1_y = y0_f + norm_y * half_width
    plane3 = HalfPlane.new(side1_x, side1_y, -norm_x, -norm_y)

    # 4. Side 2: offset by -half_width along normal, facing inward (+normal)
    side2_x = x0_f - norm_x * half_width
    side2_y = y0_f - norm_y * half_width
    plane4 = HalfPlane.new(side2_x, side2_y, norm_x, norm_y)

    @planes = [plane1, plane2, plane3, plane4]
  end

  def inside?(x, y)
    # Point is inside if it's inside all four half-planes
    @planes.all? { |plane| plane.inside?(x, y) }
  end
end

# segment(a, b, width): chapter 3's thick_line with real endpoints instead
# of pixel indices.
def segment(a, b, width)
  Segment.new(a, b, width)
end

# thick_line(x0, y0, x1, y1, w) is now a one-liner: it's segment() between
# the centers of pixels (x0, y0) and (x1, y1).
def thick_line(x0, y0, x1, y1, width)
  segment(point(x0 + 0.5, y0 + 0.5), point(x1 + 0.5, y1 + 0.5), width)
end

# Render functions for Chapter 3

def ray_ends
  ends = []
  12.times do |k|
    a = k * 30 * Math::PI / 180.0  # Convert degrees to radians
    x = (80 + 72 * Math.cos(a)).round
    y = (80 + 72 * Math.sin(a)).round
    ends << [x, y]
  end
  ends
end

def fan_bresenham
  c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  ray_ends.each do |x, y|
    line_bresenham(c, 80, 80, x, y, color(0.92, 0.92, 0.88))
  end
  c
end

def fan_wu
  c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  ray_ends.each do |x, y|
    line_wu(c, 80, 80, x, y, color(0.92, 0.92, 0.88))
  end
  c
end

def fan_coverage
  c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  ray_ends.each do |x, y|
    cov = rasterize(thick_line(80, 80, x, y, 1), 160, 160)
    paint_through(c, cov, color(0.92, 0.92, 0.88))
  end
  magnify(c, 2)
end

def plate_03
  both = canvas(320, 160)
  a = fan_bresenham
  b = fan_wu
  160.times do |y|
    160.times do |x|
      write_pixel(both, x, y, pixel_at(a, x, y))
      write_pixel(both, x + 160, y, pixel_at(b, x, y))
    end
  end
  magnify(both, 2)
end

# ========================================
# Chapter 4: Points, Vectors, Transforms
# ========================================

# A point or a vector: (x, y, w) with w = 1 for a point, w = 0 for a
# vector. Arithmetic is component-wise, including on w, so the bookkeeping
# (point - point = vector, point + vector = point, vector + vector =
# vector) falls out for free.
class Tup
  attr_accessor :x, :y, :w

  def initialize(x, y, w)
    @x = x
    @y = y
    @w = w
  end

  def +(other)
    Tup.new(@x + other.x, @y + other.y, @w + other.w)
  end

  def -(other)
    Tup.new(@x - other.x, @y - other.y, @w - other.w)
  end

  def -@
    Tup.new(-@x, -@y, -@w)
  end

  def *(scalar)
    Tup.new(@x * scalar, @y * scalar, @w * scalar)
  end

  def /(scalar)
    Tup.new(@x / scalar.to_f, @y / scalar.to_f, @w / scalar.to_f)
  end

  def ==(other)
    equal_within?(other, 0.0001)
  end

  def !=(other)
    !equal_within?(other, 0.0001)
  end

  def equal_within?(other, tolerance)
    return false unless other.is_a?(Tup)
    (@x - other.x).abs <= tolerance &&
      (@y - other.y).abs <= tolerance &&
      (@w - other.w).abs <= tolerance
  end

  def to_s
    "Tup(#{@x}, #{@y}, #{@w})"
  end
end

def point(x, y)
  Tup.new(x, y, 1)
end

def vector(x, y)
  Tup.new(x, y, 0)
end

def magnitude(v)
  Math.sqrt(v.x * v.x + v.y * v.y)
end

def normalize(v)
  v / magnitude(v)
end

def dot(a, b)
  a.x * b.x + a.y * b.y
end

def cross(a, b)
  a.x * b.y - a.y * b.x
end

# A 3 by 3 matrix of real numbers, row by row. M[r, c] is the entry in
# row r, column c, both counted from zero.
class Matrix3
  def initialize(data)
    @data = data # 3x3 array of arrays, row-major
  end

  def [](r, c)
    @data[r][c]
  end

  def ==(other)
    return false unless other.is_a?(Matrix3)
    (0..2).all? do |r|
      (0..2).all? { |c| (self[r, c] - other[r, c]).abs <= 0.0001 }
    end
  end

  def !=(other)
    !(self == other)
  end

  def *(other)
    if other.is_a?(Matrix3)
      result = Array.new(3) { Array.new(3, 0.0) }
      (0..2).each do |r|
        (0..2).each do |c|
          result[r][c] = (0..2).sum { |k| self[r, k] * other[k, c] }
        end
      end
      Matrix3.new(result)
    elsif other.is_a?(Tup)
      x = self[0, 0] * other.x + self[0, 1] * other.y + self[0, 2] * other.w
      y = self[1, 0] * other.x + self[1, 1] * other.y + self[1, 2] * other.w
      w = self[2, 0] * other.x + self[2, 1] * other.y + self[2, 2] * other.w
      Tup.new(x, y, w)
    else
      raise TypeError, "cannot multiply Matrix3 by #{other.class}"
    end
  end

  def to_s
    rows = (0..2).map { |r| (0..2).map { |c| self[r, c] }.join(", ") }
    "Matrix3[#{rows.join(' | ')}]"
  end
end

# matrix3 takes nine numbers, row by row.
def matrix3(a, b, c, d, e, f, g, h, i)
  Matrix3.new([[a, b, c], [d, e, f], [g, h, i]])
end

def identity
  matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1)
end

def transpose(m)
  data = Array.new(3) { |r| Array.new(3) { |c| m[c, r] } }
  Matrix3.new(data)
end

# minor(M, r, c): the 2x2 determinant left when row r and column c are
# deleted.
def matrix3_minor(m, r, c)
  rows = [0, 1, 2] - [r]
  cols = [0, 1, 2] - [c]
  m[rows[0], cols[0]] * m[rows[1], cols[1]] - m[rows[0], cols[1]] * m[rows[1], cols[0]]
end

def matrix3_cofactor(m, r, c)
  mn = matrix3_minor(m, r, c)
  (r + c).odd? ? -mn : mn
end

def determinant(m)
  m[0, 0] * matrix3_cofactor(m, 0, 0) +
    m[0, 1] * matrix3_cofactor(m, 0, 1) +
    m[0, 2] * matrix3_cofactor(m, 0, 2)
end

def is_invertible(m)
  determinant(m).abs > 1e-9
end

# inverse(M): the matrix of cofactors, transposed, divided by the
# determinant. The transpose happens by writing each cofactor straight
# into its transposed position, result[c, r].
def inverse(m)
  d = determinant(m).to_f
  data = Array.new(3) { Array.new(3, 0.0) }
  (0..2).each do |r|
    (0..2).each do |c|
      data[c][r] = matrix3_cofactor(m, r, c) / d
    end
  end
  Matrix3.new(data)
end

# The four transforms. Angles are in radians. A positive rotation turns
# the x axis toward the y axis, which on a canvas whose y runs downward is
# clockwise on the screen.

def translation(tx, ty)
  matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1)
end

def scaling(sx, sy)
  matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1)
end

def rotation(r)
  matrix3(Math.cos(r), -Math.sin(r), 0,
          Math.sin(r), Math.cos(r), 0,
          0, 0, 1)
end

def shearing(xy, yx)
  matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1)
end

# approx_scale(m): the square root of the absolute value of the
# determinant of m's upper-left 2 by 2. Exact for uniform scales and
# rotations; the geometric mean of the two axis scales otherwise.
def approx_scale(m)
  Math.sqrt((m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]).abs)
end

# union(shapes) is inside when any of its shapes is.
class Union < Shape
  def initialize(shapes)
    @shapes = shapes
  end

  def inside?(x, y)
    @shapes.any? { |s| s.inside?(x, y) }
  end
end

def union(shapes)
  Union.new(shapes)
end

# transformed(shape, m) is the shape seen through m: a point is inside it
# when the inverse of m takes that point inside the original shape. A
# shape seen through a matrix with no inverse is empty.
class Transformed < Shape
  def initialize(shape, m)
    @shape = shape
    @inv = is_invertible(m) ? inverse(m) : nil
  end

  def inside?(x, y)
    return false if @inv.nil?
    p = @inv * point(x, y)
    @shape.inside?(p.x, p.y)
  end
end

def transformed(shape, m)
  Transformed.new(shape, m)
end

# Run every point of a list through a matrix.
def transform_points(points, m)
  points.map { |p| m * p }
end

# outline(points, m, width): the points through m, then the union of the
# segments between consecutive points, last back to first, every edge
# that width in device space, as one shape (so shared corners are painted
# once, not twice).
def outline(points, m, width)
  pts = transform_points(points, m)
  n = pts.length
  segments = (0...n).map { |i| segment(pts[i], pts[(i + 1) % n], width) }
  union(segments)
end

# side_by_side(a, b): a copied into the left half of a wider canvas, b
# into the right.
def side_by_side(a, b)
  result = Canvas.new(a.width + b.width, [a.height, b.height].max)
  a.height.times do |y|
    a.width.times do |x|
      write_pixel(result, x, y, pixel_at(a, x, y))
    end
  end
  b.height.times do |y|
    b.width.times do |x|
      write_pixel(result, a.width + x, y, pixel_at(b, x, y))
    end
  end
  result
end

# A pixel-for-pixel copy of a canvas, for drawing more than one variant on
# top of the same starting image.
def copy_canvas(c)
  result = Canvas.new(c.width, c.height)
  c.height.times do |y|
    c.width.times do |x|
      write_pixel(result, x, y, pixel_at(c, x, y))
    end
  end
  result
end

# Chapter 3's fan, described as points around the origin: the center
# first, then twelve ends at radius 36, one every 30 degrees.
def fan_points
  pts = [point(0, 0)]
  12.times do |k|
    a = k * 30 * Math::PI / 180.0
    pts << point(36 * Math.cos(a), 36 * Math.sin(a))
  end
  pts
end

def fan_transformed(m)
  c = canvas(160, 160)
  fill(c, color(0.02, 0.02, 0.025))
  pts = transform_points(fan_points, m)
  rays = union((1..12).map { |k| segment(pts[0], pts[k], 1) })
  paint_through(c, rasterize(rays, 160, 160), color(0.92, 0.92, 0.88))
  c
end

def fan_both_orders
  turn = rotation(Math::PI / 6)
  move = translation(104.5, 76.5)
  side_by_side(fan_transformed(move * turn), fan_transformed(turn * move))
end

# An F has no symmetry at all, so a rotation shows its own orientation.
# Ten corners, clockwise from the top left, in a box 40 wide and 60 tall
# centered on the origin.
def letter_f
  [point(-20, -30), point(20, -30), point(20, -20), point(-10, -20),
   point(-10, -5), point(12, -5), point(12, 5), point(-10, 5),
   point(-10, 30), point(-20, 30)]
end

def f_both_orders
  turn = rotation(Math::PI / 6)
  move = translation(104.5, 76.5)
  home = translation(44.5, 44.5)
  ink_color = color(0.92, 0.92, 0.88)
  dim_color = color(0.16, 0.16, 0.17)

  ghost = canvas(160, 160)
  fill(ghost, color(0.02, 0.02, 0.025))
  paint_through(ghost, rasterize(outline(letter_f, home, 1), 160, 160), dim_color)

  a = copy_canvas(ghost)
  b = copy_canvas(ghost)
  paint_through(a, rasterize(outline(letter_f, move * turn, 1), 160, 160), ink_color)
  paint_through(b, rasterize(outline(letter_f, turn * move, 1), 160, 160), ink_color)

  side_by_side(a, b)
end

def plate_04
  magnify(f_both_orders, 2)
end
