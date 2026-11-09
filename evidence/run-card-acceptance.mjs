import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const HDC = 'D:/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc';
const TARGET = '5KPBB25927200695';
const APP = 'com.example.minimal';
const OUT = '.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/verify-signing/acceptance-2026-11-08';
mkdirSync(OUT, { recursive: true });

function hdc(args) { return execFileSync(HDC, ['-t', TARGET, ...args], { encoding: 'utf8', timeout: 120000 }); }
function shell(command) { return hdc(['shell', command]); }
function sleep(ms) { const until = Date.now() + ms; while (Date.now() < until) {} }
function capture(tag) {
  const remote = `/data/local/tmp/accept_${tag}.png`;
  shell(`uitest screenCap -p ${remote}`);
  hdc(['file', 'recv', remote, `${OUT}/${tag}.png`]);
}
function layout(tag) {
  const remote = `/data/local/tmp/accept_${tag}.json`;
  const local = `${OUT}/${tag}.json`;
  shell(`uitest dumpLayout -p ${remote}`);
  hdc(['file', 'recv', remote, local]);
  const root = JSON.parse(readFileSync(local, 'utf8'));
  const nodes = [];
  const walk = (node) => {
    if (!node || typeof node !== 'object') return;
    const a = node.attributes || {};
    if (a.text || a.originalText || a.type === 'TextInput') {
      nodes.push({ text: a.text || a.originalText || '', type: a.type || '', bounds: a.bounds || '', clickable: a.clickable || '' });
    }
    (node.children || []).forEach(walk);
  };
  walk(root);
  writeFileSync(`${OUT}/${tag}-texts.json`, JSON.stringify(nodes, null, 2));
  return nodes;
}
function find(nodes, text) {
  const n = nodes.find(x => x.text.includes(text));
  if (!n || !n.bounds) return null;
  const q = n.bounds.match(/\d+/g).map(Number);
  return { ...n, cx: Math.round((q[0] + q[2]) / 2), cy: Math.round((q[1] + q[3]) / 2) };
}
function input(nodes, query) {
  const n = nodes.find(x => x.type === 'TextInput' && x.bounds);
  if (!n) throw new Error('TextInput not found');
  const q = n.bounds.match(/\d+/g).map(Number);
  const cx = Math.round((q[0] + q[2]) / 2), cy = Math.round((q[1] + q[3]) / 2);
  shell(`uitest uiInput click ${cx} ${cy}`);
  shell(`uitest uiInput inputText ${cx} ${cy} "${query}"`);
}
function openPage(page, category = '') {
  shell(`aa force-stop ${APP}`);
  const extra = category ? ` --ps category ${category}` : '';
  shell(`aa start -a EntryAbility -b ${APP} --ps page ${page}${extra}`);
  sleep(1300);
}

const results = [];
const record = (step, expected, nodes, extra = {}) => {
  const texts = [...new Set(nodes.map(n => n.text).filter(Boolean))];
  const row = { step, expected, actualTexts: texts, ...extra };
  results.push(row);
  console.log(JSON.stringify({ step, ...extra }));
};

// Card on the desktop: this is the real service-card surface, not the UIAbility page.
shell('uitest uiInput keyEvent Home'); sleep(900);
const card = layout('00-card'); capture('00-card');
record('00-card', '桌面卡片可见，包含探索/更多入口和推荐区域', card, {
  hasCardTitle: card.some(n => n.text === '功能面板'),
  hasExplore: card.some(n => n.text === '探索'),
  hasMore: card.some(n => n.text.includes('更多')),
  hasEmptyState: card.some(n => n.text.includes('添加你常用的功能'))
});

// All-functions page and search hit.
openPage('all');
let all = layout('01-all'); capture('01-all');
record('01-all', '全部功能页显示 5 个入口并可按拼音浏览', all, {
  totalLine: all.find(n => n.text.includes('按拼音'))?.text || null,
  labels: all.map(n => n.text).filter(t => /路线规划|存储空间|千问助手|无效路由/.test(t))
});
input(all, '京东'); sleep(1000);
let searchHit = layout('02-search-jd'); capture('02-search-jd');
record('02-search-jd', '搜索“京东”只保留京东存储空间', searchHit, {
  totalLine: searchHit.find(n => n.text.includes('按拼音'))?.text || null,
  hasJd: searchHit.some(n => n.text.includes('京东存储空间')),
  hasOtherRoute: searchHit.some(n => /高德路线规划|微博存储空间|夸克千问助手|无效路由/.test(n.text))
});

// Fresh page and no-match search.
openPage('all');
all = layout('03-all-nomatch'); input(all, '不存在'); sleep(900);
const noMatch = layout('04-search-nomatch'); capture('04-search-nomatch');
record('04-search-nomatch', '无匹配显示 0 项和暂无可用功能', noMatch, {
  totalLine: noMatch.find(n => n.text.includes('按拼音'))?.text || null,
  empty: noMatch.some(n => n.text.includes('暂无可用功能'))
});

// Category page and category search.
openPage('category', '购物');
let category = layout('05-category-shopping'); capture('05-category-shopping');
record('05-category-shopping', '购物分类显示京东入口', category, {
  title: category.some(n => n.text === '购物'),
  hasJd: category.some(n => n.text.includes('京东存储空间')),
  hasSearch: category.some(n => n.text.includes('搜索功能'))
});
input(category, '京东'); sleep(900);
const categorySearch = layout('06-category-search-jd'); capture('06-category-search-jd');
record('06-category-search-jd', '分类内搜索京东仍可命中', categorySearch, {
  hasJd: categorySearch.some(n => n.text.includes('京东存储空间')),
  empty: categorySearch.some(n => n.text.includes('该分类暂无可用功能'))
});

// Config page.
openPage('config');
const config = layout('07-config'); capture('07-config');
record('07-config', '配置页可达并显示能力库路径与能力探索入口', config, {
  hasSettings: config.some(n => n.text === '设置'),
  hasExplorer: config.some(n => n.text.includes('能力探索')),
  hasCatalogPath: config.some(n => n.text.includes('capabilities.json'))
});

writeFileSync(`${OUT}/acceptance-results.json`, JSON.stringify(results, null, 2));
console.log(`WROTE ${OUT}/acceptance-results.json`);
