# Mihomo 配置文件集合

> **项目地址**: [666OS/YYDS](https://github.com/666OS/YYDS) ｜ **TG 频道**: https://t.me/Pinched666

---

> [!IMPORTANT]
> **📢 旧版本归档与 v2.0 路径调整通知**
> 历史版本（`MihomoPro`、`OneSmartPro`、`OneSmart`、`OneTouch`）已迁移至 [legacy/](./legacy/) 目录维护，内容保持不变。**老用户订阅需在直连 URL 中添加 `/legacy/`，否则将返回 404**。
> 新版采用 `Pro`（全能）、`Lite`（轻量）、`Mini`（极简）三级方案，分别位于 [cn/](./cn/) 与 [en/](./en/) 目录。
>
> **⚠️ Mihomo 内核与兼容性说明**
> > - **内核要求**：v2.0 基于最新 Mihomo 规范，支持 MRS 二进制规则等特性。
> > - **配置语法**：采用 `x-` 前缀扩展锚点（如 `x-base-provider`、`x-url-test`），结构更简洁。
> > - **不兼容旧版**：v2.0 与 legacy 版本的锚点定义、配置结构及订阅接口均不兼容，请勿混用。

---

## 📦 配置文件概览 (v2.0)

| 配置文件 | 版本 | 分流策略 | 中文版路径 | 英文版路径 |
| :--- | :---: | :--- | :---: | :---: |
| **Pro** | v2.0.0 | 完整策略集，支持测速与负载均衡。 | [Pro_cn.yaml](./cn/Pro_cn.yaml) | [Pro_en.yaml](./en/Pro_en.yaml) |
| **Lite** | v2.0.0 | 常用策略集，采用自动测速。 | [Lite_cn.yaml](./cn/Lite_cn.yaml) | [Lite_en.yaml](./en/Lite_en.yaml) |
| **Mini** | v2.0.0 | 基础分流，仅保留手动节点选择。 | [Mini_cn.yaml](./cn/Mini_cn.yaml) | [Mini_en.yaml](./en/Mini_en.yaml) |

---

## ✨ 核心特性

### 1. 策略与规则对称
本配置遵循 **「策略即路径」** 的设计理念。

- 策略组排序与规则匹配顺序严格 1:1 对应。
- 客户端看到的策略列表，即为流量实际匹配路径。
- 无需阅读规则文件，即可直观理解流量走向。

### 2. 多格式规则集
规则文件由规则库 [Rules](https://github.com/666OS/rules/tree/release) 于**每日北京时间 2:00 自动更新**。为了兼顾匹配性能与客户端兼容性，规则集提供以下多格式版本：

| 软件 | 目录 (支持格式) | 规则行为 (Behavior) | 运行效率 |
| :--- | :--- | :--- | :---: |
| **Mihomo** | `mihomo/domain/` (`.mrs` / `.text`) <br> `mihomo/ip/` (`.mrs` / `.text`) | 域名与 IP 集合 (`domain` / `ipcidr`) | **二进制加速** |
| | `mihomo/` (`.text`) | 经典规则 (`classical`) | 文本检索 |
| **Sing-box** | `singbox/domain/` (`.srs`) <br> `singbox/ip/` (`.srs`) | 域名与 IP 集合 (`domain` / `ipcidr`) | **二进制加速** |
| | `singbox/` (`.srs` / `.json`) | 二进制与源码 (`binary` / `source`) | 高效 / 标准 |
| **Surge** | `surge/` (`.text`) | 任意规则类型 (`RULE-SET`) | **原生索引** |

### 3. 自动故障转移 (Fallback)
- **基础流量策略默认启用故障转移**，节点异常时自动切换备用节点或地区；
- AI、流媒体等独立策略组仍采用固定地区策略，避免频繁切换影响使用体验。

---

## 📊 策略特性对比

| 特征维度 | Pro (全能版) | Lite (轻量版) | Mini (极简版) |
| :--- | :---: | :---: | :---: |
| **选择方式** | 测速 + 负载均衡 | 自动测速 | 手动选择 |
| **故障转移** | ✅ | ✅ | ❌ |
| **广告拦截** | ✅ | ❌ | ❌ |
| **QUIC 阻断** | ✅ | ✅ | ✅ |
| **策略组数量** | 17 | 9 | 3 |

### 🎛️ 策略组

| 策略组（对应 rules 规则集） | Pro (全能版) | Lite (轻量版) | Mini (极简版) |
| :--- | :---: | :---: | :---: |
| **GUARD / 广告拦截** | ✅ | ❌ | ❌ |
| **SPEEDTEST / 网络测试** | ✅ | ❌ | ❌ |
| **TM / 即时通讯** | ✅ | ✅ | ❌ |
| **SOCIAL / 社交平台** | ✅ | ✅ | ❌ |
| **AI / 人工智能** | ✅ | ✅ | ❌ |
| **DEV / 开发服务** | ✅ | ✅ | ❌ |
| **EMBY / EMBY 专线** | ✅ | ❌ | ❌ |
| **STREAMING / 国际媒体** | ✅ | ✅ | ❌ |
| **GAMES / 游戏平台** | ✅ | ❌ | ❌ |
| **CRYPTO / 货币平台** | ✅ | ❌ | ❌ |
| **GOOGLE / 谷歌服务** | ✅ | ❌ | ❌ |
| **MICROSOFT / 微软服务** | ✅ | ❌ | ❌ |
| **FACEBOOK / 脸书服务** | ✅ | ❌ | ❌ |
| **APPLE / 苹果服务** | ✅ | ✅ | ❌ |
| **OUTCN / 国外流量** | ✅ | ✅ | ✅ |
| **CN / 国内流量** | ✅ | ✅ | ✅ |
| **MATCH / 漏网之鱼** | ✅ | ✅ | ✅ |

---

## 🚀 快速上手与配置

本配置支持两种使用方式：

### 方式一：本地配置

下载对应的 YAML 配置文件到本地，在 `proxy-providers` 下填入您真实的主/备机场订阅链接，或在 `proxies` 下添加自定义节点：
```yaml
proxy-providers:
  Primary: {<<: *base-provider, url: '填入主订阅链接', override: {additional-prefix: '[P] '}}
  Backup:   {<<: *base-provider, url: '填入备订阅链接', override: {additional-prefix: '[B] '}}
```

### 方式二：远程覆写

在代理客户端（如 Clash Verge Rev、Mihomo Party、OpenClash 等）导入本仓库配置作为模板，再通过 Merge / Mixin 动态注入真实订阅链接。模板可随仓库自动同步更新。

---

## 📜 版本归档

旧版本位于 [legacy/](./legacy/) 目录：
- 📂 [MihomoPro.yaml](./legacy/MihomoPro.yaml) (经典全面版)
- 📂 [OneSmartPro.yaml](./legacy/OneSmartPro.yaml) (智能多维版)
- 📂 [OneSmart.yaml](./legacy/OneSmart.yaml) (智能极简版)
- 📂 [OneTouch.yaml](./legacy/OneTouch.yaml) (经典极简版)

*订阅修改示例*：
`https://raw.githubusercontent.com/666OS/YYDS/main/mihomo/config/legacy/MihomoPro.yaml`

> [!CAUTION]
>
> **禁止任何形式转载或发布至中国大陆地区**
