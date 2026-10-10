# Performance and Bandwidth Optimization

Cost optimization and performance align well for a static site: fewer bytes transferred means faster page loads and lower bandwidth consumption.

## Practices

- keep JavaScript minimal;
- avoid frontend frameworks unless they solve an actual requirement;
- compress/resize images before commit;
- use modern image formats when visual assets are added;
- avoid third-party font payloads when system fonts are acceptable;
- cache stable CSS, JavaScript, and PDF assets;
- avoid embedding large videos in the repository;
- link externally hosted large media when appropriate;
- keep the deployed `dist/` artifact limited to public runtime files.

Azure Static Web Apps automatically serves Gzip or Brotli compressed versions of common text-based static assets when supported by the browser.
