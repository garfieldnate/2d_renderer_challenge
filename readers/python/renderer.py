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
