# 好好记账

一个供个人使用的离线 Flutter 记账应用。无需注册或登录，账本保存在设备本地的 `ledger.json` 文件中，不使用数据库。

## 下载 Android 安装包

[下载好好记账 v1.1.0 APK](https://github.com/NOTISMOON/mybill/releases/download/v1.1.0/haohao-jizhang-v1.1.0-build3.apk)（适用于 Android 7.0 及以上）。其他版本可在 [Releases 页面](https://github.com/NOTISMOON/mybill/releases)查看。

当前安装包使用项目开发签名，后续覆盖安装需要沿用同一签名。升级或卸载前建议先在“我的”导出账本备份。

## 功能

- **账单**：新增、编辑、删除收入与支出；按月份查看收支和结余；按类型、分类及备注筛选。账单、统计、我的使用底部悬浮胶囊导航切换。
- **总资产**：可在首页或“我的 → 设置本金”输入期初本金。总资产＝期初本金＋全部收入－全部支出，始终按整本账计算；切换月份只改变本月结余，不改变总资产。
- **统计**：月度每日趋势与支出分类占比；年度 12 个月收支对比，点击月份可返回该月账单。
- **我的**：把 JSON 备份保存到手机本地文件夹，或通过系统分享发送；导入时预览记录数，选择按 ID 合并或替换。替换前自动在应用内保存原账本。
- **个性化外观**：在“我的 → 外观偏好”选择壁纸，自动搭配模块颜色；账单、统计、记一笔、我的、底部导航可分别修改颜色与面板不透明度。壁纸遮罩可从 0% 调整，文字和图标保持实色。设置保存在本机。
- **人民币**：输入和展示以元为单位，JSON 内以整数分保存金额。例如 ¥12.50 存为 `1250`。

## 运行

使用 Flutter 3.44 或兼容版本，在项目目录执行：

```bash
flutter pub get
flutter run
```

已生成 Android、iOS 工程。连接手机并允许调试后，可以运行 `flutter devices` 查看设备 ID，再执行 `flutter run -d <设备 ID>`。Android 需要 Android SDK；iOS 需要 Xcode。

## 代码结构

```text
lib/
  main.dart                              启动入口
  app/                                   应用主题接入、底部导航、路由
  core/                                  共用主题与人民币格式化
  features/
    ledger/domain/                       流水模型与 JSON 字段
    ledger/data/                         本地账本读写
    ledger/presentation/                 账单页、录入页、可复用组件
    statistics/presentation/             月度与年度统计
    profile/data/                        JSON 备份与外观设置持久化
    profile/domain/                      外观模块与配置模型
    profile/presentation/                个人中心与独立外观偏好页面
```

应用首次启动就在应用文档目录创建空的 `ledger.json`。这个文件由应用自动维护；“导出到手机”会另存一份到你选择的位置。本金以整数分保存，不作为一笔收入。格式示例：

```json
{
  "schemaVersion": 2,
  "principalCents": 100000,
  "entries": [
    {
      "id": "example-1",
      "type": "expense",
      "amountCents": 1250,
      "category": "餐饮",
      "date": "2026-10-20",
      "note": "午餐"
    }
  ]
}
```

新版导入文件必须符合此结构，旧版 `schemaVersion: 1` 备份仍可导入，本金按 0 元处理。合并导入保留当前本金，替换导入使用文件中的本金。应用会校验版本、字段、日期、金额和重复 ID。正常保存先写临时文件，再替换账本文件。请定期从“我的”导出到手机文件夹，方便卸载应用或换设备时恢复。

各模块颜色、面板不透明度和壁纸遮罩强度保存在同一应用文档目录的 `appearance.json`，背景图保存在 `background.img`。旧版外观设置会自动升级并保留原主题色与蒙层状态。账本 JSON 备份包含本金与记账记录，外观设置保存在当前设备上。

## 验证

```bash
flutter analyze
flutter test
```
