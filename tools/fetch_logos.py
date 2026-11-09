"""Download official App Store artwork for the StarGate capability catalog.

Source: Apple iTunes Search API (country=cn). Artwork is the official app icon
published by each vendor; it is bundled only as a local UI asset for the
user's personal launcher panel. Output: entry/src/main/resources/base/media/
logo_<key>.png at 256x256.
"""
import io
import json
import os
import ssl
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "entry", "src", "main", "resources", "base", "media")
TMP_DIR = os.path.join(ROOT, "tools", "downloaded_logos")

# key: (search term, required prefix, exact)
APPS = {
    "alipay": ("支付宝", "支付宝", False),
    "wechat": ("微信", "微信", True),
    "qq": ("QQ", "QQ", True),
    "qqmusic": ("QQ音乐", "QQ音乐", False),
    "taobao": ("淘宝", "淘宝", False),
    "tmall": ("天猫", "天猫", False),
    "jd": ("京东", "京东", False),
    "pinduoduo": ("拼多多", "拼多多", False),
    "vip": ("唯品会", "唯品会", False),
    "dewu": ("得物", "得物", False),
    "xiaohongshu": ("小红书", "小红书", False),
    "douyin": ("抖音", "抖音", True),
    "kuaishou": ("快手", "快手", True),
    "weibo": ("微博", "微博", True),
    "bilibili": ("哔哩哔哩", "哔哩哔哩", False),
    "zhihu": ("知乎", "知乎", True),
    "meituan": ("美团", "美团", False),
    "dianping": ("大众点评", "大众点评", False),
    "amap": ("高德地图", "高德地图", False),
    "baidu_map": ("百度地图", "百度地图", False),
    "baidu_netdisk": ("百度网盘", "百度网盘", False),
    "railway12306": ("铁路12306", "铁路12306", False),
    "china_mobile": ("中国移动", "中国移动", False),
    "ximalaya": ("喜马拉雅", "喜马拉雅", False),
    "wps": ("WPS Office", "WPS Office", False),
    "quark": ("夸克", "夸克", False),
    "dongqiudi": ("懂球帝", "懂球帝", False),
    "hupu": ("虎扑", "虎扑", False),
    "zhuanzhuan": ("转转", "转转", False),
    "iqiyi": ("爱奇艺", "爱奇艺", False),
    "meituan_waimai": ("美团外卖", "美团外卖", False),
    "doubao": ("豆包", "豆包", False),
    "fiftyeight": ("58同城", "58同城", False),
    "uc": ("UC浏览器", "UC浏览器", False),
    "tax": ("个人所得税", "个人所得税", False),
    "huawei_health": ("华为运动健康", "华为运动健康", False),
}

BAD_TOKENS = ["极速版", "众包", "闪购", "骑士", "儿童", "专业版", "企业版", "轻享版", "简洁版"]


def search(term):
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"term": term, "country": "cn", "entity": "software", "limit": 10})
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(url, timeout=20, context=ctx) as resp:
        return json.load(resp).get("results", [])


def pick(results, prefix, exact):
    for track in results:
        name = track.get("trackName", "")
        if exact and name == prefix:
            return track
        if not exact and name.startswith(prefix):
            if any(bad in name for bad in BAD_TOKENS):
                continue
            return track
    return None


def download(url):
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(url, timeout=30, context=ctx) as resp:
        return resp.read()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)
    failures = []
    for key, (term, prefix, exact) in APPS.items():
        try:
            chosen = pick(search(term), prefix, exact)
            if chosen is None:
                failures.append((key, "no match"))
                print("MISS", key)
                continue
            art = chosen.get("artworkUrl512") or chosen.get("artworkUrl100", "").replace(
                "100x100bb", "512x512bb")
            raw = download(art)
            src = os.path.join(TMP_DIR, key + ".img")
            with open(src, "wb") as f:
                f.write(raw)
            im = Image.open(io.BytesIO(raw)).convert("RGB")
            im = im.resize((256, 256), Image.LANCZOS)
            dst = os.path.join(OUT_DIR, "logo_" + key + ".png")
            im.save(dst, "PNG", optimize=True)
            print("OK  ", key, "<-", chosen.get("trackName"))
            time.sleep(0.35)
        except Exception as exc:  # noqa: BLE001 - report and continue
            failures.append((key, str(exc)))
            print("FAIL", key, exc)
    print("failures:", failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
