/* Demo player: plays a scripted conversation or terminal session inside the active demo panel.
   Steps are revealed in order, prompts and commands are typed, tool calls show a short pending state.
   It plays only while its panel is the active tab and on screen, loops, and shows the end state
   for reduced motion. Markup: [data-play] holds [data-step] children, or [data-play-lines] treats
   every child line as a step and types the command after a prompt. */
(function () {
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function sleep(ms, run) {
    return new Promise(function (res, rej) {
      var t = setTimeout(function () { run.alive ? res() : rej("stop"); }, ms);
      run.timers.push(t);
    });
  }

  function setup(root) {
    var lineMode = root.hasAttribute("data-play-lines");
    var steps = lineMode ? Array.prototype.slice.call(root.children) : Array.prototype.slice.call(root.querySelectorAll("[data-step]"));
    var items = steps.map(function (el) {
      var typeEl = el.querySelector("[data-type]") || (el.hasAttribute("data-type") ? el : null);
      if (!typeEl && lineMode && el.querySelector(".t-prompt")) typeEl = el.querySelector(".t-cmd");
      return { el: el, type: typeEl, text: typeEl ? typeEl.textContent : "", pending: el.getAttribute("data-pending"), done: el.getAttribute("data-done") };
    });
    items.forEach(function (it) { if (it.pending) it.el.textContent = it.done; });
    if (reduce) return;
    var panel = root.closest(".demo-panel") || root;
    var run = null, visible = false;

    function reset() {
      items.forEach(function (it) {
        it.el.classList.add("pl-hide");
        it.el.classList.remove("pl-pending");
        if (it.type) it.type.textContent = "";
        if (it.pending) it.el.textContent = it.pending;
      });
      root.scrollTop = 0;
    }
    function showAll() {
      items.forEach(function (it) {
        it.el.classList.remove("pl-hide", "pl-pending");
        if (it.type) it.type.textContent = it.text;
        if (it.pending) it.el.textContent = it.done;
      });
    }
    function follow() {
      if (root.scrollHeight > root.clientHeight) root.scrollTop = root.scrollHeight;
    }
    async function play(r) {
      reset();
      await sleep(500, r);
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        var wait = parseInt(it.el.getAttribute("data-wait") || "", 10);
        await sleep(isNaN(wait) ? (lineMode ? 260 : 520) : wait, r);
        it.el.classList.remove("pl-hide");
        follow();
        if (it.type) {
          it.type.classList.add("pl-caret");
          for (var c = 1; c <= it.text.length; c++) {
            it.type.textContent = it.text.slice(0, c);
            await sleep(it.text.charAt(c - 1) === " " ? 55 : 28 + Math.random() * 34, r);
          }
          it.type.classList.remove("pl-caret");
          await sleep(lineMode ? 220 : 360, r);
        }
        if (it.pending) {
          it.el.classList.add("pl-pending");
          await sleep(1200, r);
          it.el.classList.remove("pl-pending");
          it.el.textContent = it.done;
        }
        follow();
      }
      await sleep(5200, r);
      if (r.alive) play(r).catch(function () {});
    }
    function start() {
      if (run) return;
      run = { alive: true, timers: [] };
      play(run).catch(function () {});
    }
    function stop() {
      if (!run) return;
      run.alive = false;
      run.timers.forEach(clearTimeout);
      run = null;
      showAll();
    }
    function check() {
      var active = !panel.classList.contains("demo-panel") || panel.classList.contains("active");
      if (active && visible) start(); else stop();
    }
    new MutationObserver(check).observe(panel, { attributes: true, attributeFilter: ["class"] });
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; check(); }, { threshold: 0.35 }).observe(root);
    } else { visible = true; check(); }
  }

  document.querySelectorAll("[data-play], [data-play-lines]").forEach(setup);
})();
