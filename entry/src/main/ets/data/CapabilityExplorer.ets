import type { AtomicFunction, Route } from '../model/AtomicFunction';

/** 能力探索页使用的证据分层。它描述来源，不代表运行时一定能打开目标页面。 */
export type EvidenceLevel = 'verified' | 'rea' | 'ui-test' | 'manual' | 'unknown';

export interface ExplorerSummary {
  total: number;
  verified: number;
  rea: number;
  uiTest: number;
  manual: number;
  unknown: number;
}

export class CapabilityExplorer {
  static levelOf(source: string): EvidenceLevel {
    if (source === 'shortcut' || source === 'linkFeature' || source === 'scheme') {
      return 'verified';
    }
    if (source === 'rea') return 'rea';
    if (source === 'injection') return 'ui-test';
    if (source === 'manual') return 'manual';
    return 'unknown';
  }

  static levelLabel(level: EvidenceLevel): string {
    if (level === 'verified') return '已验证直达';
    if (level === 'rea') return 'REA 线索';
    if (level === 'ui-test') return 'UI Test 候选';
    if (level === 'manual') return '人工确认';
    return '待探测';
  }

  static sourceLabel(source: string): string {
    if (source === 'shortcut') return '系统快捷入口';
    if (source === 'linkFeature') return 'Link 特性';
    if (source === 'scheme') return '公开 Scheme';
    if (source === 'rea') return 'REA 静态分析';
    if (source === 'injection') return 'UI Test / 注入';
    if (source === 'manual') return '人工录入';
    return source.length > 0 ? source : '未知来源';
  }

  static routeLabel(route: Route): string {
    if (route.kind === 'shortcut-param') return 'Shortcut 参数';
    if (route.kind === 'deeplink') return 'Deep Link';
    if (route.kind === 'applinking') return 'App Linking';
    return 'Want';
  }

  static summarize(items: AtomicFunction[]): ExplorerSummary {
    const summary: ExplorerSummary = {
      total: items.length,
      verified: 0,
      rea: 0,
      uiTest: 0,
      manual: 0,
      unknown: 0
    };
    items.forEach((item: AtomicFunction) => {
      const level = CapabilityExplorer.levelOf(item.source);
      if (level === 'verified') summary.verified += 1;
      else if (level === 'rea') summary.rea += 1;
      else if (level === 'ui-test') summary.uiTest += 1;
      else if (level === 'manual') summary.manual += 1;
      else summary.unknown += 1;
    });
    return summary;
  }
}

export default CapabilityExplorer;
