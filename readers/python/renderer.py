"""The 2D Renderer Challenge - Chapter 1: The Canvas and the Color"""
import math
import json


class Color:
    """A color is three floating point numbers representing light: R, G, B."""

    def __init__(self, red, green, blue):
        self.red = red
        self.green = green
        self.blue = blue

    def __add__(self, other):
        """Add two colors component-wise."""
        return Color(
            self.red + other.red,
            self.green + other.green,
            self.blue + other.blue
        )

    def __sub__(self, other):
        """Subtract two colors component-wise."""
        return Color(
            self.red - other.red,
            self.green - other.green,
            self.blue - other.blue
        )

    def __mul__(self, other):
        """Multiply: either color*scalar or color*color (Hadamard product)."""
        if isinstance(other, (int, float)):
            return Color(
                self.red * other,
                self.green * other,
                self.blue * other
            )
        else:  # other is a Color
            return Color(
                self.red * other.red,
                self.green * other.green,
                self.blue * other.blue
            )

    def __rmul__(self, other):
        """Scalar multiplication from the left."""
        return self.__mul__(other)

    def __eq__(self, other):
        """Colors are equal within tolerance (default 0.0001)."""
        if not isinstance(other, Color):
            return False
        tolerance = 0.0001
        return (abs(self.red - other.red) <= tolerance and
                abs(self.green - other.green) <= tolerance and
                abs(self.blue - other.blue) <= tolerance)

    def __ne__(self, other):
        """Not equal."""
        return not self.__eq__(other)

    def __repr__(self):
        return f"Color({self.red}, {self.green}, {self.blue})"


def approx_equal(a, b, tolerance=0.0001):
    """Check if two floats are approximately equal."""
    return abs(a - b) <= tolerance


def color(r, g, b):
    """Create a color."""
    return Color(r, g, b)


class Canvas:
    """A rectangle of colors with width, height, and pixel storage."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        # Initialize all pixels to black
        self.pixels = [[Color(0, 0, 0) for _ in range(width)] for _ in range(height)]

    def __repr__(self):
        return f"Canvas({self.width}, {self.height})"


def canvas(width, height):
    """Create a canvas."""
    return Canvas(width, height)


def write_pixel(canvas, x, y, color):
    """Write a pixel to the canvas. Out-of-bounds writes are ignored."""
    if 0 <= x < canvas.width and 0 <= y < canvas.height:
        canvas.pixels[y][x] = color


def pixel_at(canvas, x, y):
    """Read a pixel from the canvas."""
    if 0 <= x < canvas.width and 0 <= y < canvas.height:
        return canvas.pixels[y][x]
    return Color(0, 0, 0)


def fill(canvas, c):
    """Fill the entire canvas with a color."""
    for y in range(canvas.height):
        for x in range(canvas.width):
            canvas.pixels[y][x] = c


def encode(light):
    """Convert light (0-1) to file value (0-1) using sRGB encoding."""
    if light <= 0.0031308:
        return light * 12.92
    else:
        return 1.055 * (light ** (1 / 2.4)) - 0.055


def decode(file_value):
    """Convert file value (0-1) to light (0-1) using sRGB decoding."""
    if file_value <= 0.04045:
        return file_value / 12.92
    else:
        return ((file_value + 0.055) / 1.055) ** 2.4


def clamp(value):
    """Clamp a value to [0, 1]."""
    return max(0.0, min(1.0, value))


def round_half_up(x):
    """Round to nearest integer."""
    return math.floor(x + 0.5)


def color_to_byte(light):
    """Convert light to byte: clamp, encode, scale, round."""
    clamped = clamp(light)
    encoded = encode(clamped)
    scaled = encoded * 255
    return round_half_up(scaled)


def canvas_to_ppm(canvas):
    """Convert canvas to PPM P3 format string."""
    lines = []
    lines.append("P3")
    lines.append(f"{canvas.width} {canvas.height}")
    lines.append("255")

    # Convert pixels to bytes
    pixel_data = []
    for y in range(canvas.height):
        row_bytes = []
        for x in range(canvas.width):
            c = canvas.pixels[y][x]
            r = color_to_byte(c.red)
            g = color_to_byte(c.green)
            b = color_to_byte(c.blue)
            row_bytes.extend([str(r), str(g), str(b)])

        # Pack bytes with line wrapping at 70 characters
        line = ""
        for byte_str in row_bytes:
            if line and len(line) + len(byte_str) + 1 > 70:
                lines.append(line)
                line = byte_str
            else:
                if line:
                    line += " " + byte_str
                else:
                    line = byte_str
        if line:
            lines.append(line)

    # Join with newlines and add final newline
    return "\n".join(lines) + "\n"


def ppm_pixel(ppm_text, x, y):
    """Extract a pixel value (r, g, b) from PPM text."""
    tokens = ppm_text.split()
    # Skip header (P3, width, height, 255)
    skip = 4
    values = [int(t) for t in tokens[skip:]]

    # Get width from tokens[1] for proper indexing
    width = int(tokens[1])
    idx = y * width * 3 + x * 3
    return (values[idx], values[idx + 1], values[idx + 2])


def max_channel_difference(ppm1_text, ppm2_text):
    """Find the maximum difference between any channel in two PPM files."""
    tokens1 = ppm1_text.split()
    tokens2 = ppm2_text.split()

    values1 = [int(t) for t in tokens1[4:]]
    values2 = [int(t) for t in tokens2[4:]]

    max_diff = 0
    for v1, v2 in zip(values1, values2):
        diff = abs(v1 - v2)
        if diff > max_diff:
            max_diff = diff

    return max_diff


def read_file(path):
    """Read a file and return its contents."""
    with open(path, 'r') as f:
        return f.read()


def distinct_values(ppm_text):
    """Count the number of distinct pixel values in a PPM file."""
    tokens = ppm_text.split()
    values = [int(t) for t in tokens[4:]]
    return len(set(values))


# Global linear blending flag
_linear_blending = True


def set_linear_blending(value):
    """Set the linear blending mode."""
    global _linear_blending
    _linear_blending = value


def get_linear_blending():
    """Get the current linear blending mode."""
    return _linear_blending


def mix(a, b, t, linear=None):
    """Mix two colors. With linear blending on, mix in light space.
    With it off, mix in encoded file space (like web browsers do).
    The optional fourth argument overrides the global switch."""
    if linear is None:
        linear = _linear_blending
    if linear:
        # Mix in light space (correct)
        return Color(
            a.red + (b.red - a.red) * t,
            a.green + (b.green - a.green) * t,
            a.blue + (b.blue - a.blue) * t
        )
    else:
        # Mix in encoded space (browser way, wrong)
        # Encode both ends, mix, decode
        a_enc = Color(encode(clamp(a.red)), encode(clamp(a.green)), encode(clamp(a.blue)))
        b_enc = Color(encode(clamp(b.red)), encode(clamp(b.green)), encode(clamp(b.blue)))
        mixed_enc = Color(
            a_enc.red + (b_enc.red - a_enc.red) * t,
            a_enc.green + (b_enc.green - a_enc.green) * t,
            a_enc.blue + (b_enc.blue - a_enc.blue) * t
        )
        return Color(
            decode(clamp(mixed_enc.red)),
            decode(clamp(mixed_enc.green)),
            decode(clamp(mixed_enc.blue))
        )


def gray_match():
    """Render the gray match figure: checkerboard, 128-gray, and 0.5-gray patches."""
    c = Canvas(300, 100)

    # Left third: checkerboard (white when (x + y) is even)
    for y in range(100):
        for x in range(100):
            if (x + y) % 2 == 0:
                write_pixel(c, x, y, Color(1, 1, 1))
            else:
                write_pixel(c, x, y, Color(0, 0, 0))

    # Middle third: solid gray at decode(128/255)
    g = decode(128 / 255)
    for y in range(100):
        for x in range(100, 200):
            write_pixel(c, x, y, Color(g, g, g))

    # Right third: solid gray at 0.5 light
    for y in range(100):
        for x in range(200, 300):
            write_pixel(c, x, y, Color(0.5, 0.5, 0.5))

    return c


def quarter_match():
    """One pixel in four: white when (x + y) is a multiple of 4."""
    c = Canvas(200, 100)

    # Left half: pattern (white when (x + y) % 4 == 0)
    for y in range(100):
        for x in range(100):
            if (x + y) % 4 == 0:
                write_pixel(c, x, y, Color(1, 1, 1))
            else:
                write_pixel(c, x, y, Color(0, 0, 0))

    # Right half: solid gray at 0.25 light
    for y in range(100):
        for x in range(100, 200):
            write_pixel(c, x, y, Color(0.25, 0.25, 0.25))

    return c


def ramp():
    """A 256-step gray ramp from black to white."""
    c = Canvas(256, 32)

    for x in range(256):
        g = x / 255
        for y in range(32):
            write_pixel(c, x, y, Color(g, g, g))

    return c


def clamp_pair():
    """Two patches: color(2, 0.5, 0.5) on left, color(1, 0.25, 0.25) on right."""
    c = Canvas(200, 100)

    # Left: color(2, 0.5, 0.5)
    for y in range(100):
        for x in range(100):
            write_pixel(c, x, y, Color(2, 0.5, 0.5))

    # Right: color(1, 0.25, 0.25)
    for y in range(100):
        for x in range(100, 200):
            write_pixel(c, x, y, Color(1, 0.25, 0.25))

    return c


def plate_01():
    """Two ramps (black-white and red-green), each mixed both ways.
    Browser way (naive, wrong) on top, light way (correct) beneath."""
    c = Canvas(400, 180)

    ramps = [
        (Color(0, 0, 0), Color(1, 1, 1)),
        (Color(0.7, 0, 0), Color(0, 0.3, 0.02))
    ]

    for i, (a, b) in enumerate(ramps):
        top = i * 90

        for x in range(400):
            t = x / 399

            # Mix the wrong way (browser way)
            set_linear_blending(False)
            naive = mix(a, b, t)

            # Mix the right way (light way)
            set_linear_blending(True)
            light = mix(a, b, t)

            # Naive (wrong) on top (rows top to top+39)
            for y in range(top, top + 40):
                write_pixel(c, x, y, naive)

            # Light (correct) on bottom (rows top+45 to top+84)
            for y in range(top + 45, top + 85):
                write_pixel(c, x, y, light)

    # Ensure linear blending is on at the end
    set_linear_blending(True)

    return c


# ============================================================
# Chapter 2: Coverage
# ============================================================


class Shape:
    """Base class for shapes."""
    pass


class Circle(Shape):
    """A circle defined by center and radius."""
    def __init__(self, cx, cy, r):
        self.cx = cx
        self.cy = cy
        self.r = r


class Rectangle(Shape):
    """A rectangle defined by left, top, right, bottom."""
    def __init__(self, x0, y0, x1, y1):
        self.x0 = x0
        self.y0 = y0
        self.x1 = x1
        self.y1 = y1


class HalfPlane(Shape):
    """A half-plane defined by a point and normal vector."""
    def __init__(self, px, py, nx, ny):
        self.px = px
        self.py = py
        self.nx = nx
        self.ny = ny


def circle(cx, cy, r):
    """Create a circle."""
    return Circle(cx, cy, r)


def rectangle(x0, y0, x1, y1):
    """Create a rectangle."""
    return Rectangle(x0, y0, x1, y1)


def half_plane(px, py, nx, ny):
    """Create a half-plane."""
    return HalfPlane(px, py, nx, ny)


def inside(shape, x, y):
    """Test if a point (x, y) is inside a shape."""
    if isinstance(shape, Circle):
        # Distance from center
        dx = x - shape.cx
        dy = y - shape.cy
        dist_sq = dx * dx + dy * dy
        return dist_sq <= shape.r * shape.r
    elif isinstance(shape, Rectangle):
        return (shape.x0 <= x <= shape.x1 and
                shape.y0 <= y <= shape.y1)
    elif isinstance(shape, HalfPlane):
        # Vector from point on line to test point
        dx = x - shape.px
        dy = y - shape.py
        # Dot product with normal
        dot = dx * shape.nx + dy * shape.ny
        return dot >= 0
    return False


def canvas_to_p6(canvas):
    """Convert canvas to PPM P6 format (binary)."""
    # Build header
    header = f"P6\n{canvas.width} {canvas.height}\n255\n"
    header_bytes = header.encode('ascii')

    # Build pixel data
    pixel_data = bytearray()
    for y in range(canvas.height):
        for x in range(canvas.width):
            c = canvas.pixels[y][x]
            r = color_to_byte(c.red)
            g = color_to_byte(c.green)
            b = color_to_byte(c.blue)
            pixel_data.append(r)
            pixel_data.append(g)
            pixel_data.append(b)

    return header_bytes + pixel_data


def ppm_pixel(ppm_data, x, y):
    """Extract a pixel value (r, g, b) from PPM data (P3 text or P6 binary)."""
    # Convert to bytes if string
    if isinstance(ppm_data, str):
        ppm_bytes = ppm_data.encode('latin-1')
    else:
        ppm_bytes = ppm_data

    # Check if P6 or P3
    if ppm_bytes.startswith(b'P6'):
        # Binary P6 format
        # Find the end of header (3 newlines: after P6, dimensions, and 255)
        count = 0
        pos = 0
        while count < 3 and pos < len(ppm_bytes):
            if ppm_bytes[pos:pos+1] == b'\n':
                count += 1
            pos += 1

        # Parse header to get width
        header_str = ppm_bytes[:pos].decode('ascii')
        lines = header_str.split('\n')
        width = int(lines[1].split()[0])

        # pixel_bytes starts after the header
        pixel_bytes = ppm_bytes[pos:]

        # Calculate pixel index
        idx = y * width * 3 + x * 3
        return (pixel_bytes[idx], pixel_bytes[idx + 1], pixel_bytes[idx + 2])
    else:
        # Text P3 format
        ppm_str = ppm_bytes.decode('latin-1')
        tokens = ppm_str.split()
        skip = 4
        values = [int(t) for t in tokens[skip:]]
        width = int(tokens[1])
        idx = y * width * 3 + x * 3
        return (values[idx], values[idx + 1], values[idx + 2])


def read_file(path):
    """Read a file and return its contents (as bytes for binary, str for text)."""
    with open(path, 'rb') as f:
        data = f.read()
    # Try to detect if it's P6 or P3
    if data.startswith(b'P6'):
        return data
    else:
        # P3 format - return as string for compatibility
        return data.decode('utf-8')


def distinct_values(ppm_data):
    """Count the number of distinct pixel values in a PPM file."""
    # Convert to bytes if string
    if isinstance(ppm_data, str):
        ppm_bytes = ppm_data.encode('latin-1')
    else:
        ppm_bytes = ppm_data

    if ppm_bytes.startswith(b'P6'):
        # Binary P6
        # Find end of header (3 newlines)
        count = 0
        pos = 0
        while count < 3 and pos < len(ppm_bytes):
            if ppm_bytes[pos:pos+1] == b'\n':
                count += 1
            pos += 1

        # Get pixel data
        pixel_bytes = ppm_bytes[pos:]
        values = list(pixel_bytes)
        return len(set(values))
    else:
        # P3 text format
        ppm_str = ppm_bytes.decode('latin-1')
        tokens = ppm_str.split()
        values = [int(t) for t in tokens[4:]]
        return len(set(values))


def max_channel_difference(ppm1_data, ppm2_data):
    """Find the maximum difference between any channel in two PPM files."""
    # Convert both to bytes
    if isinstance(ppm1_data, str):
        ppm1_bytes = ppm1_data.encode('latin-1')
    else:
        ppm1_bytes = ppm1_data

    if isinstance(ppm2_data, str):
        ppm2_bytes = ppm2_data.encode('latin-1')
    else:
        ppm2_bytes = ppm2_data

    # Parse dimensions from headers
    width1, height1 = None, None
    width2, height2 = None, None

    # Parse file 1
    if ppm1_bytes.startswith(b'P6'):
        # P6 format
        count = 0
        pos = 0
        while count < 3 and pos < len(ppm1_bytes):
            if ppm1_bytes[pos:pos+1] == b'\n':
                count += 1
            pos += 1
        ppm1_header = ppm1_bytes[:pos].decode('ascii')
        lines = ppm1_header.split('\n')
        dims = lines[1].split()
        width1, height1 = int(dims[0]), int(dims[1])
        values1 = list(ppm1_bytes[pos:])
    else:
        # P3 format
        ppm1_str = ppm1_bytes.decode('latin-1')
        tokens1 = ppm1_str.split()
        width1, height1 = int(tokens1[1]), int(tokens1[2])
        values1 = [int(t) for t in tokens1[4:]]

    # Parse file 2
    if ppm2_bytes.startswith(b'P6'):
        # P6 format
        count = 0
        pos = 0
        while count < 3 and pos < len(ppm2_bytes):
            if ppm2_bytes[pos:pos+1] == b'\n':
                count += 1
            pos += 1
        ppm2_header = ppm2_bytes[:pos].decode('ascii')
        lines = ppm2_header.split('\n')
        dims = lines[1].split()
        width2, height2 = int(dims[0]), int(dims[1])
        values2 = list(ppm2_bytes[pos:])
    else:
        # P3 format
        ppm2_str = ppm2_bytes.decode('latin-1')
        tokens2 = ppm2_str.split()
        width2, height2 = int(tokens2[1]), int(tokens2[2])
        values2 = [int(t) for t in tokens2[4:]]

    # Check if dimensions match
    if width1 != width2 or height1 != height2:
        return 255

    # Handle size mismatch in pixel data
    if len(values1) != len(values2):
        return 255

    max_diff = 0
    for v1, v2 in zip(values1, values2):
        diff = abs(v1 - v2)
        if diff > max_diff:
            max_diff = diff

    return max_diff


def magnify(canvas, k):
    """Magnify a canvas by factor k, repeating each pixel into a k×k block."""
    new_width = canvas.width * k
    new_height = canvas.height * k
    new_canvas = Canvas(new_width, new_height)

    for y in range(canvas.height):
        for x in range(canvas.width):
            pixel = canvas.pixels[y][x]
            # Repeat this pixel into a k×k block
            for dy in range(k):
                for dx in range(k):
                    new_x = x * k + dx
                    new_y = y * k + dy
                    new_canvas.pixels[new_y][new_x] = pixel

    return new_canvas


class CoverageBuffer:
    """A buffer of coverage values (0-1) instead of colors."""
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.coverage = [[0.0 for _ in range(width)] for _ in range(height)]

    def __repr__(self):
        return f"CoverageBuffer({self.width}, {self.height})"


def coverage_buffer(width, height):
    """Create a coverage buffer."""
    return CoverageBuffer(width, height)


def coverage_at(cov, x, y):
    """Read coverage at a pixel."""
    if 0 <= x < cov.width and 0 <= y < cov.height:
        return cov.coverage[y][x]
    return 0.0


def set_coverage(cov, x, y, value):
    """Set coverage at a pixel. Out-of-bounds writes are ignored."""
    if 0 <= x < cov.width and 0 <= y < cov.height:
        cov.coverage[y][x] = value


def ink(cov):
    """Sum of all coverage values in the buffer."""
    total = 0.0
    for row in cov.coverage:
        for val in row:
            total += val
    return total


def center_inside(shape, x, y):
    """Test if the center of pixel (x, y) is inside the shape.
    The center is at (x + 0.5, y + 0.5)."""
    return 1 if inside(shape, x + 0.5, y + 0.5) else 0


def rasterize_centers(shape, width, height):
    """Rasterize by asking if each pixel's center is inside."""
    cov = CoverageBuffer(width, height)
    for y in range(height):
        for x in range(width):
            cov.coverage[y][x] = 1.0 if inside(shape, x + 0.5, y + 0.5) else 0.0
    return cov


def coverage(shape, x, y):
    """Compute coverage using 8×8 supersampling.
    Each pixel is divided into 64 sample points in an 8×8 grid."""
    count = 0
    for j in range(8):
        for i in range(8):
            # Sample point at center of cell (i, j) within pixel (x, y)
            sx = x + (i + 0.5) / 8.0
            sy = y + (j + 0.5) / 8.0
            if inside(shape, sx, sy):
                count += 1
    return count / 64.0


def rasterize(shape, width, height):
    """Rasterize using 8×8 supersampling."""
    cov = CoverageBuffer(width, height)
    for y in range(height):
        for x in range(width):
            cov.coverage[y][x] = coverage(shape, x, y)
    return cov


def paint_through(canvas, cov, color):
    """Paint through a coverage buffer onto a canvas.
    Uses mix to blend the paint color with existing pixels."""
    for y in range(min(canvas.height, cov.height)):
        for x in range(min(canvas.width, cov.width)):
            coverage_val = coverage_at(cov, x, y)
            if coverage_val > 0:
                current = pixel_at(canvas, x, y)
                painted = mix(current, color, coverage_val, True)
                write_pixel(canvas, x, y, painted)


def disc_centers():
    """Render a disc using center sampling.
    40×40 canvas, circle at (20, 20) with radius 16, magnified 8×."""
    c = Canvas(40, 40)
    fill(c, Color(0.02, 0.02, 0.025))
    cov = rasterize_centers(circle(20, 20, 16), 40, 40)
    paint_through(c, cov, Color(0.9, 0.55, 0.1))
    return magnify(c, 8)


def painted_twice():
    """Demonstrate that painting twice gives different results than opacity.
    80×40 canvas: left half painted once, right half painted twice."""
    c = Canvas(80, 40)
    fill(c, Color(0.02, 0.02, 0.025))
    cov = rasterize(circle(20, 20, 16), 40, 40)

    # Left half: painted once
    once = CoverageBuffer(80, 40)
    for y in range(40):
        for x in range(40):
            set_coverage(once, x, y, coverage_at(cov, x, y))
    paint_through(c, once, Color(0.9, 0.55, 0.1))

    # Right half: painted twice
    twice = CoverageBuffer(80, 40)
    for y in range(40):
        for x in range(40):
            set_coverage(twice, x + 40, y, coverage_at(cov, x, y))
    paint_through(c, twice, Color(0.9, 0.55, 0.1))
    paint_through(c, twice, Color(0.9, 0.55, 0.1))

    return magnify(c, 6)


def disc_coverage():
    """Render a disc using coverage-based sampling.
    Same as disc_centers but with rasterize instead of rasterize_centers."""
    c = Canvas(40, 40)
    fill(c, Color(0.02, 0.02, 0.025))
    cov = rasterize(circle(20, 20, 16), 40, 40)
    paint_through(c, cov, Color(0.9, 0.55, 0.1))
    return magnify(c, 8)


def plate_02():
    """Side-by-side comparison of centers vs coverage sampling.
    80×40 canvas: left half with centers, right half with coverage."""
    c = Canvas(80, 40)
    fill(c, Color(0.02, 0.02, 0.025))
    shape = circle(20, 20, 16)
    left = rasterize_centers(shape, 40, 40)
    right = rasterize(shape, 40, 40)

    both = CoverageBuffer(80, 40)
    for y in range(40):
        for x in range(40):
            set_coverage(both, x, y, coverage_at(left, x, y))
            set_coverage(both, x + 40, y, coverage_at(right, x, y))

    paint_through(c, both, Color(0.9, 0.55, 0.1))
    return magnify(c, 6)


# ============================================================
# Chapter 3: Lines
# ============================================================


def lit_pixels(canvas):
    """Return every pixel of a canvas that isn't black, as (x, y) pairs in reading order.
    Reading order: top row first, left to right within a row."""
    result = []
    for y in range(canvas.height):
        for x in range(canvas.width):
            p = canvas.pixels[y][x]
            # Check if not black (any channel > 0)
            if p.red > 0 or p.green > 0 or p.blue > 0:
                result.append((x, y))
    return result


def line_bresenham(canvas, x0, y0, x1, y1, col):
    """Draw a line using Bresenham's algorithm.
    Uses integer arithmetic to rasterize the line from (x0, y0) to (x1, y1)."""
    # Determine if steep (more vertical than horizontal)
    steep = abs(y1 - y0) > abs(x1 - x0)

    if steep:
        # Swap x and y coordinates
        x0, y0 = y0, x0
        x1, y1 = y1, x1

    # Ensure we walk left to right
    if x0 > x1:
        x0, x1 = x1, x0
        y0, y1 = y1, y0

    dx = x1 - x0
    dy = abs(y1 - y0)
    ystep = 1 if y0 < y1 else -1
    err = dx // 2
    y = y0

    for x in range(x0, x1 + 1):
        if steep:
            write_pixel(canvas, y, x, col)
        else:
            write_pixel(canvas, x, y, col)

        err -= dy
        if err < 0:
            y += ystep
            err += dx


def plot(canvas, x, y, col, weight):
    """Paint a pixel with a weight, using mix.
    Drops writes off the canvas and skips weight of zero."""
    if weight <= 0 or not (0 <= x < canvas.width and 0 <= y < canvas.height):
        return

    current = pixel_at(canvas, x, y)
    painted = mix(current, col, weight, True)   # in light, whatever the switch says
    write_pixel(canvas, x, y, painted)


