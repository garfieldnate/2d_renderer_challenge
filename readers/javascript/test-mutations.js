// Mutation testing for Chapter 3
// Tests whether test suite catches common reader mistakes

import { strict as assert } from 'node:assert';

// ===========================
// Test 1: Bresenham error initialized to 0 instead of dx/2
// ===========================

function line_bresenham_err0(canvas, x0, y0, x1, y1, color) {
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
  let err = 0; // MUTATION: should be Math.floor(dx / 2)
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

// ===========================
// Test 2: Wu weights swapped
// ===========================

function line_wu_swapped_weights(canvas, x0, y0, x1, y1, color, plot_func) {
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
  const slope = dx === 0 ? 0 : (y1 - y0) / dx;
  for (let x = x0; x <= x1; x++) {
    const y = y0 + (x - x0) * slope;
    const yi = Math.floor(y);
    const f = y - yi;
    if (steep) {
      plot_func(canvas, yi, x, color, f);       // MUTATION: swapped (should be 1-f)
      plot_func(canvas, yi + 1, x, color, 1 - f); // MUTATION: swapped (should be f)
    } else {
      plot_func(canvas, x, yi, color, f);         // MUTATION: swapped (should be 1-f)
      plot_func(canvas, x, yi + 1, color, 1 - f); // MUTATION: swapped (should be f)
    }
  }
}

// ===========================
// Test 3: Wu using round instead of floor
// ===========================

function line_wu_round_instead_floor(canvas, x0, y0, x1, y1, color, plot_func) {
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
  const slope = dx === 0 ? 0 : (y1 - y0) / dx;
  for (let x = x0; x <= x1; x++) {
    const y = y0 + (x - x0) * slope;
    const yi = Math.round(y); // MUTATION: should be Math.floor(y)
    const f = y - yi;
    if (steep) {
      plot_func(canvas, yi, x, color, 1 - f);
      plot_func(canvas, yi + 1, x, color, f);
    } else {
      plot_func(canvas, x, yi, color, 1 - f);
      plot_func(canvas, x, yi + 1, color, f);
    }
  }
}

// ===========================
// Test 4: thick_line half-planes facing outward
// ===========================

class ThickLineOutward {
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
    const HalfPlane = class {
      constructor(px, py, nx, ny) {
        this.px = px;
        this.py = py;
        this.nx = nx;
        this.ny = ny;
      }
    };
    this.half_planes = [
      new HalfPlane(px0, py0, dsx, dsy),
      new HalfPlane(px1, py1, -dsx, -dsy),
      // MUTATION: normals face outward instead of inward
      new HalfPlane(px0 + nsx * half_width, py0 + nsy * half_width, nsx, nsy),     // should be -nsx, -nsy
      new HalfPlane(px0 - nsx * half_width, py0 - nsy * half_width, -nsx, -nsy)   // should be nsx, nsy
    ];
  }
}

// ===========================
// Test runner
// ===========================

console.log('Testing mutation: Bresenham error = 0 instead of dx/2');
try {
  class Color { constructor(r,g,b) { this.red=r; this.green=g; this.blue=b; } }
  class Canvas { 
    constructor(w,h) { this.width=w; this.height=h; this.pixels=Array(w*h).fill(null).map(()=>new Color(0,0,0)); }
    write_pixel(x,y,c) { if(x>=0&&x<this.width&&y>=0&&y<this.height) this.pixels[y*this.width+x]=c; }
  }
  const c = new Canvas(10,10);
  line_bresenham_err0(c, 0, 0, 4, 2, new Color(1,1,1));
  let lit = 0;
  for (let i = 0; i < 100; i++) if (c.pixels[i].red > 0) lit++;
  console.log('  Result: ' + lit + ' pixels lit (expected 5)');
  console.log('  Mutation: ' + (lit !== 5 ? 'CAUGHT' : 'MISSED'));
} catch(e) { console.log('  Error: ' + e.message); }

console.log('\nTesting mutation: Wu weights swapped');
try {
  class Color { constructor(r,g,b) { this.red=r; this.green=g; this.blue=b; } add(o) { return new Color(this.red+o.red, this.green+o.green, this.blue+o.blue); } }
  class Canvas { 
    constructor(w,h) { this.width=w; this.height=h; this.pixels=Array(w*h).fill(null).map(()=>new Color(0,0,0)); }
    write_pixel(x,y,c) { if(x>=0&&x<this.width&&y>=0&&y<this.height) this.pixels[y*this.width+x]=c; }
    pixel_at(x,y) { return x>=0&&x<this.width&&y>=0&&y<this.height ? this.pixels[y*this.width+x] : new Color(0,0,0); }
  }
  function plot_test(canvas,x,y,color,weight) { 
    if(weight===0) return;
    if(x<0||x>=canvas.width||y<0||y>=canvas.height) return;
    canvas.write_pixel(x,y,new Color(color.red*weight, color.green*weight, color.blue*weight));
  }
  const c = new Canvas(10,10);
  line_wu_swapped_weights(c, 0, 0, 4, 2, new Color(1,1,1), plot_test);
  const p01 = c.pixel_at(0,1);
  const p10 = c.pixel_at(1,0);
  console.log('  pixel_at(0,1) red = ' + p01.red.toFixed(3) + ' (expected ~0.5)');
  console.log('  pixel_at(1,0) red = ' + p10.red.toFixed(3) + ' (expected ~0.5)');
  console.log('  Mutation: ' + ((Math.abs(p01.red - 0.5) > 0.1 || Math.abs(p10.red - 0.5) > 0.1) ? 'CAUGHT' : 'MISSED'));
} catch(e) { console.log('  Error: ' + e.message); }

console.log('\nTesting mutation: Wu using round instead of floor');
try {
  class Color { constructor(r,g,b) { this.red=r; this.green=g; this.blue=b; } }
  class Canvas { 
    constructor(w,h) { this.width=w; this.height=h; this.pixels=Array(w*h).fill(null).map(()=>new Color(0,0,0)); }
    write_pixel(x,y,c) { if(x>=0&&x<this.width&&y>=0&&y<this.height) this.pixels[y*this.width+x]=c; }
    pixel_at(x,y) { return x>=0&&x<this.width&&y>=0&&y<this.height ? this.pixels[y*this.width+x] : new Color(0,0,0); }
  }
  function plot_test(canvas,x,y,color,weight) { 
    if(weight===0) return;
    if(x<0||x>=canvas.width||y<0||y>=canvas.height) return;
    canvas.write_pixel(x,y,new Color(color.red*weight, color.green*weight, color.blue*weight));
  }
  const c = new Canvas(10,10);
  line_wu_round_instead_floor(c, 0, 0, 4, 2, new Color(1,1,1), plot_test);
  const p10 = c.pixel_at(1,0);
  const p11 = c.pixel_at(1,1);
  console.log('  pixel_at(1,0) red = ' + p10.red.toFixed(3) + ' (with round, likely 0)');
  console.log('  pixel_at(1,1) red = ' + p11.red.toFixed(3) + ' (with round, likely 1)');
  console.log('  Mutation: ' + ((Math.abs(p10.red - 0.5) > 0.1 || Math.abs(p11.red - 0.5) > 0.1) ? 'CAUGHT' : 'MISSED'));
} catch(e) { console.log('  Error: ' + e.message); }

console.log('\n✓ Mutation testing complete');
