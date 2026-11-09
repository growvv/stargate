import { describe, it, expect } from '@ohos/hypium';
import { ConfigAccess } from '../main/ets/data/ConfigAccess';

export default function configAccessTest() {
  describe('ConfigAccess', () => {
    it('config_entry_never_dead', 0, () => {
      expect(ConfigAccess.isReachable(true)).assertTrue();
      expect(ConfigAccess.isReachable(false)).assertFalse();
      expect(ConfigAccess.firstAddGuideEnabled(false)).assertTrue();
      expect(ConfigAccess.firstAddGuideEnabled(true)).assertFalse();
    });
    it('form_config_want_opens_config_page_not_dead_index', 0, () => {
      // I5：formConfigAbility 的 Want 不带 page，必须解析成 config 页，而非落到 pages/Index 占位页。
      expect(ConfigAccess.pageForFormConfig('')).assertEqual('config');
      expect(ConfigAccess.pageForFormConfig('all')).assertEqual('all');
    });
  });
}
