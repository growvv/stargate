/**
 * 原子功能契约（产品 Spec §7 覆盖预研 Spec：运行时单路由、无 home kind、无 routes[]）。
 * appName 为可读 App 名（如「支付宝」），bundleName 为包名（如 com.alipay.mobile.client）。
 */
export type RouteKind = 'want' | 'deeplink' | 'applinking' | 'shortcut-param' | 'vertical';

export interface Route {
  kind: RouteKind;
  uri?: string;
  /** 值必须可放进 Want.parameters；A3 实测经纬度是真 number，不能字符串化。 */
  parameters?: Record<string, string | number | boolean>;
  abilityName?: string;
  moduleName?: string;
}

export interface AtomicFunction {
  id: string;
  label: string;
  appName: string;
  bundleName: string;
  category: string;
  route: Route;
  source: string;
  confidence: number;
  appVersionFingerprint?: string;
  /**
   * 用户可见的接入提示（A3 第 4 轮政策）：该入口点开后有反应，但可能需要
   * 登录 / 同意隐私协议 / 系统选择应用。空字符串表示直接打开。
   * 仅影响展示，不参与路由与启动。
   */
  hint?: string;
}

/** IOS_CATEGORY_SPEC 定稿：系统预置 9 类目，用户不可增删改。 */
export const CATEGORIES: string[] = [
  '支付', '购物', '出行', '社交', '生活', '娱乐', '健康运动', '工具效率', '其他'
];

/** 来源置信度（预研 Spec：L1=1.0 … L5=0.2 / L0=1.0）。 */
export const SOURCE_CONFIDENCE: Record<string, number> = {
  'shortcut': 1.0,
  'linkFeature': 0.95,
  'scheme': 0.85,
  // Template candidates prove installation/link availability only; the
  // concrete atomic-page landing still needs a separate A3 probe.
  'template': 0.5,
  'rea': 0.6,
  'injection': 0.2,
  'manual': 1.0
};

/**
 * L0 = 来自官方声明或人工登记、可进卡片的条目（形态 A Spec §4.1）。
 * template / rea / injection 只是候选，永远不进 EffectiveCatalog 的输出。
 * A3 第 4 轮政策（2026-11-09）：L0 不再要求「落到功能子页」；真机上点击后
 * 打开目标 App 的任意页面（首页 / 登录 / 隐私同意）即算有反应，予以保留。
 */
export const L0_SOURCES: string[] = ['linkFeature', 'scheme', 'shortcut', 'manual'];
export const L0_MIN_CONFIDENCE: number = 0.85;

export function isL0(fn: AtomicFunction): boolean {
  if (!fn || typeof fn.confidence !== 'number' || !Number.isFinite(fn.confidence)) return false;
  return L0_SOURCES.indexOf(fn.source) >= 0 && fn.confidence >= L0_MIN_CONFIDENCE;
}
