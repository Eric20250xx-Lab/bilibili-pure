# 简看

用于 Android 的 B 站纯净观看客户端，基于 [PiliPlus 2.1.4](https://github.com/bggRGjQaUbCoE/PiliPlus/releases/tag/2.1.4) 修改。

## 功能

- 搜索普通视频、番剧和影视，保留官方网页分类搜索的返回顺序，支持分页与视频排序、时长筛选。
- 短信或官方 App 扫码登录，使用同一个账号进行搜索和视频播放。
- 视频、弹幕、字幕、分 P / 选集、倍速、清晰度与全屏播放。
- 查看评论与楼中楼，支持热度/时间排序、分页和评论图片。
- 查看当前 B 站账号的观看历史，点击按记录的进度继续播放。
- 不提供推荐、直播、发表评论、点赞、投币、关注、收藏或下载入口。
- 去掉标记为广告的搜索卡片；UP 主录制在视频内的广告原样播放。

## 安装

安装 `dist/jiankan-0.1.1-arm64-v8a.apk`。应用名称为“简看”，包名 `com.jiankan.player`，可与官方 B 站和 PiliPlus 共存。

首次打开点击“登录”。使用大会员账号后，播放能力仍取决于官方接口返回的权限、片源和设备解码支持。搜索以官方网页分类接口为准，官方 App 与网页不同时间、不同会话的结果可能不同。

此包使用本机测试签名；后续更新需要保留同一签名。没有后台服务器，账号凭证只存放在应用私有目录。退出登录会清除本地账号凭证。

## 本机构建

```bash
bash scripts/pure-build-setup.sh
bash scripts/pure-build.sh
```

首次构建需要联网下载较大的工具链和依赖。工具、缓存与补丁隔离在 `.toolchain/`；不修改共享 Flutter SDK。上游需要特定 Flutter 与 material_ui 补丁，由构建脚本按固定顺序应用。

```bash
source scripts/pure-build-env.sh
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub test/pure_search_test.dart
```

以上 `source` 命令在 Bash 中执行。APK 原始产物为 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。

## 验证

具体构建、模拟器和待用户验证项目见 [验收记录](docs/ACCEPTANCE.md)。小米 Android 16 真机已验证普通视频、会员番剧和纪录片播放及弹幕；具体通过项与限制见验收记录。

## 开源来源

上游版本：`ce17223a8d71338d0c452a05f8fc55e86a3bba64`（PiliPlus 2.1.4）。

遵循 [GPL-3.0](LICENSE)，保留 [PiliPlus 原说明](docs/PiliPlus-README.md) 和依赖许可。修改后的源码随 APK 提供；没有修改或解锁 B 站会员权限。