def line_wu(canvas, x0, y0, x1, y1, col):
    """Draw a line using Xiaolin Wu's antialiased algorithm.
    Integer endpoints only. Two pixels per column, weighted by fractional position."""
    # Determine if steep (more vertical than horizontal)
    steep = abs(y1 - y0) > abs(x1 - x0)

    if steep:
        # Swap x and y coordinates
        x0, y0 = y0, x0
        x1, y1 = y1, x1

    # Ensure we walk left to right
    if x0 > x1:
        x0, x1 = x1, x0
        y0, y1 = y1, y0

    dx = x1 - x0
    slope = 0 if dx == 0 else (y1 - y0) / dx

    for x in range(x0, x1 + 1):
        y = y0 + (x - x0) * slope
        yi = int(math.floor(y))
        f = y - yi

        if steep:
            plot(canvas, yi, x, col, 1 - f)
            plot(canvas, yi + 1, x, col, f)
        else:
            plot(canvas, x, yi, col, 1 - f)
            plot(canvas, x, yi + 1, col, f)


class ThickLine(Shape):
    """A thick line as a shape: four half-planes."""
    def __init__(self, half_planes):
        self.half_planes = half_planes


def thick_line(x0, y0, x1, y1, width):
    """Create a thick line as four half-planes.
    The rectangle of given width centered on the segment from pixel center
    (x0 + 0.5, y0 + 0.5) to (x1 + 0.5, y1 + 0.5)."""
    # Get pixel centers
    ax = x0 + 0.5
    ay = y0 + 0.5
    bx = x1 + 0.5
    by = y1 + 0.5

    # Direction vector
    dx = bx - ax
    dy = by - ay
    length = math.sqrt(dx * dx + dy * dy)

    # Half-width offset
    h = width / 2.0

    if length == 0:
        # Degenerate case: a single point becomes a width-by-width square,
        # extended by the half-width along an arbitrary axis (any axis
        # gives the same square, since a point has no direction of its own).
        dx, dy = 1.0, 0.0
        nx, ny = -dy, dx
        hp1 = HalfPlane(ax - dx * h, ay - dy * h, dx, dy)
        hp2 = HalfPlane(bx + dx * h, by + dy * h, -dx, -dy)
        hp3 = HalfPlane(ax + nx * h, ay + ny * h, -nx, -ny)
        hp4 = HalfPlane(ax - nx * h, ay - ny * h, nx, ny)
        return ThickLineShape([hp1, hp2, hp3, hp4])

    dx /= length
    dy /= length

    # Normal vector (perpendicular to direction)
    nx = -dy
    ny = dx

    # Four half-planes:
    # 1. Through start point, facing along direction
    hp1 = HalfPlane(ax, ay, dx, dy)
    # 2. Through end point, facing back along -direction
    hp2 = HalfPlane(bx, by, -dx, -dy)
    # 3. Along top side (offset by +h along normal), facing inward (-normal)
    hp3 = HalfPlane(ax + nx * h, ay + ny * h, -nx, -ny)
    # 4. Along bottom side (offset by -h along normal), facing inward (+normal)
    hp4 = HalfPlane(ax - nx * h, ay - ny * h, nx, ny)

    # Return a shape that is the intersection of all four half-planes
    return ThickLineShape([hp1, hp2, hp3, hp4])


class ThickLineShape(Shape):
    """A thick line shape made of four half-planes."""
    def __init__(self, half_planes):
        self.half_planes = half_planes


def inside(shape, x, y):
    """Test if a point (x, y) is inside a shape."""
    if isinstance(shape, Circle):
        # Distance from center
        dx = x - shape.cx
        dy = y - shape.cy
        dist_sq = dx * dx + dy * dy
        return dist_sq <= shape.r * shape.r
    elif isinstance(shape, Rectangle):
        return (shape.x0 <= x <= shape.x1 and
                shape.y0 <= y <= shape.y1)
    elif isinstance(shape, HalfPlane):
        # Vector from point on line to test point
        dx = x - shape.px
        dy = y - shape.py
        # Dot product with normal
        dot = dx * shape.nx + dy * shape.ny
        return dot >= 0
    elif isinstance(shape, ThickLineShape):
        # Inside all four half-planes
        for hp in shape.half_planes:
            if not inside(hp, x, y):
                return False
        return True
    elif isinstance(shape, Segment):
        # Use the segment's inside method
        return shape.inside(x, y)
    elif isinstance(shape, Union):
        # Inside if inside any of the shapes
        for s in shape.shapes:
            if inside(s, x, y):
                return True
        return False
    elif isinstance(shape, Transformed):
        # Transform the point backwards and check the original shape
        if shape.inv is None:
            # Matrix is not invertible, so nothing is inside
            return False
        p = shape.inv * point(x, y)
        return inside(shape.shape, p.x, p.y)
    elif isinstance(shape, Outline):
        # Check if inside the union of segments
        return inside(shape.union, x, y)
    elif isinstance(shape, Filled):
        # Inside according to the path's winding number under the given rule
        if shape.rule == "nonzero":
            return inside_nonzero(shape.path, x, y)
        else:  # "evenodd"
            return inside_evenodd(shape.path, x, y)
    return False


def total_ink(canvas):
    """Sum the red channel of all pixels in the canvas.
    For a white line on black, this is how much paint went down."""
    total = 0.0
    for y in range(canvas.height):
        for x in range(canvas.width):
            p = canvas.pixels[y][x]
            total += p.red
    return total


def ray_ends():
    """Return endpoints for 12 rays from (80, 80) at 30-degree intervals.
    Each ray extends 72 pixels from the center."""
    ends = []
    for k in range(12):
        angle = k * 30 * math.pi / 180
        x = round(80 + 72 * math.cos(angle))
        y = round(80 + 72 * math.sin(angle))
        ends.append((x, y))
    return ends


def fan_bresenham():
    """Draw 12 rays from the center using Bresenham's algorithm.
    160×160 canvas, off-white on near-black."""
    c = Canvas(160, 160)
    fill(c, Color(0.02, 0.02, 0.025))

    for (x, y) in ray_ends():
        line_bresenham(c, 80, 80, x, y, Color(0.92, 0.92, 0.88))

    return c


def fan_wu():
    """Draw 12 rays from the center using Wu's algorithm.
    160×160 canvas, off-white on near-black."""
    c = Canvas(160, 160)
    fill(c, Color(0.02, 0.02, 0.025))

    for (x, y) in ray_ends():
        line_wu(c, 80, 80, x, y, Color(0.92, 0.92, 0.88))

    return c


def fan_coverage():
    """Draw 12 rays from the center as thick lines with coverage.
    Each ray is a 1-pixel-wide thick line, rasterized with coverage,
    then magnified by 2 to see the edges."""
    c = Canvas(160, 160)
    fill(c, Color(0.02, 0.02, 0.025))

    for (x, y) in ray_ends():
        cov = rasterize(thick_line(80, 80, x, y, 1), 160, 160)
        paint_through(c, cov, Color(0.92, 0.92, 0.88))

    return magnify(c, 2)


def plate_03():
    """Side-by-side fan of Bresenham and Wu, magnified by 2.
    Creates a 640×320 canvas: left half is Bresenham, right half is Wu."""
    a = fan_bresenham()
    b = fan_wu()

    both = Canvas(320, 160)
    for y in range(160):
        for x in range(160):
            write_pixel(both, x, y, pixel_at(a, x, y))
            write_pixel(both, x + 160, y, pixel_at(b, x, y))

    return magnify(both, 2)


# ============================================================================
# Chapter 4: Points, Vectors, Transforms
# ============================================================================

class Tuple:
    """A 3-tuple (x, y, w) representing either a point or a vector."""
    
    def __init__(self, x, y, w):
        self.x = x
        self.y = y
        self.w = w
    
    def __eq__(self, other):
        if not isinstance(other, Tuple):
            return False
        tolerance = 0.0001
        return (abs(self.x - other.x) <= tolerance and
                abs(self.y - other.y) <= tolerance and
                abs(self.w - other.w) <= tolerance)
    
    def __ne__(self, other):
        return not self.__eq__(other)
    
    def __add__(self, other):
        if not isinstance(other, Tuple):
            raise TypeError("Can only add tuples to tuples")
        return Tuple(self.x + other.x, self.y + other.y, self.w + other.w)
    
    def __sub__(self, other):
        if not isinstance(other, Tuple):
            raise TypeError("Can only subtract tuples from tuples")
        return Tuple(self.x - other.x, self.y - other.y, self.w - other.w)
    
    def __mul__(self, scalar):
        if not isinstance(scalar, (int, float)):
            raise TypeError("Can only multiply tuple by scalar")
        return Tuple(self.x * scalar, self.y * scalar, self.w * scalar)
    
    def __rmul__(self, scalar):
        return self.__mul__(scalar)
    
    def __truediv__(self, scalar):
        if not isinstance(scalar, (int, float)):
            raise TypeError("Can only divide tuple by scalar")
        return Tuple(self.x / scalar, self.y / scalar, self.w / scalar)
    
    def __neg__(self):
        return Tuple(-self.x, -self.y, -self.w)
    
    def __repr__(self):
        return f"Tuple({self.x}, {self.y}, {self.w})"


def point(x, y):
    """Create a point with w = 1."""
    return Tuple(x, y, 1)


def vector(x, y):
    """Create a vector with w = 0."""
    return Tuple(x, y, 0)


def magnitude(v):
    """Compute the magnitude (length) of a vector."""
    if not isinstance(v, Tuple):
        raise TypeError("magnitude requires a tuple")
    return math.sqrt(v.x * v.x + v.y * v.y)


def normalize(v):
    """Normalize a vector to unit length."""
    if not isinstance(v, Tuple):
        raise TypeError("normalize requires a tuple")
    mag = magnitude(v)
    if mag == 0:
        raise ValueError("Cannot normalize a zero-length vector")
    return Tuple(v.x / mag, v.y / mag, v.w / mag)


def dot(a, b):
    """Compute the dot product of two vectors."""
    if not isinstance(a, Tuple) or not isinstance(b, Tuple):
        raise TypeError("dot requires two tuples")
    return a.x * b.x + a.y * b.y


def cross(a, b):
    """Compute the 2D cross product (returns a scalar)."""
    if not isinstance(a, Tuple) or not isinstance(b, Tuple):
        raise TypeError("cross requires two tuples")
    return a.x * b.y - a.y * b.x


class Matrix3:
    """A 3x3 matrix for 2D transforms."""
    
    def __init__(self, *values):
        if len(values) != 9:
            raise ValueError("Matrix3 requires exactly 9 values")
        # Store row-major: values[0:3] is row 0, values[3:6] is row 1, values[6:9] is row 2
        self.values = list(values)
    
    def __getitem__(self, key):
        """Access matrix element by [row, col]."""
        if isinstance(key, tuple):
            r, c = key
            return self.values[r * 3 + c]
        raise TypeError("Matrix3 requires [row, col] indexing")
    
    def __setitem__(self, key, value):
        """Set matrix element by [row, col]."""
        if isinstance(key, tuple):
            r, c = key
            self.values[r * 3 + c] = value
        else:
            raise TypeError("Matrix3 requires [row, col] indexing")
    
    def __eq__(self, other):
        if not isinstance(other, Matrix3):
            return False
        tolerance = 0.0001
        return all(abs(a - b) <= tolerance for a, b in zip(self.values, other.values))
    
    def __ne__(self, other):
        return not self.__eq__(other)
    
    def __mul__(self, other):
        """Multiply: matrix * matrix or matrix * tuple."""
        if isinstance(other, Tuple):
            # Matrix * Tuple
            x = self[0, 0] * other.x + self[0, 1] * other.y + self[0, 2] * other.w
            y = self[1, 0] * other.x + self[1, 1] * other.y + self[1, 2] * other.w
            w = self[2, 0] * other.x + self[2, 1] * other.y + self[2, 2] * other.w
            return Tuple(x, y, w)
        elif isinstance(other, Matrix3):
            # Matrix * Matrix
            result = []
            for r in range(3):
                for c in range(3):
                    val = (self[r, 0] * other[0, c] +
                           self[r, 1] * other[1, c] +
                           self[r, 2] * other[2, c])
                    result.append(val)
            return Matrix3(*result)
        else:
            raise TypeError("Can only multiply matrix by matrix or tuple")
    
    def __repr__(self):
        lines = []
        for r in range(3):
            lines.append(f"[{self[r, 0]:.4f} {self[r, 1]:.4f} {self[r, 2]:.4f}]")
        return "\n".join(lines)


def matrix3(*values):
    """Create a 3x3 matrix from 9 values in row-major order."""
    return Matrix3(*values)


def identity():
    """Return the 3x3 identity matrix."""
    return Matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1)


def transpose(m):
    """Transpose a matrix."""
    if not isinstance(m, Matrix3):
        raise TypeError("transpose requires a Matrix3")
    return Matrix3(
        m[0, 0], m[1, 0], m[2, 0],
        m[0, 1], m[1, 1], m[2, 1],
        m[0, 2], m[1, 2], m[2, 2]
    )


def minor(m, r, c):
    """Compute the 2x2 minor determinant by deleting row r and column c."""
    if not isinstance(m, Matrix3):
        raise TypeError("minor requires a Matrix3")
    # Find the two row indices that aren't r
    rows = [i for i in range(3) if i != r]
    # Find the two column indices that aren't c
    cols = [j for j in range(3) if j != c]
    return m[rows[0], cols[0]] * m[rows[1], cols[1]] - m[rows[0], cols[1]] * m[rows[1], cols[0]]


def cofactor(m, r, c):
    """Compute the cofactor of element at (r, c)."""
    if not isinstance(m, Matrix3):
        raise TypeError("cofactor requires a Matrix3")
    min_val = minor(m, r, c)
    if (r + c) % 2 == 1:
        return -min_val
    else:
        return min_val


def determinant(m):
    """Compute the determinant of a 3x3 matrix."""
    if not isinstance(m, Matrix3):
        raise TypeError("determinant requires a Matrix3")
    return (m[0, 0] * cofactor(m, 0, 0) +
            m[0, 1] * cofactor(m, 0, 1) +
            m[0, 2] * cofactor(m, 0, 2))


def is_invertible(m):
    """Check if a matrix is invertible (determinant != 0)."""
    if not isinstance(m, Matrix3):
        raise TypeError("is_invertible requires a Matrix3")
    return determinant(m) != 0


def inverse(m):
    """Compute the inverse of a matrix."""
    if not isinstance(m, Matrix3):
        raise TypeError("inverse requires a Matrix3")
    d = determinant(m)
    if d == 0:
        raise ValueError("Matrix is not invertible (determinant is 0)")
    
    result = []
    for r in range(3):
        for c in range(3):
            # Transpose happens here: result[c, r] = cofactor(m, r, c) / d
            result.append(cofactor(m, r, c) / d)
    
    # Rearrange to transpose
    transposed = []
    for c in range(3):
        for r in range(3):
            transposed.append(result[r * 3 + c])
    
    return Matrix3(*transposed)


def translation(tx, ty):
    """Create a translation transform matrix."""
    return Matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1)


def scaling(sx, sy):
    """Create a scaling transform matrix."""
    return Matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1)


def rotation(r):
    """Create a rotation transform matrix (angle in radians)."""
    c = math.cos(r)
    s = math.sin(r)
    return Matrix3(c, -s, 0, s, c, 0, 0, 0, 1)


def shearing(xy, yx):
    """Create a shearing transform matrix."""
    return Matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1)


def approx_scale(m):
    """Compute the approximate scale factor of a transform.
    Uses the square root of the absolute value of the determinant of the 2x2 part."""
    if not isinstance(m, Matrix3):
        raise TypeError("approx_scale requires a Matrix3")
    det_2x2 = m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]
    return math.sqrt(abs(det_2x2))


def transform_points(points, matrix):
    """Transform a list of points through a matrix."""
    if not isinstance(matrix, Matrix3):
        raise TypeError("transform_points requires a Matrix3")
    return [matrix * p for p in points]


# Shape representation and functions

class Shape:
    """Base class for shapes that can answer the inside() query."""
    
    def inside(self, x, y):
        """Return True if point (x, y) is inside the shape."""
        raise NotImplementedError


class Segment(Shape):
    """A line segment of given width, with square ends."""

    def __init__(self, a, b, width):
        if not isinstance(a, Tuple) or not isinstance(b, Tuple):
            raise TypeError("Segment endpoints must be tuples")
        self.a = a
        self.b = b
        self.width = width

        # Pre-compute half-planes
        ax, ay = a.x, a.y
        bx, by = b.x, b.y

        dx = bx - ax
        dy = by - ay
        length = math.sqrt(dx * dx + dy * dy)

        h = width / 2.0

        self.half_planes = []

        if length == 0:
            # Degenerate case: a single point becomes a width-by-width square
            dx, dy = 1.0, 0.0
            nx, ny = -dy, dx
            self.half_planes = [
                HalfPlane(ax - dx * h, ay - dy * h, dx, dy),
                HalfPlane(bx + dx * h, by + dy * h, -dx, -dy),
                HalfPlane(ax + nx * h, ay + ny * h, -nx, -ny),
                HalfPlane(ax - nx * h, ay - ny * h, nx, ny)
            ]
        else:
            dx /= length
            dy /= length

            # Normal vector (perpendicular to direction)
            nx = -dy
            ny = dx

            # Four half-planes
            self.half_planes = [
                HalfPlane(ax, ay, dx, dy),  # Start point, facing along direction
                HalfPlane(bx, by, -dx, -dy),  # End point, facing back
                HalfPlane(ax + nx * h, ay + ny * h, -nx, -ny),  # Top side
                HalfPlane(ax - nx * h, ay - ny * h, nx, ny)  # Bottom side
            ]

    def inside(self, x, y):
        """Check if point is inside the segment using half-plane tests."""
        # Inside if it's inside all four half-planes
        for hp in self.half_planes:
            dx = x - hp.px
            dy = y - hp.py
            dot = dx * hp.nx + dy * hp.ny
            if dot < 0:
                return False
        return True


def segment(a, b, width):
    """Create a segment shape."""
    return Segment(a, b, width)


class Union(Shape):
    """A union of shapes - inside when any of its shapes is inside."""

    def __init__(self, shapes):
        self.shapes = list(shapes)


def union(shapes):
    """Create a union of shapes."""
    return Union(shapes)


class Transformed(Shape):
    """A shape seen through a matrix transform."""

    def __init__(self, shape, matrix):
        if not isinstance(matrix, Matrix3):
            raise TypeError("Transformed requires a Matrix3")
        self.shape = shape
        self.matrix = matrix
        self.inv = None
        if is_invertible(matrix):
            self.inv = inverse(matrix)


def transformed(shape, matrix):
    """Create a transformed shape."""
    return Transformed(shape, matrix)


class Outline(Shape):
    """A closed polygon as a union of segments."""

    def __init__(self, points, matrix, width):
        if not isinstance(matrix, Matrix3):
            raise TypeError("Outline requires a Matrix3")
        # Transform the points through the matrix
        transformed_pts = [matrix * p for p in points]
        # Create segments between consecutive points (wrapping around)
        segs = []
        for i in range(len(transformed_pts)):
            next_i = (i + 1) % len(transformed_pts)
            segs.append(segment(transformed_pts[i], transformed_pts[next_i], width))
        self.union = union(segs)


def outline(points, matrix, width):
    """Create an outline from points, transformed by matrix, with given width."""
    return Outline(points, matrix, width)


def side_by_side(a, b):
    """Create a canvas with a on the left and b on the right."""
    if not isinstance(a, Canvas) or not isinstance(b, Canvas):
        raise TypeError("side_by_side requires two Canvas objects")
    if a.height != b.height:
        raise ValueError("Canvases must have the same height")
    
    result = Canvas(a.width + b.width, a.height)
    
    # Copy a into the left half
    for y in range(a.height):
        for x in range(a.width):
            write_pixel(result, x, y, pixel_at(a, x, y))
    
    # Copy b into the right half
    for y in range(b.height):
        for x in range(b.width):
            write_pixel(result, a.width + x, y, pixel_at(b, x, y))
    
    return result


# Chapter 4 renders

def fan_points():
    """Generate 13 points for a fan: center at origin, then 12 end points at radius 36."""
    pts = [point(0, 0)]
    for k in range(12):
        angle = k * math.pi / 6  # 30 degrees in radians
        pts.append(point(36 * math.cos(angle), 36 * math.sin(angle)))
    return pts


def fan_transformed(m):
    """Draw a fan transformed by matrix m."""
    if not isinstance(m, Matrix3):
        raise TypeError("fan_transformed requires a Matrix3")
    
    c = Canvas(160, 160)
    fill(c, Color(0.02, 0.02, 0.025))
    
    pts = transform_points(fan_points(), m)
    
    # Create segments from center to each endpoint
    rays = []
    for k in range(1, 13):
        rays.append(segment(pts[0], pts[k], 1))
    
    rays_union = union(rays)
    cov = rasterize(rays_union, 160, 160)
    paint_through(c, cov, Color(0.92, 0.92, 0.88))
    
    return c


def fan_both_orders():
    """Draw the fan in two different transformation orders."""
    turn = rotation(math.pi / 6)
    move = translation(104.5, 76.5)
    
    left = fan_transformed(move * turn)
    right = fan_transformed(turn * move)
    
    return side_by_side(left, right)


def letter_f():
    """Generate the 10 points of an F shape centered at origin."""
    return [
        point(-20, -30), point(20, -30), point(20, -20), point(-10, -20),
        point(-10, -5), point(12, -5), point(12, 5), point(-10, 5),
        point(-10, 30), point(-20, 30)
    ]


def f_both_orders():
    """Draw the F in two different transformation orders with a ghost reference."""
    turn = rotation(math.pi / 6)
    move = translation(104.5, 76.5)
    home = translation(44.5, 44.5)
    ink = Color(0.92, 0.92, 0.88)
    dim = Color(0.16, 0.16, 0.17)
    
    # Create the ghost with the untransformed F
    ghost = Canvas(160, 160)
    fill(ghost, Color(0.02, 0.02, 0.025))
    ghost_outline = outline(letter_f(), home, 1)
    cov = rasterize(ghost_outline, 160, 160)
    paint_through(ghost, cov, dim)
    
    # Left: move * turn (rotate about center, then move)
    left = Canvas(160, 160)
    for y in range(160):
        for x in range(160):
            write_pixel(left, x, y, pixel_at(ghost, x, y))
    left_outline = outline(letter_f(), move * turn, 1)
    cov_left = rasterize(left_outline, 160, 160)
    paint_through(left, cov_left, ink)
    
    # Right: turn * move (move, then rotate about origin)
    right = Canvas(160, 160)
    for y in range(160):
        for x in range(160):
            write_pixel(right, x, y, pixel_at(ghost, x, y))
    right_outline = outline(letter_f(), turn * move, 1)
    cov_right = rasterize(right_outline, 160, 160)
    paint_through(right, cov_right, ink)
    
    return side_by_side(left, right)


def plate_04():
    """The final plate for chapter 4: F in two transformation orders, magnified by 2."""
    return magnify(f_both_orders(), 2)


# ============================================================================
# Chapter 5: Paths and Insideness
# ============================================================================

class Subpath:
    """A list of points, in order, and a flag for whether it was closed."""

    def __init__(self, points=None, closed=False):
        self.points = points if points is not None else []
        self.closed = closed

    def __repr__(self):
        return f"Subpath({self.points}, closed={self.closed})"


class Edge:
    """An edge of a path, as an (a, b) pair. Compares equal to a plain
    (a, b) tuple, component-wise with the usual tolerance."""

    def __init__(self, a, b):
        self.a = a
        self.b = b

    def __getitem__(self, idx):
        if idx == 0:
            return self.a
        elif idx == 1:
            return self.b
        raise IndexError("Edge index out of range")

    def __len__(self):
        return 2

    def __eq__(self, other):
        if isinstance(other, Edge):
            return self.a == other.a and self.b == other.b
        elif isinstance(other, tuple) and len(other) == 2:
            return self.a == other[0] and self.b == other[1]
        return False

    def __ne__(self, other):
        return not self.__eq__(other)

    def __repr__(self):
        return f"Edge({self.a}, {self.b})"


class Path:
    """A path: a list of subpaths, each a list of points and a closed flag."""

    def __init__(self):
        self.subpaths = []


def path():
    """Create an empty path."""
    return Path()


def move_to(p, pt):
    """Lift the pen and put it down at pt, starting a new subpath."""
    p.subpaths.append(Subpath([pt], False))


def line_to(p, pt):
    """Draw a straight line from wherever the pen is to pt.

    With nothing to draw from, behaves as move_to. After a close, the
    pen is where the closed subpath began, so this starts a new subpath
    there and draws to pt."""
    if not p.subpaths:
        move_to(p, pt)
        return
    last = p.subpaths[-1]
    if last.closed:
        start = last.points[0]
        p.subpaths.append(Subpath([start, pt], False))
    else:
        last.points.append(pt)


def close(p):
    """Draw a line back to where the pen was last put down, and mark the
    subpath closed. Closing nothing, or closing twice, does nothing more."""
    if not p.subpaths:
        return
    p.subpaths[-1].closed = True


def subpaths(p):
    """The list of subpaths, each with .points and .closed."""
    return p.subpaths


def edges(p):
    """Every edge of every subpath as (a, b) pairs, treating every subpath
    as closed whether or not close() was called. A subpath of one point
    contributes no edges."""
    result = []
    for sp in p.subpaths:
        n = len(sp.points)
        if n < 2:
            continue
        for i in range(n):
            a = sp.points[i]
            b = sp.points[(i + 1) % n]
            result.append(Edge(a, b))
    return result


