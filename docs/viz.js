/* Visual explainer for this project site: shape and flow only, drawn on canvas.
   Each canvas runs only while visible and shows one calm frame for reduced motion. */
(function () {
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var C = { cyan: "#62d6ff", blue: "#6aa9ff", warm: "#ffc266", mint: "#7be0b0", coral: "#ff8fa3", ice: "#bdeeff" };
  var TAU = Math.PI * 2;
  function rgba(hex, a) {
    var n = parseInt(hex.slice(1), 16);
    return "rgba(" + (n >> 16) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a.toFixed(3) + ")";
  }
  function clamp(v, a, b) { return Math.min(b, Math.max(a, v)); }
  function ease(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
  function rng(seed) {
    var s = seed >>> 0;
    return function () {
      s = (s + 0x6d2b79f5) >>> 0;
      var t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  var MONO = "600 11px 'Geist Mono', ui-monospace, Menlo, monospace";
  function stage(canvas, init, draw) {
    var ctx = canvas.getContext("2d");
    var w = 0, h = 0, visible = false, raf = 0, last = 0, t0 = 0, state = null;
    function size() {
      var r = canvas.getBoundingClientRect();
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = Math.max(1, Math.round(r.width));
      h = Math.max(1, Math.round(r.height));
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      state = init(w, h, state);
      if (reduce || !visible) frame(performance.now(), true);
    }
    function frame(now, still) {
      if (!t0) t0 = now;
      var t = reduce ? 40 : (now - t0) / 1000;
      var dt = Math.min(0.05, last ? (now - last) / 1000 : 0.016);
      last = now;
      ctx.clearRect(0, 0, w, h);
      draw(ctx, w, h, t, dt, state, reduce || still);
      if (!reduce && visible && !still) raf = requestAnimationFrame(function (n) { frame(n, false); });
    }
    if ("ResizeObserver" in window) new ResizeObserver(size).observe(canvas);
    else window.addEventListener("resize", size);
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) {
        visible = es[0].isIntersecting;
        cancelAnimationFrame(raf);
        last = 0;
        if (visible && !reduce) raf = requestAnimationFrame(function (n) { frame(n, false); });
      }).observe(canvas);
    } else {
      visible = true;
      if (!reduce) raf = requestAnimationFrame(function (n) { frame(n, false); });
    }
    size();
  }
  function bez(p0, p1, p2, p3, u) {
    var m = 1 - u;
    return m * m * m * p0 + 3 * m * m * u * p1 + 3 * m * u * u * p2 + u * u * u * p3;
  }
  var q = function (id) { return document.getElementById(id); };
  /* Hero: small containers drift across the field; one of them is always being assembled. */
  function heroDocker(canvas) {
    var R = rng(9);
    var layers = [C.cyan, C.blue, C.mint, C.warm, C.coral];
    function mk(w, h) {
      var arr = [];
      for (var i = 0; i < 16; i++) arr.push({ x: R() * w, y: h * (0.08 + R() * 0.84), s: 0.5 + R() * 0.7, v: 6 + R() * 14, k: 2 + Math.floor(R() * 3), c: Math.floor(R() * 5), ph: R() * TAU });
      return arr;
    }
    return stage(canvas, function (w, h, old) { return { items: mk(w, h) }; }, function (ctx, w, h, t, dt, st, still) {
      st.items.forEach(function (it) {
        if (!still) { it.x += it.v * dt; if (it.x > w + 60) { it.x = -60; it.y = h * (0.08 + R() * 0.84); } }
        var bw = 46 * it.s, bh = 30 * it.s, bob = still ? 0 : Math.sin(t * 0.8 + it.ph) * 3;
        var x = it.x, y = it.y + bob;
        ctx.fillStyle = "rgba(11,42,76,0.55)"; ctx.strokeStyle = rgba(C.ice, 0.28); ctx.lineWidth = 1;
        roundRect(ctx, x, y, bw, bh, 5); ctx.fill(); ctx.stroke();
        for (var l = 0; l < it.k; l++) {
          ctx.fillStyle = rgba(layers[(it.c + l) % 5], 0.55);
          ctx.fillRect(x + 5, y + 5 + l * ((bh - 10) / it.k), bw - 10, (bh - 10) / it.k - 2);
        }
      });
    });
  }

  /* Block: image layers drop into a container, then the services come up. */
  function buildDocker(canvas) {
    var names = [["AlmaLinux", C.blue], ["PostgreSQL + SVN", C.mint], ["Java 21", C.warm], ["Polarion", C.cyan]];
    var ports = [["Polarion", ":80", C.cyan], ["Mailpit", ":8025", C.warm], ["Debugger", ":5005", C.coral]];
    var T = 11;
    return stage(canvas, function () { return {}; }, function (ctx, w, h, t, dt, s, still) {
      var u = still ? 9 : (t % T);
      var cw = Math.min(w * 0.46, 300), ch = h * 0.74, cx = w * 0.12, cy = h * 0.14;
      ctx.strokeStyle = rgba(C.ice, 0.7); ctx.lineWidth = 2;
      roundRect(ctx, cx, cy, cw, ch, 12); ctx.stroke();
      ctx.font = MONO; ctx.textAlign = "left"; ctx.fillStyle = "rgba(255,255,255,0.7)";
      ctx.fillText("CONTAINER", cx + 4, cy - 8);
      var lh = (ch - 28) / 4;
      for (var i = 0; i < 4; i++) {
        var start = 0.6 + i * 1.5, p = ease(clamp((u - start) / 1.1, 0, 1));
        if (p <= 0) continue;
        var ty = cy + ch - 12 - (i + 1) * lh + 3;
        var y = ty - (1 - p) * (ch + 40);
        ctx.fillStyle = rgba(names[i][1], 0.2 + 0.5 * p);
        roundRect(ctx, cx + 12, y, cw - 24, lh - 6, 8); ctx.fill();
        ctx.strokeStyle = rgba(names[i][1], 0.95); ctx.lineWidth = 1.4; ctx.stroke();
        ctx.fillStyle = "#fff"; ctx.textAlign = "left";
        ctx.fillText(names[i][0].toUpperCase(), cx + 26, y + (lh - 6) / 2 + 4);
      }
      var up = clamp((u - 7.2) / 1.2, 0, 1);
      var px = cx + cw + 40, pw = Math.max(110, w - px - 14);
      for (var k = 0; k < 3; k++) {
        var yy = cy + 24 + k * (ch / 3), on = clamp(up * 3 - k, 0, 1);
        ctx.strokeStyle = rgba(ports[k][2], 0.2 + on * 0.6); ctx.lineWidth = 1.4;
        ctx.setLineDash([4, 5]);
        ctx.beginPath(); ctx.moveTo(cx + cw, cy + ch / 2); ctx.bezierCurveTo(cx + cw + 20, cy + ch / 2, px - 24, yy + 14, px, yy + 14); ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = rgba(ports[k][2], 0.08 + on * 0.18);
        roundRect(ctx, px, yy, pw, 30, 9); ctx.fill();
        ctx.strokeStyle = rgba(ports[k][2], 0.35 + on * 0.6); ctx.stroke();
        ctx.fillStyle = on > 0.5 ? "#fff" : "rgba(255,255,255,0.45)"; ctx.textAlign = "left";
        ctx.fillText(ports[k][0].toUpperCase() + "  " + ports[k][1], px + 12, yy + 19);
        if (on > 0.95) {
          var pulse = still ? 0.6 : 0.5 + 0.5 * Math.sin(t * 3 + k);
          ctx.fillStyle = rgba(C.mint, 0.5 + pulse * 0.5);
          ctx.beginPath(); ctx.arc(px + pw - 14, yy + 15, 4, 0, TAU); ctx.fill();
        }
      }
    });
  }
  if (q("viz-hero")) heroDocker(q("viz-hero"));
  if (q("viz-flow")) buildDocker(q("viz-flow"));
})();
