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
    """The shoelace formula over every edge of every subpath, unsigned."""
    total = 0.0
    for e in edges(p):
        total += e.a.x * e.b.y - e.b.x * e.a.y
    return abs(total) / 2.0


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