def bounds(p):
    """The smallest axis-aligned box around every point of every subpath,
    as (min x, min y, max x, max y). An empty path is (0, 0, 0, 0)."""
    pts = [pt for sp in p.subpaths for pt in sp.points]
    if not pts:
        return (0.0, 0.0, 0.0, 0.0)
    xs = [pt.x for pt in pts]
    ys = [pt.y for pt in pts]
    return (min(xs), min(ys), max(xs), max(ys))


def polygon(*points):
    """A closed subpath through the given points."""
    p = Path()
    p.subpaths = [Subpath(list(points), True)]
    return p


def circle_path(cx, cy, r, n):
    """A regular n-gon standing in for a circle: first point at angle 0
    (on the right), going clockwise on the screen."""
    pts = []
    for k in range(n):
        angle = 2 * math.pi * k / n
        pts.append(point(cx + r * math.cos(angle), cy + r * math.sin(angle)))
    return polygon(*pts)


def crossings(p, x, y):
    """Count the edges a ray from (x, y) toward +x crosses, using the
    half-open rule: an edge from a to b is crossed when the ray's height y
    satisfies a.y <= y < b.y or b.y <= y < a.y."""
    count = 0
    for e in edges(p):
        a, b = e.a, e.b
        if (a.y <= y < b.y) or (b.y <= y < a.y):
            t = (y - a.y) / (b.y - a.y)
            cx = a.x + t * (b.x - a.x)
            if cx > x:
                count += 1
    return count


def winding_at(p, x, y):
    """The winding number of the path around (x, y): each edge that
    crosses the ray's height counts +1 (heading down the canvas) or -1
    (heading up). Positive is clockwise on the screen."""
    q = point(x, y)
    w = 0
    for e in edges(p):
        a, b = e.a, e.b
        if a.y <= y:
            if b.y > y and cross(b - a, q - a) > 0:
                w += 1
        else:
            if b.y <= y and cross(b - a, q - a) < 0:
                w -= 1
    return w


def inside_nonzero(p, x, y):
    """Nonzero rule: inside when the winding number isn't zero."""
    return winding_at(p, x, y) != 0


def inside_evenodd(p, x, y):
    """Even-odd rule: inside when the winding number is odd."""
    return winding_at(p, x, y) % 2 != 0


class Filled(Shape):
    """The shape a path encloses under a rule, "nonzero" or "evenodd"."""

    def __init__(self, path, rule):
        self.path = path
        self.rule = rule


def filled(p, rule):
    """Create a filled-path shape."""
    return Filled(p, rule)


def rasterize_within(shape, box, width, height):
    """Chapter 2's rasterize, restricted to the pixels a box touches:
    columns from floor(min x) up to but not including ceil(max x), rows
    likewise, clipped to the buffer."""
    min_x, min_y, max_x, max_y = box
    cov = CoverageBuffer(width, height)
    x0 = max(0, math.floor(min_x))
    x1 = min(width, math.ceil(max_x))
    y0 = max(0, math.floor(min_y))
    y1 = min(height, math.ceil(max_y))
    for y in range(y0, y1):
        for x in range(x0, x1):
            cov.coverage[y][x] = coverage(shape, x, y)
    return cov


def star():
    """Five points on a circle of radius 70 about (80.5, 80.5), the first
    straight up, visited every second one so the pen crosses itself."""
    p = path()
    for k in range(5):
        a = math.radians(-90 + 144 * k)
        q = point(80.5 + 70 * math.cos(a), 80.5 + 70 * math.sin(a))
        if k == 0:
            move_to(p, q)
        else:
            line_to(p, q)
    close(p)
    return p


def star_panel(rule, method):
    """One panel of plate 5: the star filled under rule, rasterized either
    by center sampling or by coverage within its bounds."""
    c = canvas(160, 160)
    fill(c, color(0.02, 0.02, 0.025))
    s = filled(star(), rule)
    if method == "centers":
        cov = rasterize_centers(s, 160, 160)
    else:
        cov = rasterize_within(s, bounds(star()), 160, 160)
    paint_through(c, cov, color(0.9, 0.55, 0.1))
    return c


def star_centers():
    """Nonzero and even-odd panels, by the center question, side by side."""
    return side_by_side(star_panel("nonzero", "centers"), star_panel("evenodd", "centers"))


def star_coverage():
    """Nonzero and even-odd panels, by coverage, side by side."""
    return side_by_side(star_panel("nonzero", "coverage"), star_panel("evenodd", "coverage"))


def plate_05():
    """The final plate for chapter 5: centers on top, coverage below,
    magnified by 2."""
    top = star_centers()
    bottom = star_coverage()
    both = canvas(320, 320)
    for y in range(160):
        for x in range(320):
            write_pixel(both, x, y, pixel_at(top, x, y))
            write_pixel(both, x, y + 160, pixel_at(bottom, x, y))
    return magnify(both, 2)


# ============================================================================
# Chapter 6: Filling a Polygon
# ============================================================================

class EdgeTableEntry:
    """One edge, prepared for the sweep: its top, its x there, its slope
    in x per unit of y, and its direction (+1 down the canvas, -1 up)."""

    def __init__(self, y_top, y_bottom, x_top, slope, direction):
        self.y_top = y_top
        self.y_bottom = y_bottom
        self.x_top = x_top
        self.slope = slope
        self.direction = direction

    def __repr__(self):
        return (f"EdgeTableEntry(y_top={self.y_top}, y_bottom={self.y_bottom}, "
                f"x_top={self.x_top}, slope={self.slope}, direction={self.direction})")


def edge_table(p):
    """Every non-horizontal edge of a path, prepared for the sweep and
    sorted by y_top, then by x_top. Horizontal edges (a.y = b.y exactly)
    are dropped."""
    entries = []
    for e in edges(p):
        a, b = e.a, e.b
        if a.y == b.y:
            continue
        dy = b.y - a.y
        slope = (b.x - a.x) / dy
        if a.y < b.y:
            y_top, y_bottom, x_top, direction = a.y, b.y, a.x, 1
        else:
            y_top, y_bottom, x_top, direction = b.y, a.y, b.x, -1
        entries.append(EdgeTableEntry(y_top, y_bottom, x_top, slope, direction))
    entries.sort(key=lambda entry: (entry.y_top, entry.x_top))
    return entries


def x_at(edge, y):
    """Where an edge crosses height y: x_top + (y - y_top) * slope."""
    return edge.x_top + (y - edge.y_top) * edge.slope


def crossings_on_row(table, y):
    """(x, direction) for every edge of the table that spans height y
    under the half-open rule y_top <= y < y_bottom, sorted by x."""
    result = []
    for e in table:
        if e.y_top <= y < e.y_bottom:
            result.append((x_at(e, y), e.direction))
    result.sort(key=lambda t: t[0])
    return result


def spans_from_crossings(xs, rule):
    """Walk sorted (x, direction) crossings left to right, accumulating
    the winding number, and return the maximal intervals where the rule
    says inside. Touching inside stretches merge into one span."""
    out = []
    w = 0
    start = None
    for (x, d) in xs:
        w += d
        if rule == "nonzero":
            is_inside = w != 0
        else:
            is_inside = (w % 2) != 0
        if is_inside and start is None:
            start = x
        if not is_inside and start is not None:
            out.append((start, x))
            start = None
    return out


def spans(p, rule, row):
    """The spans of a path on pixel row `row`, sampled at height row + 0.5."""
    y = row + 0.5
    table = edge_table(p)
    xs = crossings_on_row(table, y)
    return spans_from_crossings(xs, rule)


def fill_span(cov, row, x0, x1):
    """Set to 1 every pixel of the row whose center lies in [x0, x1)."""
    first = math.ceil(x0 - 0.5)
    last = math.ceil(x1 - 0.5) - 1
    lo = max(first, 0)
    hi = min(last, cov.width - 1)
    for x in range(lo, hi + 1):
        set_coverage(cov, x, row, 1)


def fill_path_aliased(p, rule, width, height):
    """The scanline fill: sweep the rows top to bottom keeping the active
    edge list, sorting crossings and filling spans on each row."""
    cov = coverage_buffer(width, height)
    table = edge_table(p)
    active = []
    next_idx = 0
    n = len(table)
    for row in range(height):
        y = row + 0.5
        while next_idx < n and table[next_idx].y_top <= y:
            active.append(table[next_idx])
            next_idx += 1
        active = [e for e in active if e.y_bottom > y]
        xs = sorted(((x_at(e, y), e.direction) for e in active), key=lambda t: t[0])
        for (x0, x1) in spans_from_crossings(xs, rule):
            fill_span(cov, row, x0, x1)
    return cov


def max_coverage_difference(a, b):
    """The largest difference between corresponding entries of two
    coverage buffers, or 1 when their sizes differ."""
    if a.width != b.width or a.height != b.height:
        return 1
    max_diff = 0.0
    for y in range(a.height):
        for x in range(a.width):
            diff = abs(coverage_at(a, x, y) - coverage_at(b, x, y))
            if diff > max_diff:
                max_diff = diff
    return max_diff


def transform_path(p, m):
    """A new path with every point of every subpath taken through m,
    closed flags and all. The original path is untouched."""
    if not isinstance(m, Matrix3):
        raise TypeError("transform_path requires a Matrix3")
    new_p = Path()
    for sp in p.subpaths:
        new_points = [m * pt for pt in sp.points]
        new_p.subpaths.append(Subpath(new_points, sp.closed))
    return new_p


def unit_star():
    """The chapter 5 star, shrunk to radius 1 about the origin."""
    return transform_path(star(), scaling(1 / 70, 1 / 70) * translation(-80.5, -80.5))


def spiral():
    """Twenty-four unit stars along a spiral, each bigger and turned a
    little further, in three inks, filled nonzero by the sweep."""
    c = canvas(320, 320)
    fill(c, color(0.02, 0.02, 0.025))
    inks = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
    for k in range(24):
        a = math.radians(k * 25)
        r = 20 + 5 * k
        m = (translation(160.5 + r * math.cos(a), 160.5 + r * math.sin(a)) *
             rotation(a) *
             scaling(6 + 1.25 * k, 6 + 1.25 * k))
        cov = fill_path_aliased(transform_path(unit_star(), m), "nonzero", 320, 320)
        paint_through(c, cov, inks[k % 3])
    return c


def plate_06():
    """The final plate for chapter 6: the spiral, magnified by 2."""
    return magnify(spiral(), 2)


# ============================================================================
# Chapter 7: Analytic Antialiasing
# ============================================================================

class Accumulator:
    """A grid of (area, cover) pairs, one per cell, all zero to start."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.area = [0.0] * (width * height)
        self.cover = [0.0] * (width * height)

    def __repr__(self):
        return f"Accumulator({self.width}, {self.height})"


def accumulator(w, h):
    """Create a fresh accumulator, all zero."""
    return Accumulator(w, h)


def area_at(acc, x, y):
    """The area a cell has itself collected."""
    if 0 <= x < acc.width and 0 <= y < acc.height:
        return acc.area[y * acc.width + x]
    return 0.0


def cover_at(acc, x, y):
    """The cover a cell carries to every cell on its right."""
    if 0 <= x < acc.width and 0 <= y < acc.height:
        return acc.cover[y * acc.width + x]
    return 0.0


def add_cell(acc, x, row, area, cover):
    """Deposit an area and a cover into one cell, adding to what's there.
    A deposit left of the buffer folds onto column 0 as pure cover (the
    whole height carries in, since everything in the row is to its right);
    a deposit right of the buffer is dropped."""
    if row < 0 or row >= acc.height:
        return
    if x < 0:
        x = 0
        area = cover
    if x >= acc.width:
        return
    i = row * acc.width + x
    acc.area[i] += area
    acc.cover[i] += cover


def accumulate_row(acc, row, x0, x1, height):
    """Deposit the piece of an edge lying in a single row, from x0 to x1,
    carrying a signed height. The height is shared among the cells the
    piece crosses in proportion to the width it has in each; each cell's
    area is its share weighted by how far to the left of the cell the
    piece's midpoint sits (the trapezoid rule)."""
    xa, xb = (x0, x1) if x0 <= x1 else (x1, x0)
    ca = math.floor(xa)
    cb = math.floor(xb)
    if ca == cb:
        xm = (xa + xb) / 2 - ca
        add_cell(acc, ca, row, height * (1 - xm), height)
        return
    dx = xb - xa
    for c in range(ca, cb + 1):
        lo = max(xa, c)
        hi = min(xb, c + 1)
        share = height * (hi - lo) / dx
        m = (lo + hi) / 2 - c
        add_cell(acc, c, row, share * (1 - m), share)


def accumulate(acc, a, b):
    """Deposit a whole edge: clip it to each row it crosses and hand each
    piece to accumulate_row. Heading up the canvas (a.y > b.y) carries a
    positive height, heading down a negative one. A horizontal edge
    deposits nothing."""
    if a.y == b.y:
        return
    sign = 1.0 if a.y > b.y else -1.0
    top, bottom = (b, a) if a.y > b.y else (a, b)
    slope = (bottom.x - top.x) / (bottom.y - top.y)
    first = max(math.floor(top.y), 0)
    last = min(math.ceil(bottom.y) - 1, acc.height - 1)
    for row in range(first, last + 1):
        y0 = max(top.y, row)
        y1 = min(bottom.y, row + 1)
        if y1 <= y0:
            continue
        x0 = top.x + (y0 - top.y) * slope
        x1 = top.x + (y1 - top.y) * slope
        accumulate_row(acc, row, x0, x1, sign * (y1 - y0))


def apply_rule(w, rule):
    """Turn a (possibly fractional) winding number into coverage: for
    "nonzero", min(1, |w|); for "evenodd", the triangle wave that folds
    |w| back and forth between 0 and 1."""
    if rule == "nonzero":
        return min(1.0, abs(w))
    t = abs(w) % 2.0
    return t if t <= 1.0 else 2.0 - t


def resolve(acc, rule):
    """Sweep each row left to right: a cell's winding number is the cover
    of every cell to its left plus its own area, and apply_rule turns that
    into coverage."""
    cov = CoverageBuffer(acc.width, acc.height)
    for row in range(acc.height):
        running = 0.0
        base = row * acc.width
        for x in range(acc.width):
            i = base + x
            cov.coverage[row][x] = apply_rule(running + acc.area[i], rule)
            running += acc.cover[i]
    return cov


def fill_path(p, rule, w, h):
    """The fill from chapter 7 on: deposit every edge of the path into an
    accumulator and resolve it."""
    acc = accumulator(w, h)
    for e in edges(p):
        accumulate(acc, e.a, e.b)
    return resolve(acc, rule)


def polygon_area(p):
    """The shoelace formula over every edge of every subpath, signed: positive
    for a path wound clockwise on screen (the same sign as cross), negative
    for counterclockwise. Chapter 13 uses the sign to orient stroke pieces."""
    total = 0.0
    for e in edges(p):
        total += e.a.x * e.b.y - e.b.x * e.a.y
    return total / 2.0


# Chapter 7 renders

PAPER = color(0.02, 0.02, 0.025)
INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
PALE = color(0.92, 0.9, 0.82)


def needle_path():
    """Twelve thin triangles radiating from a shared apex."""
    p = path()
    for k in range(12):
        a = math.radians(30 * k + 7)
        half = math.radians(1.6)
        move_to(p, point(30.5, 30.5))
        line_to(p, point(30.5 + 29 * math.cos(a - half), 30.5 + 29 * math.sin(a - half)))
        line_to(p, point(30.5 + 29 * math.cos(a + half), 30.5 + 29 * math.sin(a + half)))
        close(p)
    return p


def needles():
    """The same twelve needles, chapter 6's aliased fill on the left and
    this chapter's exact fill on the right, each magnified by 4."""
    np_ = needle_path()
    left = canvas(60, 60)
    fill(left, PAPER)
    paint_through(left, fill_path_aliased(np_, "nonzero", 60, 60), INKS[0])
    right = canvas(60, 60)
    fill(right, PAPER)
    paint_through(right, fill_path(np_, "nonzero", 60, 60), INKS[0])
    return side_by_side(magnify(left, 4), magnify(right, 4))


def soft_square():
    """A small square whose edges land on pixel centers, magnified by 24."""
    c = canvas(8, 8)
    fill(c, PAPER)
    p = polygon(point(1.5, 1.5), point(5.5, 1.5), point(5.5, 5.5), point(1.5, 5.5))
    paint_through(c, fill_path(p, "nonzero", 8, 8), INKS[0])
    return magnify(c, 24)


def star_panel_exact(rule):
    """One panel of the exact star: the chapter 5 star filled under rule
    by this chapter's analytic fill."""
    c = canvas(160, 160)
    fill(c, PAPER)
    paint_through(c, fill_path(star(), rule, 160, 160), INKS[0])
    return c


def star_exact():
    """Chapter 5's star filled both ways, exactly, side by side."""
    return side_by_side(star_panel_exact("nonzero"), star_panel_exact("evenodd"))


def spiral_smooth():
    """Chapter 6's spiral of stars, now filled by the analytic fill."""
    c = canvas(320, 320)
    fill(c, PAPER)
    for k in range(24):
        a = math.radians(k * 25)
        r = 20 + 5 * k
        m = (translation(160.5 + r * math.cos(a), 160.5 + r * math.sin(a)) *
             rotation(a) *
             scaling(6 + 1.25 * k, 6 + 1.25 * k))
        cov = fill_path(transform_path(unit_star(), m), "nonzero", 320, 320)
        paint_through(c, cov, INKS[k % 3])
    return c


def rays(i):
    """Every third of the sunburst's 72 rays, starting at i."""
    p = path()
    k = i
    while k < 72:
        a = math.radians(5 * k)
        half = math.radians(1.4)
        move_to(p, point(240, 240))
        line_to(p, point(240 + 232 * math.cos(a - half), 240 + 232 * math.sin(a - half)))
        line_to(p, point(240 + 232 * math.cos(a + half), 240 + 232 * math.sin(a + half)))
        close(p)
        k += 3
    return p


def sunburst():
    """Seventy-two rays, a punched disc and an even-odd star, all filled
    analytically."""
    c = canvas(480, 480)
    fill(c, PAPER)
    for i in range(3):
        cov = fill_path(rays(i), "nonzero", 480, 480)
        paint_through(c, cov, INKS[i])
    disc = circle_path(240, 240, 78, 180)
    cov = fill_path(disc, "nonzero", 480, 480)
    paint_through(c, cov, PAPER)
    m = translation(240, 240) * scaling(64, 64)
    cov = fill_path(transform_path(unit_star(), m), "evenodd", 480, 480)
    paint_through(c, cov, PALE)
    return c


def plate_07():
    """The final plate for chapter 7: the sunburst."""
    return sunburst()


# ============================================================================
# Chapter 8: Curves
# ============================================================================

class Curve:
    """A Bezier curve, held as its control points: three for a quadratic,
    four for a cubic."""

    def __init__(self, points):
        self.points = list(points)

    def __repr__(self):
        return f"Curve({self.points})"


def quadratic(p0, p1, p2):
    """A quadratic Bezier curve from its three control points."""
    return Curve([p0, p1, p2])


def cubic(p0, p1, p2, p3):
    """A cubic Bezier curve from its four control points."""
    return Curve([p0, p1, p2, p3])


def _lerp_xy(a, b, t):
    """Linear interpolation between two (x, y) pairs."""
    ax, ay = a
    bx, by = b
    return (ax + (bx - ax) * t, ay + (by - ay) * t)


def _de_casteljau(points_xy, t):
    """De Casteljau's construction on a list of (x, y) pairs: repeatedly
    interpolate neighbouring pairs by t until one point is left. Returns
    that point along with the left edge and right edge of the pyramid
    (the control points of the two curves split_at produces)."""
    pts = list(points_xy)
    left = [pts[0]]
    right = [pts[-1]]
    while len(pts) > 1:
        pts = [_lerp_xy(pts[i], pts[i + 1], t) for i in range(len(pts) - 1)]
        left.append(pts[0])
        right.append(pts[-1])
    right.reverse()
    return pts[0], left, right


def point_at(c, t):
    """The point on the curve at parameter t, by de Casteljau's
    construction."""
    xy = [(p.x, p.y) for p in c.points]
    (x, y), _left, _right = _de_casteljau(xy, t)
    return point(x, y)


def split_at(c, t):
    """Split a curve in two at t: the piece from 0 to t and the piece from
    t to 1, whose control points are the left and right edges of the de
    Casteljau pyramid."""
    xy = [(p.x, p.y) for p in c.points]
    _p, left, right = _de_casteljau(xy, t)
    left_pts = [point(x, y) for x, y in left]
    right_pts = [point(x, y) for x, y in right]
    return (Curve(left_pts), Curve(right_pts))


def derivative(c, t):
    """The tangent vector at parameter t: the curve's hodograph (its
    derivative, itself a Bezier one degree lower) evaluated at t."""
    n = len(c.points) - 1
    diffs = [(n * (c.points[i + 1].x - c.points[i].x),
              n * (c.points[i + 1].y - c.points[i].y)) for i in range(n)]
    (dx, dy), _left, _right = _de_casteljau(diffs, t)
    return vector(dx, dy)


def transform_curve(c, m):
    """A new curve with every control point taken through m."""
    if not isinstance(m, Matrix3):
        raise TypeError("transform_curve requires a Matrix3")
    return Curve([m * p for p in c.points])


def _axis_roots(coeffs, axis):
    """Roots in (0, 1) of one axis-component of the curve's derivative,
    given as polynomial coefficients low-to-high degree."""
    roots = []
    if len(coeffs) == 2:
        a, b = coeffs
        if b != 0:
            t = -a / b
            if 0 < t < 1:
                roots.append(t)
    elif len(coeffs) == 3:
        a, b, cc = coeffs
        if abs(cc) < 1e-12:
            if b != 0:
                t = -a / b
                if 0 < t < 1:
                    roots.append(t)
        else:
            disc = b * b - 4 * cc * a
            if disc >= 0:
                sq = math.sqrt(disc)
                for t in ((-b + sq) / (2 * cc), (-b - sq) / (2 * cc)):
                    if 0 < t < 1:
                        roots.append(t)
    return roots


def curve_bounds(c):
    """The smallest axis-aligned box that holds the curve itself, as
    (min x, min y, max x, max y): the curve's endpoints plus every
    parameter where a component of the derivative is zero."""
    n = len(c.points) - 1
    pts = c.points
    ts = {0.0, 1.0}
    if n == 2:
        p0, p1, p2 = pts
        for axis in ('x', 'y'):
            v0, v1, v2 = getattr(p0, axis), getattr(p1, axis), getattr(p2, axis)
            a = 2 * (v1 - v0)
            b = 2 * (v2 - 2 * v1 + v0)
            ts.update(_axis_roots((a, b), axis))
    elif n == 3:
        p0, p1, p2, p3 = pts
        for axis in ('x', 'y'):
            v0, v1, v2, v3 = (getattr(p0, axis), getattr(p1, axis),
                               getattr(p2, axis), getattr(p3, axis))
            d0, d1, d2 = v1 - v0, v2 - v1, v3 - v2
            a = 3 * d0
            b = 6 * (d1 - d0)
            cc = 3 * (d0 - 2 * d1 + d2)
            ts.update(_axis_roots((a, b, cc), axis))
    else:
        raise ValueError("curve_bounds only supports quadratic and cubic curves")
    xs = []
    ys = []
    for t in ts:
        pt = point_at(c, t)
        xs.append(pt.x)
        ys.append(pt.y)
    return (min(xs), min(ys), max(xs), max(ys))


def flatness(c):
    """How far the curve strays from the straight chord between its ends:
    the greatest distance of an interior control point from that chord."""
    a = c.points[0]
    b = c.points[-1]
    dx = b.x - a.x
    dy = b.y - a.y
    length = math.hypot(dx, dy)
    worst = 0.0
    for p in c.points[1:-1]:
        if length == 0:
            d = math.hypot(p.x - a.x, p.y - a.y)
        else:
            d = abs((p.x - a.x) * dy - (p.y - a.y) * dx) / length
        worst = max(worst, d)
    return worst


def _flatten_into(c, tolerance, out):
    if flatness(c) <= tolerance:
        out.append(c.points[-1])
    else:
        left, right = split_at(c, 0.5)
        _flatten_into(left, tolerance, out)
        _flatten_into(right, tolerance, out)


def flatten(c, tolerance):
    """A polyline within tolerance of the curve, as a list of points from
    start to end, by subdividing wherever a piece isn't yet flat enough."""
    out = [c.points[0]]
    _flatten_into(c, tolerance, out)
    return out


def polyline_length(pts):
    """The total length of a polyline given as a list of points."""
    total = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        total += math.hypot(b.x - a.x, b.y - a.y)
    return total


def flatten_length(c, tolerance):
    """The length of the curve's flattened polyline at this tolerance."""
    return polyline_length(flatten(c, tolerance))


def flatten_into_path(p, c, tolerance):
    """Append a flattened curve to a path with line_to, so a curve becomes
    an ordinary run of line segments. Starts a new subpath if the path is
    empty or its last subpath is closed; otherwise continues from wherever
    the pen already is."""
    pts = flatten(c, tolerance)
    if not p.subpaths or p.subpaths[-1].closed:
        move_to(p, pts[0])
        pts = pts[1:]
    else:
        cur = p.subpaths[-1].points[-1]
        if cur.x == pts[0].x and cur.y == pts[0].y:
            pts = pts[1:]
    for q in pts:
        line_to(p, q)


