import fileIo from '@ohos.file.fs';
import type common from '@ohos.app.ability.common';
import { CATEGORIES } from '../model/AtomicFunction';
import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 能力库。D5 拍板：加载路径可配置，开发期可用 `hdc push` 替换外部 JSON，
 * 不重新打包 HAP、不建服务端、不上云。
 *
 * 优先级：外部可替换配置文件 > HAP 内 rawfile 种子 > 直接注入的内存条目。
 * A3 第 4 轮政策（2026-11-09，用户拍板）：capabilities.json 收录**所有在真机
 * 上点击后有反应**的入口 —— 落到目标 App 首页、登录页、注册页、隐私/授权同意页
 * 都算有反应；只有「暂无可用打开方式 / 启动失败」才剔除。需要用户自己完成的
 * 登录与协议同意，由卡片上的 hint 明示（需登录 / 需同意 / 选择打开）。
 * TestFixtures.makeCatalog 仍用合成条目做单测，不冒充真实能力库。
 *
 * 产品层覆盖预研层：每个 AtomicFunction 只保留**一条最可靠路由**（`route`），
 * 无 `routes[]`、无 `home` kind（Spec §7）。
 */
const DEFAULT_SEED_PATH: string = 'capabilities.json';
const EXTERNAL_CONFIG_PATH: string = '/data/storage/el2/base/haps/entry/files/capabilities.json';

/** 能力库只读访问契约（供 Task 3/4/5/6 消费）。 */
export interface CapabilityCatalog {
  listAll(): Promise<AtomicFunction[]>;
  listByCategory(category: string): Promise<AtomicFunction[]>;
  get(id: string): Promise<AtomicFunction | undefined>;
}

/** 能力库种子 JSON 的顶层结构（D5 外部文件与 rawfile 种子共用）。 */
export interface CapabilitySeed {
  items: AtomicFunction[];
}

const ROUTE_KINDS: string[] = ['want', 'deeplink', 'applinking', 'shortcut-param', 'vertical'];

export class CapabilityRepository implements CapabilityCatalog {
  private items: AtomicFunction[] = [];
  private seedPath: string;

  constructor(seedPath: string = DEFAULT_SEED_PATH) {
    this.seedPath = seedPath;
  }

  /**
   * UTF-8 字节 → 字符串。`getRawFileContentSync` 返回 UTF-8；逐字节当 Latin-1
   * 会把「支付宝」解成 mojibake。纯 TS 实现（不依赖 SDK），Node / ArkTS 均可编译。
   * 1/2/3/4 字节序列分别处理；非法字节尽力保留、不抛异常。
   */
  static decodeUtf8(bytes: Uint8Array): string {
    let out = '';
    for (let i = 0; i < bytes.length;) {
      const b0 = bytes[i];
      if (b0 < 0x80) {
        out += String.fromCharCode(b0);
        i += 1;
      } else if ((b0 & 0xE0) === 0xC0 && i + 1 < bytes.length) {
        const cp = ((b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
        out += String.fromCharCode(cp);
        i += 2;
      } else if ((b0 & 0xF0) === 0xE0 && i + 2 < bytes.length) {
        const cp = ((b0 & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
        out += String.fromCharCode(cp);
        i += 3;
      } else if ((b0 & 0xF8) === 0xF0 && i + 3 < bytes.length) {
        const cp = ((b0 & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) |
          ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
        out += String.fromCodePoint(cp);
        i += 4;
      } else {
        out += String.fromCharCode(b0); // 非法/孤立字节：尽力保留，不崩
        i += 1;
      }
    }
    return out;
  }

  /**
   * 同步生产构造（C1 修复）：FormAbility 的 onAddForm/onUpdateForm 是同步回调，
   * 无法 await。内部 I/O 本就全是同步 API，故同步工厂是唯一能接进运行时的路径。
   * 优先读取外部可替换配置（D5），不存在则回退 HAP rawfile 种子（UTF-8 正确解码）。
   */
  static fromContextSync(context: common.Context, externalPath?: string): CapabilityRepository {
    const repo = new CapabilityRepository();
    let text = '';
    try {
      const p = externalPath ?? EXTERNAL_CONFIG_PATH;
      if (fileIo.accessSync(p)) {
        text = fileIo.readTextSync(p); // D5：外部可替换文件，hdc push 即生效
      } else {
        const bytes = context.resourceManager.getRawFileContentSync(repo.seedPath);
        text = CapabilityRepository.decodeUtf8(bytes);
      }
    } catch (_err) {
      text = '';
    }
    repo.items = CapabilityRepository.parse(text);
    return repo;
  }

  /** 保留异步门面供既有调用方；委托同步工厂（内部无 await）。 */
  static async fromContext(context: common.Context, externalPath?: string): Promise<CapabilityRepository> {
    return CapabilityRepository.fromContextSync(context, externalPath);
  }

  /** 纯逻辑构造（本地单测 / 预览）：直接注入条目，不触碰 SDK。 */
  static fromItems(items: AtomicFunction[], seedPath?: string): CapabilityRepository {
    const repo = new CapabilityRepository(seedPath ?? DEFAULT_SEED_PATH);
    repo.items = items.slice();
    return repo;
  }

  /**
   * 解析能力库 JSON 文本；非法/空文本返回空数组（空态不崩）。
   * 只保留带 id / appName / route 的合法条目，且每条只含单条 route（无 routes[]/home）。
   */
  static parse(text: string): AtomicFunction[] {
    if (!text) return [];
    try {
      const seed = JSON.parse(text) as CapabilitySeed;
      const arr: AtomicFunction[] = seed && Array.isArray(seed.items) ? seed.items : [];
      // M1/I1：外部可替换文件是配置边界，必须校验，禁止 home kind / 非法类目混入。
      return arr.filter((f) => f && f.id && f.appName && f.bundleName && f.route && f.category &&
        ROUTE_KINDS.indexOf(f.route.kind) >= 0 && CATEGORIES.indexOf(f.category) >= 0 &&
        typeof f.confidence === 'number' && f.confidence >= 0 && f.confidence <= 1);
    } catch (_err) {
      return [];
    }
  }

  async listAll(): Promise<AtomicFunction[]> {
    return this.items.slice();
  }

  /** 同步读取条目副本（卡片 onAddForm / onUpdateForm 同步回调用，不触碰异步 SDK）。 */
  itemsSnapshot(): AtomicFunction[] {
    return this.items.slice();
  }

  async listByCategory(category: string): Promise<AtomicFunction[]> {
    return this.items.filter((f) => f.category === category);
  }

  async get(id: string): Promise<AtomicFunction | undefined> {
    return this.items.find((f) => f.id === id);
  }
}

export default CapabilityRepository;
