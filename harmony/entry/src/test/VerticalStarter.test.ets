import { describe, it, expect } from '@ohos/hypium';
import type common from '@ohos.app.ability.common';
import { createVerticalStarter } from '../main/ets/launch/VerticalStarter';

/** 结构替身：只实现 startAbilityByType 的四参 callback 重载。 */
function ctx(impl: Function): common.UIAbilityContext {
  return { startAbilityByType: impl } as unknown as common.UIAbilityContext;
}

export default function verticalStarterTest() {
  describe('VerticalStarter', () => {
    it('success_resolves_true_with_type_and_wantParam', 0, async () => {
      const calls: Object[] = [];
      const c = ctx((type: string, p: Record<string, Object>, _cb: Object, done: (e?: Object) => void) => {
        calls.push({ type: type, p: p });
        done();
      });
      expect(await createVerticalStarter(c)('navigation', { sceneType: 1 })).assertTrue();
      expect((calls[0] as Record<string, Object>)['type']).assertEqual('navigation');
      expect(((calls[0] as Record<string, Object>)['p'] as Record<string, Object>)['sceneType']).assertEqual(1);
    });
    it('callback_error_resolves_false', 0, async () => {
      const c = ctx((_t: string, _p: Object, _cb: Object, done: (e?: Object) => void) => {
        done({ code: 16000050 });
      });
      expect(await createVerticalStarter(c)('mail', {})).assertFalse();
    });
    it('onError_resolves_false_and_throw_never_leaks', 0, async () => {
      const onErr = ctx((_t: string, _p: Object, cb: Object, _done: (e?: Object) => void) => {
        (cb as { onError: (code: number, name: string, message: string) => void })
          .onError(16000050, 'InternalError', 'internal');
      });
      expect(await createVerticalStarter(onErr)('mail', {})).assertFalse();
      const boom = ctx(() => { throw new Error('boom'); });
      expect(await createVerticalStarter(boom)('mail', {})).assertFalse();
    });
  });
}
