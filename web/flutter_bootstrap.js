{{flutter_js}}
{{flutter_build_config}}

// Avoid the deprecated generated service worker. Production HTML and critical
// bundles use explicit cache headers, so a stale worker cannot pin old auth or
// AI safety behavior after a release.
_flutter.loader.load();
