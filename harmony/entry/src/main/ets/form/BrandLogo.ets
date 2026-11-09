/**
 * 真实 App logo 资源映射（2026-11-09 用户反馈）。
 *
 * 卡片与内页共用：BrandMark 负责「App 名 → 品牌键 / 是否有真实 logo」，
 * 本类负责「品牌键 → HAP 内置 media 资源」。图片是各 App 官方图标，
 * 同一 App 的所有原子功能共用同一 logo（用户明确要求）。
 *
 * 纯 UI 映射，使用 ArkUI 编译期 $r；未知键回退 StarGate 自身图标。
 */
export class BrandLogo {
  /** 品牌键 → 真实 App logo 资源。 */
  static image(key: string): Resource {
    switch (key) {
      case 'alipay': return $r('app.media.logo_alipay');
      case 'wechat': return $r('app.media.logo_wechat');
      case 'qq': return $r('app.media.logo_qq');
      case 'qqmusic': return $r('app.media.logo_qqmusic');
      case 'taobao': return $r('app.media.logo_taobao');
      case 'tmall': return $r('app.media.logo_tmall');
      case 'jd': return $r('app.media.logo_jd');
      case 'pinduoduo': return $r('app.media.logo_pinduoduo');
      case 'vip': return $r('app.media.logo_vip');
      case 'dewu': return $r('app.media.logo_dewu');
      case 'xiaohongshu': return $r('app.media.logo_xiaohongshu');
      case 'douyin': return $r('app.media.logo_douyin');
      case 'kuaishou': return $r('app.media.logo_kuaishou');
      case 'weibo': return $r('app.media.logo_weibo');
      case 'bilibili': return $r('app.media.logo_bilibili');
      case 'zhihu': return $r('app.media.logo_zhihu');
      case 'meituan': return $r('app.media.logo_meituan');
      case 'meituan_waimai': return $r('app.media.logo_meituan_waimai');
      case 'dianping': return $r('app.media.logo_dianping');
      case 'amap': return $r('app.media.logo_amap');
      case 'baidu_map': return $r('app.media.logo_baidu_map');
      case 'baidu_netdisk': return $r('app.media.logo_baidu_netdisk');
      case 'railway12306': return $r('app.media.logo_railway12306');
      case 'china_mobile': return $r('app.media.logo_china_mobile');
      case 'ximalaya': return $r('app.media.logo_ximalaya');
      case 'wps': return $r('app.media.logo_wps');
      case 'quark': return $r('app.media.logo_quark');
      case 'dongqiudi': return $r('app.media.logo_dongqiudi');
      case 'hupu': return $r('app.media.logo_hupu');
      case 'zhuanzhuan': return $r('app.media.logo_zhuanzhuan');
      case 'iqiyi': return $r('app.media.logo_iqiyi');
      case 'doubao': return $r('app.media.logo_doubao');
      case 'fiftyeight': return $r('app.media.logo_fiftyeight');
      case 'uc': return $r('app.media.logo_uc');
      case 'tax': return $r('app.media.logo_tax');
      case 'huawei_health': return $r('app.media.logo_huawei_health');
      default: return $r('app.media.app_icon');
    }
  }

  /** 该品牌键是否有真实 logo（与 BrandMark.hasLogo 保持一致）。 */
  static has(key: string): boolean {
    return key !== '';
  }
}

export default BrandLogo;
