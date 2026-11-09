/**
 * 配置可达性纯判定（产品 Spec §3.1 / B3′ / Task 0 SYSTEM_EDIT_ENTRY=false）。
 *
 * SYSTEM_EDIT_ENTRY=false：桌面长按菜单没有自定义配置页入口。
 * 因此产品里不存在「点了没反应」的配置入口：
 *  - isReachable(entry)：只有系统确实提供入口时才为 true；
 *  - firstAddGuideEnabled(entry)：无系统入口时，仅在首次添加卡片时显示引导配置。
 */
export class ConfigAccess {
  static isReachable(systemEditEntry: boolean): boolean {
    return systemEditEntry;
  }

  static firstAddGuideEnabled(systemEditEntry: boolean): boolean {
    return !systemEditEntry;
  }

  /**
   * I5：formConfigAbility ("ability://EntryAbility") 拉起 UIAbility 时 Want 不带 page。
   * 不能让它落到 pages/Index 占位页（死入口）；缺省即视为打开配置页。
   * 已有明确 page 时原样放行，避免覆盖分类/全量/直达路由。
   */
  static pageForFormConfig(page: string): string {
    return page ? page : 'config';
  }
}

export default ConfigAccess;
