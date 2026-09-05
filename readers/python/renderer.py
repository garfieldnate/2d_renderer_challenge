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


def mix(a, b, t):
    """Mix two colors. With linear blending on, mix in light space.
    With it off, mix in encoded file space (like web browsers do)."""
    if _linear_blending:
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
                painted = mix(current, color, coverage_val)
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
