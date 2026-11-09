# probe/card_probe — THROWAWAY

一次性最小卡片 HAP，仅用于 Task 0 验证编译链/Form Kit 声明。
**不并入产品工程、不作为产品代码、不进 git。** 四个结论见 `probe/card_feasibility.md`。

构建（执行阶段已验证）：
```
DEVECO_SDK_HOME=D:/Huawei/command-line-tools/sdk \
  /d/Huawei/command-line-tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default
```
签名需本机材料；参考工程过期证书不复用。
