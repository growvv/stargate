import { describe, it, expect } from '@ohos/hypium';
import { makeCatalog } from './TestFixtures';
import { CapabilityRepository } from '../main/ets/data/CapabilityRepository';

/** 把 JS 字符串编成 UTF-8 字节（模拟 getRawFileContentSync 的真实返回）。 */
function utf8(s: string): Uint8Array {
  const enc = unescape(encodeURIComponent(s));
  const out = new Uint8Array(enc.length);
  for (let i = 0; i < enc.length; i++) out[i] = enc.charCodeAt(i);
  return out;
}

export default function capabilityRepositoryTest() {
  describe('CapabilityRepository', () => {
    it('list_by_category_filters_correctly', 0, async () => {
      const repo = makeCatalog(12);
      const all = await repo.listAll();
      expect(all.length).assertEqual(12);
      const pay = await repo.listByCategory(all[0].category);
      expect(pay.length > 0).assertTrue();
      expect(await repo.get(all[0].id)).assertEqual(all[0]);
    });
    it('items_snapshot_supports_sync_form_callbacks', 0, () => {
      // 卡片 onAddForm/onUpdateForm 是同步回调，需要一个不 await 的读取路径。
      const repo = makeCatalog(4);
      expect(repo.itemsSnapshot().length).assertEqual(4);
      expect(makeCatalog(0).itemsSnapshot().length).assertEqual(0);
    });
    it('decode_utf8_seed_preserves_chinese_labels', 0, () => {
      // Gap 2：getRawFileContentSync 返回 UTF-8 字节；逐字节 Latin-1 解码会产生 mojibake。
      const seed = JSON.stringify({ items: [
        { id: 'a', appName: '支付宝', label: '付款码', category: '支付',
          bundleName: 'com.alipay.mobile.client',
          route: { kind: 'deeplink', uri: 'alipays://platformapi/startapp' },
          source: 'scheme', confidence: 0.85 }
      ]});
      const text = CapabilityRepository.decodeUtf8(utf8(seed));
      const parsed = CapabilityRepository.parse(text);
      expect(parsed.length).assertEqual(1);
      expect(parsed[0].appName).assertEqual('支付宝');
      expect(parsed[0].label).assertEqual('付款码');
      expect(parsed[0].category).assertEqual('支付');
    });
    it('from_context_sync_reads_rawfile_seed', 0, () => {
      // C1：同步工厂必须能被 FormAbility 的同步回调直接调用，读回真实种子条目。
      const seed = JSON.stringify({ items: [
        { id: 'x', appName: '微信', label: '扫一扫', category: '社交',
          bundleName: 'com.tencent.wechat', route: { kind: 'deeplink', uri: 'weixin://scan' },
          source: 'scheme', confidence: 0.85 }
      ]});
      const ctx = { resourceManager: { getRawFileContentSync: (_p: string) => utf8(seed) } };
      const repo = CapabilityRepository.fromContextSync(ctx);
      expect(repo.itemsSnapshot().length).assertEqual(1);
      expect(repo.itemsSnapshot()[0].label).assertEqual('扫一扫');
    });
    it('parse_accepts_vertical_kind', 0, () => {
      // 形态 A：系统垂类入口（startAbilityByType）是一等 route kind。
      const seed = JSON.stringify({ items: [
        { id: 'v', appName: '系统能力', label: '路线规划·选应用', category: '出行',
          bundleName: 'com.example.verticalhost',
          route: { kind: 'vertical', parameters: { verticalType: 'navigation', sceneType: 1 } },
          source: 'manual', confidence: 1 }
      ]});
      const parsed = CapabilityRepository.parse(seed);
      expect(parsed.length).assertEqual(1);
      expect(parsed[0].route.kind).assertEqual('vertical');
      expect(parsed[0].bundleName).assertEqual('com.example.verticalhost');
    });
    it('parse_rejects_invalid_route_kind_and_category', 0, () => {
      // M1/I1：外部可替换配置必须校验，禁止 home kind / 非法类目 / 非法 confidence 混入。
      const seed = JSON.stringify({ items: [
        { id: 'ok', appName: '支付宝', label: '付款码', category: '支付', bundleName: 'b',
          route: { kind: 'shortcut-param', abilityName: 'A', moduleName: 'm' }, source: 'shortcut', confidence: 1 },
        { id: 'home', appName: 'X', label: '首页', category: '支付', bundleName: 'b',
          route: { kind: 'home' }, source: 'scheme', confidence: 1 },
        { id: 'badcat', appName: 'X', label: 'X', category: '不存在', bundleName: 'b',
          route: { kind: 'deeplink', uri: 'x://y' }, source: 'scheme', confidence: 1 }
      ]});
      const parsed = CapabilityRepository.parse(seed);
      expect(parsed.length).assertEqual(1);
      expect(parsed[0].id).assertEqual('ok');
    });
  });
}
