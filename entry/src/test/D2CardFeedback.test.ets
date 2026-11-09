import { describe, it, expect } from '@ohos/hypium';
import { CardFeedback, FAILURE_TTL_MS } from '../main/ets/form/CardFeedback';
import { CardBinding } from '../main/ets/form/CardBinding';
import { makeCatalog, fakeUsage, nowMorning } from './TestFixtures';

/**
 * D2（真机发现）：直达失败文案被 pushCardResult 写进「持久」formBindingData，
 * 而唯一清除它的 onUpdateForm 是 1 小时级定时、onFormEvent 又依赖卡片从未发出的
 * message 动作 → force-stop / 返桌面后失败提示常驻。
 * 修法：绑定里带 failureAt 时间戳，compose 用「当前 now」判定是否仍显示；
 * 并给失败态排一次确定性刷新 + 卡片可点「×」主动清除。
 */
export default function d2CardFeedbackTest() {
  describe('CardFeedback (D2 regression)', () => {
    it('failure_is_visible_immediately_after_push', 0, () => {
      const t = 1_700_000_000_000;
      expect(CardFeedback.visibleAt('『X』暂无可用直达入口', t, t + 10, FAILURE_TTL_MS)).assertTrue();
    });
    it('failure_expires_after_ttl', 0, () => {
      const t = 1_700_000_000_000;
      expect(CardFeedback.visibleAt('『X』暂无可用直达入口', t, t + FAILURE_TTL_MS - 1, FAILURE_TTL_MS)).assertTrue();
      expect(CardFeedback.visibleAt('『X』暂无可用直达入口', t, t + FAILURE_TTL_MS, FAILURE_TTL_MS)).assertFalse();
      expect(CardFeedback.visibleAt('『X』暂无可用直达入口', t, t + 3600_000, FAILURE_TTL_MS)).assertFalse();
    });
    it('empty_failure_never_visible', 0, () => {
      expect(CardFeedback.visibleAt('', 1_700_000_000_000, 1_700_000_000_000, FAILURE_TTL_MS)).assertFalse();
    });
    it('legacy_binding_without_timestamp_stays_visible', 0, () => {
      // 兼容旧路径：没有 failureAt 时仍显示（不静默吞掉反馈）。
      expect(CardFeedback.visibleAt('msg', 0, 1_700_000_000_000, FAILURE_TTL_MS)).assertTrue();
    });
    it('compose_drops_expired_failure_from_binding', 0, () => {
      const t = 1_700_000_000_000;
      const fresh = CardBinding.compose(makeCatalog(3), fakeUsage(), t,
        'form-42', '『付款码』暂无可用直达入口', false, true, t);
      expect(fresh.failure).assertContain('暂无可用直达入口');
      const stale = CardBinding.compose(makeCatalog(3), fakeUsage(), t + FAILURE_TTL_MS,
        'form-42', '『付款码』暂无可用直达入口', false, true, t);
      expect(stale.failure).assertEqual('');
    });
    it('compose_carries_failure_at_for_card_side_ttl', 0, () => {
      const t = 1_700_000_000_000;
      const b = CardBinding.compose(makeCatalog(3), fakeUsage(), t,
        'form-42', 'msg', false, true, t);
      expect(b.failureAt).assertEqual(t);
    });
  });
}
