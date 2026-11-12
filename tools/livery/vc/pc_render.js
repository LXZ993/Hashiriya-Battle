const { chromium } = require('playwright');
(async () => {
  const [,, svg, out, scale] = process.argv;
  const b = await chromium.launch(); const p = await b.newPage({ deviceScaleFactor: Number(scale || 2) });
  const fs = require('fs'); const s = fs.readFileSync(svg, 'utf8');
  const m = s.match(/width="(\d+)" height="(\d+)"/);
  await p.setViewportSize({ width: +m[1], height: +m[2] });
  await p.setContent(`<html><body style="margin:0;background:transparent">${s}</body></html>`);
  await p.screenshot({ path: out, omitBackground: true }); await b.close();
})();
