import { describe, it, expect } from '@ohos/hypium';
import { CategoryOrder } from '../main/ets/data/CategoryOrder';
import { CategoryOrderStore } from '../main/ets/data/CategoryOrderStore';
import { CATEGORIES } from '../main/ets/model/AtomicFunction';

export default function categoryOrderStoreTest() {
  describe('CategoryOrderStore', () => {
    it('normalize_drops_unknown_dedupes_and_appends_missing', 0, () => {
      const out = CategoryOrder.normalize(['购物', '购物', '不存在', '支付']);
      expect(out.length).assertEqual(CATEGORIES.length);
      expect(out[0]).assertEqual('购物');
      expect(out[1]).assertEqual('支付');
      expect(out.indexOf('不存在')).assertEqual(-1);
      // 缺失的类目按默认顺序补齐在后。
      expect(out[2]).assertEqual('出行');
      expect(new Set(out).size).assertEqual(CATEGORIES.length);
    });
    it('move_reorders_and_clamps', 0, () => {
      const moved = CategoryOrder.move(CATEGORIES, 0, 3);
      expect(moved[3]).assertEqual(CATEGORIES[0]);
      expect(moved[0]).assertEqual(CATEGORIES[1]);
      expect(moved.length).assertEqual(CATEGORIES.length);
      const clamped = CategoryOrder.move(CATEGORIES, 8, 99);
      expect(clamped[clamped.length - 1]).assertEqual(CATEGORIES[8]);
      expect(CategoryOrder.move(CATEGORIES, -1, 2).join(',')).assertEqual(CATEGORIES.join(','));
    });
    it('memory_store_round_trips_and_persists', 0, () => {
      const st = CategoryOrderStore.fromMemory();
      expect(st.load().join(',')).assertEqual(CATEGORIES.join(','));
      const custom = CategoryOrder.move(CATEGORIES, 0, 4);
      st.save(custom);
      expect(st.load().join(',')).assertEqual(custom.join(','));
    });
  });
}