# Chapter 8: the SVG elliptical arc

def _angle_between(ux, uy, vx, vy):
    """The signed angle from vector (ux, uy) to vector (vx, vy)."""
    dot_ = ux * vx + uy * vy
    length = math.hypot(ux, uy) * math.hypot(vx, vy)
    a = math.acos(max(-1.0, min(1.0, dot_ / length)))
    return a if (ux * vy - uy * vx) >= 0 else -a


class Arc:
    """An elliptical arc in center form: a center, radii, the x-axis
    rotation phi (radians), a start angle theta1 and a swept angle delta.
    corrected says whether the radii had to be grown to reach."""

    def __init__(self, cx, cy, rx, ry, phi, theta1, delta, corrected):
        self.cx = cx
        self.cy = cy
        self.rx = rx
        self.ry = ry
        self.phi = phi
        self.theta1 = theta1
        self.delta = delta
        self.corrected = corrected

    def __repr__(self):
        return (f"Arc(cx={self.cx}, cy={self.cy}, rx={self.rx}, ry={self.ry}, "
                f"phi={self.phi}, theta1={self.theta1}, delta={self.delta}, "
                f"corrected={self.corrected})")


def arc(x1, y1, rx, ry, phi, large_arc, sweep, x2, y2):
    """SVG's endpoint form of an elliptical arc, turned into center form.
    Coincident endpoints or a zero radius describe no arc at all (None).
    Radii too small to reach the endpoints are grown together until they
    do, and corrected is set."""
    if (x1 == x2 and y1 == y2) or rx == 0 or ry == 0:
        return None
    rx = abs(rx)
    ry = abs(ry)
    cphi = math.cos(phi)
    sphi = math.sin(phi)
    dx = (x1 - x2) / 2
    dy = (y1 - y2) / 2
    x1p = cphi * dx + sphi * dy
    y1p = -sphi * dx + cphi * dy
    corrected = False
    lam = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
    if lam > 1:
        s = math.sqrt(lam)
        rx *= s
        ry *= s
        corrected = True
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den))
    if large_arc == sweep:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cphi * cxp - sphi * cyp + (x1 + x2) / 2
    cy = sphi * cxp + cphi * cyp + (y1 + y2) / 2
    theta1 = _angle_between(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    delta = _angle_between((x1p - cxp) / rx, (y1p - cyp) / ry,
                            (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi
    return Arc(cx, cy, rx, ry, phi, theta1, delta, corrected)


def arc_point(a, t):
    """The point at t (0 to 1) along the arc."""
    theta = a.theta1 + a.delta * t
    cphi = math.cos(a.phi)
    sphi = math.sin(a.phi)
    ex = a.rx * math.cos(theta)
    ey = a.ry * math.sin(theta)
    return point(a.cx + cphi * ex - sphi * ey, a.cy + sphi * ex + cphi * ey)


# Chapter 8 renders

def teardrop():
    """A teardrop as two cubics, tip to base and back."""
    return [
        cubic(point(30.5, 12), point(58, 16), point(46, 52), point(30.5, 52)),
        cubic(point(30.5, 52), point(15, 52), point(3, 16), point(30.5, 12)),
    ]


def drops():
    """The same teardrop, flattened coarse on the left and fine on the
    right, each magnified by 4."""
    td = teardrop()
    coarse = path()
    flatten_into_path(coarse, td[0], 4.0)
    flatten_into_path(coarse, td[1], 4.0)
    close(coarse)
    fine = path()
    flatten_into_path(fine, td[0], 0.1)
    flatten_into_path(fine, td[1], 0.1)
    close(fine)
    left = canvas(60, 60)
    fill(left, PAPER)
    paint_through(left, fill_path(coarse, "nonzero", 60, 60), INKS[2])
    right = canvas(60, 60)
    fill(right, PAPER)
    paint_through(right, fill_path(fine, "nonzero", 60, 60), INKS[2])
    return side_by_side(magnify(left, 4), magnify(right, 4))


def petal():
    """One flower petal, about one unit tall, as two cubics."""
    return [
        cubic(point(0, 0), point(0.55, -0.35), point(0.4, -0.92), point(0, -1)),
        cubic(point(0, -1), point(-0.4, -0.92), point(-0.55, -0.35), point(0, 0)),
    ]


def flower_at(p, m, n, tolerance):
    """Add n petals around the origin, placed by m, flattening each in
    device space (after the transform) at the given tolerance."""
    right_half, left_half = petal()
    for k in range(n):
        spin = m * rotation(2 * math.pi * k / n)
        flatten_into_path(p, transform_curve(right_half, spin), tolerance)
        flatten_into_path(p, transform_curve(left_half, spin), tolerance)
        close(p)


def flower():
    """Three flowers of curved petals at three sizes, each punched out at
    the center."""
    c = canvas(360, 360)
    fill(c, PAPER)
    spots = [(108, 250, 44, 8, 0.0), (200, 145, 74, 8, 0.39), (286, 252, 54, 7, 0.8)]
    for i, (cx, cy, s, n, rot) in enumerate(spots):
        m = translation(cx, cy) * scaling(s, s) * rotation(rot)
        petals = path()
        flower_at(petals, m, n, 0.2)
        paint_through(c, fill_path(petals, "nonzero", 360, 360), INKS[i % 3])
        disc = circle_path(cx, cy, s * 0.3, 64)
        paint_through(c, fill_path(disc, "nonzero", 360, 360), PAPER)
    return c


def plate_08():
    """The final plate for chapter 8: the flowers, magnified by 2."""
    return magnify(flower(), 2)



# ============================================================
# Chapter 9: Compositing
# ============================================================

class Pixel:
    """A premultiplied pixel: r, g, b already scaled by a, each in [0, a]."""

    def __init__(self, r, g, b, a):
        self.r = r
        self.g = g
        self.b = b
        self.a = a

    def __eq__(self, other):
        if not isinstance(other, Pixel):
            return False
        tolerance = 0.0001
        return (abs(self.r - other.r) <= tolerance and
                abs(self.g - other.g) <= tolerance and
                abs(self.b - other.b) <= tolerance and
                abs(self.a - other.a) <= tolerance)

    def __ne__(self, other):
        return not self.__eq__(other)

    def __repr__(self):
        return f"Pixel({self.r}, {self.g}, {self.b}, {self.a})"


def pixel(r, g, b, a):
    """Create a premultiplied pixel directly."""
    return Pixel(r, g, b, a)


def from_color(c, a):
    """Premultiply a straight colour at the given alpha."""
    return Pixel(c.red * a, c.green * a, c.blue * a, a)


def opaque(c):
    """A colour at alpha 1, premultiplied (which leaves it unchanged)."""
    return from_color(c, 1)


CLEAR = Pixel(0, 0, 0, 0)


def pixel_color(p):
    """Un-premultiply: the straight colour a pixel holds. A transparent
    pixel has no colour to recover, so it reads black."""
    if p.a == 0:
        return Color(0, 0, 0)
    return Color(p.r / p.a, p.g / p.a, p.b / p.a)


def pixel_alpha(p):
    """The alpha a pixel holds."""
    return p.a


def lerp_pixel(a, b, t):
    """Blend two pixels straight down the premultiplied channels."""
    return Pixel(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        a.a + (b.a - a.a) * t,
    )


def over(src, dst):
    """Source-over: keep all of src, and the fraction of dst src didn't
    cover. Every channel, including alpha, in premultiplied form."""
    return Pixel(
        src.r + (1 - src.a) * dst.r,
        src.g + (1 - src.a) * dst.g,
        src.b + (1 - src.a) * dst.b,
        src.a + (1 - src.a) * dst.a,
    )


def coefficients(op, a_s, a_d):
    """The Porter-Duff (Fa, Fb) coefficients for an operator: how much of
    the source survives, and how much of the destination."""
    table = {
        "clear":    (0,       0),
        "src":      (1,       0),
        "dst":      (0,       1),
        "src-over": (1,       1 - a_s),
        "dst-over": (1 - a_d, 1),
        "src-in":   (a_d,     0),
        "dst-in":   (0,       a_s),
        "src-out":  (1 - a_d, 0),
        "dst-out":  (0,       1 - a_s),
        "src-atop": (a_d,     1 - a_s),
        "dst-atop": (1 - a_d, a_s),
        "xor":      (1 - a_d, 1 - a_s),
    }
    return table[op]


def composite(op, src, dst):
    """Fa * src + Fb * dst, every channel including alpha."""
    fa, fb = coefficients(op, src.a, dst.a)
    return Pixel(
        fa * src.r + fb * dst.r,
        fa * src.g + fb * dst.g,
        fa * src.b + fb * dst.b,
        fa * src.a + fb * dst.a,
    )


# --- Blend modes ---

def _multiply(b, s):
    return b * s


def _screen(b, s):
    return b + s - b * s


def _hard_light(b, s):
    if s <= 0.5:
        return _multiply(b, 2 * s)
    return _screen(b, 2 * s - 1)


def _color_dodge(b, s):
    if b == 0:
        return 0.0
    if s == 1:
        return 1.0
    return min(1.0, b / (1 - s))


def _color_burn(b, s):
    if b == 1:
        return 1.0
    if s == 0:
        return 0.0
    return 1 - min(1.0, (1 - b) / s)


def _soft_light_d(x):
    if x <= 0.25:
        return ((16 * x - 12) * x + 4) * x
    return math.sqrt(x)


def _soft_light(b, s):
    if s <= 0.5:
        return b - (1 - 2 * s) * b * (1 - b)
    return b + (2 * s - 1) * (_soft_light_d(b) - b)


_SEPARABLE_MODES = {
    "normal":      lambda b, s: s,
    "multiply":    _multiply,
    "screen":      _screen,
    "overlay":     lambda b, s: _hard_light(s, b),
    "darken":      lambda b, s: min(b, s),
    "lighten":     lambda b, s: max(b, s),
    "color-dodge": _color_dodge,
    "color-burn":  _color_burn,
    "hard-light":  _hard_light,
    "soft-light":  _soft_light,
    "difference":  lambda b, s: abs(b - s),
    "exclusion":   lambda b, s: b + s - 2 * b * s,
}


def _lum(c):
    """A colour's brightness."""
    return 0.3 * c.red + 0.59 * c.green + 0.11 * c.blue


def _sat(c):
    """How far a colour's channels spread."""
    return max(c.red, c.green, c.blue) - min(c.red, c.green, c.blue)


def _clip_color(c):
    """Shift a colour back into range without changing its hue or luminosity."""
    l = _lum(c)
    n = min(c.red, c.green, c.blue)
    x = max(c.red, c.green, c.blue)
    r, g, b = c.red, c.green, c.blue
    if n < 0:
        r = l + (r - l) * l / (l - n)
        g = l + (g - l) * l / (l - n)
        b = l + (b - l) * l / (l - n)
    if x > 1:
        r = l + (r - l) * (1 - l) / (x - l)
        g = l + (g - l) * (1 - l) / (x - l)
        b = l + (b - l) * (1 - l) / (x - l)
    return Color(r, g, b)


def _set_lum(c, l):
    """Shift a colour to a target brightness, clipped back into range."""
    d = l - _lum(c)
    return _clip_color(Color(c.red + d, c.green + d, c.blue + d))


def _set_sat(c, s):
    """Stretch a colour to a target saturation."""
    channels = ['red', 'green', 'blue']
    vals = {ch: getattr(c, ch) for ch in channels}
    order = sorted(channels, key=lambda ch: vals[ch])
    cmin, cmid, cmax = order
    if vals[cmax] > vals[cmin]:
        new_mid = (vals[cmid] - vals[cmin]) * s / (vals[cmax] - vals[cmin])
    else:
        new_mid = 0.0
    result = {cmin: 0.0, cmid: new_mid, cmax: s}
    return Color(result['red'], result['green'], result['blue'])


def _blend_hue(cb, cs):
    return _set_lum(_set_sat(cs, _sat(cb)), _lum(cb))


def _blend_saturation(cb, cs):
    return _set_lum(_set_sat(cb, _sat(cs)), _lum(cb))


def _blend_color_mode(cb, cs):
    return _set_lum(cs, _lum(cb))


def _blend_luminosity(cb, cs):
    return _set_lum(cb, _lum(cs))


_NONSEPARABLE_MODES = {
    "hue": _blend_hue,
    "saturation": _blend_saturation,
    "color": _blend_color_mode,
    "luminosity": _blend_luminosity,
}


def blend_color(mode, backdrop, source):
    """The blend function on two straight colours."""
    if mode in _NONSEPARABLE_MODES:
        return _NONSEPARABLE_MODES[mode](backdrop, source)
    fn = _SEPARABLE_MODES[mode]
    return Color(
        fn(backdrop.red, source.red),
        fn(backdrop.green, source.green),
        fn(backdrop.blue, source.blue),
    )


def blend(mode, src, dst):
    """Source-over, with the overlap blended first."""
    a_s = src.a
    a_d = dst.a
    cs = pixel_color(src)
    cb = pixel_color(dst)
    b = blend_color(mode, cb, cs)
    out_r = a_s * (1 - a_d) * cs.red + a_s * a_d * b.red + (1 - a_s) * dst.r
    out_g = a_s * (1 - a_d) * cs.green + a_s * a_d * b.green + (1 - a_s) * dst.g
    out_b = a_s * (1 - a_d) * cs.blue + a_s * a_d * b.blue + (1 - a_s) * dst.b
    out_a = a_s + a_d * (1 - a_s)
    return Pixel(out_r, out_g, out_b, out_a)


# --- Layers ---

class Layer:
    """A buffer of premultiplied pixels."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.pixels = [[CLEAR for _ in range(width)] for _ in range(height)]

    def __repr__(self):
        return f"Layer({self.width}, {self.height})"


def layer(width, height):
    """Create a layer, fully transparent."""
    return Layer(width, height)


def paint_shape(lyr, cov, color):
    """Paint a colour into a layer through a coverage buffer, the way
    chapter 2 painted colour through coverage onto a canvas -- except a
    layer's transparent parts are genuinely transparent."""
    for y in range(min(lyr.height, cov.height)):
        for x in range(min(lyr.width, cov.width)):
            c = coverage_at(cov, x, y)
            if c > 0:
                src = from_color(color, c)
                lyr.pixels[y][x] = over(src, lyr.pixels[y][x])


def composite_layers(op, src, dst):
    """Composite two layers pixel by pixel with a Porter-Duff operator."""
    width = min(src.width, dst.width)
    height = min(src.height, dst.height)
    result = Layer(width, height)
    for y in range(height):
        for x in range(width):
            result.pixels[y][x] = composite(op, src.pixels[y][x], dst.pixels[y][x])
    return result


def flatten_layer(lyr, paper):
    """Flatten a layer over an opaque backing colour into a canvas."""
    c = Canvas(lyr.width, lyr.height)
    backing = opaque(paper)
    for y in range(lyr.height):
        for x in range(lyr.width):
            c.pixels[y][x] = pixel_color(over(lyr.pixels[y][x], backing))
    return c


# --- Chapter 9 renders ---

_PD_ORANGE = color(0.95, 0.55, 0.1)
_PD_BLUE = color(0.2, 0.5, 0.85)


def _pd_square_path():
    return polygon(point(10, 10), point(42, 10), point(42, 42), point(10, 42))


def _pd_circle_path():
    return circle_path(38, 38, 20, 48)


def porter_duff_table():
    """The twelve Porter-Duff operators applied to a blue square (dst)
    and an orange circle (src), each tile 64x64 in a 4x3 grid."""
    tile = 64
    ops = ["clear", "src", "dst", "src-over", "dst-over", "src-in",
           "dst-in", "src-out", "dst-out", "src-atop", "dst-atop", "xor"]

    dst = layer(tile, tile)
    paint_shape(dst, fill_path(_pd_square_path(), "nonzero", tile, tile), _PD_BLUE)
    src = layer(tile, tile)
    paint_shape(src, fill_path(_pd_circle_path(), "nonzero", tile, tile), _PD_ORANGE)

    grid = Canvas(tile * 4, tile * 3)
    fill(grid, PAPER)
    for i, op in enumerate(ops):
        flat = flatten_layer(composite_layers(op, src, dst), PAPER)
        col = i % 4
        row = i // 4
        for y in range(tile):
            for x in range(tile):
                grid.pixels[row * tile + y][col * tile + x] = flat.pixels[y][x]
    return grid


def plate_09():
    """Chapter 9's plate: the operator table, magnified by 2."""
    return magnify(porter_duff_table(), 2)


def blend_strip():
    """All sixteen blend modes: an orange circle blended over a blue
    square, each in its own 64x64 tile, four to a row. The square is a
    layer -- genuinely transparent outside it, not painted on paper --
    so a mode fades to plain source-over where the square doesn't reach,
    and only the finished blend is flattened onto paper."""
    tile = 64
    modes = ["normal", "multiply", "screen", "overlay",
             "darken", "lighten", "color-dodge", "color-burn",
             "hard-light", "soft-light", "difference", "exclusion",
             "hue", "saturation", "color", "luminosity"]

    square_cov = fill_path(_pd_square_path(), "nonzero", tile, tile)
    disc_cov = fill_path(_pd_circle_path(), "nonzero", tile, tile)

    dst_layer = layer(tile, tile)
    paint_shape(dst_layer, square_cov, _PD_BLUE)

    grid = Canvas(tile * 4, tile * 4)
    fill(grid, PAPER)
    for i, mode in enumerate(modes):
        col = i % 4
        row = i // 4
        result = layer(tile, tile)
        for y in range(tile):
            for x in range(tile):
                cv = coverage_at(disc_cov, x, y)
                src = from_color(_PD_ORANGE, cv)
                dst = dst_layer.pixels[y][x]
                result.pixels[y][x] = blend(mode, src, dst)
        flat = flatten_layer(result, PAPER)
        for y in range(tile):
            for x in range(tile):
                grid.pixels[row * tile + y][col * tile + x] = flat.pixels[y][x]
    return grid


def seam():
    """The conflation trap: two opaque triangles that should tile a solid
    square, each composited via over, leaking a seam along the diagonal
    they share. Rendered at quarter scale and magnified by 4, so the
    single-pixel-wide seam reads clearly in the plate."""
    base = Canvas(80, 80)
    fill(base, PAPER)
    orange = _PD_ORANGE
    t1 = polygon(point(4, 4), point(76, 4), point(76, 76))
    t2 = polygon(point(4, 4), point(76, 76), point(4, 76))
    paint_through(base, fill_path(t1, "nonzero", 80, 80), orange)
    cov2 = fill_path(t2, "nonzero", 80, 80)
    for y in range(80):
        for x in range(80):
            cv = coverage_at(cov2, x, y)
            if cv > 0:
                src = from_color(orange, cv)
                dst = opaque(pixel_at(base, x, y))
                base.pixels[y][x] = pixel_color(over(src, dst))
    return magnify(base, 4)


# ============================================================
# Chapter 10: Paint Servers and Gradients
# ============================================================

class Stop:
    """One colour stop: an offset in [0, 1] and a colour."""

    def __init__(self, offset, color):
        self.offset = offset
        self.color = color

    def __repr__(self):
        return f"Stop({self.offset}, {self.color})"


def stop(offset, color):
    """Create a colour stop."""
    return Stop(offset, color)


def sample_stops(stops, t):
    """The colour at parameter t: the first colour below the first stop,
    the last colour above the last stop, and a straight blend in linear
    light between the two stops that bracket t, found by binary search."""
    if stops[0].offset >= t:
        return stops[0].color
    if stops[-1].offset <= t:
        return stops[-1].color
    lo, hi = 0, len(stops) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if stops[mid].offset <= t:
            lo = mid
        else:
            hi = mid
    s0, s1 = stops[lo], stops[hi]
    frac = (t - s0.offset) / (s1.offset - s0.offset)
    return Color(
        s0.color.red + (s1.color.red - s0.color.red) * frac,
        s0.color.green + (s1.color.green - s0.color.green) * frac,
        s0.color.blue + (s1.color.blue - s0.color.blue) * frac,
    )


def extend(t, mode):
    """Fold a parameter that fell outside [0, 1] back in."""
    if mode == "pad":
        return clamp(t)
    if mode == "repeat":
        return t % 1.0
    if mode == "reflect":
        tt = t % 2.0
        return tt if tt <= 1.0 else 2.0 - tt
    raise ValueError(f"unknown extend mode: {mode}")


class LinearGradient:
    def __init__(self, p0, p1, stops, mode):
        self.p0 = p0
        self.p1 = p1
        self.stops = stops
        self.mode = mode


def linear_gradient(p0, p1, stops, mode):
    """A gradient whose axis runs from p0 to p1."""
    return LinearGradient(p0, p1, stops, mode)


def linear_t(g, x, y):
    """How far (x, y) projects onto the axis, as a fraction of its length."""
    dx = g.p1.x - g.p0.x
    dy = g.p1.y - g.p0.y
    len2 = dx * dx + dy * dy
    if len2 == 0:
        return 0.0
    px = x - g.p0.x
    py = y - g.p0.y
    return (px * dx + py * dy) / len2


class RadialGradient:
    def __init__(self, c0, r0, c1, r1, stops, mode):
        self.c0 = c0
        self.r0 = r0
        self.c1 = c1
        self.r1 = r1
        self.stops = stops
        self.mode = mode


def radial_gradient(c0, r0, c1, r1, stops, mode):
    """A gradient between a start circle (t = 0) and an end circle (t = 1)."""
    return RadialGradient(c0, r0, c1, r1, stops, mode)


def radial_t(g, x, y):
    """The t of the interpolated circle that passes through (x, y), or
    None if no circle in the family reaches it."""
    cdx = g.c1.x - g.c0.x
    cdy = g.c1.y - g.c0.y
    dr = g.r1 - g.r0
    pdx = x - g.c0.x
    pdy = y - g.c0.y
    a = cdx * cdx + cdy * cdy - dr * dr
    b = -2 * (pdx * cdx + pdy * cdy + g.r0 * dr)
    c = pdx * pdx + pdy * pdy - g.r0 * g.r0

    roots = []
    if abs(a) < 1e-9:
        if abs(b) > 1e-9:
            roots = [-c / b]
    else:
        disc = b * b - 4 * a * c
        if disc >= 0:
            sq = math.sqrt(disc)
            roots = [(-b + sq) / (2 * a), (-b - sq) / (2 * a)]

    best = None
    for t in roots:
        if g.r0 + t * dr >= 0:
            if best is None or t > best:
                best = t
    return best


class ConicGradient:
    def __init__(self, center, angle, stops, mode):
        self.center = center
        self.angle = angle
        self.stops = stops
        self.mode = mode


def conic_gradient(center, angle, stops, mode):
    """A gradient that sweeps the angle around a center, starting at angle."""
    return ConicGradient(center, angle, stops, mode)


def conic_t(g, x, y):
    """The angle from the center to (x, y), as a fraction of a full turn."""
    dx = x - g.center.x
    dy = y - g.center.y
    two_pi = 2 * math.pi
    theta = (math.atan2(dy, dx) - g.angle) % two_pi
    return theta / two_pi


class SolidPaint:
    """A paint that ignores the point and always returns its colour."""

    def __init__(self, color):
        self.color = color


def solid(color):
    """A solid paint: paint_at ignores the point."""
    return SolidPaint(color)


def paint_at(paint, x, y):
    """Sample a paint at a device point."""
    if isinstance(paint, SolidPaint):
        return paint.color
    if isinstance(paint, LinearGradient):
        t = extend(linear_t(paint, x, y), paint.mode)
        return sample_stops(paint.stops, t)
    if isinstance(paint, RadialGradient):
        t = radial_t(paint, x, y)
        if t is None:
            return paint.stops[-1].color
        t = extend(t, paint.mode)
        return sample_stops(paint.stops, t)
    if isinstance(paint, ConicGradient):
        t = extend(conic_t(paint, x, y), paint.mode)
        return sample_stops(paint.stops, t)
    if isinstance(paint, ImagePaint):
        src = paint.inv * point(x, y)
        sampler = _SAMPLERS[paint.filt]
        p = sampler(paint.img, src.x, src.y, paint.extend)
        return pixel_color(p)
    raise TypeError(f"unknown paint type: {paint!r}")


def paint_fill(canvas, cov, paint):
    """paint_through with the colour replaced by a function: for every
    covered pixel, sample paint_at at the pixel's centre and blend that
    colour in through the coverage, in linear light."""
    for y in range(min(canvas.height, cov.height)):
        for x in range(min(canvas.width, cov.width)):
            cv = coverage_at(cov, x, y)
            if cv > 0:
                col = paint_at(paint, x + 0.5, y + 0.5)
                current = pixel_at(canvas, x, y)
                painted = mix(current, col, cv, True)
                write_pixel(canvas, x, y, painted)


def _full_coverage(width, height):
    cov = CoverageBuffer(width, height)
    for y in range(height):
        for x in range(width):
            cov.coverage[y][x] = 1.0
    return cov


# --- Chapter 10 renders ---

_SUNSET_STOPS = [
    stop(0.0, color(0.05, 0.02, 0.15)),
    stop(0.35, color(0.75, 0.15, 0.25)),
    stop(0.7, color(0.98, 0.6, 0.15)),
    stop(1.0, color(1.0, 0.95, 0.75)),
]


def three_gradients():
    """One stop table -- a sunset, dark to pale -- addressed three ways:
    a linear ramp, a focal radial, and a conic sweep, side by side."""
    stops = _SUNSET_STOPS
    lin = linear_gradient(point(10, 10), point(140, 140), stops, "pad")
    rad = radial_gradient(point(55, 55), 0, point(75, 75), 85, stops, "pad")
    con = conic_gradient(point(75, 75), -math.pi / 2, stops, "pad")

    panel_size = 150
    gap = 4
    width = panel_size * 3 + gap * 2
    row = Canvas(width, panel_size)
    fill(row, PAPER)
    cov = _full_coverage(panel_size, panel_size)
    for i, paint in enumerate([lin, rad, con]):
        panel = Canvas(panel_size, panel_size)
        paint_fill(panel, cov, paint)
        x0 = i * (panel_size + gap)
        for y in range(panel_size):
            for x in range(panel_size):
                row.pixels[y][x0 + x] = panel.pixels[y][x]
    return row


def plate_10():
    """Chapter 10's plate: the three gradients, side by side."""
    return three_gradients()


_EXTEND_STOPS = [
    stop(0.0, color(0.1, 0.15, 0.5)),
    stop(1.0, color(1.0, 0.7, 0.1)),
]


def extend_strip():
    """One short gradient under the three extend modes: pad holds the
    ends, repeat tiles, reflect mirrors."""
    base_w, base_h = 180, 90
    band_h = 30
    p0 = point(60, 0)
    p1 = point(100, 0)
    modes = ["pad", "repeat", "reflect"]

    base = Canvas(base_w, base_h)
    cov = _full_coverage(base_w, band_h)
    for i, mode in enumerate(modes):
        g = linear_gradient(p0, p1, _EXTEND_STOPS, mode)
        panel = Canvas(base_w, band_h)
        paint_fill(panel, cov, g)
        for y in range(band_h):
            for x in range(base_w):
                base.pixels[i * band_h + y][x] = panel.pixels[y][x]
    return magnify(base, 2)


# --- Ordered dithering ---

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def dither_threshold(x, y):
    """The Bayer-matrix nudge for this pixel position, in [0, 1)."""
    return BAYER4[y % 4][x % 4] / 16.0


def to_byte(light):
    """Plain eight-bit encoding: clamp, encode, scale, round."""
    return color_to_byte(light)


def to_byte_dithered(light, x, y):
    """Ordered dithering: nudge by the position's threshold before the
    floor, so a value that sits between two bytes splits across both."""
    clamped = clamp(light)
    encoded = encode(clamped)
    scaled = encoded * 255
    value = math.floor(scaled + dither_threshold(x, y))
    return max(0, min(255, value))


def canvas_to_p6_dithered(canvas):
    """Like canvas_to_p6, but each byte is ordered-dithered instead of
    plainly rounded."""
    header = f"P6\n{canvas.width} {canvas.height}\n255\n"
    header_bytes = header.encode('ascii')
    pixel_data = bytearray()
    for y in range(canvas.height):
        for x in range(canvas.width):
            c = canvas.pixels[y][x]
            pixel_data.append(to_byte_dithered(c.red, x, y))
            pixel_data.append(to_byte_dithered(c.green, x, y))
            pixel_data.append(to_byte_dithered(c.blue, x, y))
    return header_bytes + pixel_data


# ============================================================================
# Chapter 11: Images and Resampling
# ============================================================================

class Image:
    """A grid of premultiplied linear-light pixels."""

    def __init__(self, width, height, pixels):
        self.width = width
        self.height = height
        self.pixels = pixels  # flat list, row-major: pixels[y * width + x]

    def __repr__(self):
        return f"Image({self.width}, {self.height})"


def image(width, height, pixels):
    """Create an image from a flat, row-major list of premultiplied pixels."""
    return Image(width, height, list(pixels))


def read_image(ppm_data):
    """Read a PPM (P6) back into an image: decode each byte from sRGB to
    linear light and store an opaque premultiplied pixel."""
    if isinstance(ppm_data, str):
        ppm_bytes = ppm_data.encode('latin-1')
    else:
        ppm_bytes = ppm_data

    # Find the end of the header (3 newlines: after P6, dimensions, and 255)
    count = 0
    pos = 0
    while count < 3 and pos < len(ppm_bytes):
        if ppm_bytes[pos:pos + 1] == b'\n':
            count += 1
        pos += 1

    header_str = ppm_bytes[:pos].decode('ascii')
    lines = header_str.split('\n')
    width, height = (int(v) for v in lines[1].split())

    pixel_bytes = ppm_bytes[pos:]
    pixels = []
    for i in range(width * height):
        r = decode(pixel_bytes[i * 3] / 255.0)
        g = decode(pixel_bytes[i * 3 + 1] / 255.0)
        b = decode(pixel_bytes[i * 3 + 2] / 255.0)
        pixels.append(opaque(Color(r, g, b)))
    return Image(width, height, pixels)


def _wrap_index(i, n, extend):
    """Fold an out-of-range texel index back in for the given extend mode."""
    if 0 <= i < n:
        return i
    if extend == "clamp":
        return 0 if i < 0 else n - 1
    if extend == "repeat":
        return i % n
    # "reflect": bounce off both ends without a seam
    p = 2 * n
    i = i % p
    return i if i < n else p - 1 - i


def image_texel(img, ix, iy, extend="clamp"):
    """The pixel at an integer texel, with an out-of-range index folded
    back in by the extend mode."""
    x = _wrap_index(ix, img.width, extend)
    y = _wrap_index(iy, img.height, extend)
    return img.pixels[y * img.width + x]


def sample_nearest(img, sx, sy, extend="clamp"):
    """The texel the point falls in -- blocky, but honest."""
    return image_texel(img, math.floor(sx), math.floor(sy), extend)


def sample_bilinear(img, sx, sy, extend="clamp"):
    """Blend the four texels around the point by distance. Works in
    texel-centre space: the source coordinate minus 0.5, so integer
    values land on texel centres and the fractional part is the blend."""
    gx, gy = sx - 0.5, sy - 0.5
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0
    top = lerp_pixel(image_texel(img, x0, y0, extend), image_texel(img, x0 + 1, y0, extend), fx)
    bot = lerp_pixel(image_texel(img, x0, y0 + 1, extend), image_texel(img, x0 + 1, y0 + 1, extend), fx)
    return lerp_pixel(top, bot, fy)


def catmull(t):
    """The four Catmull-Rom weights for a fractional offset t, summing
    to one and passing through the samples at t = 0 and t = 1."""
    t2 = t * t
    t3 = t2 * t
    return [
        -0.5 * t3 + t2 - 0.5 * t,
        1.5 * t3 - 2.5 * t2 + 1,
        -1.5 * t3 + 2 * t2 + 0.5 * t,
        0.5 * t3 - 0.5 * t2,
    ]


def sample_bicubic(img, sx, sy, extend="clamp"):
    """Fit a curve through sixteen texels with Catmull-Rom weights,
    again in texel-centre space."""
    gx, gy = sx - 0.5, sy - 0.5
    x0, y0 = math.floor(gx), math.floor(gy)
    wx = catmull(gx - x0)
    wy = catmull(gy - y0)
    r = g = b = a = 0.0
    for j in range(4):
        for i in range(4):
            p = image_texel(img, x0 - 1 + i, y0 - 1 + j, extend)
            w = wx[i] * wy[j]
            r += w * p.r
            g += w * p.g
            b += w * p.b
            a += w * p.a
    return Pixel(r, g, b, a)


_SAMPLERS = {
    "nearest": sample_nearest,
    "bilinear": sample_bilinear,
    "bicubic": sample_bicubic,
}


class ImagePaint:
    """A paint that samples an image, placed on the canvas by a matrix."""

    def __init__(self, img, m, filt, extend):
        self.img = img
        self.inv = inverse(m)
        self.filt = filt
        self.extend = extend


def image_paint(img, m, filt, extend):
    """A paint that, at a device point, walks backward through the
    inverse of m to find where in the image to sample."""
    return ImagePaint(img, m, filt, extend)


def downsample(img):
    """Halve an image, each new texel the box-average of the 2x2 block
    above it, premultiplied channels alike."""
    new_w = max(1, img.width // 2)
    new_h = max(1, img.height // 2)
    pixels = []
    for y in range(new_h):
        for x in range(new_w):
            p00 = image_texel(img, 2 * x, 2 * y, "clamp")
            p10 = image_texel(img, 2 * x + 1, 2 * y, "clamp")
            p01 = image_texel(img, 2 * x, 2 * y + 1, "clamp")
            p11 = image_texel(img, 2 * x + 1, 2 * y + 1, "clamp")
            pixels.append(Pixel(
                (p00.r + p10.r + p01.r + p11.r) / 4,
                (p00.g + p10.g + p01.g + p11.g) / 4,
                (p00.b + p10.b + p01.b + p11.b) / 4,
                (p00.a + p10.a + p01.a + p11.a) / 4,
            ))
    return Image(new_w, new_h, pixels)


def mip_chain(img):
    """The whole mip pyramid: the image, then halved repeatedly down to
    a single pixel."""
    chain = [img]
    cur = img
    while not (cur.width == 1 and cur.height == 1):
        cur = downsample(cur)
        chain.append(cur)
    return chain


def mip_level_for(scale):
    """The mip level whose texels are about the size of an output
    pixel, from a minification scale factor (1.0 is no minification)."""
    if scale <= 0:
        return 0
    level = math.floor(math.log2(1.0 / scale) + 1e-9)
    return max(0, level)


# --- Chapter 11 renders ---

def sprite():
    """An 8x8 sprite, built as a canvas and round-tripped through a PPM."""
    orange = color(0.95, 0.55, 0.1)
    blue = color(0.15, 0.45, 0.85)
    white = color(0.95, 0.93, 0.85)
    black = color(0.06, 0.06, 0.08)
    grid = [
        black, black, blue, blue, blue, blue, black, black,
        black, blue, blue, blue, blue, blue, blue, black,
        blue, blue, white, blue, blue, white, blue, blue,
        blue, blue, white, blue, blue, white, blue, blue,
        blue, blue, blue, blue, blue, blue, blue, blue,
        orange, blue, blue, orange, orange, blue, blue, orange,
        black, orange, orange, blue, blue, orange, orange, black,
        black, black, orange, orange, orange, orange, black, black,
    ]
    c = canvas(8, 8)
    for iy in range(8):
        for ix in range(8):
            write_pixel(c, ix, iy, grid[iy * 8 + ix])
    return read_image(canvas_to_p6(c))


def _paint_canvas(width, height, paint):
    """Render a paint over a whole canvas, one sample per pixel centre."""
    c = Canvas(width, height)
    for y in range(height):
        for x in range(width):
            c.pixels[y][x] = paint_at(paint, x + 0.5, y + 0.5)
    return c


def two_filters():
    """The 8x8 sprite, magnified 20x: nearest on the left, bilinear on
    the right."""
    s = sprite()
    left = _paint_canvas(s.width * 20, s.height * 20, image_paint(s, scaling(20, 20), "nearest", "clamp"))
    right = _paint_canvas(s.width * 20, s.height * 20, image_paint(s, scaling(20, 20), "bilinear", "clamp"))
    return side_by_side(left, right)


def plate_11():
    """Chapter 11's plate: two filters, magnified."""
    return two_filters()


def three_filters():
    """The 8x8 sprite, magnified 16x, under all three filters."""
    s = sprite()
    a = _paint_canvas(s.width * 16, s.height * 16, image_paint(s, scaling(16, 16), "nearest", "clamp"))
    b = _paint_canvas(s.width * 16, s.height * 16, image_paint(s, scaling(16, 16), "bilinear", "clamp"))
    c = _paint_canvas(s.width * 16, s.height * 16, image_paint(s, scaling(16, 16), "bicubic", "clamp"))
    return side_by_side(side_by_side(a, b), c)


# ============================================================================
# Chapter 12: Clipping, Masks and Groups
# ============================================================================

def multiply_coverage(a, b):
    """Clip one coverage buffer by another, cell by cell."""
    width = min(a.width, b.width)
    height = min(a.height, b.height)
    result = CoverageBuffer(width, height)
    for y in range(height):
        for x in range(width):
            result.coverage[y][x] = coverage_at(a, x, y) * coverage_at(b, x, y)
    return result


def full_clip(width, height):
    """A clip that's coverage 1 everywhere -- clipping to it is a no-op."""
    return _full_coverage(width, height)


def clip_path(p, rule, width, height):
    """A clip is only a fill: there was never a difference between a
    clip and a shape."""
    return fill_path(p, rule, width, height)


def clip_rect(x0, y0, x1, y1, width, height):
    """A rectangular clip, as a fill of a rectangle path."""
    rect = polygon(point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1))
    return clip_path(rect, "nonzero", width, height)


def soft_mask(cx, cy, r, width, height):
    """A radial falloff: coverage 1 at (cx, cy), fading linearly to 0
    at radius r."""
    cov = CoverageBuffer(width, height)
    for y in range(height):
        for x in range(width):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy
            d = math.sqrt(dx * dx + dy * dy)
            cov.coverage[y][x] = clamp(1 - d / r)
    return cov


def set_layer_pixel(lyr, x, y, p):
    """Write a premultiplied pixel to a layer. Out-of-bounds writes are
    ignored, the same rule as write_pixel."""
    if 0 <= x < lyr.width and 0 <= y < lyr.height:
        lyr.pixels[y][x] = p


def layer_pixel(lyr, x, y):
    """Read a premultiplied pixel from a layer."""
    if 0 <= x < lyr.width and 0 <= y < lyr.height:
        return lyr.pixels[y][x]
    return CLEAR


def push_group(width, height):
    """Start a fresh, fully transparent offscreen layer."""
    return layer(width, height)


def paint_into(lyr, cov, color, opacity=1.0):
    """Paint a colour into a layer through a coverage buffer, scaled by
    an overall opacity, and return the layer."""
    for y in range(min(lyr.height, cov.height)):
        for x in range(min(lyr.width, cov.width)):
            c = coverage_at(cov, x, y) * opacity
            if c > 0:
                src = from_color(color, c)
                lyr.pixels[y][x] = over(src, lyr.pixels[y][x])
    return lyr


def scale_opacity(lyr, opacity):
    """Scale every premultiplied channel of a layer by opacity,
    returning a new layer."""
    result = Layer(lyr.width, lyr.height)
    for y in range(lyr.height):
        for x in range(lyr.width):
            p = lyr.pixels[y][x]
            result.pixels[y][x] = Pixel(p.r * opacity, p.g * opacity, p.b * opacity, p.a * opacity)
    return result


def pop_group_with_opacity(group, base, opacity):
    """Flatten a group at an opacity and composite it over a base layer,
    once -- the group resolves its own overlaps before the opacity is
    applied, unlike fading each child on its own."""
    faded = scale_opacity(group, opacity)
    return composite_layers("src-over", faded, base)


# --- Chapter 12 renders ---

_GROUP_PAPER = color(0.02, 0.02, 0.025)
_GROUP_INKS = [color(0.95, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
_GROUP_SIZE = 150


def _three_circles():
    """Three overlapping circles and their inks, for the opacity plate."""
    centers = [(60, 62), (90, 62), (75, 92)]
    return [(circle_path(cx, cy, 34, 64), ink) for (cx, cy), ink in zip(centers, _GROUP_INKS)]


def per_child():
    """Left panel: each circle painted at 50% opacity in turn, so the
    overlaps composite twice and darken."""
    base = layer(_GROUP_SIZE, _GROUP_SIZE)
    for y in range(_GROUP_SIZE):
        for x in range(_GROUP_SIZE):
            base.pixels[y][x] = opaque(_GROUP_PAPER)
    for shape, colour in _three_circles():
        cov = fill_path(shape, "nonzero", _GROUP_SIZE, _GROUP_SIZE)
        base = paint_into(base, cov, colour, 0.5)
    return base


def group_opacity():
    """Right panel: the three circles drawn opaque into a group, the
    whole group composited at 50% once."""
    base = layer(_GROUP_SIZE, _GROUP_SIZE)
    for y in range(_GROUP_SIZE):
        for x in range(_GROUP_SIZE):
            base.pixels[y][x] = opaque(_GROUP_PAPER)
    group = push_group(_GROUP_SIZE, _GROUP_SIZE)
    for shape, colour in _three_circles():
        cov = fill_path(shape, "nonzero", _GROUP_SIZE, _GROUP_SIZE)
        group = paint_into(group, cov, colour, 1.0)
    return pop_group_with_opacity(group, base, 0.5)


def _layer_to_canvas(lyr):
    """A fully opaque layer, read straight into a canvas (no flattening
    needed -- every pixel is already alpha 1)."""
    c = Canvas(lyr.width, lyr.height)
    for y in range(lyr.height):
        for x in range(lyr.width):
            c.pixels[y][x] = pixel_color(lyr.pixels[y][x])
    return c


def opacity_plate():
    """Three overlapping circles, two ways: per-child opacity on the
    left, group opacity on the right."""
    return side_by_side(_layer_to_canvas(per_child()), _layer_to_canvas(group_opacity()))


def plate_12():
    """Chapter 12's plate: the opacity plate, magnified by 2."""
    return magnify(opacity_plate(), 2)


def clip_demo():
    """A star clipped to a circle on the left, and to a soft radial
    mask on the right -- the same shape, a hard edge against a soft one."""
    size = _GROUP_SIZE
    ink = color(0.95, 0.55, 0.1)
    cx, cy = size / 2, size / 2
    star_r, clip_r, mask_r = 60, 45, 70

    star_shape = transform_path(unit_star(), translation(cx, cy) * scaling(star_r, star_r))
    star_cov = fill_path(star_shape, "nonzero", size, size)

    hard = multiply_coverage(star_cov, clip_path(circle_path(cx, cy, clip_r, 64), "nonzero", size, size))
    soft = multiply_coverage(star_cov, soft_mask(cx, cy, mask_r, size, size))

    left = Canvas(size, size)
    fill(left, _GROUP_PAPER)
    paint_through(left, hard, ink)
    right = Canvas(size, size)
    fill(right, _GROUP_PAPER)
    paint_through(right, soft, ink)
    return side_by_side(left, right)


# --- Chapter 13: stroking is filling ---

def _perp(v):
    """The perpendicular of a vector, rotated 90 degrees."""
    return vector(-v.y, v.x)


def _add_scaled(p, v, s):
    """A point offset from p by vector v scaled by s."""
    return point(p.x + v.x * s, p.y + v.y * s)


def _seg_intersect(p1, d1, p2, d2):
    """Where the line through p1 in direction d1 crosses the line through
    p2 in direction d2, or None when the directions are parallel."""
    den = cross(d1, d2)
    if abs(den) < 1e-12:
        return None
    t = cross(p2 - p1, d2) / den
    return _add_scaled(p1, d1, t)


def _arc_points(c, a0, a1, r, steps):
    """Sample points along an arc of radius r centred at c, from angle a0
    to a1 inclusive of both ends."""
    pts = []
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        pts.append(point(c.x + r * math.cos(a), c.y + r * math.sin(a)))
    return pts


def _arc_steps(a0, a1):
    """How many segments to sample an arc's sweep into: roughly one every
    1/16 of a turn, never fewer than two."""
    return max(2, math.ceil(abs(a1 - a0) / (math.pi / 16)))


def _dedupe_points(points):
    """Drop consecutive duplicate points -- the fix that keeps a doubled
    point from becoming a zero-length, direction-less segment."""
    if not points:
        return []
    out = [points[0]]
    for pt in points[1:]:
        if magnitude(pt - out[-1]) > 1e-9:
            out.append(pt)
    return out


def miter_length(d_in, d_out, h):
    """The distance from a vertex to a miter's tip: h / sin(theta / 2),
    where theta is the turn's interior angle -- the angle between the
    incoming direction reversed and the outgoing direction."""
    d_in = normalize(d_in)
    d_out = normalize(d_out)
    cos_theta = max(-1.0, min(1.0, -dot(d_in, d_out)))
    sin_half = math.sqrt(max(0.0, (1.0 - cos_theta) / 2.0))
    return h / sin_half


def _seg_rect(a, b, h):
    """The rectangle of half-width h centred on segment a..b."""
    d = normalize(b - a)
    n = _perp(d)
    return [_add_scaled(a, n, h), _add_scaled(b, n, h),
            _add_scaled(b, n, -h), _add_scaled(a, n, -h)]


def _join_shape(v, d_in, d_out, h, join, miter_limit):
    """The wedge that fills the outer gap at an interior vertex, or None
    when the path doesn't actually turn there."""
    turn = cross(d_in, d_out)
    if abs(turn) < 1e-12:
        return None
    s = -1 if turn > 0 else 1
    n_in = _perp(d_in) * s
    n_out = _perp(d_out) * s
    a = _add_scaled(v, n_in, h)
    b = _add_scaled(v, n_out, h)

    if join == "bevel":
        return [v, a, b]

    if join == "round":
        a0 = math.atan2(a.y - v.y, a.x - v.x)
        a1 = math.atan2(b.y - v.y, b.x - v.x)
        # Sweep the short way round -- the long way is the inside of the
        # turn and leaves a notch where the gap should have been filled.
        diff = ((a1 - a0 + math.pi) % (2 * math.pi)) - math.pi
        a1 = a0 + diff
        return [v] + _arc_points(v, a0, a1, h, _arc_steps(a0, a1))

    # miter, falling back to bevel past the limit
    m = _seg_intersect(a, d_in, b, d_out)
    if m is not None and magnitude(m - v) <= miter_limit * h:
        return [v, a, m, b]
    return [v, a, b]


def _cap_shape(p, d_out, h, cap):
    """The shape that closes an open end, or None for a butt cap."""
    n = _perp(d_out)
    if cap == "butt":
        return None
    if cap == "square":
        l = _add_scaled(p, n, h)
        r = _add_scaled(p, n, -h)
        return [l, _add_scaled(l, d_out, h), _add_scaled(r, d_out, h), r]
    # round
    a0 = math.atan2(n.y, n.x)
    outw = math.atan2(d_out.y, d_out.x)
    d = ((outw - a0) % (2 * math.pi) + 2 * math.pi) % (2 * math.pi)
    if d > math.pi:
        d -= 2 * math.pi
    a1 = a0 + (math.pi if d > 0 else -math.pi)
    return _arc_points(p, a0, a1, h, _arc_steps(a0, a1))


def _dot_points(c, h, cap):
    """A single-point subpath's stand-in shape: a disc for a round cap, a
    square for a square cap, nothing (None) for a butt cap."""
    if cap == "round":
        return _arc_points(c, 0, 2 * math.pi, h, 48)
    if cap == "square":
        return [point(c.x - h, c.y - h), point(c.x + h, c.y - h),
                point(c.x + h, c.y + h), point(c.x - h, c.y + h)]
    return None


def _signed_polygon_area(points):
    """The shoelace formula over a closed polygon's points -- the same sign
    convention as polygon_area, computed directly on a bare point list."""
    total = 0.0
    n = len(points)
    for i in range(n):
        a, b = points[i], points[(i + 1) % n]
        total += a.x * b.y - b.x * a.y
    return total / 2.0


def _emit(out, piece):
    """Append a piece to the output path, oriented counterclockwise on
    screen (negative polygon_area) so every piece winds the same way and
    overlaps add under nonzero fill instead of cancelling."""
    if piece is None:
        return
    if _signed_polygon_area(piece) > 0:
        piece = list(reversed(piece))
    out.subpaths.append(Subpath(piece, True))


def stroke_to_path(p, width, cap, join, miter_limit):
    """Turn a stroked path into a fillable outline: one rectangle per
    segment, one join wedge per interior vertex, one cap shape per open
    end, all as subpaths of one path. Fill it nonzero; that's the stroke."""
    h = width / 2.0
    out = path()
    for sp in subpaths(p):
        pts = _dedupe_points(sp.points)
        if not pts:
            continue
        # A closed subpath whose points already end where they began (an
        # explicit line_to back to the start, then close) would otherwise
        # produce a zero-length closing segment once wrapped around --
        # drop the repeated point before treating it as closed.
        if sp.closed and len(pts) > 1 and magnitude(pts[-1] - pts[0]) <= 1e-9:
            pts = pts[:-1]
        if not pts:
            continue
        if len(pts) == 1:
            dot = _dot_points(pts[0], h, cap)
            _emit(out, dot)
            continue

        segs = [(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
        if sp.closed:
            segs.append((pts[-1], pts[0]))

        for a, b in segs:
            _emit(out, _seg_rect(a, b, h))

        dirs = [normalize(b - a) for a, b in segs]
        n_joins = len(segs) if sp.closed else len(segs) - 1
        for k in range(n_joins):
            v = segs[(k + 1) % len(segs)][0]
            j = _join_shape(v, dirs[k], dirs[(k + 1) % len(dirs)], h, join, miter_limit)
            _emit(out, j)

        if not sp.closed:
            start_dir = vector(-dirs[0].x, -dirs[0].y)
            _emit(out, _cap_shape(pts[0], start_dir, h, cap))
            _emit(out, _cap_shape(pts[-1], dirs[-1], h, cap))
    return out


def chevron():
    """A three-point open path, a wide V, used to show off each join
    style on the same corner."""
    p = path()
    move_to(p, point(30, 40))
    line_to(p, point(80, 120))
    line_to(p, point(130, 40))
    return p


def u_turn():
    """Nine points on the upper half of a circle of radius 10 about
    (50, 50), from 180 degrees to 360 degrees in steps of 22.5 degrees --
    a tight bend whose 40-wide stroke overlaps itself all the way round."""
    p = path()
    cx, cy, radius = 50.0, 50.0, 10.0
    for k in range(9):
        angle = math.radians(180 + 22.5 * k)
        pt = point(cx + radius * math.cos(angle), cy + radius * math.sin(angle))
        if k == 0:
            move_to(p, pt)
        else:
            line_to(p, pt)
    return p


# --- Chapter 13 renders ---

_STROKE_GRAY = color(0.62, 0.62, 0.66)
_STROKE_MAG = color(0.85, 0.2, 0.55)
_STROKE_SIZE = 160


def _stroke_render_panel(stroke_path, width_px, height_px, stroke_width, cap, join, miter_limit):
    """Fill a stroked path in gray and draw its generated outline in
    magenta over it, integer endpoints and all -- one panel of the plate."""
    c = canvas(width_px, height_px)
    fill(c, PAPER)
    outline = stroke_to_path(stroke_path, stroke_width, cap, join, miter_limit)
    cov = fill_path(outline, "nonzero", width_px, height_px)
    paint_through(c, cov, _STROKE_GRAY)
    for e in edges(outline):
        line_wu(c, round_half_up(e.a.x), round_half_up(e.a.y),
                round_half_up(e.b.x), round_half_up(e.b.y), _STROKE_MAG)
    return c


def _side_by_side_n(canvases):
    """Lay out any number of same-height canvases left to right."""
    total_w = sum(cv.width for cv in canvases)
    h = canvases[0].height
    result = Canvas(total_w, h)
    x_off = 0
    for cv in canvases:
        for y in range(h):
            for x in range(cv.width):
                write_pixel(result, x_off + x, y, pixel_at(cv, x, y))
        x_off += cv.width
    return result


def joins_plate():
    """A chevron stroked three ways -- miter, round, bevel -- each the
    generated outline in magenta over a gray fill of it."""
    panels = [
        _stroke_render_panel(chevron(), _STROKE_SIZE, _STROKE_SIZE, 26, "butt", join, 4.0)
        for join in ("miter", "round", "bevel")
    ]
    return _side_by_side_n(panels)


def plate_13():
    """Chapter 13's plate: the three joins, magnified by 2."""
    return magnify(joins_plate(), 2)


def _cap_segment():
    """The one horizontal segment the caps demo strokes three ways."""
    p = path()
    move_to(p, point(45, 40))
    line_to(p, point(115, 40))
    return p


def caps_demo():
    """One horizontal segment stroked with butt, round and square caps."""
    panels = [
        _stroke_render_panel(_cap_segment(), _STROKE_SIZE, 80, 30, cap, "miter", 4.0)
        for cap in ("butt", "round", "square")
    ]
    return _side_by_side_n(panels)


# --- Chapter 14: Offsetting Curves ---

def tangent_at(c, t):
    """The unit tangent at parameter t. Where the derivative vanishes (a
    handle sitting on its anchor), the direction is taken a hair further
    into the curve instead: t + 0.0001 at the start, t - 0.0001 at the
    end."""
    d = derivative(c, t)
    if magnitude(d) < 1e-9:
        t2 = t + 0.0001 if t < 1.0 else t - 0.0001
        d = derivative(c, t2)
    return normalize(d)


def normal_at(c, t):
    """The tangent turned a quarter turn toward +y -- on the y-down
    canvas, the right-hand side of travel, the same +h side chapter 13's
    rectangles used."""
    return _perp(tangent_at(c, t))


def offset_point(c, t, d):
    """The point at distance d along the normal at parameter t. Positive
    d is the right of travel, negative the left."""
    p = point_at(c, t)
    n = normal_at(c, t)
    return _add_scaled(p, n, d)


def second_derivative(c, t):
    """The curve's second derivative: a constant for a quadratic, a
    straight-line blend of the two second differences for a cubic."""
    pts = c.points
    if len(pts) == 3:
        p0, p1, p2 = pts
        return vector(2 * (p0.x - 2 * p1.x + p2.x), 2 * (p0.y - 2 * p1.y + p2.y))
    p0, p1, p2, p3 = pts
    ax, ay = p0.x - 2 * p1.x + p2.x, p0.y - 2 * p1.y + p2.y
    bx, by = p1.x - 2 * p2.x + p3.x, p1.y - 2 * p2.y + p3.y
    return vector(6 * ((1 - t) * ax + t * bx), 6 * ((1 - t) * ay + t * by))


def curvature(c, t):
    """Signed curvature, cross(v, a) / |v|^3: positive where the curve
    turns clockwise on screen, the same side positive d points to. Uses
    the same live-tangent nudge as tangent_at where the derivative
    vanishes."""
    if magnitude(derivative(c, t)) < 1e-9:
        t = t + 0.0001 if t < 1.0 else t - 0.0001
    v = derivative(c, t)
    a = second_derivative(c, t)
    s = magnitude(v)
    return cross(v, a) / (s ** 3)


def cusps(c, d):
    """The parameters where 1 - curvature(c, t) * d changes sign: 64
    evenly spaced samples, bisected 40 times between any pair that
    disagree."""
    n = 64

    def f(t):
        return 1 - curvature(c, t) * d

    out = []
    prev_t, prev_f = 0.0, f(0.0)
    for i in range(1, n + 1):
        t, fv = i / n, f(i / n)
        if (prev_f < 0) != (fv < 0):
            lo, hi, flo = prev_t, t, prev_f
            for _ in range(40):
                mid = (lo + hi) / 2
                fm = f(mid)
                if (fm < 0) == (flo < 0):
                    lo, flo = mid, fm
                else:
                    hi = mid
            out.append((lo + hi) / 2)
        prev_t, prev_f = t, fv
    return out


def fit_offset(c, d):
    """One cubic through the two offset endpoints with the curve's own
    end tangents, its handle lengths solved so it passes through the
    offset point at t = 0.5 when its own t is 0.5."""
    p0 = offset_point(c, 0, d)
    p3 = offset_point(c, 1, d)
    t0 = tangent_at(c, 0)
    t1 = tangent_at(c, 1)
    m = offset_point(c, 0.5, d)
    r = vector((8 * m.x - 4 * p0.x - 4 * p3.x) / 3.0,
               (8 * m.y - 4 * p0.y - 4 * p3.y) / 3.0)
    den = cross(t0, t1)
    if abs(den) < 1e-9:
        a = b = magnitude(p3 - p0) / 3.0
    else:
        a = cross(r, t1) / den
        b = cross(r, t0) / den
    return cubic(p0, _add_scaled(p0, t0, a), _add_scaled(p3, t1, -b), p3)


def offset_error(c, d, fitted):
    """The largest miss between the fitted cubic and the true offset, at
    17 matched parameters t = i / 16."""
    worst = 0.0
    for i in range(17):
        t = i / 16.0
        worst = max(worst, magnitude(point_at(fitted, t) - offset_point(c, t, d)))
    return worst


def distance_to_curve(c, p):
    """The honest distance from a point to a curve: the nearest of 65
    samples at t = i / 64, refined by 32 rounds of ternary search between
    that sample's two neighbours."""
    n = 64
    ts = [i / n for i in range(n + 1)]

    def d(t):
        return magnitude(point_at(c, t) - p)

    best_i = min(range(n + 1), key=lambda i: d(ts[i]))
    lo = ts[max(0, best_i - 1)]
    hi = ts[min(n, best_i + 1)]
    for _ in range(32):
        m1 = lo + (hi - lo) / 3.0
        m2 = hi - (hi - lo) / 3.0
        if d(m1) < d(m2):
            hi = m2
        else:
            lo = m1
    return min(d(lo), d((lo + hi) / 2.0), d(hi))


def sub_curve(c, t0, t1):
    """The piece of a curve between two parameters, by splitting twice."""
    right = split_at(c, t0)[1] if t0 > 0 else c
    if t1 < 1:
        tt = (t1 - t0) / (1 - t0) if t0 < 1 else 1.0
        return split_at(right, tt)[0]
    return right


def _offset_into(c, d, tolerance, pieces, depth):
    fitted = fit_offset(c, d)
    if offset_error(c, d, fitted) <= tolerance or depth >= 16:
        pieces.append(fitted)
    else:
        left, right = split_at(c, 0.5)
        _offset_into(left, d, tolerance, pieces, depth + 1)
        _offset_into(right, d, tolerance, pieces, depth + 1)


def offset_curve(c, d, tolerance):
    """The offset as a list of cubics in order: the curve is split at its
    cusps, and each piece is fitted, halved and fitted again until
    offset_error is within tolerance, at most sixteen halvings deep."""
    ts = [0.0]
    for t in cusps(c, d):
        if t - ts[-1] > 1e-9 and 1 - t > 1e-9:
            ts.append(t)
    ts.append(1.0)
    pieces = []
    for i in range(len(ts) - 1):
        _offset_into(sub_curve(c, ts[i], ts[i + 1]), d, tolerance, pieces, 0)
    return pieces


def offset_distance_error(c, d, tolerance):
    """The honest check: how far 100 points spread along the offset
    curve stray from distance |d| to the original curve."""
    pieces = offset_curve(c, d, tolerance)
    n = 100
    worst = 0.0
    for i in range(n):
        u = i / (n - 1) * len(pieces)
        idx = min(int(u), len(pieces) - 1)
        local_t = u - idx
        p = point_at(pieces[idx], local_t)
        worst = max(worst, abs(distance_to_curve(c, p) - abs(d)))
    return worst


def offset_path(c, d, tolerance):
    """The offset curve, flattened and stitched into one polyline (a
    list of points) with no duplicate joints between pieces."""
    pts = []
    for piece in offset_curve(c, d, tolerance):
        f = flatten(piece, tolerance)
        if pts and magnitude(pts[-1] - f[0]) < 1e-9:
            f = f[1:]
        pts.extend(f)
    return pts


def stroke_curve_to_path(c, width, cap, tolerance):
    """The stroke of a curve as one closed subpath: the offset at +h
    flattened forward, the end cap's points, the offset at -h flattened
    backward, the start cap's points, with consecutive duplicates
    dropped. Fill it nonzero."""
    h = width / 2.0
    pts = []
    for piece in offset_curve(c, h, tolerance):
        pts.extend(flatten(piece, tolerance))
    end_cap = _cap_shape(point_at(c, 1), tangent_at(c, 1), h, cap)
    if end_cap is not None:
        pts.extend(end_cap)
    for piece in reversed(offset_curve(c, -h, tolerance)):
        pts.extend(list(reversed(flatten(piece, tolerance))))
    t0 = tangent_at(c, 0)
    start_cap = _cap_shape(point_at(c, 0), vector(-t0.x, -t0.y), h, cap)
    if start_cap is not None:
        pts.extend(start_cap)
    pts = _dedupe_points(pts)
    if len(pts) > 1 and magnitude(pts[-1] - pts[0]) < 1e-9:
        pts = pts[:-1]
    out = path()
    out.subpaths.append(Subpath(pts, True))
    return out


def flatten_then_stroke(c, width, cap, tolerance):
    """Chapter 13's way: flatten the curve, then stroke the polyline with
    round joins."""
    p = path()
    flatten_into_path(p, c, tolerance)
    return stroke_to_path(p, width, cap, "round", 4.0)


def point_count(p):
    """The total number of points across every subpath of a path."""
    return sum(len(sp.points) for sp in subpaths(p))


def hairpin():
    """A cubic that bends back on itself with a tightest radius of about
    8, used to show off the fold in the inner offset of a wide stroke."""
    return cubic(point(35, 140), point(65, -30), point(95, -30), point(125, 140))


def arch():
    """A cubic arch, tightest radius about 26, used for the offsets
    plate."""
    return cubic(point(60, 250), point(130, 5), point(190, 5), point(260, 250))


# --- Chapter 14 renders ---

_OFFSET_MAG = color(0.85, 0.2, 0.55)
_OFFSET_WHITE = color(0.9, 0.9, 0.92)
_OFFSET_SIZE = 160
_WARM = [color(0.95, 0.75, 0.2), color(0.95, 0.55, 0.15),
         color(0.9, 0.35, 0.15), color(0.8, 0.2, 0.2)]
_COOL = [color(0.35, 0.8, 0.9), color(0.25, 0.6, 0.9),
         color(0.3, 0.4, 0.85), color(0.45, 0.3, 0.8)]


def _outline_panel(outline_path, rule):
    """Fill an outline path under a rule in gray and draw its edges in
    magenta over it -- one panel of the offset plates. Endpoint pixels are
    rounded to the nearest pixel with halves up (chapter 1's round_half_up,
    floor(v + 0.5), the same rule for negative halves too): the hairpin's
    outline has two points that land exactly on a half-integer row, and
    that's the convention the reference render resolves the tie with."""
    c = canvas(_OFFSET_SIZE, _OFFSET_SIZE)
    fill(c, PAPER)
    cov = fill_path(outline_path, rule, _OFFSET_SIZE, _OFFSET_SIZE)
    paint_through(c, cov, _STROKE_GRAY)
    for e in edges(outline_path):
        line_wu(c, round_half_up(e.a.x), round_half_up(e.a.y),
                round_half_up(e.b.x), round_half_up(e.b.y), _OFFSET_MAG)
    return c


def two_strokes():
    """The hairpin stroked twice, 60 wide with butt caps: flattened and
    stroked with chapter 13's stroker on the left, one outline from the
    offset curves on the right."""
    left = _outline_panel(flatten_then_stroke(hairpin(), 60, "butt", 0.25), "nonzero")
    right = _outline_panel(stroke_curve_to_path(hairpin(), 60, "butt", 0.25), "nonzero")
    return side_by_side(left, right)


def fold_demo():
    """The offset-curve outline filled nonzero on the left and even-odd
    on the right -- the fold becomes a hole under even-odd."""
    o = stroke_curve_to_path(hairpin(), 60, "butt", 0.25)
    left = _outline_panel(o, "nonzero")
    right = _outline_panel(o, "evenodd")
    return side_by_side(left, right)


def _hairline(c, pts, col, width=1.5):
    """Stroke an open polyline hairline-thin with chapter 13 and paint
    it onto a canvas."""
    if not pts:
        return
    p = path()
    move_to(p, pts[0])
    for pt in pts[1:]:
        line_to(p, pt)
    outline = stroke_to_path(p, width, "butt", "round", 4.0)
    cov = fill_path(outline, "nonzero", c.width, c.height)
    paint_through(c, cov, col)


def offsets_plate():
    """An arch with its offsets at 15, 30, 45 and 60 on both sides, warm
    on the inside where they fold, cool outside, the curve in white and
    every cusp a magenta dot."""
    w, h = 320, 270
    c = canvas(w, h)
    fill(c, PAPER)
    curve = arch()
    ds = [15, 30, 45, 60]
    for k, d in enumerate(ds):
        _hairline(c, offset_path(curve, -d, 0.1), _COOL[k])
    for k, d in enumerate(ds):
        _hairline(c, offset_path(curve, d, 0.1), _WARM[k])
    _hairline(c, flatten(curve, 0.1), _OFFSET_WHITE, 2.0)
    for d in ds:
        for t in cusps(curve, d):
            q = offset_point(curve, t, d)
            cov = fill_path(circle_path(q.x, q.y, 2.5, 24), "nonzero", w, h)
            paint_through(c, cov, _OFFSET_MAG)
    return c


def plate_14():
    """Chapter 14's plate: the offsets plate, magnified by 2."""
    return magnify(offsets_plate(), 2)


# --- Chapter 15: Dashes ---

def path_length(p):
    """The total length of a path: every subpath's segments, plus the
    closing segment for a subpath that was closed."""
    total = 0.0
    for sp in subpaths(p):
        pts = sp.points
        for i in range(len(pts) - 1):
            total += magnitude(pts[i + 1] - pts[i])
        if sp.closed and len(pts) > 1:
            total += magnitude(pts[0] - pts[-1])
    return total


def arc_length_table(c, n):
    """n + 1 running lengths of the polyline through point_at(c, i / n),
    i = 0 .. n: table[i] is the distance along the chords from the start
    to that point."""
    table = [0.0]
    prev = point_at(c, 0)
    for i in range(1, n + 1):
        cur = point_at(c, i / n)
        table.append(table[-1] + magnitude(cur - prev))
        prev = cur
    return table


def arc_length(c, n):
    """The curve's length at this chord count: the arc-length table's
    last entry."""
    return arc_length_table(c, n)[n]


def t_at_length(table, s):
    """The parameter where the running length reaches s, by linear
    interpolation inside the chord that spans it: 0 before the start, 1
    past the end."""
    n = len(table) - 1
    if s <= 0:
        return 0.0
    if s >= table[n]:
        return 1.0
    lo, hi = 0, n
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if table[mid] <= s:
            lo = mid
        else:
            hi = mid
    span = table[lo + 1] - table[lo]
    frac = (s - table[lo]) / span if span > 0 else 0.0
    return (lo + frac) / n


def point_at_length(c, s, n):
    """The point at running length s along the curve, found through its
    n-chord arc-length table."""
    return point_at(c, t_at_length(arc_length_table(c, n), s))


def split_at_length(c, s, n):
    """Split the curve at the parameter that running length s maps to,
    through its n-chord arc-length table."""
    return split_at(c, t_at_length(arc_length_table(c, n), s))


def normalize_pattern(pattern):
    """The list a dash walk actually uses: an odd count is repeated so
    on/off alternate the same way every cycle. A pattern with a negative
    entry, or that sums to nothing, is no pattern and comes back empty."""
    total = 0.0
    negative = False
    for v in pattern:
        total += v
        if v < 0:
            negative = True
    if negative or total <= 0:
        return []
    pat = list(pattern)
    return pat + pat if len(pat) % 2 else pat


def _lerp_point(a, b, t):
    return point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)


def dash(p, pattern, phase):
    """Walk every subpath from its start by arc length, on for
    pattern[0], off for pattern[1], and so on around the pattern; every
    on-stretch becomes an open subpath of the result. A closed subpath is
    walked around its closing segment too, and a last dash that runs back
    into the first is joined into one, turning the starting corner."""
    pat = normalize_pattern(pattern)
    if not pat:
        out = path()
        for sp in subpaths(p):
            out.subpaths.append(Subpath(list(sp.points), sp.closed))
        return out

    n = len(pat)
    total = sum(pat)
    out = path()
    for sp in subpaths(p):
        pts = list(sp.points)
        if sp.closed and len(pts) > 1:
            pts = pts + [pts[0]]

        i = 0
        remaining = pat[0]
        on = True
        ph = phase % total
        while ph > 0:
            if ph >= remaining:
                ph -= remaining
                i = (i + 1) % n
                remaining = pat[i]
                on = not on
            else:
                remaining -= ph
                ph = 0

        first_idx = len(out.subpaths)
        cur = None
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            seg_len = magnitude(b - a)
            if seg_len < 1e-9:
                continue
            pos = 0.0
            while pos < seg_len:
                step = min(remaining, seg_len - pos)
                if on:
                    if cur is None:
                        cur = Subpath([_lerp_point(a, b, pos / seg_len)], False)
                        out.subpaths.append(cur)
                    if step > 0:
                        cur.points.append(_lerp_point(a, b, (pos + step) / seg_len))
                pos += step
                remaining -= step
                if remaining <= 1e-9:
                    i = (i + 1) % n
                    remaining = pat[i]
                    on = not on
                    cur = None

        dashes = out.subpaths[first_idx:]
        if sp.closed and dashes:
            head, tail = dashes[0], dashes[-1]
            if (magnitude(head.points[0] - pts[0]) < 1e-9 and
                    magnitude(tail.points[-1] - pts[0]) < 1e-9):
                if head is tail:
                    tail.points.pop()
                    tail.closed = True
                else:
                    tail.points.extend(head.points[1:])
                    del out.subpaths[first_idx]
    return out


def dash_count(p, pattern, phase):
    """How many dashes result -- the number of subpaths dash produces."""
    return len(subpaths(dash(p, pattern, phase)))


def lopsided():
    """A cubic with one short handle and one long one, so its parameter
    crawls at the start and races at the end -- the curve where the
    parameter lies about distance."""
    return cubic(point(15, 100), point(25, 85), point(100, 5), point(185, 95))


# --- Chapter 15 renders ---

_DASH_DIM = color(0.25, 0.25, 0.28)
_DASH_INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
_PHI = (1 + math.sqrt(5)) / 2
_SPIRAL_KAPPA = 0.5522847498


def _polyline_path(pts, closed=False):
    """An open (or closed) path built by walking straight through a list
    of points."""
    p = path()
    if not pts:
        return p
    move_to(p, pts[0])
    for pt in pts[1:]:
        line_to(p, pt)
    if closed:
        close(p)
    return p


def _stroke_path(c, path_obj, width, col, cap="butt", join="round"):
    """Stroke every subpath of a path (chapter 13) and paint it onto a
    canvas in one fill."""
    outline = stroke_to_path(path_obj, width, cap, join, 4.0)
    cov = fill_path(outline, "nonzero", c.width, c.height)
    paint_through(c, cov, col)


def _dot(c, q, r, col):
    """A small filled circle, used to mark a point on a plate."""
    cov = fill_path(circle_path(q.x, q.y, r, 24), "nonzero", c.width, c.height)
    paint_through(c, cov, col)


def even_marks():
    """lopsided() drawn twice with eleven marks: at equal steps of the
    parameter on the left, at equal steps of arc length on the right."""
    w, h = 200, 120
    c = lopsided()
    left = canvas(w, h)
    fill(left, PAPER)
    right = canvas(w, h)
    fill(right, PAPER)
    spine = _polyline_path(flatten(c, 0.1))
    _stroke_path(left, spine, 1.5, _DASH_DIM)
    _stroke_path(right, spine, 1.5, _DASH_DIM)
    total = arc_length(c, 256)
    for i in range(11):
        _dot(left, point_at(c, i / 10), 3, _DASH_INKS[0])
        _dot(right, point_at_length(c, total * i / 10, 256), 3, _DASH_INKS[1])
    return side_by_side(left, right)


def wave(dy):
    """The one wavy curve the strip demo strokes four different ways,
    offset vertically by dy."""
    curve = cubic(point(20, 20 + dy), point(120, -20 + dy),
                  point(200, 60 + dy), point(300, 20 + dy))
    return _polyline_path(flatten(curve, 0.1))


def dash_strip():
    """One wave stroked four ways: solid, 12 on 6 off, the same at phase
    9, and dots (0 on 9 off with round caps)."""
    w, h = 320, 160
    c = canvas(w, h)
    fill(c, PAPER)
    rows = [
        ([], 0, "butt", _STROKE_GRAY),
        ([12, 6], 0, "butt", _DASH_INKS[0]),
        ([12, 6], 9, "butt", _DASH_INKS[1]),
        ([0, 9], 0, "round", _DASH_INKS[2]),
    ]
    for k, (pattern, phase, cap, col) in enumerate(rows):
        d = dash(wave(40 * k), pattern, phase)
        _stroke_path(c, d, 5, col, cap, "round")
    return c


def golden_spiral():
    """Seven quarter circles, each phi times the radius of the last and
    tangent to it, flattened into one open subpath."""
    p = path()
    r = 6.0
    cx, cy = 148.0, 130.0
    theta = math.pi
    for _ in range(7):
        a0, a1 = theta, theta + math.pi / 2
        d0 = vector(math.cos(a0), math.sin(a0))
        d1 = vector(math.cos(a1), math.sin(a1))
        p0 = point(cx + r * d0.x, cy + r * d0.y)
        p3 = point(cx + r * d1.x, cy + r * d1.y)
        p1 = _add_scaled(p0, d1, _SPIRAL_KAPPA * r)
        p2 = _add_scaled(p3, d0, _SPIRAL_KAPPA * r)
        flatten_into_path(p, cubic(p0, p1, p2, p3), 0.05)
        nr = r * _PHI
        cx = p3.x - nr * d1.x
        cy = p3.y - nr * d1.y
        r = nr
        theta = a1
    return p


def spiral_dashes():
    """The golden spiral dashed 16 on 10 off, every dash stroked 7 wide
    with round caps in the next of three inks, the spiral itself drawn
    faintly underneath."""
    w, h = 340, 340
    c = canvas(w, h)
    fill(c, PAPER)
    sp = golden_spiral()
    _stroke_path(c, sp, 1.0, _DASH_DIM)
    d = dash(sp, [16, 10], 0)
    for k, sub in enumerate(subpaths(d)):
        one = path()
        one.subpaths.append(Subpath(list(sub.points), sub.closed))
        _stroke_path(c, one, 7, _DASH_INKS[k % 3], "round", "round")
    return c


def plate_15():
    """Chapter 15's plate: the dashed spiral, magnified by 2."""
    return magnify(spiral_dashes(), 2)


# ============================================================================
# Chapter 16: What a Glyph Is
# ============================================================================

class Font:
    """A font: its vertical metrics, a codepoint-to-name cmap, and every
    glyph by name. kern and ligatures are optional sections that arrive
    in chapter 18; joining, forms, marks and anchors are optional
    sections the Arabic font in chapter 19 carries. All default to
    empty."""

    def __init__(self, units_per_em, ascender, descender, line_gap, cmap, glyphs,
                 kern=None, ligatures=None, joining=None, forms=None,
                 marks=None, anchors=None):
        self.units_per_em = units_per_em
        self.ascender = ascender
        self.descender = descender
        self.line_gap = line_gap
        self.cmap = cmap
        self.glyphs = glyphs
        self.kern = kern if kern is not None else []
        self.ligatures = ligatures if ligatures is not None else []
        self.joining = joining if joining is not None else {}
        self.forms = forms if forms is not None else {}
        self.marks = marks if marks is not None else {}
        self.anchors = anchors if anchors is not None else {}


class Glyph:
    """A glyph: its advance, its contours (each a list of (x, y, on)
    points in font units), and its components (each another glyph's name
    with a six-number transform)."""

    def __init__(self, advance, contours, components):
        self.advance = advance
        self.contours = contours
        self.components = components


def load_font(text):
    """Read a font from its JSON text. Every language reads JSON; this is
    the one loader, written once."""
    data = json.loads(text)
    cmap = dict(data.get("cmap", {}))
    glyphs = {}
    for name, g in data.get("glyphs", {}).items():
        contours = [[(pt[0], pt[1], bool(pt[2])) for pt in contour]
                    for contour in g.get("contours", [])]
        components = [(c["glyph"], list(c["transform"])) for c in g.get("components", [])]
        glyphs[name] = Glyph(g.get("advance", 0), contours, components)
    marks = None
    if "marks" in data:
        marks = {name: tuple(v) for name, v in data["marks"].items()}
    anchors = None
    if "anchors" in data:
        anchors = {name: {cls: tuple(pt) for cls, pt in classes.items()}
                   for name, classes in data["anchors"].items()}
    return Font(data["units_per_em"], data["ascender"], data["descender"],
                data.get("line_gap", 0), cmap, glyphs,
                data.get("kern"), data.get("ligatures"),
                data.get("joining"), data.get("forms"), marks, anchors)


def glyph_name(font, codepoint):
    """The glyph name a codepoint maps to, or .notdef when the font
    doesn't have the character."""
    return font.cmap.get(str(codepoint), ".notdef")


def glyph_advance(font, name):
    """A glyph's advance, in font units."""
    return font.glyphs[name].advance


def glyph_count(font):
    """How many glyphs the font holds."""
    return len(font.glyphs)


def implied_points(contour):
    """Make every implied on-curve point explicit: walk the loop (which
    wraps, so the last and first points count as a pair too), and after
    every off-curve point followed by another off-curve point, insert
    their midpoint flagged on. Then rotate the result to start on an
    on-curve point, since a contour may start off-curve."""
    pts = [tuple(p) for p in contour]
    n = len(pts)
    if n == 0:
        return []
    out = []
    for i in range(n):
        cur = pts[i]
        nxt = pts[(i + 1) % n]
        out.append(cur)
        if not cur[2] and not nxt[2]:
            out.append(((cur[0] + nxt[0]) / 2.0, (cur[1] + nxt[1]) / 2.0, True))
    start = next((i for i, p in enumerate(out) if p[2]), 0)
    return out[start:] + out[:start]


def contour_curves(contour):
    """A contour as quadratics: from each on-curve point through the
    off-curve point after it (if any) to the next on-curve point. Two
    on-curve points in a row are a straight edge, written as a quadratic
    with its control point at the edge's midpoint, so every piece of
    every contour is the same shape."""
    pts = implied_points(contour)
    n = len(pts)
    on_indices = [i for i, p in enumerate(pts) if p[2]]
    curves = []
    for k in range(len(on_indices)):
        i0 = on_indices[k]
        i1 = on_indices[(k + 1) % len(on_indices)]
        if i1 > i0:
            between = pts[i0 + 1:i1]
        else:
            between = pts[i0 + 1:] + pts[:i1]
        p0 = point(pts[i0][0], pts[i0][1])
        p2 = point(pts[i1][0], pts[i1][1])
        if between:
            ctrl = point(between[0][0], between[0][1])
        else:
            ctrl = point((p0.x + p2.x) / 2.0, (p0.y + p2.y) / 2.0)
        curves.append(quadratic(p0, ctrl, p2))
    return curves


def component_matrix(t):
    """A component's six-number transform [a, b, c, d, dx, dy] as a
    matrix3, applied the way TrueType applies it:
    x' = a*x + c*y + dx, y' = b*x + d*y + dy."""
    a, b, c, d, dx, dy = t
    return Matrix3(a, c, dx, b, d, dy, 0, 0, 1)


def glyph_outline(font, name):
    """Every contour of a glyph as quadratics, in font units: its own
    contours, followed by each component's outline taken through its
    matrix, recursively. Returns a list of contours, each a list of
    quadratics."""
    g = font.glyphs[name]
    contours = [contour_curves(c) for c in g.contours]
    for comp_name, transform in g.components:
        m = component_matrix(transform)
        for sub_contour in glyph_outline(font, comp_name):
            contours.append([transform_curve(c, m) for c in sub_contour])
    return contours


def glyph_bounds(font, name):
    """The tight box of a glyph's outline: the union, over every
    quadratic of every contour (including components), of chapter 8's
    curve_bounds -- not the box of the control points. An empty glyph's
    bounds are (0, 0, 0, 0)."""
    xs0, ys0, xs1, ys1 = [], [], [], []
    for contour in glyph_outline(font, name):
        for c in contour:
            b = curve_bounds(c)
            xs0.append(b[0]); ys0.append(b[1])
            xs1.append(b[2]); ys1.append(b[3])
    if not xs0:
        return (0.0, 0.0, 0.0, 0.0)
    return (min(xs0), min(ys0), max(xs1), max(ys1))


def text_matrix(font, size, x, y):
    """The one place the y-up/y-down difference lives: scale by
    size / units_per_em, turn y over, and put the glyph's origin on the
    baseline at (x, y)."""
    scale = size / font.units_per_em
    return translation(x, y) * scaling(scale, -scale)


def contour_path(font, name, i, m, tolerance):
    """One contour of a glyph as a closed subpath, in device space: its
    quadratics through m, flattened at tolerance."""
    p = path()
    for c in glyph_outline(font, name)[i]:
        flatten_into_path(p, transform_curve(c, m), tolerance)
    close(p)
    return p


def glyph_path(font, name, m, tolerance):
    """A glyph's outline as a path, in device space: every quadratic
    through m, flattened, one closed subpath per contour."""
    p = path()
    contours = glyph_outline(font, name)
    for i in range(len(contours)):
        if not contours[i]:
            continue
        sub = contour_path(font, name, i, m, tolerance)
        p.subpaths.extend(sub.subpaths)
    return p


# --- Chapter 16 renders ---

_GLYPH_GRAY = _STROKE_GRAY
_GLYPH_MAGENTA = _STROKE_MAG
_GLYPH_CYAN = color(0.2, 0.75, 0.9)
_GLYPH_DIM = color(0.3, 0.3, 0.34)


def _square_path(q, half_side):
    """A small square centred on q, half_side to each side."""
    return polygon(point(q.x - half_side, q.y - half_side),
                   point(q.x + half_side, q.y - half_side),
                   point(q.x + half_side, q.y + half_side),
                   point(q.x - half_side, q.y + half_side))


def glyph_plate():
    """The letter a, filled, with the file's control polygon drawn over
    it: on-curve points as filled squares, off-curve points as hollow
    circles, implied on-curve points as smaller squares."""
    c = canvas(320, 320)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    m = text_matrix(font, 300, 40, 250)

    cov = fill_path(glyph_path(font, "a", m, 0.1), "nonzero", c.width, c.height)
    paint_through(c, cov, _GLYPH_GRAY)

    for contour in font.glyphs["a"].contours:
        pts = [m * point(x, y) for (x, y, _on) in contour]
        _stroke_path(c, _polyline_path(pts, True), 1.0, _GLYPH_DIM, "butt", "round")

    for contour in font.glyphs["a"].contours:
        file_points = {(x, y) for (x, y, _on) in contour}
        for (x, y, on) in implied_points(contour):
            q = m * point(x, y)
            if not on:
                ring = fill_path(stroke_to_path(circle_path(q.x, q.y, 4, 24), 1.5, "butt", "round", 4.0),
                                  "nonzero", c.width, c.height)
                paint_through(c, ring, _GLYPH_MAGENTA)
            elif (x, y) in file_points:
                sq = fill_path(_square_path(q, 3), "nonzero", c.width, c.height)
                paint_through(c, sq, _GLYPH_CYAN)
            else:
                sq = fill_path(_square_path(q, 2), "nonzero", c.width, c.height)
                paint_through(c, sq, _GLYPH_CYAN)
    return c


def plate_16():
    """Chapter 16's plate: the annotated a, magnified by 2."""
    return magnify(glyph_plate(), 2)


def composite_demo():
    """eacute drawn as its two components, each in its own ink, with
    glyph_bounds as a hairline box."""
    w, h = 240, 240
    c = canvas(w, h)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    m = text_matrix(font, 240, 50, 190)

    g = font.glyphs["eacute"]
    comp_inks = [INKS[0], INKS[1]]
    for i, (comp_name, transform) in enumerate(g.components):
        mm = m * component_matrix(transform)
        cov = fill_path(glyph_path(font, comp_name, mm, 0.1), "nonzero", w, h)
        paint_through(c, cov, comp_inks[i % len(comp_inks)])

    x0, y0, x1, y1 = glyph_bounds(font, "eacute")
    corners = [m * point(x0, y0), m * point(x1, y0), m * point(x1, y1), m * point(x0, y1)]
    _stroke_path(c, _polyline_path(corners, True), 1.0, _GLYPH_MAGENTA, "butt", "round")
    return c


def sizes():
    """The letter g at 12, 24, 48 and 96 pixels, on one baseline."""
    w, h = 240, 120
    c = canvas(w, h)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    baseline_y = 80
    x = 8
    for size in (12, 24, 48, 96):
        m = text_matrix(font, size, x, baseline_y)
        cov = fill_path(glyph_path(font, "g", m, 0.1), "nonzero", w, h)
        paint_through(c, cov, _GLYPH_GRAY)
        x += glyph_advance(font, "g") * size / font.units_per_em + 8
    return c


def _flip_trap_panel(font, name, m, w, h, baseline_y, ink):
    """One panel of flip_trap: the glyph filled in ink -- gray where the
    flip is right, magenta where it's forgotten -- then a dim hairline
    along the baseline drawn over it, so the reader can see the glyph
    sitting on the baseline versus hanging below it."""
    c = canvas(w, h)
    fill(c, PAPER)
    cov = fill_path(glyph_path(font, name, m, 0.1), "nonzero", w, h)
    paint_through(c, cov, ink)
    _stroke_path(c, _polyline_path([point(0, baseline_y), point(w, baseline_y)], False),
                 1.0, _GLYPH_DIM, "butt", "round")
    return c


def flip_trap():
    """R drawn correctly through text_matrix on the left, and through a
    scale that forgot to turn y over on the right -- the glyph hangs
    below the baseline, upside down."""
    w, h = 120, 120
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    baseline_y = 60

    m_good = text_matrix(font, 60, 35, baseline_y)
    left = _flip_trap_panel(font, "R", m_good, w, h, baseline_y, _GLYPH_GRAY)

    scale = 60 / font.units_per_em
    m_bad = translation(35, baseline_y) * scaling(scale, scale)
    right = _flip_trap_panel(font, "R", m_bad, w, h, baseline_y, _GLYPH_MAGENTA)

    return side_by_side(left, right)


# ============================================================================
# Chapter 17: Rasterizing Type Well
# ============================================================================

def subpixel_of(x):
    """Split a fractional pen position into a whole pixel and one of four
    quarters, the fraction rounded to the nearest quarter and carried
    into the next pixel when it rounds all the way up to four."""
    whole = math.floor(x)
    frac = x - whole
    q = round_half_up(frac * 4)
    if q == 4:
        whole += 1
        q = 0
    return (whole, q)


class Bitmap:
    """A glyph's coverage in a buffer of its own, plus the offset (left,
    top) of the buffer's corner relative to the pen."""

    def __init__(self, coverage, left, top):
        self.coverage = coverage
        self.left = left
        self.top = top

    @property
    def width(self):
        return self.coverage.width

    @property
    def height(self):
        return self.coverage.height


def bitmap(coverage, left, top):
    """Build a bitmap from an existing coverage buffer and an offset."""
    return Bitmap(coverage, left, top)


_BITMAP_TOLERANCE = 0.1


def glyph_bitmap(font, name, size, subpixel):
    """Render a glyph at a given quarter-pixel subposition into a
    coverage buffer just big enough for it: columns floor(xmin) to
    ceil(xmax) - 1 of its device bounds shifted by the quarter, rows
    floor(-ymax) to ceil(-ymin) - 1, with left/top saying where the
    buffer's corner sits relative to the pen."""
    scale = size / font.units_per_em
    fx0, fy0, fx1, fy1 = glyph_bounds(font, name)
    sx0, sx1 = fx0 * scale, fx1 * scale
    sy0, sy1 = fy0 * scale, fy1 * scale
    shift = subpixel / 4.0

    left = math.floor(sx0 + shift)
    right = math.ceil(sx1 + shift) - 1
    width = max(0, right - left + 1)

    top = math.floor(-sy1)
    bottom = math.ceil(-sy0) - 1
    height = max(0, bottom - top + 1)

    if width <= 0 or height <= 0:
        return Bitmap(coverage_buffer(max(0, width), max(0, height)), left, top)

    m = text_matrix(font, size, shift - left, -top)
    cov = fill_path(glyph_path(font, name, m, _BITMAP_TOLERANCE), "nonzero", width, height)
    return Bitmap(cov, left, top)


def paint_bitmap(canvas, bmp, x, y, col, linear):
    """Composite a bitmap onto a canvas with its pen at whole pixel
    (x, y), mixing toward col by each covered pixel's coverage. linear
    picks chapter 1's blending lane explicitly, not the global switch."""
    cov = bmp.coverage
    for j in range(cov.height):
        for i in range(cov.width):
            c = coverage_at(cov, i, j)
            if c <= 0:
                continue
            px = x + bmp.left + i
            py = y + bmp.top + j
            if 0 <= px < canvas.width and 0 <= py < canvas.height:
                current = pixel_at(canvas, px, py)
                painted = mix(current, col, c, linear)
                write_pixel(canvas, px, py, painted)


# --- The cache and the atlas ---

def glyph_cache():
    """An empty glyph cache: a table keyed by (name, size, subpixel)."""
    return {}


def cache_size(cache):
    """How many bitmaps a cache holds."""
    return len(cache)


def cached_bitmap(cache, font, name, size, subpixel):
    """Render a glyph on the first request for this key, and hand back
    the very same bitmap on every request after."""
    key = (name, size, subpixel)
    if key not in cache:
        cache[key] = glyph_bitmap(font, name, size, subpixel)
    return cache[key]


class Atlas:
    """A big coverage buffer that bitmaps are packed into shelf by
    shelf: left to right along a shelf whose height is its first
    bitmap's, a new shelf opening below the tallest shelf so far when
    one doesn't fit."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.coverage = coverage_buffer(width, height)
        self.shelf_y = 0
        self.shelf_height = 0
        self.cursor_x = 0


def atlas(width, height):
    """An empty atlas of the given size."""
    return Atlas(width, height)


def atlas_add(at, bmp):
    """Copy a bitmap's coverage into the atlas, shelf-packed, and answer
    where its top-left corner landed -- or none when there's no room."""
    w, h = bmp.width, bmp.height
    if w > at.width or h > at.height:
        return None

    if at.cursor_x + w > at.width:
        # This bitmap doesn't fit on the current shelf: open a new one
        # below the tallest shelf seen so far.
        at.shelf_y += at.shelf_height
        at.shelf_height = 0
        at.cursor_x = 0

    if at.shelf_y + h > at.height:
        return None

    x0, y0 = at.cursor_x, at.shelf_y
    for j in range(h):
        for i in range(w):
            set_coverage(at.coverage, x0 + i, y0 + j, coverage_at(bmp.coverage, i, j))

    at.cursor_x += w
    at.shelf_height = max(at.shelf_height, h)
    return (x0, y0)


# --- The fudge, named ---

def embolden(font, name, size, amount):
    """Stem darkening: the glyph's fill plus chapter 13's stroke of its
    outline, amount wide, the two coverages added and clamped to one, in
    a bitmap grown a pixel all round to make room."""
    plain = glyph_bitmap(font, name, size, 0)
    left = plain.left - 1
    top = plain.top - 1
    width = plain.width + 2
    height = plain.height + 2
    if width <= 0 or height <= 0:
        return Bitmap(coverage_buffer(max(0, width), max(0, height)), left, top)

    m = text_matrix(font, size, -left, -top)
    gp = glyph_path(font, name, m, _BITMAP_TOLERANCE)
    fill_cov = fill_path(gp, "nonzero", width, height)
    stroke_outline = stroke_to_path(gp, amount, "round", "round", 4.0)
    stroke_cov = fill_path(stroke_outline, "nonzero", width, height)

    result = coverage_buffer(width, height)
    for j in range(height):
        for i in range(width):
            total = coverage_at(fill_cov, i, j) + coverage_at(stroke_cov, i, j)
            set_coverage(result, i, j, min(1.0, total))
    return Bitmap(result, left, top)


# --- Three coverages per pixel (LCD) ---

LCD_TAPS = (1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)


def lcd_filter(values):
    """Replace every value with the average of itself and its two
    neighbours, zero beyond the ends: three taps that sum to one, so ink
    spreads across neighbouring stripes but is never lost."""
    n = len(values)
    out = []
    for i in range(n):
        left = values[i - 1] if i - 1 >= 0 else 0
        mid = values[i]
        right = values[i + 1] if i + 1 < n else 0
        out.append((left + mid + right) / 3.0)
    return out


def lcd_coverage(font, name, size, x, y, w, h):
    """Rasterize the glyph three times wider -- one coverage per stripe
    -- into a buffer 3w wide and h tall, with lcd_filter run along every
    row."""
    wide = coverage_buffer(3 * w, h)
    scale = size / font.units_per_em
    m = translation(3 * x, y) * scaling(3 * scale, -scale)
    gp = glyph_path(font, name, m, _BITMAP_TOLERANCE)
    raw = fill_path(gp, "nonzero", 3 * w, h)
    for row in range(h):
        values = [coverage_at(raw, col, row) for col in range(3 * w)]
        filtered = lcd_filter(values)
        for col in range(3 * w):
            set_coverage(wide, col, row, filtered[col])
    return wide


def paint_lcd(canvas, cov3, col):
    """Composite an LCD coverage buffer: red through the first stripe of
    each pixel, green the second, blue the third, each channel mixed on
    its own."""
    w = cov3.width // 3
    h = cov3.height
    for y in range(h):
        for x in range(w):
            cr = coverage_at(cov3, 3 * x, y)
            cg = coverage_at(cov3, 3 * x + 1, y)
            cb = coverage_at(cov3, 3 * x + 2, y)
            if cr <= 0 and cg <= 0 and cb <= 0:
                continue
            current = pixel_at(canvas, x, y)
            painted = Color(
                current.red + (col.red - current.red) * cr,
                current.green + (col.green - current.green) * cg,
                current.blue + (col.blue - current.blue) * cb,
            )
            write_pixel(canvas, x, y, painted)


# --- Putting it together ---

def pen_advance(font, name, size):
    """A glyph's advance, in pixels, at a given size."""
    return glyph_advance(font, name) * size / font.units_per_em


def draw_text(canvas, font, text, size, x, y, col, linear=True):
    """Step the pen across a string, drawing each glyph at its nearest
    quarter and advancing by pen_advance."""
    cache = glyph_cache()
    pen = x
    for ch in text:
        name = glyph_name(font, ord(ch))
        whole, q = subpixel_of(pen)
        bmp = cached_bitmap(cache, font, name, size, q)
        paint_bitmap(canvas, bmp, whole, y, col, linear)
        pen += pen_advance(font, name, size)
    return pen


def subpixel_strip():
    """l at 11 pixels with its pen at x = 4, 4.25, 4.5 and 4.75, in four
    10x14 panels, black on white, magnified eight times."""
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    panels = []
    for q in range(4):
        c = canvas(10, 14)
        fill(c, color(1, 1, 1))
        bmp = glyph_bitmap(font, "l", 11, q)
        paint_bitmap(c, bmp, 4, 11, color(0, 0, 0), True)
        panels.append(c)
    combined = _side_by_side_n(panels)
    return magnify(combined, 8)


def smoothing_demo():
    """Hamburg at 11 pixels three ways: blended in linear light, blended
    in encoded space, and linear with the stems emboldened by a third of
    a pixel, magnified four times."""
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    text = "Hamburg"
    w, h = 72, 14
    rows = []

    c1 = canvas(w, h)
    fill(c1, color(1, 1, 1))
    cache1 = glyph_cache()
    pen = 2.0
    for ch in text:
        name = glyph_name(font, ord(ch))
        whole, q = subpixel_of(pen)
        bmp = cached_bitmap(cache1, font, name, 11, q)
        paint_bitmap(c1, bmp, whole, 11, color(0, 0, 0), True)
        pen += pen_advance(font, name, 11)
    rows.append(c1)

    c2 = canvas(w, h)
    fill(c2, color(1, 1, 1))
    cache2 = glyph_cache()
    pen = 2.0
    for ch in text:
        name = glyph_name(font, ord(ch))
        whole, q = subpixel_of(pen)
        bmp = cached_bitmap(cache2, font, name, 11, q)
        paint_bitmap(c2, bmp, whole, 11, color(0, 0, 0), False)
        pen += pen_advance(font, name, 11)
    rows.append(c2)

    c3 = canvas(w, h)
    fill(c3, color(1, 1, 1))
    pen = 2.0
    for ch in text:
        name = glyph_name(font, ord(ch))
        whole, q = subpixel_of(pen)
        bmp = embolden(font, name, 11, 1.0 / 3.0)
        paint_bitmap(c3, bmp, whole, 11, color(0, 0, 0), True)
        pen += pen_advance(font, name, 11)
    rows.append(c3)

    total_h = sum(r.height for r in rows)
    result = Canvas(w, total_h)
    y_off = 0
    for r_ in rows:
        for y in range(r_.height):
            for x in range(w):
                write_pixel(result, x, y_off + y, pixel_at(r_, x, y))
        y_off += r_.height
    return magnify(result, 4)


def lcd_plate():
    """ea at 13 pixels twice: grayscale coverage above, three coverages
    per pixel below."""
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    top = canvas(24, 16)
    fill(top, color(1, 1, 1))
    bottom = canvas(24, 16)
    fill(bottom, color(1, 1, 1))
    pen = 2.0
    for ch in "ea":
        name = glyph_name(font, ord(ch))
        m = text_matrix(font, 13, pen, 12)
        cov = fill_path(glyph_path(font, name, m, 0.1), "nonzero", 24, 16)
        paint_through(top, cov, color(0, 0, 0))
        cov3 = lcd_coverage(font, name, 13, pen, 12, 24, 16)
        paint_lcd(bottom, cov3, color(0, 0, 0))
        pen += pen_advance(font, name, 13)
    total_h = top.height + bottom.height
    result = Canvas(24, total_h)
    for y in range(top.height):
        for x in range(24):
            write_pixel(result, x, y, pixel_at(top, x, y))
    for y in range(bottom.height):
        for x in range(24):
            write_pixel(result, x, top.height + y, pixel_at(bottom, x, y))
    return magnify(result, 6)


def plate_17():
    """Chapter 17's plate: the grayscale/LCD comparison, magnified by 2."""
    return magnify(lcd_plate(), 2)


# ============================================================================
# Chapter 18: Setting a Line of Text
# ============================================================================

class Placement:
    """Where one character's glyph goes: its name and the fractional
    pixel position of its origin on the baseline."""

    def __init__(self, name, x, y):
        self.name = name
        self.x = x
        self.y = y

    def __repr__(self):
        return f"Placement({self.name!r}, {self.x!r}, {self.y!r})"


def ascent(font, size):
    """How far the font reaches above the baseline, in pixels."""
    return font.ascender * size / font.units_per_em


def descent(font, size):
    """How far the font reaches below the baseline, in pixels -- a
    positive number, even though the file stores the descender as a
    negative one."""
    return -font.descender * size / font.units_per_em


def line_height(font, size):
    """The distance from one baseline to the next, in pixels: ascent
    plus descent plus the file's line gap."""
    return (font.ascender - font.descender + font.line_gap) * size / font.units_per_em


def kern(font, left, right):
    """The font's kerning adjustment for a pair of glyph names, in font
    units: 0 for a pair the font doesn't list. The order matters."""
    table = getattr(font, "_kern_table", None)
    if table is None:
        table = {}
        for entry in font.kern:
            l, r, v = entry[0], entry[1], entry[2]
            table[(l, r)] = v
        font._kern_table = table
    return table.get((left, right), 0)


def _run_walk(font, text, size, kerning):
    """Walk the pen across a string, returning a list of (name, pen)
    pairs -- the glyph placed at each pen position -- and the final pen
    position after the last glyph's advance. Kerning, when on, moves the
    pen by the pair's value before placing each glyph after the first."""
    entries = []
    pen = 0.0
    prev_name = None
    for ch in text:
        name = glyph_name(font, ord(ch))
        if kerning and prev_name is not None:
            pen += kern(font, prev_name, name) * size / font.units_per_em
        entries.append((name, pen))
        pen += pen_advance(font, name, size)
        prev_name = name
    return entries, pen


def layout_run(font, text, size, x, y, kerning):
    """One placement per character of text, in order: the first at
    (x, y), each next one a glyph advance further along (and, with
    kerning on, adjusted by the pair before it)."""
    entries, _ = _run_walk(font, text, size, kerning)
    return [Placement(name, x + pen, y) for name, pen in entries]


def run_advance(font, text, size, kerning):
    """How far the pen moved in all, laying out text."""
    _, total = _run_walk(font, text, size, kerning)
    return total


def break_lines(font, text, size, measure, kerning):
    """Break text into lines no wider than measure, greedily: each word
    (a run of non-space characters) joins the current line if doing so
    still fits, otherwise it starts a new line. A word wider than the
    measure on its own sits alone and overflows."""
    words = text.split()
    lines = []
    current = ""
    for word in words:
        candidate = word if current == "" else current + " " + word
        if current != "" and run_advance(font, candidate, size, kerning) > measure:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current != "":
        lines.append(current)
    return lines


def layout_line(font, text, size, x, y, measure, align, kerning):
    """Lay out one line inside a measure that starts at x. "left" leaves
    the slack on the right, "right" puts it on the left, "center" splits
    it, and "justify" spreads it over the line's spaces (each gap
    growing by slack / spaces) -- unless the line has no space, in which
    case it's laid out left."""
    run = layout_run(font, text, size, x, y, kerning)
    slack = measure - run_advance(font, text, size, kerning)
    num_spaces = text.count(" ")
    if align == "justify" and num_spaces > 0:
        extra = slack / num_spaces
        spaces_seen = 0
        out = []
        for ch, placement in zip(text, run):
            out.append(Placement(placement.name, placement.x + extra * spaces_seen, placement.y))
            if ch == " ":
                spaces_seen += 1
        return out
    if align == "right":
        shift = slack
    elif align == "center":
        shift = slack / 2.0
    else:
        shift = 0.0
    return [Placement(p.name, p.x + shift, p.y) for p in run]


def layout_paragraph(font, text, size, x, y, measure, align, kerning):
    """Break text into lines and lay out every line with the same
    alignment, the first baseline at y and each next one line_height
    below. A justified paragraph's last line is laid out left. Answers
    one flat list of placements."""
    lines = break_lines(font, text, size, measure, kerning)
    lh = line_height(font, size)
    out = []
    for i, line in enumerate(lines):
        line_align = "left" if (align == "justify" and i == len(lines) - 1) else align
        ly = y + i * lh
        out.extend(layout_line(font, line, size, x, ly, measure, line_align, kerning))
    return out


def draw_run(canvas, font, run, size, col, linear):
    """The seam between layout and rendering: hand every placement to
    chapter 17. Its x is split by subpixel_of into a whole pixel and a
    quarter; the glyph's bitmap for that quarter is painted with the pen
    at that pixel. The baseline rounds to the nearest whole pixel row,
    halves up."""
    cache = glyph_cache()
    for p in run:
        whole, q = subpixel_of(p.x)
        row = round_half_up(p.y)
        bmp = cached_bitmap(cache, font, p.name, size, q)
        paint_bitmap(canvas, bmp, whole, row, col, linear)


# --- Chapter 18 renders ---

THROUGH_LINE = ("Rasterization computes coverage. Painting composites "
                 "paint through coverage. Once you hold a coverage buffer, "
                 "a stroke is a fill of a different outline, a clip is a "
                 "multiplication of two buffers, and a glyph is a path "
                 "somebody else drew.")


def _hairline_seg(c, a, b, col, width=1.0):
    """A single straight hairline segment, stroked butt-capped."""
    _hairline(c, [a, b], col, width)


def kern_demo():
    """TAVERN at a 64 pixel em, kerned on one baseline and not on the
    next, with tick marks at every placement and a magenta bracket
    across the five pixels the kerning saved."""
    w, h = 320, 190
    c = canvas(w, h)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    size = 64
    x0 = 12
    rows = [(70, True, _GLYPH_CYAN), (160, False, _GLYPH_DIM)]
    ends = []
    for baseline, kerning, tick_col in rows:
        run = layout_run(font, "TAVERN", size, x0, baseline, kerning)
        end_x = x0 + run_advance(font, "TAVERN", size, kerning)
        draw_run(c, font, run, size, _GLYPH_GRAY, True)
        _hairline_seg(c, point(4, baseline), point(316, baseline), _GLYPH_DIM)
        for p in run:
            _hairline_seg(c, point(p.x, baseline + 3), point(p.x, baseline + 12), tick_col)
        _hairline_seg(c, point(end_x, baseline + 3), point(end_x, baseline + 12), tick_col)
        ends.append(end_x)
    for end_x in ends:
        _hairline_seg(c, point(end_x, 84), point(end_x, 180), _GLYPH_MAGENTA)
    _hairline_seg(c, point(ends[0], 180), point(ends[1], 180), _GLYPH_MAGENTA)
    return c


def break_demo():
    """The through-line broken into a 300 pixel measure, left aligned,
    with cyan hairlines marking the measure's edges."""
    w, h = 340, 150
    c = canvas(w, h)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    x, y, size, measure = 20, 30, 16, 300
    run = layout_paragraph(font, THROUGH_LINE, size, x, y, measure, "left", True)
    draw_run(c, font, run, size, _GLYPH_GRAY, True)
    _hairline_seg(c, point(x, 10), point(x, 140), _GLYPH_CYAN)
    _hairline_seg(c, point(x + measure, 10), point(x + measure, 140), _GLYPH_CYAN)
    return c


def _rounded_run(font, text, size, x, y):
    """The trap: place each glyph, then round the pen to a whole pixel
    before placing the next one. The errors don't cancel. The run's end
    is where the pen physically lands after the last glyph's advance --
    the rounding only ever decided where the *next* glyph would go, and
    the last glyph has no next."""
    out = []
    pen = float(x)
    chars = list(text)
    for i, ch in enumerate(chars):
        name = glyph_name(font, ord(ch))
        out.append(Placement(name, pen, y))
        pen += pen_advance(font, name, size)
        if i < len(chars) - 1:
            pen = round_half_up(pen)
    return out, pen


def drift_demo():
    """The same line set twice at 11 pixels: the pen kept fractional
    above, rounded to a whole pixel after every glyph below. The magenta
    bracket is the accumulated drift."""
    w, h = 260, 44
    c = canvas(w, h)
    fill(c, color(1, 1, 1))
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    text = "little illicit lilies fill the hill until it is still"
    size = 11
    x = 6

    exact_run = layout_run(font, text, size, x, 14, False)
    exact_end = x + run_advance(font, text, size, False)
    draw_run(c, font, exact_run, size, color(0, 0, 0), True)

    rounded_run, rounded_end = _rounded_run(font, text, size, x, 34)
    draw_run(c, font, rounded_run, size, color(0, 0, 0), True)

    _hairline_seg(c, point(exact_end, 3), point(exact_end, 18), _GLYPH_CYAN, 2.0)
    _hairline_seg(c, point(exact_end, 23), point(exact_end, 38), _GLYPH_CYAN, 2.0)
    _hairline_seg(c, point(rounded_end, 23), point(rounded_end, 38), _GLYPH_MAGENTA, 2.0)
    _hairline_seg(c, point(exact_end, 40), point(rounded_end, 40), _GLYPH_MAGENTA, 2.0)

    return magnify(c, 3)


def alignment_plate():
    """One paragraph, set four ways: left, right, center, and justify,
    each with hairlines marking its baselines and measure."""
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    w, h = 660, 236
    c = canvas(w, h)
    fill(c, PAPER)
    text = THROUGH_LINE
    size = 14
    measure = 300
    aligns = ["left", "right", "center", "justify"]
    lh = line_height(font, size)
    for k, align in enumerate(aligns):
        x = 20 + (k % 2) * 320
        y = 24 + (k // 2) * 108
        run = layout_paragraph(font, text, size, x, y, measure, align, True)
        n = len(break_lines(font, text, size, measure, True))
        for i in range(n):
            baseline = y + i * lh
            _hairline_seg(c, point(x, baseline), point(x + measure, baseline), _GLYPH_DIM, 0.5)
        first_baseline = y
        last_baseline = y + (n - 1) * lh
        _hairline_seg(c, point(x, first_baseline - 14), point(x, last_baseline + 5), _GLYPH_CYAN, 0.5)
        _hairline_seg(c, point(x + measure, first_baseline - 14), point(x + measure, last_baseline + 5), _GLYPH_CYAN, 0.5)
        draw_run(c, font, run, size, _GLYPH_GRAY, True)
    return c


def plate_18():
    """Chapter 18's plate: the through-line set four ways."""
    return alignment_plate()



# ============================================================================
# Chapter 19: Shaping, a Field Guide
# ============================================================================

class Item:
    """One run of a string: one script, one direction. start/end are
    character indices into the original text (end exclusive)."""

    def __init__(self, start, end, text, script, direction):
        self.start = start
        self.end = end
        self.text = text
        self.script = script
        self.direction = direction

    def __repr__(self):
        return f"Item({self.start!r}, {self.end!r}, {self.text!r}, {self.script!r}, {self.direction!r})"


def script_of(codepoint):
    """"arabic" for U+0600-U+06FF, "latin" for A-Z, a-z and U+00C0-U+024F,
    "common" for everything else (spaces, digits, punctuation)."""
    if 0x0600 <= codepoint <= 0x06FF:
        return "arabic"
    if 65 <= codepoint <= 90 or 97 <= codepoint <= 122 or 0x00C0 <= codepoint <= 0x024F:
        return "latin"
    return "common"


def itemize(text):
    """Cut text into runs of one script and one direction. A common
    character joins the run before it; common characters at the very
    start join the first run, and text of nothing but common characters
    is one Latin run."""
    n = len(text)
    if n == 0:
        return []
    raw = [script_of(ord(ch)) for ch in text]
    resolved = [None] * n
    last_definite = None
    for i in range(n):
        if raw[i] != "common":
            resolved[i] = raw[i]
            last_definite = raw[i]
        else:
            resolved[i] = last_definite
    first_definite = next((s for s in raw if s != "common"), "latin")
    for i in range(n):
        if resolved[i] is None:
            resolved[i] = first_definite

    items = []
    start = 0
    for i in range(1, n + 1):
        if i == n or resolved[i] != resolved[start]:
            script = resolved[start]
            direction = "rtl" if script == "arabic" else "ltr"
            items.append(Item(start, i, text[start:i], script, direction))
            start = i
    return items


class GlyphEntry:
    """One entry of a glyph buffer: a glyph name, the cluster (character
    index) it came from, and a mark's offset from its base, in font
    units (zero for anything that isn't a positioned mark)."""

    def __init__(self, glyph, cluster, dx=0.0, dy=0.0):
        self.glyph = glyph
        self.cluster = cluster
        self.dx = dx
        self.dy = dy

    def __repr__(self):
        return f"GlyphEntry({self.glyph!r}, {self.cluster!r}, {self.dx!r}, {self.dy!r})"


def glyph_buffer(font, text):
    """The starting buffer: one entry per character, straight through
    the cmap, each carrying the index of the character it came from."""
    return [GlyphEntry(glyph_name(font, ord(ch)), i) for i, ch in enumerate(text)]


def clusters(buffer):
    """The distinct clusters a buffer holds, in the order they appear."""
    seen = set()
    out = []
    for e in buffer:
        if e.cluster not in seen:
            seen.add(e.cluster)
            out.append(e.cluster)
    return out


def apply_ligatures(font, buffer):
    """Walk the buffer from the left. At each position try the font's
    ligature rules, longest first; a match is replaced by its result,
    which takes the first part's cluster. The result is never fed back
    into another rule."""
    rules = sorted(font.ligatures, key=lambda r: -len(r[0]))
    out = []
    i = 0
    n = len(buffer)
    while i < n:
        matched = False
        for parts, result in rules:
            L = len(parts)
            if L == 0 or i + L > n:
                continue
            if all(buffer[i + k].glyph == parts[k] for k in range(L)):
                out.append(GlyphEntry(result, buffer[i].cluster))
                i += L
                matched = True
                break
        if not matched:
            out.append(buffer[i])
            i += 1
    return out


def joining_type(font, codepoint):
    """A codepoint's Unicode joining type: "dual", "right", "transparent"
    or "none" -- "none" for a character the table doesn't list."""
    return font.joining.get(str(codepoint), "none")


def arabic_forms(font, text):
    """A positional form for every character of text: a letter joins
    backward when it's dual or right-joining and the nearest
    non-transparent character before it is dual; it joins forward when
    it's dual and the nearest non-transparent character after it is
    dual or right-joining. Both is "medi", backward alone "fina",
    forward alone "init", neither "isol"."""
    n = len(text)
    types = [joining_type(font, ord(ch)) for ch in text]

    def nearest_before(i):
        j = i - 1
        while j >= 0 and types[j] == "transparent":
            j -= 1
        return types[j] if j >= 0 else None

    def nearest_after(i):
        j = i + 1
        while j < n and types[j] == "transparent":
            j += 1
        return types[j] if j < n else None

    forms = []
    for i in range(n):
        t = types[i]
        joins_back = t in ("dual", "right") and nearest_before(i) == "dual"
        joins_fwd = t == "dual" and nearest_after(i) in ("dual", "right")
        if joins_back and joins_fwd:
            forms.append("medi")
        elif joins_back:
            forms.append("fina")
        elif joins_fwd:
            forms.append("init")
        else:
            forms.append("isol")
    return forms


def apply_forms(font, text, buffer):
    """Swap each entry's glyph for its positional form's glyph when the
    font's forms table has one for it, and leave it alone otherwise."""
    forms = arabic_forms(font, text)
    out = []
    for i, e in enumerate(buffer):
        form = forms[i] if i < len(forms) else "isol"
        glyph_forms = font.forms.get(e.glyph)
        name = glyph_forms[form] if glyph_forms and form in glyph_forms else e.glyph
        out.append(GlyphEntry(name, e.cluster, e.dx, e.dy))
    return out


def is_mark(font, name):
    """Whether a glyph name is in the font's marks table."""
    return name in font.marks


def attach_marks(font, buffer):
    """Find each mark's base -- the nearest non-mark before it -- and
    set the mark's offset to the base's anchor of the mark's class minus
    the mark's own anchor, so the two coincide; the mark takes the
    base's cluster. A mark whose base has no anchor of its class, or
    with no base before it at all, stays at offset (0, 0)."""
    out = []
    base_index = None
    for e in buffer:
        if is_mark(font, e.glyph):
            dx, dy, cluster = 0.0, 0.0, e.cluster
            mark_info = font.marks.get(e.glyph)
            if mark_info is not None and base_index is not None:
                mclass, max_, may_ = mark_info
                base = out[base_index]
                base_anchors = font.anchors.get(base.glyph)
                if base_anchors is not None and mclass in base_anchors:
                    bax, bay = base_anchors[mclass]
                    dx = bax - max_
                    dy = bay - may_
                    cluster = base.cluster
            out.append(GlyphEntry(e.glyph, cluster, dx, dy))
        else:
            out.append(GlyphEntry(e.glyph, e.cluster, e.dx, e.dy))
            base_index = len(out) - 1
    return out


def shape(font, text):
    """The pipeline for one run: the buffer, then forms when the font
    has a forms table, then ligatures, then marks when the font has a
    marks table."""
    buffer = glyph_buffer(font, text)
    if font.forms:
        buffer = apply_forms(font, text, buffer)
    buffer = apply_ligatures(font, buffer)
    if font.marks:
        buffer = attach_marks(font, buffer)
    return buffer


def buffer_advance(font, buffer, size, kerning):
    """The pen's total movement laying out a buffer: every non-mark's
    advance, plus the kern pair between consecutive non-marks."""
    scale = size / font.units_per_em
    total = 0.0
    prev_glyph = None
    for e in buffer:
        if is_mark(font, e.glyph):
            continue
        if kerning and prev_glyph is not None:
            total += kern(font, prev_glyph, e.glyph) * scale
        total += pen_advance(font, e.glyph, size)
        prev_glyph = e.glyph
    return total


def position(font, buffer, size, x, y, direction, kerning):
    """Turn a shaped buffer into chapter 18's placements, one per entry,
    in the buffer's own order. "ltr" walks the pen right from x, exactly
    as layout_run does. "rtl" starts the pen at x plus the buffer's
    advance and walks left, subtracting each advance (and kern pair)
    before placing the glyph, so the first entry lands at the right end.
    A mark never moves the pen: it is placed at its base's origin plus
    its offset, scaled to pixels with dy turned over."""
    scale = size / font.units_per_em
    if direction == "rtl":
        pen = x + buffer_advance(font, buffer, size, kerning)
    else:
        pen = x
    placements = [None] * len(buffer)
    prev_glyph = None
    base_origin = (pen, y)
    for i, e in enumerate(buffer):
        if is_mark(font, e.glyph):
            bx, by = base_origin
            placements[i] = Placement(e.glyph, bx + e.dx * scale, by - e.dy * scale)
            continue
        if direction == "rtl":
            if kerning and prev_glyph is not None:
                pen -= kern(font, prev_glyph, e.glyph) * scale
            pen -= pen_advance(font, e.glyph, size)
            placements[i] = Placement(e.glyph, pen, y)
        else:
            if kerning and prev_glyph is not None:
                pen += kern(font, prev_glyph, e.glyph) * scale
            placements[i] = Placement(e.glyph, pen, y)
            pen += pen_advance(font, e.glyph, size)
        base_origin = (placements[i].x, y)
        prev_glyph = e.glyph
    return placements


def caret_offsets(buffer, length):
    """The character offsets a cursor may stand at: every cluster
    start, in order, then the text's length."""
    return clusters(buffer) + [length]


def caret_positions(font, buffer, length, size, x, direction, kerning):
    """The x of each caret offset, in the same order: the pen where
    each cluster's first glyph is placed, then the pen after the last
    glyph. For "rtl" the first position is the run's right end and the
    last is x."""
    scale = size / font.units_per_em
    if direction == "rtl":
        pen = x + buffer_advance(font, buffer, size, kerning)
    else:
        pen = x
    checkpoints = []
    prev_glyph = None
    last_cluster = None
    for e in buffer:
        if is_mark(font, e.glyph):
            continue
        if e.cluster != last_cluster:
            checkpoints.append(pen)
            last_cluster = e.cluster
        if direction == "rtl":
            if kerning and prev_glyph is not None:
                pen -= kern(font, prev_glyph, e.glyph) * scale
            pen -= pen_advance(font, e.glyph, size)
        else:
            if kerning and prev_glyph is not None:
                pen += kern(font, prev_glyph, e.glyph) * scale
            pen += pen_advance(font, e.glyph, size)
        prev_glyph = e.glyph
    checkpoints.append(pen)
    return checkpoints


# --- Chapter 19 renders ---

ARABIC_KITAB = "كِتاب"  # kaf, kasra, teh, alef, beh


def _caret_ticks(c, font, buffer, length, size, x, y, direction, kerning, col, lo=4, hi=16):
    for cx in caret_positions(font, buffer, length, size, x, direction, kerning):
        _hairline_seg(c, point(cx, y + lo), point(cx, y + hi), col)


def ligature_demo():
    """office shaped and positioned, the f_i glyph in magenta, the rest
    gray, with caret ticks marking where the cursor may stand."""
    w, h = 260, 100
    c = canvas(w, h)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-16/roboto.json"))
    text = "office"
    size = 64
    x, y = 20, 70
    buffer = shape(font, text)
    run = position(font, buffer, size, x, y, "ltr", True)
    _hairline_seg(c, point(4, y), point(256, y), _GLYPH_DIM)
    for e, p in zip(buffer, run):
        col = _GLYPH_MAGENTA if e.glyph == "f_i" else _GLYPH_GRAY
        draw_run(c, font, [p], size, col, True)
    _caret_ticks(c, font, buffer, len(text), size, x, y, "ltr", True, _GLYPH_CYAN)
    return c


def forms_demo():
    """One letter, beh, in its four positional forms, each labelled in
    Roboto below it."""
    w, h = 320, 110
    c = canvas(w, h)
    fill(c, PAPER)
    ar = load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    lat = load_font(read_file("reference/chapter-16/roboto.json"))
    glyphs = ["beh", "beh.init", "beh.medi", "beh.fina"]
    labels = ["isol", "init", "medi", "fina"]
    size = 64
    for k in range(4):
        ox = 16 + 76 * k
        oy = 60
        _hairline_seg(c, point(ox - 4, oy), point(ox + 68, oy), _GLYPH_DIM)
        draw_run(c, ar, [Placement(glyphs[k], ox, oy)], size, _GLYPH_GRAY, True)
        label_run = layout_run(lat, labels[k], 11, ox, 90, True)
        draw_run(c, lat, label_run, 11, _GLYPH_CYAN, True)
    return c


def word_demo():
    """kitab, with its kasra, shaped and positioned right to left. The
    letters are gray, the mark magenta."""
    w, h = 260, 100
    c = canvas(w, h)
    fill(c, PAPER)
    font = load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    text = ARABIC_KITAB
    size = 64
    x, y = 20, 64
    buffer = shape(font, text)
    run = position(font, buffer, size, x, y, "rtl", False)
    _hairline_seg(c, point(4, y), point(256, y), _GLYPH_DIM)
    for e, p in zip(buffer, run):
        col = _GLYPH_MAGENTA if is_mark(font, e.glyph) else _GLYPH_GRAY
        draw_run(c, font, [p], size, col, True)
    _caret_ticks(c, font, buffer, len(text), size, x, y, "rtl", False, _GLYPH_CYAN)
    return c


def mixed_demo():
    """"Book: " + kitab + ", again." itemized, each item shaped and
    positioned in its own script's font and direction, one after the
    other."""
    w, h = 300, 60
    c = canvas(w, h)
    fill(c, PAPER)
    lat = load_font(read_file("reference/chapter-16/roboto.json"))
    ar = load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    text = "Book: " + ARABIC_KITAB + ", again."
    size = 28
    y = 40
    cur_x = 12
    _hairline_seg(c, point(4, y), point(296, y), _GLYPH_DIM)
    for item in itemize(text):
        font = lat if item.script == "latin" else ar
        buffer = shape(font, item.text)
        run = position(font, buffer, size, cur_x, y, item.direction, True)
        _hairline_seg(c, point(cur_x, y + 3), point(cur_x, y + 10), _GLYPH_CYAN)
        for e, p in zip(buffer, run):
            col = _GLYPH_MAGENTA if is_mark(font, e.glyph) else _GLYPH_GRAY
            draw_run(c, font, [p], size, col, True)
        cur_x += buffer_advance(font, buffer, size, True)
    return c


def cluster_plate():
    """The chapter's whole argument: characters in on the top row,
    glyphs out on the bottom row, and a line from each character to the
    cluster it ended up in."""
    lat = load_font(read_file("reference/chapter-16/roboto.json"))
    ar = load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    w, h = 540, 210
    c = canvas(w, h)
    fill(c, PAPER)
    size = 52

    for font, text, direction, x0 in ((lat, "office", "ltr", 20), (ar, ARABIC_KITAB, "rtl", 290)):
        scale = size / font.units_per_em
        raw = glyph_buffer(font, text)

        pen = x0
        centers = []
        for e in raw:
            adv = glyph_advance(font, e.glyph) * scale
            wbox = max(adv, 12)
            _stroke_path(c, _polyline_path(
                [point(pen, 34), point(pen + wbox, 34),
                 point(pen + wbox, 92), point(pen, 92)], True),
                1.0, _GLYPH_DIM, "butt", "round")
            gx = pen + (wbox - adv) / 2.0
            draw_run(c, font, [Placement(e.glyph, gx, 80)], size, _GLYPH_GRAY, True)
            centers.append(pen + wbox / 2.0)
            pen += wbox + 14

        buffer = shape(font, text)
        run = position(font, buffer, size, x0, 180, direction, True)

        box_bounds = {}
        for e, p in zip(buffer, run):
            if is_mark(font, e.glyph):
                continue
            adv = glyph_advance(font, e.glyph) * scale
            lo, hi = p.x, p.x + adv
            if e.cluster in box_bounds:
                blo, bhi = box_bounds[e.cluster]
                box_bounds[e.cluster] = (min(blo, lo), max(bhi, hi))
            else:
                box_bounds[e.cluster] = (lo, hi)

        for e, p in zip(buffer, run):
            raw_name = glyph_name(font, ord(text[e.cluster])) if e.cluster < len(text) else None
            changed = is_mark(font, e.glyph) or e.glyph != raw_name
            col = _GLYPH_MAGENTA if changed else _GLYPH_GRAY
            draw_run(c, font, [p], size, col, True)

        for lo, hi in box_bounds.values():
            _stroke_path(c, _polyline_path(
                [point(lo, 134), point(hi, 134), point(hi, 192), point(lo, 192)], True),
                1.0, _GLYPH_CYAN, "butt", "round")

        cluster_starts = sorted(box_bounds.keys())
        for i in range(len(text)):
            start = max((s for s in cluster_starts if s <= i), default=cluster_starts[0])
            lo, hi = box_bounds[start]
            mid_bottom = (lo + hi) / 2.0
            _hairline_seg(c, point(centers[i], 92), point(mid_bottom, 134), _GLYPH_MAGENTA, 0.75)

    return c


def plate_19():
    """Chapter 19's plate: characters in, glyphs out, clusters joined."""
    return cluster_plate()
