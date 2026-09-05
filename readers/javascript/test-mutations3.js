// Test steep swap and thick line mutations

class Color { 
  constructor(r,g,b) { 
    this.red=r; this.green=g; this.blue=b; 
  }
}

class Canvas { 
  constructor(w,h) { 
    this.width=w; this.height=h; 
    this.pixels=Array(w*h).fill(null).map(()=>new Color(0,0,0)); 
  }
  write_pixel(x,y,c) { 
    if(x>=0&&x<this.width&&y>=0&&y<this.height) this.pixels[y*this.width+x]=c; 
  }
  pixel_at(x,y) { 
    return x>=0&&x<this.width&&y>=0&&y<this.height ? this.pixels[y*this.width+x] : new Color(0,0,0); 
  }
}

class HalfPlane {
  constructor(px, py, nx, ny) {
    this.px = px;
    this.py = py;
    this.nx = nx;
    this.ny = ny;
  }
}

function lit_pixels(canvas) {
  const pixels = [];
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const pixel = canvas.pixel_at(x, y);
      if (pixel.red > 0 || pixel.green > 0 || pixel.blue > 0) {
        pixels.push([x, y]);
      }
    }
  }
  return pixels;
}

function line_bresenham_no_steep_swap(canvas, x0, y0, x1, y1, color) {
  // MUTATION: steep swap removed
  if (x0 > x1) {
    [x0, x1] = [x1, x0];
    [y0, y1] = [y1, y0];
  }
  const dx = x1 - x0;
  const dy = Math.abs(y1 - y0);
  const ystep = y0 < y1 ? 1 : -1;
  let err = Math.floor(dx / 2);
  let y = y0;
  for (let x = x0; x <= x1; x++) {
    canvas.write_pixel(x, y, color);
    err = err - dy;
    if (err < 0) {
      y = y + ystep;
      err = err + dx;
    }
  }
}

function line_bresenham_correct(canvas, x0, y0, x1, y1, color) {
  let steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);
  if (steep) {
    [x0, y0] = [y0, x0];
    [x1, y1] = [y1, x1];
  }
  if (x0 > x1) {
    [x0, x1] = [x1, x0];
    [y0, y1] = [y1, y0];
  }
  const dx = x1 - x0;
  const dy = Math.abs(y1 - y0);
  const ystep = y0 < y1 ? 1 : -1;
  let err = Math.floor(dx / 2);
  let y = y0;
  for (let x = x0; x <= x1; x++) {
    if (steep) {
      canvas.write_pixel(y, x, color);
    } else {
      canvas.write_pixel(x, y, color);
    }
    err = err - dy;
    if (err < 0) {
      y = y + ystep;
      err = err + dx;
    }
  }
}

console.log('Testing steep swap forgotten with line (1,1) to (3,7):');
const c1 = new Canvas(10,10);
line_bresenham_correct(c1, 1, 1, 3, 7, new Color(1,1,1));
const correct = lit_pixels(c1);
console.log('  Correct: ' + JSON.stringify(correct));

const c2 = new Canvas(10,10);
line_bresenham_no_steep_swap(c2, 1, 1, 3, 7, new Color(1,1,1));
const mutated = lit_pixels(c2);
console.log('  Mutated: ' + JSON.stringify(mutated));
console.log('  Mutation: ' + (JSON.stringify(correct) !== JSON.stringify(mutated) ? 'CAUGHT' : 'MISSED'));

// Test thick_line with wrong normal directions
class ThickLineWrongNormals {
  constructor(x0, y0, x1, y1, width) {
    const px0 = x0 + 0.5;
    const py0 = y0 + 0.5;
    const px1 = x1 + 0.5;
    const py1 = y1 + 0.5;
    const dx = px1 - px0;
    const dy = py1 - py0;
    const len = Math.sqrt(dx * dx + dy * dy);
    let dsx = 0, dsy = 0, nsx = 0, nsy = 0;
    if (len > 0) {
      dsx = dx / len;
      dsy = dy / len;
      nsx = -dsy;
      nsy = dsx;
    }
    const half_width = width / 2;
    this.half_planes = [
      new HalfPlane(px0, py0, dsx, dsy),
      new HalfPlane(px1, py1, -dsx, -dsy),
      // MUTATION: normals point outward instead of inward
      new HalfPlane(px0 + nsx * half_width, py0 + nsy * half_width, nsx, nsy),
      new HalfPlane(px0 - nsx * half_width, py0 - nsy * half_width, -nsx, -nsy)
    ];
  }
}

class ThickLineCorrect {
  constructor(x0, y0, x1, y1, width) {
    const px0 = x0 + 0.5;
    const py0 = y0 + 0.5;
    const px1 = x1 + 0.5;
    const py1 = y1 + 0.5;
    const dx = px1 - px0;
    const dy = py1 - py0;
    const len = Math.sqrt(dx * dx + dy * dy);
    let dsx = 0, dsy = 0, nsx = 0, nsy = 0;
    if (len > 0) {
      dsx = dx / len;
      dsy = dy / len;
      nsx = -dsy;
      nsy = dsx;
    }
    const half_width = width / 2;
    this.half_planes = [
      new HalfPlane(px0, py0, dsx, dsy),
      new HalfPlane(px1, py1, -dsx, -dsy),
      new HalfPlane(px0 + nsx * half_width, py0 + nsy * half_width, -nsx, -nsy),
      new HalfPlane(px0 - nsx * half_width, py0 - nsy * half_width, nsx, nsy)
    ];
  }
}

function inside_correct(shape, x, y) {
  for (const hp of shape.half_planes) {
    const vx = x - hp.px;
    const vy = y - hp.py;
    if (vx * hp.nx + vy * hp.ny < 0) {
      return false;
    }
  }
  return true;
}

console.log('\nTesting thick_line with outward-facing normals:');
const correct_shape = new ThickLineCorrect(0, 0, 4, 0, 1);
const correct_inside = inside_correct(correct_shape, 2.5, 0.5);
console.log('  Correct shape inside(2.5, 0.5): ' + correct_inside);

const wrong_shape = new ThickLineWrongNormals(0, 0, 4, 0, 1);
const wrong_inside = inside_correct(wrong_shape, 2.5, 0.5);
console.log('  Wrong normals inside(2.5, 0.5): ' + wrong_inside);
console.log('  Mutation: ' + (correct_inside !== wrong_inside ? 'CAUGHT' : 'MISSED'));
