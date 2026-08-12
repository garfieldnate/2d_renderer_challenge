/* ============================================================
   The 2D Renderer Challenge — figure scaffold
   Every figure in the book is drawn with the canvas API and ships
   its own source, pulled from the live function so the code shown
   is provably the code that ran.

   Plate.add(id, aspect, draw)
       draw(ctx, w, h, p, dpr)   w/h in CSS pixels, already scaled
                                 p = theme palette, dpr for raw work
   Plate.source(host, title, text)
   ============================================================ */
(function (global) {
  "use strict";

  var MONO = 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace';
  var figures = [];

  /* current theme colours, read from the stylesheet so figures follow it */
  function P() {
    var cs = getComputedStyle(document.documentElement);
    function g(n) { return cs.getPropertyValue(n).trim(); }
    return {
      ink: g('--ink'), ink2: g('--ink-2'), ink3: g('--ink-3'), rule: g('--rule'),
      cyan: g('--cyan'), magenta: g('--magenta'), plate: g('--plate'),
      surface: g('--surface'), cyanSoft: g('--cyan-soft'), magentaSoft: g('--magenta-soft')
    };
  }

  function hex2rgb(hex) {
    var h = hex.replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function rgba(hex, a) {
    var c = hex2rgb(hex);
    return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')';
  }
  function mix(a, b, t) {
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  }
  function rgbs(c) { return 'rgb(' + Math.round(c[0]) + ',' + Math.round(c[1]) + ',' + Math.round(c[2]) + ')'; }

  function label(ctx, t, x, y, col, sz, align) {
    ctx.font = (sz || 10) + 'px ' + MONO;
    ctx.fillStyle = col;
    ctx.textAlign = align || 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.fillText(t, x, y);
    ctx.textAlign = 'left';
  }
  function offcan(w, h) {
    var c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(w));
    c.height = Math.max(1, Math.round(h));
    return c;
  }

  /* ---- sRGB transfer functions, used by more than one figure ---- */
  function s2l(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
  function l2s(v) { return v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055; }

  function size(rec) {
    var w = rec.c.clientWidth || (rec.c.parentNode && rec.c.parentNode.clientWidth) || 360;
    var h = Math.round(w * rec.aspect);
    var dpr = Math.min(global.devicePixelRatio || 1, 2);
    rec.c.width = Math.round(w * dpr);
    rec.c.height = Math.round(h * dpr);
    rec.c.style.height = h + 'px';
    rec.w = w; rec.h = h; rec.dpr = dpr;
  }
  function paint(rec) {
    var ctx = rec.c.getContext('2d');
    ctx.setTransform(rec.dpr, 0, 0, rec.dpr, 0, 0);
    ctx.clearRect(0, 0, rec.w, rec.h);
    ctx.save();
    rec.draw(ctx, rec.w, rec.h, P(), rec.dpr);
    ctx.restore();
  }
  function repaintAll() {
    figures.forEach(function (r) { size(r); paint(r); });
  }

  /* every figure carries the code that drew it */
  function source(host, title, text) {
    if (!host) return;
    var d = document.createElement('details'); d.className = 'src';
    var s = document.createElement('summary'); s.textContent = title;
    var pre = document.createElement('pre'), code = document.createElement('code');
    code.textContent = text;
    pre.appendChild(code); d.appendChild(s); d.appendChild(pre); host.appendChild(d);
  }

  function add(id, aspect, draw) {
    var c = document.getElementById(id);
    if (!c) return;
    var rec = { c: c, aspect: aspect, draw: draw };
    figures.push(rec);
    size(rec); paint(rec);
    source(c.parentNode, 'canvas source',
      "Plate.add('" + id + "', " + aspect + ", " + draw.toString() + ");");
  }

  /* ---- lifecycle ---- */
  var rt;
  global.addEventListener('resize', function () {
    clearTimeout(rt); rt = setTimeout(repaintAll, 120);
  });
  var mq = global.matchMedia('(prefers-color-scheme: dark)');
  if (mq.addEventListener) mq.addEventListener('change', repaintAll);
  new MutationObserver(repaintAll).observe(document.documentElement,
    { attributes: true, attributeFilter: ['data-theme'] });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(repaintAll);

  global.Plate = {
    add: add, source: source, repaintAll: repaintAll,
    P: P, rgba: rgba, hex2rgb: hex2rgb, mix: mix, rgbs: rgbs,
    label: label, offcan: offcan, s2l: s2l, l2s: l2s, MONO: MONO,
    helpers: [P, rgba, hex2rgb, mix, rgbs, label, offcan, s2l, l2s, add, size, paint]
  };
})(window);
