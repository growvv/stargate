/** 直达结果。失败固定 reason='NO_AVAILABLE_ENTRY'，不回退 App 首页（Spec §7）。 */
export interface LaunchResult {
  ok: boolean;
  functionId: string;
  reason?: string;
}

/** Want 构造/启动函数：注入真实 context.startAbility 或测试替身。 */
export type StartAbilityFn = (want: Object) => Promise<boolean>;

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
