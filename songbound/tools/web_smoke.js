const { chromium } = require('/usr/local/lib/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({
    executablePath: '/home/magent/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome',
    args: ['--no-sandbox', '--disable-gpu', '--use-gl=swiftshader',
           '--autoplay-policy=no-user-gesture-required', '--ignore-certificate-errors']
  });
  const page = await browser.newPage({ viewport: { width: 960, height: 720 } });
  const errors = [];
  page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE: ' + m.text()); });

  const url = 'https://fibonacci0.hunter.cryptograss.live/games/songbound-godot/index.html';
  const resp = await page.goto(url, { waitUntil: 'domcontentloaded' });
  console.log('HTTP ' + resp.status());

  let up = false;
  for (let i = 0; i < 30; i++) {
    await page.waitForTimeout(2000);
    const info = await page.evaluate(() => {
      const c = document.querySelector('canvas');
      return { has: !!c, w: c ? c.width : 0 };
    });
    if (info.has && info.w > 100) { console.log('canvas up ' + info.w + 'px after ~' + ((i+1)*2) + 's'); up = true; break; }
  }
  if (!up) console.log('canvas never came up');

  await page.waitForTimeout(5000);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-01-title.png' });

  // drive it: click to focus, then start a new game and walk creation
  await page.mouse.click(480, 400);
  await page.waitForTimeout(500);
  await page.keyboard.press('KeyZ');
  await page.waitForTimeout(1500);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-02-name.png' });

  await page.keyboard.type('Rosalie', { delay: 60 });
  await page.waitForTimeout(600);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-03-spritechoice.png' });

  await page.keyboard.press('KeyZ');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-04-editor.png' });

  await page.keyboard.press('Enter');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-05-instrument.png' });

  await page.keyboard.press('KeyZ');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-06-element.png' });

  await page.keyboard.press('KeyZ');
  await page.waitForTimeout(3000);
  await page.screenshot({ path: '/home/magent/.claude/jobs/610222dc/tmp/shots/sbweb-07-field.png' });

  console.log('errors: ' + errors.length);
  errors.slice(0, 10).forEach(e => console.log('  ' + e));
  await browser.close();
})().catch(e => { console.error('FAIL', e); process.exit(1); });
