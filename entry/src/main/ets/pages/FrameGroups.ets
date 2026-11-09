import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 精准复刻参考图（2026-11-08）：卡片 / 内页一律用「外层玻璃文件夹框 → 内层
 * 2×2 功能图标框」的嵌套框结构，不用普通列表。FrameGroups 只做纯逻辑切分：
 * 把一维功能数组切成每框 4 个功能的分组，供 ArkUI 用 Column/Row/Stack/Flex
 * （均带 @form 支持）画出嵌套框；Grid 无 @form 支持，故不用。
 *
 * D1 回归：key 含 query，搜索词变化让所有框整体失效，杜绝陈旧功能框残留。
 * B2′：不足 4 个的末组按实际数量，不补空格凑数。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */
export interface FrameGroup {
  /** ForEach 的稳定 key（含 query，查询变化整表失效）。 */
  key: string;
  /** 外层框下方的分类 / 情境标签。 */
  label: string;
  /** 该外层框内的功能（≤4）。 */
  items: AtomicFunction[];
}

export class FrameGroups {
  /**
   * 按每框 per 个功能切分。
   * @param items 已过滤/排序的功能数组
   * @param per   每个外层框内的功能数（2×2 = 4）
   * @param query 当前搜索词，参与 key（D1）
   */
  static of(items: AtomicFunction[], per: number, query: string = ''): FrameGroup[] {
    const size: number = per > 0 ? per : 4;
    const out: FrameGroup[] = [];
    for (let start = 0; start < items.length; start += size) {
      const chunk: AtomicFunction[] = items.slice(start, start + size);
      // 标签优先用框内首个功能的分类；空分类回退到「常用」。
      const label: string = chunk.length > 0 && chunk[0].category
        ? chunk[0].category : '常用';
      const g: FrameGroup = {
        key: 'f:' + query + '|' + start + ':' + chunk.length,
        label: label,
        items: chunk
      };
      out.push(g);
    }
    return out;
  }

  /**
   * 全量页专用：把 PinyinUtil.group 的「A–Z 分组」转成文件夹框序列。
   * 保留既有「按拼音 A–Z 排序」功能（IOS_PINYIN_SPEC），但每个分组呈现为
   * 外层玻璃文件夹框（框标签 = 字母），而不是普通列表 / ListItemGroup。
   * 单个字母桶超过 4 个功能时拆成多个框；query 参与 key（D1 无陈旧行）。
   */
  static fromPinyin(groups: Map<string, AtomicFunction[]>, query: string = ''): FrameGroup[] {
    const out: FrameGroup[] = [];
    groups.forEach((items: AtomicFunction[], letter: string) => {
      for (let start = 0; start < items.length; start += 4) {
        const chunk: AtomicFunction[] = items.slice(start, start + 4);
        const g: FrameGroup = {
          key: 'f:' + query + ':' + letter + ':' + start + ':' + chunk.length,
          label: letter,
          items: chunk
        };
        out.push(g);
      }
    });
    return out;
  }

  /** 把一个外层框内的功能切成每行 cols 个的二维数组（2×2）。 */
  static rows(group: FrameGroup, cols: number): AtomicFunction[][] {
    const c: number = cols > 0 ? cols : 2;
    const out: AtomicFunction[][] = [];
    for (let i = 0; i < group.items.length; i += c) {
      out.push(group.items.slice(i, i + c));
    }
    return out;
  }
}

export default FrameGroups;
