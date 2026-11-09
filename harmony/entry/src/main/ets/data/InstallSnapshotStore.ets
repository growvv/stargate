import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';
import { CatalogDiff } from './CatalogDiff';
import type { InstallSnapshot } from './CatalogDiff';

const STORE_NAME: string = 'atomic_function_install_snapshot';
const SNAPSHOT_KEY: string = 'snapshot';

export class InstallSnapshotStore {
  private snapshot: InstallSnapshot;
  private pref: preferences.Preferences | undefined;

  private constructor(initial?: InstallSnapshot, pref?: preferences.Preferences) {
    this.snapshot = initial ? InstallSnapshotStore.copy(initial) : CatalogDiff.empty();
    this.pref = pref;
  }

  private static copy(s: InstallSnapshot): InstallSnapshot {
    // JSON round-trip creates a detached map without an untyped object literal;
    // ArkTS rejects `{}` when it is assigned to a Record type.
    const streak: Record<string, number> = JSON.parse(JSON.stringify(s.streak ?? {})) as Record<string, number>;
    const seen: Record<string, number> = JSON.parse(
      JSON.stringify(s.bundleFirstSeen ?? {})) as Record<string, number>;
    const copied: InstallSnapshot = {
      installedIds: (s.installedIds ?? []).slice(),
      probedAt: s.probedAt ?? 0,
      appVersionFingerprint: s.appVersionFingerprint ?? '',
      streak,
      bundleFirstSeen: seen,
      bundlesProbedAt: s.bundlesProbedAt ?? 0
    };
    return copied;
  }

  static fromMemory(initial?: InstallSnapshot): InstallSnapshotStore {
    return new InstallSnapshotStore(initial);
  }

  static fromContextSync(context: common.Context): InstallSnapshotStore {
    try {
      const pref = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = pref.getSync(SNAPSHOT_KEY, '{}');
      if (typeof raw === 'string' && raw.length > 0) {
        const value = JSON.parse(raw) as InstallSnapshot;
        if (value && Array.isArray(value.installedIds) && typeof value.streak === 'object') {
          return new InstallSnapshotStore(value, pref);
        }
      }
      return new InstallSnapshotStore(undefined, pref);
    } catch (_err) {
      return new InstallSnapshotStore();
    }
  }

  load(): InstallSnapshot {
    return InstallSnapshotStore.copy(this.snapshot);
  }

  save(snapshot: InstallSnapshot): void {
    this.snapshot = InstallSnapshotStore.copy(snapshot);
    if (!this.pref) return;
    try {
      this.pref.putSync(SNAPSHOT_KEY, JSON.stringify(this.snapshot));
      this.pref.flushSync();
    } catch (_err) {
      // Memory state remains authoritative for this process if persistence fails.
    }
  }
}

export default InstallSnapshotStore;
