/**
 * 应用原生标识（2026-11-09 用户反馈修订）。
 *
 * 卡片进程无网络/文件系统，不能实时读取第三方 App 图标，因此把常用 App 的
 * **真实官方图标**打包进 entry 的 media 资源（logo_<key>.png），卡片与内页用
 * Image($r('app.media.logo_<key>')) 直接展示；同一 App 的不同功能共用同一 logo。
 *
 * 没有真实图标资源的系统应用（华为视频/音乐/日历/邮件等）回退到
 * 「品牌色 + 中性符号」，**不再用中文字作为 logo**；完全未命中的应用回退
 * 稳定颜色 + 「◆」符号。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动，也能编译进 widgets.abc。
 */

export interface AppMark {
  /** 是否命中了品牌标识表（true = 已知品牌，false = 稳定颜色回退）。 */
  native: boolean;
  /** 品牌键（'' = 未命中）；同时是真实 logo 资源的后缀。 */
  key: string;
  /** 是否有打包进 HAP 的真实 App logo（true 时 UI 直接画 Image）。 */
  hasLogo: boolean;
  /** 图标框底色（6 位 RGB）。 */
  bg: string;
  /** 图标框前景字形色。 */
  fg: string;
  /** 品牌符号 / 回退符号（绝不使用中文字）。 */
  glyph: string;
  /** 品牌名（回退时为空）。 */
  brand: string;
}

interface BrandEntry {
  keys: string[];
  key: string;
  hasLogo: boolean;
  bg: string;
  fg: string;
  glyph: string;
  brand: string;
}

/**
 * 品牌表：key 用「包含匹配」。顺序敏感 —— 更长/更具体的品牌必须排在
 * 短前缀之前（QQ音乐 before QQ，美团外卖 before 美团，百度网盘 before 百度…）。
 */
