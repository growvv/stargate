/**
 * D2 修复（真机 2026-11-07）：直达失败文案由 EntryAbility.pushCardResult 写进
 * 「持久」formBindingData 后常驻。唯一清除它的 onUpdateForm 是 1 小时级定时，
 * onFormEvent 又依赖卡片从未发出的 message 动作 —— force-stop / 返桌面后
 * 「●『…』暂无可用直达入口」一直挂在那里。
 *
 * 修法：绑定数据带 failureAt 时间戳，卡片按「当前时间」判定是否还显示；
 * 并给失败态排一次确定性刷新（FormAbility.clearFailureAfter）+ 卡片「×」主动清除。
 * 失败反馈是瞬态的，不该污染下一次定时刷新或跨进程持久化状态。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动，也能编译进 widgets.abc。
 */

/** 失败提示展示时长：8 秒，足够读到，又不会变成常驻横幅。 */
export const FAILURE_TTL_MS: number = 8000;

export class CardFeedback {
  /**
   * 失败文案此刻是否应显示。
   * failureAt=0 表示旧版绑定（无时间戳）—— 保持显示，不静默吞掉反馈。
   */
  static visibleAt(failure: string, failureAt: number, now: number, ttl: number = FAILURE_TTL_MS): boolean {
    if (!failure) return false;
    if (!failureAt) return true;
    return now - failureAt < ttl;
  }

  /** 是否还需要为这个失败态排一次「清除」刷新。 */
  static needsClearTimer(failure: string, failureAt: number, now: number, ttl: number = FAILURE_TTL_MS): boolean {
    return CardFeedback.visibleAt(failure, failureAt, now, ttl);
  }

  /** 距离过期还剩多少毫秒（用于 setFormNextRefreshTime 的分钟换算，最小 1 分钟）。 */
  static remainingMs(failureAt: number, now: number, ttl: number = FAILURE_TTL_MS): number {
    return Math.max(0, failureAt + ttl - now);
  }
}

export default CardFeedback;
