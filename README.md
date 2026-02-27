# Auto Lock Screen

一个 Flutter + Android 原生应用，在用户长时间未操作手机时自动锁定屏幕。

## 功能

- **自动锁屏** — 用户设定超时时间（1–60 分钟），屏幕亮起后若无操作则自动锁屏
- **前台服务** — 通过 Android Foreground Service 在后台持续监控，不会被系统杀死
- **立即锁屏** — 一键手动锁定屏幕
- **超时预设** — 提供常用时间快捷选择（1/2/3/5/10/15/30/60 分钟）
- **设置持久化** — 超时时间偏好自动保存

## 工作原理

1. 应用注册为 **设备管理员（Device Admin）**，获得调用 `DevicePolicyManager.lockNow()` 的权限
2. 启动 **前台服务（Foreground Service）**，监听屏幕亮/灭广播
3. 屏幕亮起时启动倒计时，到期后自动锁屏
4. 屏幕熄灭或用户解锁时重置计时器

## 权限说明

| 权限 | 用途 |
|------|------|
| `FOREGROUND_SERVICE` | 运行后台监控服务 |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Android 14+ 前台服务类型声明 |
| `POST_NOTIFICATIONS` | Android 13+ 显示服务通知 |
| `BIND_DEVICE_ADMIN` | 设备管理员锁屏能力 |

## 开发环境

- Flutter 3.38+
- Dart 3.10+
- Android SDK: minSdk 26 (Android 8.0+)
- Kotlin

## 运行

```bash
flutter pub get
flutter run
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口 & 主界面
└── services/
    └── lock_service.dart     # Platform Channel 服务封装

android/app/src/main/
├── AndroidManifest.xml       # 权限 & 组件声明
├── res/xml/device_admin.xml  # 设备管理员策略
└── kotlin/.../
    ├── MainActivity.kt                  # MethodChannel 处理
    ├── AutoLockDeviceAdminReceiver.kt   # 设备管理员接收器
    └── LockScreenService.kt            # 前台服务 & 锁屏逻辑
```
