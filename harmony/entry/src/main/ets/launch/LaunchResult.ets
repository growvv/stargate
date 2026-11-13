/** 直达结果。失败固定 reason='NO_AVAILABLE_ENTRY'，不回退 App 首页（Spec §7）。 */
export interface LaunchResult {
  ok: boolean;
  functionId: string;
  reason?: string;
}

/** Want 构造/启动函数：注入真实 context.startAbility 或测试替身。 */
export type StartAbilityFn = (want: Object) => Promise<boolean>;

/**
 * 打开链接函数（生产侧 = UIAbilityContext.openLink，测试侧注入替身）。
 *
 * 为什么不用 startAbility：真机 2026-11-11 验证，三方应用自己拼一个
 * bundleName + uri 的隐式 Want 调 startAbility，会被生态规则拦下
 * （AMS: [implicit_start_processor.cpp340]failed）。补 action 也不够。
 * openLink 是系统为「打开一个链接」提供的入口，由它负责按目标 App 声明的
 * skill 匹配，这正是「点开卡片图标就进到那个功能」需要的语义。
 */
export type LinkOpenerFn = (uri: string) => Promise<boolean>;

/**
 * 官方垂类面板启动函数（形态 A S3）。SDK-free：生产侧由 VerticalStarter
 * 适配 UIAbilityContext.startAbilityByType，测试侧注入替身。
 * type=verticalType，wantParam=业务参数（含 sceneType，不含 verticalType）。
 */
export type VerticalStarterFn = (type: string, wantParam: Record<string, Object>) => Promise<boolean>;

/** 用量记录接口（结构兼容 UsageStore.record，避免测试替身强耦合具体类）。 */
export interface UsageRecorder {
  record(functionId: string, at: number): Promise<void>;
}
