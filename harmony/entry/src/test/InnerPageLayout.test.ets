import { describe, it, expect } from '@ohos/hypium';
import { readFileSync } from 'node:fs';

/**
 * 真机截图（2026-11-08 02:26）暴露的内页布局缺陷，layout dump 已定位：
 *  - 全量/搜索页：Flex(wrap) 在「有剩余交叉轴空间」时把多行居中，
 *    _search.json 里 Scroll [0,525][1600,1648] 但第一个框在 y=1278（正中），
 *    而 _all.json 里 8 个框从 y=534 顶部开始。需 alignContent: FlexAlign.Start。
 *  - 分类页：Scroll 把尺寸不足的子组件垂直居中，
 *    _cat.json 里 Scroll [0,504][1600,2488] 但框在 [42,1284]（正中）。
 *    需 .align(Alignment.Top)。
 *  - 两页共有：外层框 width('100%') 叠加左右 margin，总宽超出父容器，
 *    截图右侧被裁切（_cat.json 框 bounds [42,1284][1600,1681] 右边界顶到屏边）。
 *
 * 参考图要求：内容从顶部开始排，框体完整落在屏内。这里用静态源断言钉住三条约束。
 */
export default function innerPageLayoutTest() {
  describe('InnerPageLayout (frames start at top, never clipped)', () => {
    const read = (f: string) => readFileSync(
      new URL('../main/ets/pages/' + f, import.meta.url), 'utf8');

    it('all_functions_uses_letter_sections_with_a_z_index', 0, () => {
      // 2026-11-09 改版：参考 iOS「App 资源库」搜索态，不再用文件夹框 Flex，
      // 改为 A–Z# 分段 List + 右侧 AlphabetIndexer。
      const src = read('AllFunctionsPage.ets');
      expect(src.includes('LetterSections.fromItems')).assertTrue();
      expect(src.includes('AlphabetIndexer')).assertTrue();
      expect(src.includes('.sticky(StickyStyle.Header)')).assertTrue();
    });

    it('all_functions_filters_cached_items_instead_of_reloading_on_each_key', 0, () => {
      // 旧实现每次 onChange 都 effectiveRepository + listAll（打一个字探测一轮）；
      // 现在 allItems 只在 aboutToAppear 读一次，输入只跑 applyFilter。
      const src = read('AllFunctionsPage.ets');
      expect(src.includes('this.allItems = await repo.listAll()')).assertTrue();
      expect(src.includes('this.applyFilter()')).assertTrue();
      expect(src.includes('onChange((v: string)')).assertTrue();
    });

    it('category_scroll_aligns_short_child_to_top', 0, () => {
      const src = read('CategoryPage.ets');
      expect(src.includes('.align(Alignment.Top)')).assertTrue();
    });

    it('config_list_supports_real_drag_sorting', 0, () => {
      // 用户反馈「拖不动」：旧版点「≡」调空实现。现在 List.editMode + onItemDrop，
      // 结果经 CategoryOrder.move 持久化到 CategoryOrderStore。
      const src = read('ConfigPage.ets');
      expect(src.includes('.editMode(true)')).assertTrue();
      expect(src.includes('.onItemDragStart(')).assertTrue();
      expect(src.includes('.onItemDrop(')).assertTrue();
      expect(src.includes('CategoryOrder.move(')).assertTrue();
      expect(src.includes('CategoryOrderStore.fromContextSync')).assertTrue();
    });

    it('folder_frames_never_combine_full_width_with_side_margins', 0, () => {
      // 保留分类页的历史布局约束（全量页已改为 List，不再有外层框）。
      const src = read('CategoryPage.ets');
      expect(/\.width\('100%'\)[\s\S]{0,120}\.margin\(\{\s*left:/.test(src)).assertFalse();
    });

    it('search_bars_are_inset_not_edge_to_edge', 0, () => {
      // 真机 dump：搜索胶囊 bounds [0,304][1600,455] 顶到屏幕两边，
      // 因为 width('100%') + 左右 margin 会被吞掉；参考图是内缩的胶囊。
      // 用 Row 外层 padding 实现内缩，而非满宽 + margin。
      for (const f of ['AllFunctionsPage.ets', 'CategoryPage.ets']) {
        const src = read(f);
        expect(/padding\(\{[^}]*left:\s*18[^}]*right:\s*18/.test(src)).assertTrue();
      }
    });
  });
}
