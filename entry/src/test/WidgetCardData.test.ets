import { describe, it, expect } from '@ohos/hypium';
import { WidgetCardData } from '../main/ets/form/WidgetCardData';
import { CapabilityRepository } from '../main/ets/data/CapabilityRepository';
import { makeCatalog, makeItems, fakeUsage, nowMorning } from './TestFixtures';
import type { Route } from '../main/ets/model/AtomicFunction';

export default function widgetCardDataTest() {
  describe('WidgetCardData', () => {
    it('cold_start_fills_up_to_eight_slots', 0, async () => {
      const data = await WidgetCardData.build(makeCatalog(12), fakeUsage(), nowMorning());
      expect(data.suggestions.length).assertEqual(8);
      expect(data.isEmpty).assertFalse();
      expect(data.categories.length > 0).assertTrue();
    });
    it('small_catalog_shows_actual_count', 0, async () => {
      // B2′：不足 8 格按实际数量显示，不凑数、不填未验证条目
      const data = await WidgetCardData.build(makeCatalog(3), fakeUsage(), nowMorning());
      expect(data.suggestions.length).assertEqual(3);
      expect(data.isEmpty).assertFalse();
    });
    it('empty_catalog_shows_guide_state', 0, async () => {
      const data = await WidgetCardData.build(makeCatalog(0), fakeUsage(), nowMorning());
      expect(data.isEmpty).assertTrue();
      expect(data.suggestions.length).assertEqual(0);
    });
    it('sync_build_matches_async_for_form_callbacks', 0, () => {
      // 卡片 onAddForm/onUpdateForm 是同步回调，需要不依赖 await 的组装路径。
      const data = WidgetCardData.buildSync(makeCatalog(5), fakeUsage(), nowMorning());
      expect(data.suggestions.length).assertEqual(5);
      expect(data.isEmpty).assertFalse();
      expect(data.categories.length > 0).assertTrue();
    });
    it('category_chips_follow_the_user_category_order', 0, () => {
      // 配置页拖动排序后，卡片底部 chips 的顺序跟着变。
      const data = WidgetCardData.buildSync(makeCatalog(9), fakeUsage(), nowMorning(),
        ['娱乐', '支付', '购物', '出行', '社交', '生活', '健康运动', '工具效率', '其他']);
      expect(data.categories[0].name).assertEqual('娱乐');
      expect(data.categories[1].name).assertEqual('支付');
      expect(data.categories.length).assertEqual(9);
    });
    it('recommendations_prefer_real_apps_over_system_pickers', 0, () => {
      // 用户反馈：卡片图标要显示 App 自己的 logo。冷启动时「系统能力·选应用」
      // 垂直入口（confidence 0.95）会挤满推荐位，而它们没有 App logo，卡片上
      // 只剩 4 个相同的中性符号。推荐位应优先真实 App 功能；系统选应用入口
      // 只作为后备，不占用有限的 2×2 推荐框。
      const items = makeItems(6);
      const vertical: Route = { kind: 'vertical', uri: 'vertical://courier' };
      items[0].appName = '系统能力';
      items[0].route = vertical;
      items[0].confidence = 0.99;
      const data = WidgetCardData.buildSync(CapabilityRepository.fromItems(items), fakeUsage(), nowMorning());
      expect(data.suggestions.length).assertEqual(6);
      expect(data.suggestions[0].route.kind === 'vertical').assertFalse();
      expect(data.suggestions[data.suggestions.length - 1].route.kind).assertEqual('vertical');
    });
    it('recommendations_fall_back_to_system_pickers_when_no_apps_exist', 0, () => {
      // 目录里只有系统选应用入口时不能不显示（B2′：有真实条目就展示）。
      const items = makeItems(2);
      for (const f of items) {
        f.appName = '系统能力';
        const vertical: Route = { kind: 'vertical', uri: 'vertical://x' };
        f.route = vertical;
      }
      const data = WidgetCardData.buildSync(CapabilityRepository.fromItems(items), fakeUsage(), nowMorning());
      expect(data.suggestions.length).assertEqual(2);
      expect(data.suggestions[0].route.kind).assertEqual('vertical');
    });
  });
}
