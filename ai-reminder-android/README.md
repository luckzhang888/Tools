# AI 地点提醒（Android 第一版）

在 Android 手机上集成 **公司打卡提醒、地理围栏、待取快递和本地消息通知**。本项目存放在仓库的独立 `ai-reminder-android` 分支，**不会修改 main 分支**。

## 当前可用功能

- Kotlin + Jetpack Compose 四个页面：首页、地点、快递、提醒
- 通过 Android 原生 LocationManager 获取 GPS / 网络定位，不需要 Google Play Services
- 用户点击启动后，使用 **前台定位服务** 持续监测（状态栏有常驻通知）
- 通过最近定位坐标添加公司、快递站、其它地点；自定义 80~2000m 半径
- 公司进入 / 离开提醒打卡；接近快递站且确有未领取包裹时通知
- 60m 退出迟滞，减少 GPS 漂移导致反复触发
- 快递列表、领取状态、提醒完成确认
- SharedPreferences + JSON 本地保存，无需账号、服务器和网络上传

## 重要限制

- 这只是 **MVP 第一版**：不包含 LiveKit VoIP、AI 对话、服务端或短信网关。这些会在后续迭代接入。
- 默认前台服务位置监测，**不是低功耗系统 Geofencing 实现**：需要主动点击启动，可能更耗电。锁屏后能否持续运行取决于 Android 厂商的省电策略；系统强制停止/重启后需要重新启动。
- 地理位置有误差，检测不保证准点；无需将 GPS 用于考勤作弊或自动打卡。
- 该版本使用手机当前定位添加地点：到需要提醒的位置打开 App、启动监测并等待拿到坐标后再添加。
- 需要授予精确位置、通知权限；使用前请确认定位开关已打开。
- 对快递需手工维护状态，本版本不读取短信和其他 App 的隐私通知。
- 仅用于个人手机本地提醒；代码不应上传真实家庭、公司坐标或快递取件信息。

## GitHub Actions 云端编译

打开仓库 Actions 中的 **Android AI Reminder APK**。向 `ai-reminder-android` 分支推送相关代码会自动执行 Gradle 的 `assembleDebug`。

成功后打开对应运行记录的 **Artifacts**，下载 `ai-reminder-debug-apk`，解压得到 `app-debug.apk`，安装到 Android 手机即可。

云端构建使用 JDK 17、Gradle 8.13、Android Gradle Plugin 8.13.0、Android SDK 36。Debug APK 是 Android 调试签名版，不是用于应用商店正式发布的 Release 包。

## 继续开发

1. 先在 Android 真机验证后台定位、耗电与精确度
2. 增加更省电的系统/厂商地理围栏
3. 接入 Node.js/SQLite 服务器，支持多个提醒规则和设备同步
4. 接入 LiveKit VoIP、锁屏来电推送和 AI 语音消息

## 源码目录

```
ai-reminder-android/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle.properties
└── app/
    ├── build.gradle.kts
    └── src/main/
        ├── AndroidManifest.xml
        └── java/dev/luck/aireminder/
            ├── MainActivity.kt
            ├── DataStore.kt
            └── LocationMonitorService.kt
```