const BRANDS: BrandEntry[] = [
  // ── 有真实官方图标的第三方 App（logo_<key>.png）──────────────────
  { keys: ['QQ音乐', 'qqmusic'], key: 'qqmusic', hasLogo: true, bg: '#31C27C', fg: '#ffffff', glyph: '♪', brand: 'QQ音乐' },
  { keys: ['美团外卖', 'takeaway'], key: 'meituan_waimai', hasLogo: true, bg: '#FFD100', fg: '#3a2f00', glyph: '外', brand: '美团外卖' },
  { keys: ['百度网盘', 'netdisk'], key: 'baidu_netdisk', hasLogo: true, bg: '#2468F2', fg: '#ffffff', glyph: '云', brand: '百度网盘' },
  { keys: ['华为运动健康', '运动健康', 'health'], key: 'huawei_health', hasLogo: true, bg: '#F5405B', fg: '#ffffff', glyph: '♥', brand: '运动健康' },
  { keys: ['支付宝', 'alipay'], key: 'alipay', hasLogo: true, bg: '#1677FF', fg: '#ffffff', glyph: '支', brand: '支付宝' },
  { keys: ['微信', 'wechat', 'weixin'], key: 'wechat', hasLogo: true, bg: '#07C160', fg: '#ffffff', glyph: '微', brand: '微信' },
  { keys: ['淘宝', 'taobao'], key: 'taobao', hasLogo: true, bg: '#FF5000', fg: '#ffffff', glyph: '淘', brand: '淘宝' },
  { keys: ['天猫', 'tmall'], key: 'tmall', hasLogo: true, bg: '#FF0036', fg: '#ffffff', glyph: '猫', brand: '天猫' },
  { keys: ['京东', 'jd.'], key: 'jd', hasLogo: true, bg: '#E1251B', fg: '#ffffff', glyph: '京', brand: '京东' },
  { keys: ['拼多多', 'pinduoduo'], key: 'pinduoduo', hasLogo: true, bg: '#E02E24', fg: '#ffffff', glyph: '拼', brand: '拼多多' },
  { keys: ['唯品会', 'vip.com'], key: 'vip', hasLogo: true, bg: '#F10180', fg: '#ffffff', glyph: '唯', brand: '唯品会' },
  { keys: ['得物', 'dewu'], key: 'dewu', hasLogo: true, bg: '#00C2B3', fg: '#ffffff', glyph: '得', brand: '得物' },
  { keys: ['小红书', 'rednote'], key: 'xiaohongshu', hasLogo: true, bg: '#FF2442', fg: '#ffffff', glyph: '书', brand: '小红书' },
  { keys: ['抖音', 'douyin', 'tiktok'], key: 'douyin', hasLogo: true, bg: '#161823', fg: '#ffffff', glyph: '♪', brand: '抖音' },
  { keys: ['快手', 'kuaishou'], key: 'kuaishou', hasLogo: true, bg: '#FF4906', fg: '#ffffff', glyph: '快', brand: '快手' },
  { keys: ['微博', 'weibo'], key: 'weibo', hasLogo: true, bg: '#E6162D', fg: '#ffffff', glyph: '微', brand: '微博' },
  { keys: ['哔哩哔哩', 'bilibili'], key: 'bilibili', hasLogo: true, bg: '#FB7299', fg: '#ffffff', glyph: '哔', brand: '哔哩哔哩' },
  { keys: ['知乎', 'zhihu'], key: 'zhihu', hasLogo: true, bg: '#0084FF', fg: '#ffffff', glyph: '知', brand: '知乎' },
  { keys: ['美团', 'meituan'], key: 'meituan', hasLogo: true, bg: '#FFD100', fg: '#3a2f00', glyph: '美', brand: '美团' },
  { keys: ['大众点评', 'dianping'], key: 'dianping', hasLogo: true, bg: '#FF6633', fg: '#ffffff', glyph: '评', brand: '大众点评' },
  { keys: ['高德', 'amap', 'autonavi'], key: 'amap', hasLogo: true, bg: '#00A6FB', fg: '#ffffff', glyph: '高', brand: '高德地图' },
  { keys: ['百度地图', 'baidumap'], key: 'baidu_map', hasLogo: true, bg: '#2932E1', fg: '#ffffff', glyph: '百', brand: '百度地图' },
  { keys: ['12306', '铁路'], key: 'railway12306', hasLogo: true, bg: '#E02020', fg: '#ffffff', glyph: '铁', brand: '中国铁路' },
  { keys: ['中国移动', 'cmcc'], key: 'china_mobile', hasLogo: true, bg: '#0085D0', fg: '#ffffff', glyph: '移', brand: '中国移动' },
  { keys: ['喜马拉雅', 'ximalaya'], key: 'ximalaya', hasLogo: true, bg: '#F86442', fg: '#ffffff', glyph: '听', brand: '喜马拉雅' },
  { keys: ['WPS', 'wps'], key: 'wps', hasLogo: true, bg: '#E03E2D', fg: '#ffffff', glyph: 'W', brand: 'WPS Office' },
  { keys: ['夸克', 'quark'], key: 'quark', hasLogo: true, bg: '#4A6CF7', fg: '#ffffff', glyph: '夸', brand: '夸克' },
  { keys: ['懂球帝', 'dongqiudi'], key: 'dongqiudi', hasLogo: true, bg: '#0F1E4A', fg: '#ffffff', glyph: '球', brand: '懂球帝' },
  { keys: ['虎扑', 'hupu'], key: 'hupu', hasLogo: true, bg: '#E62E2E', fg: '#ffffff', glyph: '虎', brand: '虎扑' },
  { keys: ['转转', 'zhuanzhuan'], key: 'zhuanzhuan', hasLogo: true, bg: '#0FC6C2', fg: '#ffffff', glyph: '转', brand: '转转' },
  { keys: ['爱奇艺', 'iqiyi'], key: 'iqiyi', hasLogo: true, bg: '#00BE06', fg: '#ffffff', glyph: '奇', brand: '爱奇艺' },
  { keys: ['豆包', 'doubao'], key: 'doubao', hasLogo: true, bg: '#3B82F6', fg: '#ffffff', glyph: '豆', brand: '豆包' },
  { keys: ['58同城', '58'], key: 'fiftyeight', hasLogo: true, bg: '#FF552E', fg: '#ffffff', glyph: '58', brand: '58同城' },
  { keys: ['UC浏览器', 'uc'], key: 'uc', hasLogo: true, bg: '#FF6A00', fg: '#ffffff', glyph: 'U', brand: 'UC浏览器' },
  { keys: ['个人所得税', 'tax'], key: 'tax', hasLogo: true, bg: '#2E7D32', fg: '#ffffff', glyph: '税', brand: '个人所得税' },
  { keys: ['QQ', '腾讯QQ'], key: 'qq', hasLogo: true, bg: '#12B7F5', fg: '#ffffff', glyph: 'Q', brand: 'QQ' },

  // ── 无真实图标的系统 / 内置应用：品牌色 + 中性符号（不用中文）─────
  { keys: ['华为视频', 'himovie'], key: 'huawei_video', hasLogo: false, bg: '#CF0A2C', fg: '#ffffff', glyph: '▶', brand: '华为视频' },
  { keys: ['华为音乐', 'hmsapp.music'], key: 'huawei_music', hasLogo: false, bg: '#CF0A2C', fg: '#ffffff', glyph: '♪', brand: '华为音乐' },
  { keys: ['华为阅读', 'books'], key: 'huawei_books', hasLogo: false, bg: '#CF0A2C', fg: '#ffffff', glyph: '▤', brand: '华为阅读' },
  { keys: ['华为浏览器', 'browser'], key: 'huawei_browser', hasLogo: false, bg: '#CF0A2C', fg: '#ffffff', glyph: '◎', brand: '华为浏览器' },
  { keys: ['华为地图', 'petal'], key: 'huawei_maps', hasLogo: false, bg: '#CF0A2C', fg: '#ffffff', glyph: '⌖', brand: '华为地图' },
  { keys: ['小艺', 'vassistant'], key: 'xiaoyi', hasLogo: false, bg: '#4E7CF6', fg: '#ffffff', glyph: '✦', brand: '小艺' },
  { keys: ['手机克隆', 'dataclone'], key: 'dataclone', hasLogo: false, bg: '#4E7CF6', fg: '#ffffff', glyph: '⇄', brand: '手机克隆' },
  { keys: ['教育空间'], key: 'edu_space', hasLogo: false, bg: '#F5A623', fg: '#ffffff', glyph: '⌂', brand: '教育空间' },
  { keys: ['电子邮件', 'email'], key: 'huawei_email', hasLogo: false, bg: '#CF0A2C', fg: '#ffffff', glyph: '✉', brand: '电子邮件' },
  { keys: ['日历', 'calendar'], key: 'calendar', hasLogo: false, bg: '#FFFFFF', fg: '#E02020', glyph: '▦', brand: '日历' },
  { keys: ['系统能力', 'stargate'], key: 'system', hasLogo: false, bg: '#1C1C1E', fg: '#ffffff', glyph: '✦', brand: 'StarGate' },
  { keys: ['天气', 'weather'], key: 'weather', hasLogo: false, bg: '#3B9CFF', fg: '#ffffff', glyph: '☀', brand: '天气' },
  { keys: ['腾讯视频', 'qqlive'], key: 'tencent_video', hasLogo: false, bg: '#FF6A00', fg: '#ffffff', glyph: '▶', brand: '腾讯视频' },
  { keys: ['网易云音乐', 'cloudmusic', 'netease'], key: 'netease_music', hasLogo: false, bg: '#D33A31', fg: '#ffffff', glyph: '♪', brand: '网易云音乐' },
  { keys: ['备忘录', 'notepad', 'notes'], key: 'notepad', hasLogo: false, bg: '#FFC300', fg: '#3a2f00', glyph: '▤', brand: '备忘录' },
  { keys: ['设置', 'settings'], key: 'settings', hasLogo: false, bg: '#8E8E93', fg: '#ffffff', glyph: '⚙', brand: '设置' },
  { keys: ['相机', 'camera'], key: 'camera', hasLogo: false, bg: '#8E8E93', fg: '#ffffff', glyph: '◉', brand: '相机' },
  { keys: ['时钟', 'clock'], key: 'clock', hasLogo: false, bg: '#FFFFFF', fg: '#1a1a1a', glyph: '◷', brand: '时钟' },
  { keys: ['电话', 'phone'], key: 'phone', hasLogo: false, bg: '#34C759', fg: '#ffffff', glyph: '☎', brand: '电话' },
  { keys: ['信息', 'message', '短信'], key: 'messages', hasLogo: false, bg: '#34C759', fg: '#ffffff', glyph: '✉', brand: '信息' }
];

