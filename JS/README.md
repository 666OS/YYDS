# OpenClash Mihomo Smart内核更新工具

这个脚本用于自动检查、下载和更新OpenClash的Mihomo Smart内核，适用于OpenWrt系统。

## 功能特点

- **自动检测系统架构**：自动识别系统架构（x86_64/arm64/armv7/mips等），下载对应版本
- **自动检查更新**：启动时自动在后台检查新版本
- **备份与回滚**：自动备份当前内核，支持一键回滚
- **简洁界面**：提供直观的菜单操作

## 使用方法

### 基本使用

1. 下载脚本到OpenWrt设备并运行
   ```
   wget -O smartcore.sh --no-check-certificate https://github.com/666OS/YYDS/raw/main/JS/smartcore.sh && chmod +x smartcore.sh && ./smartcore.sh
   ```
2. 运行脚本：`./smartcore.sh`

### 命令行参数

脚本支持以下命令行参数：

- `--auto` 或 `-a`：自动检查并更新内核（适合计划任务）
- `--help` 或 `-h`：显示帮助信息

### 菜单选项

脚本提供以下操作选项：

1. **马上更新内核**：直接下载并安装最新版本
2. **手动检查更新**：手动检查是否有新版本可用
3. **回滚到上一版本**：恢复到之前备份的版本
0. **退出**：退出脚本

## 自动更新

如果需要定期自动检查和更新内核，可以将脚本添加到计划任务：

```
# 每天凌晨3点检查并更新内核
0 3 * * * ./smartcore.sh --auto >> /tmp/smartcore_update.log 2>&1
```

## 注意事项

- 脚本运行需要root权限
- 请确保设备有足够的存储空间
- 脚本默认将内核文件安装到 `/etc/openclash/core/clash_meta`
- 更新前会自动备份当前内核到 `/etc/openclash/core/clash_meta.bak`

## 已知问题

- 检查更新后会刷新整个界面，可能影响用户体验
- 在某些网络环境下，可能无法访问GitHub，导致更新检查失败

## 故障排除

如果遇到问题，请检查：

1. 网络连接是否正常
2. 是否有足够的存储空间
3. OpenClash是否正确安装
4. 脚本是否有执行权限

## 许可证

此脚本是开源的，欢迎自由使用和修改。 