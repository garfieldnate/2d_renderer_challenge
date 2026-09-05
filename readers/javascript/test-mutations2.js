// More detailed mutation testing

import { strict as assert } from 'node:assert';

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
  let err = Math.floor(dx / 2); // CORRECT
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

console.log('Testing Bresenham error = 0 mutation with line (0,0) to (7,3):');
const c1 = new Canvas(10,10);
line_bresenham_correct(c1, 0, 0, 7, 3, new Color(1,1,1));
const correct = lit_pixels(c1);
console.log('  Correct: ' + JSON.stringify(correct));

const c2 = new Canvas(10,10);
line_bresenham_err0(c2, 0, 0, 7, 3, new Color(1,1,1));
const mutated = lit_pixels(c2);
console.log('  Mutated: ' + JSON.stringify(mutated));
console.log('  Mutation: ' + (JSON.stringify(correct) !== JSON.stringify(mutated) ? 'CAUGHT' : 'MISSED'));

console.log('\nTesting with line (0,0) to (4,2):');
const c3 = new Canvas(10,10);
line_bresenham_correct(c3, 0, 0, 4, 2, new Color(1,1,1));
const correct2 = lit_pixels(c3);
console.log('  Correct: ' + JSON.stringify(correct2));

const c4 = new Canvas(10,10);
line_bresenham_err0(c4, 0, 0, 4, 2, new Color(1,1,1));
const mutated2 = lit_pixels(c4);
console.log('  Mutated: ' + JSON.stringify(mutated2));
console.log('  Mutation: ' + (JSON.stringify(correct2) !== JSON.stringify(mutated2) ? 'CAUGHT' : 'MISSED'));
