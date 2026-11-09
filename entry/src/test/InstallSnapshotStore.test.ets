import { describe, it, expect } from '@ohos/hypium';
import { InstallSnapshotStore } from '../main/ets/data/InstallSnapshotStore';

export default function installSnapshotStoreTest() {
  describe('InstallSnapshotStore', () => {
    it('fromMemory_round_trips_a_snapshot', 0, () => {
      const st = InstallSnapshotStore.fromMemory(); st.save({ installedIds: ['a'], probedAt: 42, appVersionFingerprint: 'v1', streak: { a: 2 } });
      expect(st.load().installedIds[0]).assertEqual('a'); expect(st.load().probedAt).assertEqual(42); expect(st.load().streak.a).assertEqual(2);
    });
    it('fromMemory_defaults_to_empty_snapshot', 0, () => { expect(InstallSnapshotStore.fromMemory().load().installedIds.length).assertEqual(0); });
    it('fromContextSync_reads_a_persisted_snapshot', 0, () => {
      const raw = JSON.stringify({ installedIds: ['x'], probedAt: 1, appVersionFingerprint: 'v', streak: { x: 2 } });
      const ctx = { __preferences: { getSync: (_k: string, _d: Object) => raw, putSync: (_k: string, _v: Object) => {}, flushSync: () => {} } };
      const st = InstallSnapshotStore.fromContextSync(ctx); expect(st.load().installedIds[0]).assertEqual('x');
    });
    it('fromContextSync_survives_corrupt_json', 0, () => {
      const ctx = { __preferences: { getSync: (_k: string, _d: Object) => 'not-json', putSync: (_k: string, _v: Object) => {}, flushSync: () => {} } };
      expect(InstallSnapshotStore.fromContextSync(ctx).load().installedIds.length).assertEqual(0);
    });
  });
}
