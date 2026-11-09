import { describe, it, expect } from '@ohos/hypium';
import { CatalogEditor } from '../main/ets/data/CatalogEditor';

export default function catalogEditorTest() {
  describe('CatalogEditor', () => {
    it('reorder_category_updates_order_without_adding_categories', 0, () => {
      const editor = new CatalogEditor();
      const before = editor.orderFor('支付');
      expect(before.length).assertEqual(0);
      editor.reorderCategory('支付', ['fn-2', 'fn-0', 'fn-1']);
      const after = editor.orderFor('支付');
      expect(after.length).assertEqual(3);
      expect(after[0]).assertEqual('fn-2');
      expect(after[2]).assertEqual('fn-1');
      // B3′：第一期只做排序，不做分类增删改，也不做收藏/置顶/手动添加。
      // reorderCategory 只记录已存在类目的顺序，不凭空新增类目集合。
      expect(editor.categoryNames().length).assertEqual(1);
      expect(editor.categoryNames()[0]).assertEqual('支付');
    });
  });
}
