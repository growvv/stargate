// Shared stub implementations for HarmonyOS SDK modules used by pure-logic .ets files.
export class Want {}
export class FormExtensionAbility { constructor() {} }
export class UIAbility { constructor() {} }
export const window = { WindowStage: class {} };
export const formBindingData = { createFormBindingData: (o) => ({ data: o }) };
export const formProvider = {
  updateForm: async (_id, _d) => {},
  setFormNextRefreshTime: async (_id, _min) => {},
};
export const formInfo = { FormState: { UNKNOWN: 0, DEFAULT: 1 } };
export const preferences = {
  getPreferences: async (_c, _n) => ({
    get: async (_k, _d) => _d,
    put: async (_k, _v) => {},
    flush: async () => {},
    delete: async (_k) => {},
  }),
  getPreferencesSync: (c, _o) => c?.__preferences ?? ({
    getSync: (_k, d) => d,
    putSync: (_k, _v) => {},
    flushSync: () => {},
  }),
};
export const relationalStore = { getRdbStore: async (_c, _cfg) => ({}) };
export const resourceManager = { getRawFileContentSync: (_p) => new Uint8Array() };
export const fileIo = {
  accessSync: (_p) => false,
  readTextSync: (_p) => '[]',
};
