{{flutter_js}}
{{flutter_build_config}}
// Explicit asset version prevents the local preview retaining an older app
// shell after rebuilding the independently bundled 3D viewer.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += '?v=alpine-6';
}
_flutter.loader.load();
