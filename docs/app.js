// The hero page list fills in once, the way it does in the app.
(function () {
  var rows = Array.prototype.slice.call(document.querySelectorAll('.row'));
  var foot = document.getElementById('foot');
  if (!rows.length) return;
  var still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (still) {
    rows.forEach(function (r) { r.classList.add('in'); });
    if (foot) foot.classList.add('in');
    return;
  }
  rows.forEach(function (r, i) {
    setTimeout(function () { r.classList.add('in'); }, 260 + i * 115);
  });
  if (foot) setTimeout(function () { foot.classList.add('in'); }, 260 + rows.length * 115 + 180);
})();

// Theme, remembered per browser.
(function () {
  var btn = document.getElementById('theme');
  if (!btn) return;
  var root = document.documentElement;
  btn.addEventListener('click', function () {
    var dark = root.getAttribute('data-theme')
      ? root.getAttribute('data-theme') === 'dark'
      : !window.matchMedia('(prefers-color-scheme: light)').matches;
    var next = dark ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    try { localStorage.setItem('theme', next); } catch (e) {}
  });
})();

// Live numbers from GitHub, with the page's own text as the fallback.
(function () {
  var repo = 'DeveloperSarim/web-cloner-mac';

  var stars = document.getElementById('stars');
  if (stars) {
    fetch('https://api.github.com/repos/' + repo)
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (d && typeof d.stargazers_count === 'number') stars.textContent = d.stargazers_count;
      })
      .catch(function () {});
  }

  var marks = document.querySelectorAll('[data-version]');
  if (marks.length) {
    fetch('https://api.github.com/repos/' + repo + '/releases/latest')
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (!d || !d.tag_name) return;
        var v = d.tag_name.replace(/^v/, '');
        marks.forEach(function (el) {
          el.textContent = (el.getAttribute('data-version') || '').replace('%s', v) || v;
        });
      })
      .catch(function () {});
  }
})();

// The menu is a <details>, so it needs closing when you click away or hit Escape.
(function () {
  var menu = document.getElementById('menu');
  if (!menu) return;
  document.addEventListener('click', function (e) {
    if (menu.open && !menu.contains(e.target)) menu.open = false;
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && menu.open) { menu.open = false; menu.querySelector('summary').focus(); }
  });
})();
