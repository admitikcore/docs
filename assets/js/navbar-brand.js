// The landing hero carries the branding. Once it leaves the viewport, the navbar shows it again.
(function () {
  'use strict';

  const hero = document.querySelector('.td-home .td-cover-block');
  const navbar = document.querySelector('.td-home .td-navbar');
  if (!hero || !navbar || !('IntersectionObserver' in window)) return;

  new IntersectionObserver(function (entries) {
    navbar.classList.toggle('td-navbar-brand-revealed', !entries[0].isIntersecting);
  }).observe(hero);
})();
