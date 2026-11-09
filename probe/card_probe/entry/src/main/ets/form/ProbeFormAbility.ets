import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import Want from '@ohos.app.ability.Want';

export default class ProbeFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData({ title: '探针卡片', items: [] });
  }
  onFormEvent(formId: string, message: string): void {
    console.info('probe onFormEvent: ' + formId + ' / ' + message);
  }
  onUpdateForm(formId: string): void {}
  onRemoveForm(formId: string): void {}
}
