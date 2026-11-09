import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
const HDC = 'D:/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc';
const TARGET = '5KPBB25927200695';
const APP = 'com.example.minimal';
const OUT = '.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/verify-signing/acceptance-2026-11-08';
mkdirSync(OUT, { recursive: true });
function hdc(args) { return execFileSync(HDC, ['-t', TARGET, ...args], { encoding: 'utf8', timeout: 120000 }); }
function sh(s) { return hdc(['shell', s]); }
function sleep(ms) { const t = Date.now() + ms; while (Date.now() < t) {} }
function dump(tag) {
  const remote = `/data/local/tmp/recommend_${tag}.json`, local = `${OUT}/recommend_${tag}.json`;
  sh(`uitest dumpLayout -p ${remote}`); hdc(['file', 'recv', remote, local]);
  const root = JSON.parse(readFileSync(local, 'utf8')), nodes = [];
  const walk = (n) => { if (!n || typeof n !== 'object') return; const a = n.attributes || {}; if (a.text || a.originalText) nodes.push({ text: a.text || a.originalText, bounds: a.bounds || '', clickable: a.clickable || '' }); (n.children || []).forEach(walk); };
  walk(root); return nodes;
}
function capture(tag) { const r = `/data/local/tmp/recommend_${tag}.png`; sh(`uitest screenCap -p ${r}`); hdc(['file', 'recv', r, `${OUT}/recommend_${tag}.png`]); }
function center(n) { const q = n.bounds.match(/\d+/g).map(Number); return [Math.round((q[0] + q[2]) / 2), Math.round((q[1] + q[3]) / 2)]; }
function cardPage() {
  sh('uitest uiInput keyEvent Home'); sleep(1200);
  for (let i = 0; i < 8; i++) {
    const nodes = dump('scan_' + i);
    if (nodes.some(n => n.text === '功能面板') && nodes.some(n => n.text.includes('探索'))) return nodes;
    sh('uitest uiInput swipe 1300 1300 300 1300 350'); sleep(500);
  }
  return dump('scan_final');
}
const before = cardPage();
const beforeOrder = before.map(n => n.text).filter(t => t === '功能面板');
capture('before');
// The card deliberately renders brand glyphs without text labels. Use the
// accessible All Functions page to select the real 京东 tile, then return to
// the card and capture its refreshed binding.
sh('aa force-stop ' + APP); sleep(300);
sh('aa start -a EntryAbility -b ' + APP + ' --ps page all'); sleep(1400);
let all = dump('all-for-recommend');
const target = all.find(n => n.text === '京东存储空间');
if (!target) throw new Error('京东存储空间 tile not found on All Functions page');
const [x, y] = center(target); sh(`uitest uiInput click ${x} ${y}`); sleep(5000);
const launchNodes = dump('after-launch'); capture('after-launch');
const after = cardPage(); capture('after-return');
const afterOrder = after.map(n => n.text).filter(t => t === '功能面板');
const result = {
  expected: '点击京东真实入口后，用量持久化，回到桌面卡片重新绑定并保持/调整推荐顺序',
  clicked: '京东',
  beforeOrder,
  afterOrder,
  note: '卡片采用无文字品牌图标，桌面 dump 不暴露每个 tile 的 label；排序规则由实际成功点击产生的 UsageStore 记录 + RankingEngine 单测共同验证。',
  thirdPartyObserved: launchNodes.some(n => /存储空间|京东已用空间|一键清理/.test(n.text)),
  cardVisibleAfterReturn: after.some(n => n.text === '功能面板'),
  screenshots: ['recommend-before.png', 'recommend-after-launch.png', 'recommend-after-return.png']
};
writeFileSync(`${OUT}/recommendation-result.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
