import { describe, it, expect } from '@ohos/hypium';
import { CardBinding } from '../main/ets/form/CardBinding';
import { CapabilityRepository } from '../main/ets/data/CapabilityRepository';
import { makeCatalog, makeItems, fakeUsage, nowMorning } from './TestFixtures';

export default function cardBindingTest() {
  describe('CardBinding', () => {
    it('compose_includes_form_id_and_failure_for_visible_feedback', 0, () => {
      // I2：卡片点击失败必须能显示「暂无可用直达入口」，靠 binding 里的 failure + formId。
      const b = CardBinding.compose(makeCatalog(3), fakeUsage(), nowMorning(),
        'form-42', '『付款码』暂无可用直达入口', false, true);
      expect(b.formId).assertEqual('form-42');
      expect(b.failure).assertContain('暂无可用直达入口');
      expect(b.failure).assertContain('付款码');
    });
    it('compose_resolves_dark_and_blur_degraded_theme', 0, () => {
      // I7：卡片消费真实 ThemeTokens 结果，暗色/无模糊路径必须反映到 binding。
      const dark = CardBinding.compose(makeCatalog(1), fakeUsage(), nowMorning(), '', '', true, false);
      expect(dark.cardBg).assertEqual('#30000000'); // D3：AARRGGBB，alpha 在首位
      expect(dark.blurRadius).assertEqual(0); // blur 不可用 → backdropBlur(0)
      expect(dark.gradientDark).assertTrue();
      const light = CardBinding.compose(makeCatalog(1), fakeUsage(), nowMorning(), '', '', false, true);
      expect(light.cardBg).assertEqual('#30ffffff'); // D3：半透明白，非不透明黄
      expect(light.blurRadius).assertEqual(13);
      expect(light.gradientDark).assertFalse();
    });
    it('compose_reads_real_catalog_for_runtime_consumers', 0, () => {
      // C1：CardBinding 用传入 repo 的真实条目（非 fromItems([]) 空库）组装。
      const b = CardBinding.compose(makeCatalog(5), fakeUsage(), nowMorning(), '', '', false, true);
      expect(b.suggestions.length).assertEqual(5);
      expect(b.isEmpty).assertFalse();
      expect(b.categories.length > 0).assertTrue();
    });
    it('compose_attaches_icon_tile_visual_data', 0, () => {
      // 视觉改版：每个建议项带稳定的彩色渐变 + 字形，供卡片画 iOS 风格图标 tile。
      const b = CardBinding.compose(makeCatalog(3), fakeUsage(), nowMorning(), '', '', false, true);
      for (const s of b.suggestions) {
        expect(/^#[0-9a-f]{6}$/i.test(s.tileStart)).assertTrue();
        expect(/^#[0-9a-f]{6}$/i.test(s.tileEnd)).assertTrue();
        expect(s.glyph.length).assertLargerThan(0);
      }
    });
    it('compose_attaches_native_brand_marks_for_precise_replication', 0, () => {
      // 精准复刻参考图：尽可能用应用原生标识（真实 App logo / 品牌色 + 品牌字形），
      // 匹配不到才回退文字/颜色。makeCatalog(3) 首条 appName='支付宝'。
      const b = CardBinding.compose(makeCatalog(3), fakeUsage(), nowMorning(), '', '', false, true);
      expect(b.suggestions.length).assertEqual(3);
      const first = b.suggestions[0];
      expect(first.appName).assertEqual('支付宝');
      expect(first.markBg).assertEqual('#1677FF'); // 支付宝蓝
      expect(first.logoKey).assertEqual('alipay'); // 真实 App logo 资源键
      expect(first.markNative).assertTrue();
      for (const s of b.suggestions) {
        expect(/^#[0-9a-f]{6}$/i.test(s.markBg)).assertTrue();
        expect(/^#[0-9a-f]{6}$/i.test(s.markFg)).assertTrue();
        expect(s.markGlyph.length).assertLargerThan(0);
        expect(s.appName.length).assertLargerThan(0);
      }
    });
    it('compose_appends_hint_to_app_name_for_login_or_consent_entries', 0, () => {
      // A3 第 4 轮政策：点开有反应的入口全部保留；需要登录/同意隐私的，
      // 在卡片 App 名一行如实标出，不新增布局行（2×2 文件夹框比例不变）。
      const items = makeItems(2);
      items[0].hint = '需登录';
      const b = CardBinding.compose(CapabilityRepository.fromItems(items), fakeUsage(), nowMorning(),
        '', '', false, true);
      expect(b.suggestions[0].appName).assertEqual('支付宝 · 需登录');
      expect(b.suggestions[0].markGlyph).assertEqual('支'); // 品牌匹配仍按原始 appName
      expect(b.suggestions[1].appName).assertEqual('微信'); // 无 hint 不加后缀
    });
    it('compose_embeds_the_active_ratio_glass_tokens', 0, () => {
      // 三版比例迭代：整套浅色玻璃 token 随 formBindingData 推给卡片，
      // 键名与 WidgetCard 的 @LocalStorageProp 一致，否则卡片拿不到比例。
      const b = CardBinding.compose(makeCatalog(3), fakeUsage(), nowMorning(), '', '', false, true);
      expect(b.frameBg).assertEqual('#26FFFFFF');       // 浅色，不是 #30000000 深色
      expect(b.frameBorder.startsWith('#8C')).assertTrue();
      expect(b.radiusFrame > 0).assertTrue();
      expect(b.tileSize > 0).assertTrue();
      expect(b.tileGap > 0).assertTrue();
      expect(b.frameAspect > 0).assertTrue();
      expect(b.wallpaper.length).assertEqual(3);
      expect(b.activeVariant >= 0 && b.activeVariant < 3).assertTrue();
    });
    it('top_row_is_exactly_recommend_and_recent_added_frames', 0, () => {
      // 用户拍板（2026-11-09）：卡片第一排只保留两个大框 ——「推荐」与「最近添加」，
      // 不再按出行 / 工具效率等分类命名第一排。
      const b = CardBinding.compose(makeCatalog(8), fakeUsage(), nowMorning(), '', '', false, true);
      expect(b.frames.length).assertEqual(2);
      expect(b.frames[0].label).assertEqual('推荐');
      expect(b.frames[1].label).assertEqual('最近添加');
      expect(b.frames[0].items.length).assertEqual(4); // 推荐 2×2
      // 没有检测到新装 App 时，按目录尾部填充（用户要求「默认找最新的几个」）。
      expect(b.frames[1].items.length).assertEqual(4);
      expect(b.frames[1].emptyHint).assertEqual('');
      for (const f of b.frames) {
        expect(f.items.length <= 4).assertTrue();
        expect(f.key.length).assertLargerThan(0);
        for (const it of f.items) expect(it.category.length > 0).assertTrue();
      }
      // 空库 → 0 个框（诚实空态，不补空格凑数，B2′）。
      const empty = CardBinding.compose(makeCatalog(0), fakeUsage(), nowMorning(), '', '', false, true);
      expect(empty.frames.length).assertEqual(0);
    });
    it('recent_added_frame_prefers_newly_detected_apps_over_catalog_tail', 0, () => {
      const t = nowMorning();
      // 目录尾部默认填充是 fn-7/fn-6/fn-5/fn-4；fn-1、fn-6 是后来才检测到的 App，
      // 应排到最前面（fn-1 更新），其余名额仍用目录尾部补齐。
      const seen: Record<string, number> = {
        'com.stargate.demo.1': t,
        'com.stargate.demo.6': t - 1000
      };
      const b = CardBinding.compose(makeCatalog(8), fakeUsage(), t, '', '', false, true,
        undefined, undefined, seen);
      expect(b.frames[1].label).assertEqual('最近添加');
      expect(b.frames[1].items.length).assertEqual(4);
      expect(b.frames[1].items[0].id).assertEqual('fn-1');
      expect(b.frames[1].items[1].id).assertEqual('fn-6');
      expect(b.frames[1].items[2].id).assertEqual('fn-7');
      expect(b.frames[1].items[3].id).assertEqual('fn-5');
      expect(b.frames[1].emptyHint).assertEqual('');
    });
    it('frame_key_contains_its_label_so_updateForm_rebuilds_folder_frames', 0, () => {
      // 真机缺陷（2026-11-08）：框 key 只用 'frame:' + 位置 + 数量，
      // ForEach 在 updateForm 推来新绑定时按相同 key 复用旧子树，
      // Text(frame.label) 永远停在首次添加时的旧标签。与 D1 同源：key 必须随内容变化。
      const b = CardBinding.compose(makeCatalog(8), fakeUsage(), nowMorning(), '', '', false, true);
      const seen = new Set<string>();
      for (const f of b.frames) {
        expect(f.key.includes(f.label)).assertTrue();
        expect(seen.has(f.key)).assertFalse();
        seen.add(f.key);
      }
      expect(b.frames[0].key.includes('推荐')).assertTrue();
      expect(b.frames[1].key.includes('最近添加')).assertTrue();
    });
  });
}
