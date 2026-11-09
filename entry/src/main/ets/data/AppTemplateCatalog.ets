import type common from '@ohos.app.ability.common';
import { CATEGORIES } from '../model/AtomicFunction';
import type { Route } from '../model/AtomicFunction';
import { CapabilityRepository } from './CapabilityRepository';

/** A candidate function from an app template.  It is intentionally separate
 * from AtomicFunction so an unverified candidate cannot masquerade as L1. */
export interface TemplateFunction {
  label: string;
  route: Route;
}

export type TemplateKind = 'third-party' | 'system' | 'unknown';

export interface AppTemplateEntry {
  id: string;
  appName: string;
  bundleName: string;
  category: string;
  scheme: string;
  kind: TemplateKind;
  functions: TemplateFunction[];
  verifiedByProbe: boolean;
}

export interface AppTemplateSeed {
  templates: AppTemplateEntry[];
}

const ROUTE_KINDS: string[] = ['want', 'deeplink', 'applinking', 'shortcut-param', 'vertical'];
const SCHEME_RE: RegExp = /^[a-zA-Z][0-9a-zA-Z+.-]*$/;

/** Local, replaceable candidate directory.  Invalid data is discarded rather
 * than causing the card/provider process to fail. */
export class AppTemplateCatalog {
  private values: AppTemplateEntry[] = [];

  private constructor(entries: AppTemplateEntry[]) {
    this.values = entries.map((entry) => AppTemplateCatalog.copyEntry(entry));
  }

  private static copyEntry(entry: AppTemplateEntry): AppTemplateEntry {
    const copiedFunctions: TemplateFunction[] = [];
    entry.functions.forEach((fn: TemplateFunction) => {
      const route: Route = {
        kind: fn.route.kind,
        uri: fn.route.uri,
        parameters: fn.route.parameters,
        abilityName: fn.route.abilityName,
        moduleName: fn.route.moduleName
      };
      const copied: TemplateFunction = { label: fn.label, route: route };
      copiedFunctions.push(copied);
    });
    return {
      id: entry.id,
      appName: entry.appName,
      bundleName: entry.bundleName ?? '',
      category: entry.category,
      scheme: entry.scheme ?? '',
      kind: entry.kind,
      verifiedByProbe: entry.verifiedByProbe === true,
      functions: copiedFunctions
    };
  }

  static parse(text: string): AppTemplateEntry[] {
    if (!text) return [];
    try {
      const seed = JSON.parse(text) as AppTemplateSeed;
      if (!seed || !Array.isArray(seed.templates)) return [];
      const out: AppTemplateEntry[] = [];
      for (const raw of seed.templates) {
        if (!raw || typeof raw.id !== 'string' || raw.id.length === 0 ||
          typeof raw.appName !== 'string' || raw.appName.length === 0 ||
          typeof raw.category !== 'string' || CATEGORIES.indexOf(raw.category) < 0 ||
          (raw.kind !== 'third-party' && raw.kind !== 'system' && raw.kind !== 'unknown') ||
          !Array.isArray(raw.functions)) continue;
        const functions: TemplateFunction[] = [];
        for (const f of raw.functions) {
          if (!f || typeof f.label !== 'string' || f.label.length === 0 ||
            !f.route || ROUTE_KINDS.indexOf(f.route.kind) < 0) continue;
          functions.push({ label: f.label, route: f.route });
        }
        // An entry with no valid candidate cannot produce an effective item.
        if (functions.length === 0) continue;
        const scheme = typeof raw.scheme === 'string' && SCHEME_RE.test(raw.scheme)
          ? raw.scheme : '';
        out.push({
          id: raw.id,
          appName: raw.appName,
          bundleName: typeof raw.bundleName === 'string' ? raw.bundleName : '',
          category: raw.category,
          scheme,
          kind: raw.kind,
          functions,
          verifiedByProbe: raw.verifiedByProbe === true
        });
      }
      return out;
    } catch (_err) {
      return [];
    }
  }

  static schemes(entries: AppTemplateEntry[]): string[] {
    const set: Set<string> = new Set<string>();
    entries.forEach((entry) => {
      if (entry.scheme && SCHEME_RE.test(entry.scheme)) set.add(entry.scheme);
    });
    return Array.from(set).sort();
  }

  static fromEntries(entries: AppTemplateEntry[]): AppTemplateCatalog {
    return new AppTemplateCatalog(entries);
  }

  static fromContextSync(context: common.Context): AppTemplateCatalog {
    try {
      const bytes = context.resourceManager.getRawFileContentSync('app_templates.json');
      return AppTemplateCatalog.fromEntries(AppTemplateCatalog.parse(
        CapabilityRepository.decodeUtf8(bytes)));
    } catch (_err) {
      return AppTemplateCatalog.fromEntries([]);
    }
  }

  entries(): AppTemplateEntry[] {
    return this.values.map((entry) => AppTemplateCatalog.copyEntry(entry));
  }
}

export default AppTemplateCatalog;
