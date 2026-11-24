// Cache-busts the Flutter web build after `flutter build web`.
//
// Flutter always names its bundle main.dart.js and its loader
// flutter_bootstrap.js, so a browser that cached either keeps running the old
// app after a deploy. This stamps both URLs with a content hash. index.html is
// served with no-cache, so every visit picks up the new URLs at once.
//
// It also stops registering Flutter's deprecated service worker and removes any
// left over from older builds. Firebase Messaging's own worker is kept, and
// LaunchWatch's offline worker (web/sw.js) gets the same hash so each deploy
// replaces its cached copy of the app. CanvasKit loads from this site rather
// than Google's CDN, so the offline worker can keep it.
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2] ?? "app/build/web";
const read = (name) => readFileSync(join(dir, name), "utf8");
const write = (name, text) => writeFileSync(join(dir, name), text);

const hash = createHash("sha256").update(read("main.dart.js")).digest("hex").slice(0, 12);

let bootstrap = read("flutter_bootstrap.js");
const stampedMain = `"mainJsPath":"main.dart.js?v=${hash}"`;
if (!bootstrap.includes('"mainJsPath":"main.dart.js"')) {
  throw new Error("flutter_bootstrap.js no longer has the expected mainJsPath; update stamp-web.mjs");
}
bootstrap = bootstrap.replace('"mainJsPath":"main.dart.js"', stampedMain);
const loaderCall = '_flutter.loader.load({ config: { canvasKitBaseUrl: "/canvaskit/" } });';
bootstrap = bootstrap.replace(/_flutter\.loader\.load\(\{[\s\S]*?\n\}\);\s*$/, loaderCall + "\n");
if (!bootstrap.trimEnd().endsWith(loaderCall)) {
  throw new Error("Could not replace the loader call in flutter_bootstrap.js");
}
write("flutter_bootstrap.js", bootstrap);

let index = read("index.html");
const cleanup = `<script>
    // Remove Flutter service workers left by older LaunchWatch builds.
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function (regs) {
        regs.forEach(function (r) {
          var url = (r.active || r.waiting || r.installing || {}).scriptURL || '';
          if (url.indexOf('flutter_service_worker') !== -1) r.unregister();
        });
      });
    }
  </script>
  `;
index = index.replace(/<script src="flutter_bootstrap\.js(\?v=[^"]*)?" async><\/script>/, `${cleanup}<script src="flutter_bootstrap.js?v=${hash}" async></script>`);
if (!index.includes(`flutter_bootstrap.js?v=${hash}`)) {
  throw new Error("Could not stamp flutter_bootstrap.js in index.html");
}
write("index.html", index);

const worker = read("sw.js");
if (!worker.includes("'__BUILD__'")) throw new Error("sw.js no longer has the __BUILD__ placeholder");
write("sw.js", worker.replace("'__BUILD__'", `'${hash}'`));

console.log(`Stamped web build ${hash}`);
