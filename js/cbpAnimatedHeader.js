/**
 * cbpAnimatedHeader.js v1.1.0
 *
 * Toggles `navbar-shrink` on the fixed navbar once the user has scrolled
 * past `changeHeaderOn` pixels. Uses requestAnimationFrame instead of a
 * setTimeout throttle so the class flip is synced with the next paint —
 * no perceptible scroll "skip" at the threshold.
 *
 * Licensed under the MIT license.
 */
(function () {
  var header = document.querySelector('.navbar-fixed-top');
  if (!header) return;

  var changeHeaderOn = 300;
  var ticking = false;
  var isShrunk = false;

  function update() {
    var sy = window.pageYOffset || document.documentElement.scrollTop;
    var shouldShrink = sy >= changeHeaderOn;
    if (shouldShrink !== isShrunk) {
      classie[shouldShrink ? 'add' : 'remove'](header, 'navbar-shrink');
      isShrunk = shouldShrink;
    }
    ticking = false;
  }

  window.addEventListener('scroll', function () {
    if (!ticking) {
      window.requestAnimationFrame(update);
      ticking = true;
    }
  }, { passive: true });

  // Set the initial state in case the page loads already scrolled.
  update();
})();
