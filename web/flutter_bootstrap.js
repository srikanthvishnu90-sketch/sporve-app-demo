{{flutter_js}}
{{flutter_build_config}}

// Auxiliary trust UI is deliberately loaded outside the Flutter canvas so it
// remains keyboard-accessible and can ship independently of generated HTML.
(function loadSporveTrustUi() {
  if (!document.querySelector('link[data-sporve-ai-transparency]')) {
    var styles = document.createElement('link');
    styles.rel = 'stylesheet';
    styles.href = 'ai-transparency.css';
    styles.setAttribute('data-sporve-ai-transparency', '');
    document.head.appendChild(styles);
  }
  if (!document.querySelector('script[data-sporve-ai-transparency]')) {
    var script = document.createElement('script');
    script.src = 'ai-transparency.js';
    script.async = true;
    script.setAttribute('data-sporve-ai-transparency', '');
    document.head.appendChild(script);
  }
})();

// Avoid the deprecated generated service worker. Production HTML and critical
// bundles use explicit cache headers, so a stale worker cannot pin old auth or
// AI safety behavior after a release.
_flutter.loader.load();
