import type common from '@ohos.app.ability.common';
import type { VerticalStarterFn } from './LaunchResult';

/**
 * 形态 A S3：官方垂类面板的生产侧启动适配。
 *
 * UIAbilityContext.startAbilityByType 是公开 API（非 systemapi、无权限、仅要求
 * 前台）；四参 callback 重载在 SDK d.ts 标 @since 12，本工程 compatibleSdkVersion
 * 5.0.0(12) 满足。与 A3 round-3 真机 spike 已验证的调用形状一致：系统按
 * type + wantParam.sceneType 匹配各 App 声明的 linkFeature，弹出垂类选择面板，
 * 选中后由系统把 URI/参数交给目标 App。
 *
 * 成功只由 callback 的 err 判定；onError 与同步抛错都算失败，且用 settled
 * 保证 Promise 只 resolve 一次。失败由 LaunchDispatcher 统一报
 * NO_AVAILABLE_ENTRY，不重试、不回退 startAbility、不打开首页。
 *
 * 用 `@ohos.app.ability.common` 的类型别名（interface）而非 @kit 的 class 型，
 * 使对象字面量回调能通过 ArkTS 的 arkts-no-untyped-obj-literals 检查。
 */
export function createVerticalStarter(context: common.UIAbilityContext): VerticalStarterFn {
  return (type: string, wantParam: Record<string, Object>): Promise<boolean> => {
    return new Promise<boolean>((resolve) => {
      let settled = false;
      const settle = (ok: boolean): void => {
        if (settled) return;
        settled = true;
        resolve(ok);
      };
      const cb: common.AbilityStartCallback = {
        onError: (_code: number, _name: string, _message: string): void => { settle(false); },
        onResult: (_result: common.AbilityResult): void => { /* 成功只由 callback err 判定 */ }
      };
      try {
        context.startAbilityByType(type, wantParam, cb, (err: Object) => {
          settle(!err);
        });
      } catch (_e) {
        settle(false);
      }
    });
  };
}

export default createVerticalStarter;
