# entry/src/ohosTest — 设备侧测试骨架

依赖 uitest 扩展（StarStack 逆向笔记）：`@ohos/hypium@1.0.21` 的本地单测 + 设备侧测试均依赖 uitest 的隐藏扩展机制。
**测试态能力只用于验证我们自己的 HAP/卡片，不进运行时，不针对真实第三方 App 实施模拟点击。**

扩展 API 名在 Task 1 现场核对 DevEco CLI / `@ohos.UiTest.d.ts` 后再接入，本骨架不臆造。
预期验证点：4×4 卡片节点数、`BLUR_SUPPORTED`、页面往返/搜索/索引、直达成功与失败、§8 五场景回归。
