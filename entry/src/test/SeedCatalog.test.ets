import { describe, it, expect } from '@ohos/hypium';
import { readFileSync } from 'node:fs';
import { CapabilityRepository } from '../main/ets/data/CapabilityRepository';
import { isL0, CATEGORIES } from '../main/ets/model/AtomicFunction';

const PATH = 'entry/src/main/resources/rawfile/capabilities.json';
// 冻结的种子验收快照：原始探测证据清理后保留的回归基线。
const EVIDENCE = 'test/fixtures/seed-evidence.json';

interface EvidenceRow {
  bundle: string;
  uri: string;
  verdict: string;
}

function seed(): { items: Array<Record<string, Object>> } {
  return JSON.parse(readFileSync(PATH, 'utf8'));
}

function evidence(): EvidenceRow[] {
  return JSON.parse(readFileSync(EVIDENCE, 'utf8'));
}

function keepSet(): Set<string> {
  const out = new Set<string>();
  for (const r of evidence()) {
    if (r.verdict.indexOf('KEEP_') === 0) out.add(r.bundle + '|' + r.uri);
  }
  return out;
}

function droppedNoHandlerSet(): Set<string> {
  const out = new Set<string>();
  for (const r of evidence()) {
    if (r.verdict === 'DROP_NO_HANDLER') out.add(r.bundle + '|' + r.uri);
  }
  return out;
}

export default function seedCatalogTest() {
  describe('SeedCatalog', () => {
    it('keeps_every_device_responding_entry_and_nothing_unverified', 0, () => {
      // 2026-11-09 用户政策：真机点动后有反应（含首页/登录/隐私同意/选择器）
      // 的入口全部进产品；种子里的每条 URI 必须能在 probe9 证据里找到 KEEP。
      const keep = keepSet();
      for (const i of seed().items) {
        const r = i['route'] as Record<string, Object>;
        if (r['kind'] === 'vertical') continue;
        const key = i['bundleName'] + '|' + r['uri'];
        expect(keep.has(key)).assertTrue();
      }
    });
    it('never_seeds_an_explicit_no_handler_route', 0, () => {
      const dropped = droppedNoHandlerSet();
      for (const i of seed().items) {
        const r = i['route'] as Record<string, Object>;
        if (r['kind'] === 'vertical') continue;
        expect(dropped.has(i['bundleName'] + '|' + r['uri'])).assertFalse();
      }
    });
    it('has_a_broad_catalog_with_many_apps', 0, () => {
      const parsed = CapabilityRepository.parse(readFileSync(PATH, 'utf8'));
      expect(parsed.length >= 60).assertTrue();
      const apps = new Set<string>();
      for (const f of parsed) apps.add(f.bundleName);
      expect(apps.size >= 30).assertTrue();
    });
    it('keeps_the_four_verified_L0_routes', 0, () => {
      const ids = seed().items.map((i) => i['id']);
      for (const id of ['real-amap-route', 'real-jd-storage', 'real-weibo-storage', 'real-quark-qianwen']) {
        expect(ids.indexOf(id) >= 0).assertTrue();
      }
    });
    it('explicit_amap_card_keeps_float_parameters', 0, () => {
      const f = seed().items.find((i) => i['id'] === 'explicit-amap-routeplan') as Record<string, Object>;
      const route = f['route'] as Record<string, Object>;
      const p = route['parameters'] as Record<string, Object>;
      expect(route['uri']).assertEqual('systemnav://routeplan');
      expect(p['destinationLatitude']).assertEqual(32.060844);
      expect(p['destinationLongitude']).assertEqual(118.78315);
      expect(p['destinationName']).assertEqual('测试地点');
    });
    it('nine_vertical_cards_use_official_type_scene_pairs', 0, () => {
      const vs = seed().items.filter((i) => (i['route'] as Record<string, Object>)['kind'] === 'vertical');
      expect(vs.length).assertEqual(9);
      const pairs = vs.map((v) => {
        const p = (v['route'] as Record<string, Object>)['parameters'] as Record<string, Object>;
        return p['verticalType'] + '/' + p['sceneType'];
      }).sort().join(',');
      expect(pairs).assertEqual('express/1,finance/1,finance/2,flight/1,flight/2,mail/1,navigation/1,navigation/2,navigation/3');
    });
    it('all_items_have_legal_category_and_are_L0', 0, () => {
      const parsed = CapabilityRepository.parse(readFileSync(PATH, 'utf8'));
      for (const f of parsed) {
        expect(CATEGORIES.indexOf(f.category) >= 0).assertTrue();
        expect(isL0(f)).assertTrue();
      }
    });
    it('vertical_cards_are_labeled_as_app_picker_not_one_tap', 0, () => {
      // 垂类卡会弹系统应用选择，UI 必须如实标明，不伪装成一键直达。
      const vs = seed().items.filter((i) => (i['route'] as Record<string, Object>)['kind'] === 'vertical');
      for (const v of vs) expect(String(v['label']).includes('选应用')).assertTrue();
    });
    it('login_and_consent_entries_carry_visible_hints', 0, () => {
      // 用户自己完成登录/协议；产品上必须如实标出，不能假装直达。
      const hints = new Set<string>();
      for (const i of seed().items) if (i['hint']) hints.add(String(i['hint']));
      expect(hints.has('需登录')).assertTrue();
      expect(hints.has('需同意')).assertTrue();
      for (const h of hints) {
        expect(['需登录', '需同意', '选择打开', '需确认'].indexOf(h) >= 0).assertTrue();
      }
    });
    it('every_item_id_is_unique', 0, () => {
      const ids = seed().items.map((i) => String(i['id']));
      expect(new Set<string>(ids).size).assertEqual(ids.length);
    });
  });
}
