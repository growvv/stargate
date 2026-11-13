import type common from '@ohos.app.ability.common';
import type OpenLinkOptions from '@ohos.app.ability.OpenLinkOptions';
import type { LinkOpenerFn } from './LaunchResult';

/**
 * 打开链接的生产侧适配（UIAbilityContext.openLink）。
 *
 * 为什么不用 startAbility（真机 2026-11-11 定位）：
 * 卡片点「微博」后应用直接退出。AMS 日志
 *   [implicit_start_processor.cpp340]failed, uri:sinaweibo-<private>
 * 三方应用自己拼 `{ bundleName, uri }` 的隐式 Want 调 startAbility 会被生态
 * 规则拦下；补上 ohos.want.action.viewData 也不够（真机复测仍是同一条错误）。
 *
 * openLink 是系统为「打开一个链接」提供的入口（@since 12，无需特殊权限，只要求
 * 应用在前台）。它由系统按目标 App 声明的 skill（scheme + action + entities）
 * 完成匹配，正是「点图标进到那个功能」要的语义；匹配不上会以
 * 16000019 (No matching ability is found) 之类的错误返回，可以如实报告。
 *
 * 不做任何降级：失败就是失败，由 LaunchDispatcher 统一报
 * NO_AVAILABLE_ENTRY，不换第二条路再试、不回退 App 首页（Spec §7）。
 */
export function createLinkOpener(context: common.UIAbilityContext): LinkOpenerFn {
  return (uri: string): Promise<boolean> => {
    return new Promise<boolean>((resolve) => {
      let settled = false;
      const settle = (ok: boolean): void => {
        if (settled) return;
        settled = true;
        resolve(ok);
      };
      try {
        // appLinkingOnly=false：普通 scheme 链接也要能打开，不限 App Linking。
        const options: OpenLinkOptions = { appLinkingOnly: false };
        context.openLink(uri, options).then(() => {
          settle(true);
        }).catch((err: Object) => {
          // 诊断：把系统拒绝的真实原因打出来（16000019 无匹配 / 16000053 非前台 /
          // 201 权限 等），避免只看到「点不开」却不知道是哪一层拦的。
          console.error('OPEN_LINK_FAILED: ' + uri + ' / ' + JSON.stringify(err));
          settle(false);
        });
      } catch (e) {
        console.error('OPEN_LINK_THREW: ' + uri + ' / ' + JSON.stringify(e));
        settle(false);
      }
    });
  };
}

export default createLinkOpener;
