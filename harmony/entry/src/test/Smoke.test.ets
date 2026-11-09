import { describe, it, expect } from '@ohos/hypium';
import Want from '@ohos.app.ability.Want';
import { FormAbility } from '../main/ets/form/FormAbility';

export default function smokeTest() {
  describe('Smoke', () => {
    it('form_ability_returns_binding_data', 0, () => {
      const ability = new FormAbility();
      const data = ability.onAddForm({} as Want);
      expect(data).not().assertUndefined();
    });
  });
}