/** 回退配色（无品牌时按 appName 稳定取色）。 */
const FALLBACK: string[] = [
  '#5B8DEF', '#42B8A6', '#E8833A', '#C7609E', '#7A6BE0',
  '#3BA0C9', '#D26A6A', '#8A9A5B', '#6D6F9E', '#B07A46'
];

/** 未命中任何品牌时的中性符号（用户明确不要中文字 logo）。 */
const FALLBACK_GLYPH: string = '◆';

function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export class BrandMark {
  /** 按 appName 解析标识；未命中则回退「符号 + 稳定颜色」。 */
  static forApp(appName: string, label: string): AppMark {
    const key = (appName || '').toLowerCase();
    for (const b of BRANDS) {
      for (const k of b.keys) {
        if (key.indexOf(k.toLowerCase()) >= 0) {
          return {
            native: true, key: b.key, hasLogo: b.hasLogo,
            bg: b.bg, fg: b.fg, glyph: b.glyph, brand: b.brand
          };
        }
      }
    }
    const fallback: AppMark = {
      native: false,
      key: '',
      hasLogo: false,
      bg: FALLBACK[hash(key || 'x') % FALLBACK.length],
      fg: '#ffffff',
      glyph: FALLBACK_GLYPH,
      brand: ''
    };
    return fallback;
  }
}

export default BrandMark;
