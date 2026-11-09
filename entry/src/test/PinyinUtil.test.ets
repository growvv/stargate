import { describe, it, expect } from '@ohos/hypium';
import { readFileSync } from 'node:fs';
import { PinyinUtil } from '../main/ets/data/PinyinUtil';
import { makeItems, makeFunction } from './TestFixtures';

interface SeedItem {
  label: string;
  appName: string;
}

export default function pinyinTest() {
  describe('PinyinUtil', () => {
    it('every_catalog_first_character_maps_to_a_letter', 0, () => {
      // 用户反馈（2026-11-09）：全量页输入 a 返回 0 项，但目录里明明有
      // 「按航班号查询·选应用」这类拼音 A 开头的功能。根因不在过滤器，
      // 而在离线首字母表漏收了实际用到的汉字（按、登、教、账……），
      // 让它们静默掉进 '#' 桶。这里锁死：目录里每个 label / appName 的
      // 首字都必须落到 A–Z（数字/符号开头除外）。
      const seed = JSON.parse(readFileSync(
        'entry/src/main/resources/rawfile/capabilities.json', 'utf8')) as { items: SeedItem[] };
      const missing: string[] = [];
      for (const item of seed.items) {
        for (const name of [item.label, item.appName]) {
          const first = name.trim().charAt(0);
          if (!first) continue;
          const code = first.charCodeAt(0);
          if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) ||
            (code >= 97 && code <= 122)) continue;
          if (PinyinUtil.initial(name) === '#') missing.push(first + ':' + name);
        }
      }
      expect(missing.join(',')).assertEqual('');
    });
    it('pinyin_group_boundaries', 0, () => {
      expect(PinyinUtil.initial('爱奇艺')).assertEqual('A');
      expect(PinyinUtil.initial('付款码')).assertEqual('F');
      expect(PinyinUtil.initial('B站')).assertEqual('B');
      expect(PinyinUtil.initial('12306')).assertEqual('#');
      expect(PinyinUtil.initial('')).assertEqual('#');
      const g = PinyinUtil.group(makeItems(0));
      expect(g.size).assertEqual(0);
      const g2 = PinyinUtil.group([
        makeFunction({ kind: 'deeplink', uri: 'x://a' }),
        makeFunction({ kind: 'deeplink', uri: 'x://b' })
      ]);
      expect(g2.size >= 1).assertTrue();
    });
  });
}
