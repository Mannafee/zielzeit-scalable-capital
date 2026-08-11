/* Copy buttons plus restrained, progressive-enhancement motion. */

/* Copy buttons on the command blocks. */
(function () {
  "use strict";

  Array.prototype.forEach.call(document.querySelectorAll(".copy"), function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");

      var done = function () {
        var was = btn.textContent;
        btn.textContent = "Copied";
        btn.setAttribute("data-done", "");
        setTimeout(function () {
          btn.textContent = was;
          btn.removeAttribute("data-done");
        }, 1600);
      };

      var fallback = function () {
        var field = document.createElement("textarea");
        field.value = text;
        field.setAttribute("readonly", "");
        field.style.position = "fixed";
        field.style.opacity = "0";
        document.body.appendChild(field);
        field.select();
        try { document.execCommand("copy"); done(); } catch (e) { btn.textContent = "Press ⌘C"; }
        document.body.removeChild(field);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, fallback);
      } else {
        fallback();
      }
    });
  });
})();

/* Reveal the page in readable groups as it enters the viewport. Content stays
   fully visible when JavaScript is unavailable or reduced motion is requested. */
(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduced || !("IntersectionObserver" in window)) { return; }

  var selector = [
    ".specs li",
    ".band .eyebrow",
    ".band h2",
    ".band .sub",
    ".proof",
    ".reveal",
    ".cards article",
    ".callouts > div",
    ".feature-card",
    ".steps li",
    ".shot",
    ".build",
    ".close .wrap"
  ].join(",");
  var targets = Array.prototype.slice.call(document.querySelectorAll(selector));

  targets.forEach(function (target, index) {
    target.classList.add("scroll-reveal");
    target.style.setProperty("--reveal-delay", ((index % 5) * 55) + "ms");
    if (target.getBoundingClientRect().top < window.innerHeight * 0.96) {
      target.classList.add("is-visible");
    }
  });
  document.documentElement.classList.add("motion-ready");

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) { return; }
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  }, { rootMargin: "0px 0px -8%", threshold: 0.08 });

  targets.forEach(function (target) {
    if (!target.classList.contains("is-visible")) { observer.observe(target); }
  });
})();

/* A fine progress line and an active section marker turn the sticky nav into a
   map of the page rather than a floating row of unrelated links. */
(function () {
  "use strict";

  var progress = document.querySelector("[data-scroll-progress]");
  var links = Array.prototype.slice.call(document.querySelectorAll('.nav__links a[href^="#"]'));
  var ticking = false;

  function updateProgress() {
    var range = document.documentElement.scrollHeight - window.innerHeight;
    var value = range > 0 ? Math.min(Math.max(window.scrollY / range, 0), 1) : 0;
    if (progress) { progress.style.transform = "scaleX(" + value + ")"; }
    ticking = false;
  }

  window.addEventListener("scroll", function () {
    if (ticking) { return; }
    ticking = true;
    window.requestAnimationFrame(updateProgress);
  }, { passive: true });
  updateProgress();

  if (!("IntersectionObserver" in window)) { return; }
  var sectionObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) { return; }
      links.forEach(function (link) {
        var active = link.getAttribute("href") === "#" + entry.target.id;
        if (active) { link.setAttribute("aria-current", "true"); }
        else { link.removeAttribute("aria-current"); }
      });
    });
  }, { rootMargin: "-32% 0px -58%", threshold: 0 });

  links.forEach(function (link) {
    var section = document.querySelector(link.getAttribute("href"));
    if (section) { sectionObserver.observe(section); }
  });
})();

/* The desktop stage gets a soft cursor-following reflection. It changes only a
   gradient position, so the 2x app screenshot stays pixel-crisp. */
(function () {
  "use strict";

  var stage = document.querySelector("[data-tilt]");
  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var precisePointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  if (!stage || reduced || !precisePointer) { return; }

  stage.addEventListener("pointermove", function (event) {
    var bounds = stage.getBoundingClientRect();
    var x = ((event.clientX - bounds.left) / bounds.width) * 100;
    var y = ((event.clientY - bounds.top) / bounds.height) * 100;
    stage.style.setProperty("--spot-x", x.toFixed(1) + "%");
    stage.style.setProperty("--spot-y", y.toFixed(1) + "%");
  });

  stage.addEventListener("pointerleave", function () {
    stage.style.removeProperty("--spot-x");
    stage.style.removeProperty("--spot-y");
  });
})();
