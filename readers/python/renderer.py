"""The 2D Renderer Challenge - Chapter 1: The Canvas and the Color"""
import math


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

