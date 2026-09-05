{{flutter_js}}
{{flutter_build_config}}

(function () {
  function startFlutterApp(buildVersion) {
    var v = buildVersion || ("b" + new Date().getTime());
    if (window._flutter && window._flutter.buildConfig && Array.isArray(window._flutter.buildConfig.builds)) {
      window._flutter.buildConfig.builds.forEach(function (b) {
        if (b && b.mainJsPath) {
          // Append version query parameter to bust browser cache
          b.mainJsPath = b.mainJsPath + "?v=" + encodeURIComponent(v);
        }
      });
    }
    // Load Flutter without deprecated ServiceWorker caching
    window._flutter.loader.load();
  }

  var isLoaded = false;
  var fallbackTimer = setTimeout(function () {
    if (!isLoaded) {
      isLoaded = true;
      startFlutterApp();
    }
  }, 1200);

  // Fetch version.json without cache to obtain the unique build timestamp
  fetch("version.json?t=" + new Date().getTime(), { cache: "no-store" })
    .then(function (res) { return res.json(); })
    .then(function (data) {
      if (!isLoaded) {
        isLoaded = true;
        clearTimeout(fallbackTimer);
        var buildId = (data && data.version ? data.version : "1.0.0") + "." + (data && data.build_number ? data.build_number : new Date().getTime());
        startFlutterApp(buildId);
      }
    })
    .catch(function () {
      if (!isLoaded) {
        isLoaded = true;
        clearTimeout(fallbackTimer);
        startFlutterApp();
      }
    });
})();
