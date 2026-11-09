// Minimal SDK shims so real .ets production files can be imported by the Node test runner.
// Only pure logic is exercised here; ArkUI/device APIs are stubbed.
export default class Want {}
export class FormExtensionAbility { constructor() {} }
export const formBindingData = { createFormBindingData: (o) => ({ data: o }) };
export const formProvider = { updateForm: async (_id, _d) => {} };
export const preferences = {
  getPreferences: async () => ({ get: async () => '', put: async () => {}, flush: async () => {} }),
  getPreferencesSync: (context, _options) => context?.__preferences ?? ({
    getSync: (_key, fallback) => fallback,
    putSync: (_key, _value) => {},
    flushSync: () => {}
  })
};
export const relationalStore = { getRdbStore: async () => ({}) };
export const formInfo = { FormState: { UNKNOWN: 0 } };
export const window = { WindowStage: class {} };
export class UIAbility { constructor() {} }
