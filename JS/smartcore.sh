#!/bin/sh

# OpenClash Mihomo Smart内核更新脚本
# 根据系统架构自动下载对应的mihomo Smart内核并重启OpenClash服务

# 错误处理
set -e
trap 'echo "错误: 脚本执行失败，行 $LINENO"; exit 1' ERR

# 日志函数
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# OpenClash目录路径
OPENCLASH_DIR="/etc/openclash"
CORE_DIR="${OPENCLASH_DIR}/core"
DOWNLOAD_DIR="/tmp"

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 检测系统架构并设置下载URL
detect_arch() {
  ARCH=$(uname -m)
  log "检测到系统架构: $ARCH"

  # 根据架构确定下载文件
  case "$ARCH" in
    "x86_64"|"amd64")
      CLASH_URL="https://github.com/vernesong/OpenClash/releases/download/mihomo/clash-linux-amd64.tar.gz"
      CLASH_FILENAME="clash-linux-amd64.tar.gz"
      ;;
    "aarch64"|"arm64")
      CLASH_URL="https://github.com/vernesong/OpenClash/releases/download/mihomo/clash-linux-arm64.tar.gz"
      CLASH_FILENAME="clash-linux-arm64.tar.gz"
      ;;
    "armv7l"|"armv7"|"arm")
      CLASH_URL="https://github.com/vernesong/OpenClash/releases/download/mihomo/clash-linux-armv7.tar.gz"
      CLASH_FILENAME="clash-linux-armv7.tar.gz"
      ;;
    "mips"|"mipsel")
      CLASH_URL="https://github.com/vernesong/OpenClash/releases/download/mihomo/clash-linux-mipsle.tar.gz"
      CLASH_FILENAME="clash-linux-mipsle.tar.gz"
      ;;
    *)
      log "错误: 不支持的系统架构: $ARCH"
      exit 1
      ;;
  esac
}

# 获取当前内核信息
get_current_info() {
  if [ ! -f "${CORE_DIR}/clash_meta" ]; then
    echo "未安装"
    return
  fi
  
  # 检查文件是否可执行
  if [ -x "${CORE_DIR}/clash_meta" ]; then
    VERSION_FULL=$("${CORE_DIR}/clash_meta" -v 2>/dev/null || echo "无法获取版本")
    INSTALL_DATE=$(date -r "${CORE_DIR}/clash_meta" "+%Y-%m-%d %H:%M:%S")
    
    # 提取内核版本和系统信息 (假设格式一致)
    CORE_INFO=$(echo "$VERSION_FULL" | head -n 1 | awk '{print $1, $2, $3}')
    SYS_INFO=$(echo "$VERSION_FULL" | head -n 1 | cut -d' ' -f4-)
    
    echo "$CORE_INFO"
    echo "$SYS_INFO"
    echo "安装于: $INSTALL_DATE"
  else
    echo "已安装但无法执行"
  fi
}

# 检查远程版本信息
check_remote_version() {
  log "检查远程版本信息..."
  
  # 先尝试获取本地版本号
  LOCAL_VERSION=""
  if [ -f "${CORE_DIR}/clash_meta" ] && [ -x "${CORE_DIR}/clash_meta" ]; then
    LOCAL_VERSION_FULL=$("${CORE_DIR}/clash_meta" -v 2>/dev/null || echo "")
    LOCAL_VERSION=$(echo "$LOCAL_VERSION_FULL" | head -n 1 | grep -o 'alpha(smart)-g[0-9a-f]*' || echo "")
    log "本地版本号: $LOCAL_VERSION"
  fi
  
  # 直接从GitHub页面获取最新版本号
  log "获取远程版本信息..."
  TEMP_PAGE="${DOWNLOAD_DIR}/mihomo_page.html"
  
  if curl -s --connect-timeout 10 --max-time 15 "https://github.com/vernesong/OpenClash/releases/tag/mihomo" > "$TEMP_PAGE"; then
    # 根据上次运行的结果，直接使用成功率最高的方法3
    REMOTE_VERSION=$(grep -o 'alpha(smart)-g[0-9a-f]*' "$TEMP_PAGE" | head -1 || echo "")
    
    # 如果简单提取失败，再尝试更复杂的方法
    if [ -z "$REMOTE_VERSION" ]; then
      # 尝试从版本标记中提取
      REMOTE_VERSION=$(grep -o 'Version: alpha(smart)-g[0-9a-f]*' "$TEMP_PAGE" | head -1 | sed 's/Version: //' || echo "")
    fi
    
    # 清理临时文件
    rm -f "$TEMP_PAGE"
    
    # 如果提取到版本号
    if [ -n "$REMOTE_VERSION" ]; then
      log "远程版本号: $REMOTE_VERSION"
      
      # 设置全局变量以供后台检查使用
      REMOTE_VERSION_INFO="$REMOTE_VERSION"
      
      # 显示版本信息
      echo "远程版本: $REMOTE_VERSION"
      echo "本地版本: $LOCAL_VERSION"
      
      # 比较版本
      if [ -z "$LOCAL_VERSION" ] || [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        UPDATE_AVAILABLE="1"
        return 0  # 有更新
      else
        echo "当前已是最新版本"
        UPDATE_AVAILABLE=""
        return 1  # 无更新
      fi
    else
      log "无法提取远程版本号"
      REMOTE_VERSION_INFO=""
      UPDATE_AVAILABLE=""
      return 2  # 提取失败
    fi
  else
    log "无法访问GitHub发布页面，请检查网络连接"
    REMOTE_VERSION_INFO=""
    UPDATE_AVAILABLE=""
    return 2  # 访问失败
  fi
}

# 下载并更新内核
update_core() {
  log "开始更新OpenClash Smart内核..."
  
  # 创建必要的目录
  mkdir -p "$CORE_DIR"
  mkdir -p "$DOWNLOAD_DIR"

  # 下载内核文件
  echo -ne "下载内核中..."
  # 使用安静模式下载，隐藏下载细节
  if wget -q --show-progress --progress=bar:force:noscroll -O "${DOWNLOAD_DIR}/${CLASH_FILENAME}" "$CLASH_URL"; then
    echo "完成"
  else
    echo "失败"
    echo -ne "尝试其他方式下载..."
    if curl -s -L --progress-bar -o "${DOWNLOAD_DIR}/${CLASH_FILENAME}" "$CLASH_URL"; then
      echo "完成"
    else
      log "错误: 无法下载内核文件，请检查网络连接"
      return 1
    fi
  fi

  # 解压文件
  echo -ne "解压内核文件..."
  mkdir -p "${DOWNLOAD_DIR}/clash_temp"
  if tar -xzf "${DOWNLOAD_DIR}/${CLASH_FILENAME}" -C "${DOWNLOAD_DIR}/clash_temp" >/dev/null 2>&1; then
    echo "完成"
  else
    echo "失败"
    log "错误: 解压文件失败"
    rm -rf "${DOWNLOAD_DIR}/clash_temp"
    return 1
  fi

  # 备份旧内核文件(如果存在)
  if [ -f "${CORE_DIR}/clash_meta" ]; then
    echo -ne "备份现有内核文件..."
    cp "${CORE_DIR}/clash_meta" "${CORE_DIR}/clash_meta.bak"
    echo "完成"
  fi

  # 移动新内核文件并重命名为clash_meta
  echo -ne "安装新内核..."
  if cp "${DOWNLOAD_DIR}/clash_temp/clash" "${CORE_DIR}/clash_meta"; then
    chmod 755 "${CORE_DIR}/clash_meta"
    echo "完成"
  else
    echo "失败"
    log "错误: 无法复制新内核文件"
    return 1
  fi

  # 清理临时文件
  echo -ne "清理临时文件..."
  rm -rf "${DOWNLOAD_DIR}/clash_temp"
  rm -f "${DOWNLOAD_DIR}/${CLASH_FILENAME}"
  echo "完成"

  # 重启OpenClash服务
  echo -ne "重启OpenClash服务..."
  if /etc/init.d/openclash restart >/dev/null 2>&1; then
    echo "完成"
  else
    echo "失败"
    log "错误: 重启OpenClash服务失败"
    return 1
  fi

  echo -e "${GREEN}OpenClash Smart内核更新成功完成！${NC}"
  return 0
}

# 回滚到备份版本
rollback() {
  if [ ! -f "${CORE_DIR}/clash_meta.bak" ]; then
    log "错误: 没有找到备份文件"
    return 1
  fi
  
  log "开始回滚到备份版本..."
  
  # 现在的版本再次备份
  if [ -f "${CORE_DIR}/clash_meta" ]; then
    cp "${CORE_DIR}/clash_meta" "${CORE_DIR}/clash_meta.current"
    log "当前版本已备份为 clash_meta.current"
  fi
  
  # 恢复备份
  cp "${CORE_DIR}/clash_meta.bak" "${CORE_DIR}/clash_meta" || {
    log "错误: 无法恢复备份文件"
    return 1
  }
  
  # 设置权限
  chmod 755 "${CORE_DIR}/clash_meta"
  
  # 重启OpenClash服务
  log "重启OpenClash服务..."
  /etc/init.d/openclash restart || {
    log "错误: 重启OpenClash服务失败"
    return 1
  }
  
  log "成功回滚到备份版本！"
  return 0
}

# 显示菜单
show_menu() {
  clear
  
  echo "==========================================="
  echo "   OpenClash Mihomo Smart 内核管理工具    "
  echo "==========================================="
  echo "当前内核: "
  get_current_info
  echo
  
  # 显示更新提示（如果有）
  if [ -n "$UPDATE_AVAILABLE" ] && [ -n "$REMOTE_VERSION_INFO" ]; then
    echo -e "${RED}发现新版本: $REMOTE_VERSION_INFO !${NC}"
    echo
  fi
  
  # 添加说明区域
  echo -e "说明: "
  echo -e "- 本工具用于管理OpenClash的Mihomo Smart内核"
  echo -e "- 更新前会自动备份当前内核"
  echo -e "- 如更新后出现问题，可使用回滚功能还原"
  echo -e "- 建议定期检查更新以获取最新功能"
  echo -e "- 可添加计划任务自动更新：0 3 * * * ./smartcore.sh --auto"
  echo -e "- 上面的意思是在每天凌晨3点检查并更新内核，增加方法：系统/计划任务/添加上面的代码/保存"
  echo
  
  echo "请选择操作:"
  echo "1. 马上更新内核"
  echo "2. 手动检查更新"
  echo "3. 回滚到上一版本"
  echo "0. 退出"
  echo "==========================================="
  printf "请输入选项 [0-3]: "
  read -r choice
  
  case $choice in
    1)
      detect_arch
      update_core
      echo
      read -p "按回车键继续..." dummy
      ;;
    2)
      detect_arch
      if check_remote_version; then
        echo -e "${GREEN}发现新版本！可以选择更新内核。${NC}"
        echo -n "是否立即更新？[y/N]: "
        read -r update_now
        if [ "$update_now" = "y" ] || [ "$update_now" = "Y" ]; then
          update_core
        fi
      else
        echo "当前已是最新版本。"
      fi
      echo
      read -p "按回车键继续..." dummy
      ;;
    3)
      rollback
      echo
      read -p "按回车键继续..." dummy
      ;;
    0)
      echo "感谢使用！"
      clear
      exit 0
      ;;
    *)
      echo "无效的选择，请重试"
      sleep 2
      ;;
  esac
}

# 显示初始检查中的菜单
show_initial_menu() {
  clear
  
  echo "==========================================="
  echo "   OpenClash Mihomo Smart 内核管理工具    "
  echo "==========================================="
  echo "当前内核: "
  get_current_info
  echo
  echo -e "${YELLOW}正在自动检查远程版本中...${NC}"
  echo
  
  # 添加说明区域
  echo -e "说明: "
  echo -e "- 本工具用于管理OpenClash的Mihomo Smart内核"
  echo -e "- 更新前会自动备份当前内核"
  echo -e "- 如更新后出现问题，可使用回滚功能还原"
  echo -e "- 建议定期检查更新以获取最新功能"
  echo -e "- 可添加计划任务自动更新：0 3 * * * ./smartcore.sh --auto"
  echo -e "- 说明:每天凌晨3点检查并更新内核，增加方法：系统/计划任务/添加上面的代码/保存"
  echo
  
  echo "请选择操作:"
  echo "1. 更新内核"
  echo "2. 手动检查更新"
  echo "3. 回滚到上一版本"
  echo "0. 退出"
  echo "==========================================="
  echo "等待检查完成..."
}

# 获取版本日期和变更日志
show_changelog() {
  TEMP_PAGE="${DOWNLOAD_DIR}/mihomo_changelog.html"
  
  if curl -s --connect-timeout 10 --max-time 15 "https://github.com/vernesong/OpenClash/releases/tag/mihomo" > "$TEMP_PAGE"; then
    echo "版本变更信息:"
    echo "-------------"
    grep -A 15 "## Changelog" "$TEMP_PAGE" | head -n 15 | sed 's/<[^>]*>//g' || echo "未找到变更日志"
    echo "-------------"
    
    # 清理临时文件
    rm -f "$TEMP_PAGE"
  else
    echo "无法获取变更日志信息"
  fi
}

# 非交互式自动更新模式
auto_update() {
  log "开始自动更新检查..."
  detect_arch
  
  if check_remote_version; then
    log "检测到新版本，开始更新..."
    update_core
    return 0
  else
    log "当前已是最新版本，无需更新"
    return 1
  fi
}

# 后台检查更新
background_check() {
  log "后台检查更新..."
  detect_arch
  
  # 先尝试获取本地版本号
  LOCAL_VERSION=""
  if [ -f "${CORE_DIR}/clash_meta" ] && [ -x "${CORE_DIR}/clash_meta" ]; then
    LOCAL_VERSION_FULL=$("${CORE_DIR}/clash_meta" -v 2>/dev/null || echo "")
    LOCAL_VERSION=$(echo "$LOCAL_VERSION_FULL" | head -n 1 | grep -o 'alpha(smart)-g[0-9a-f]*' || echo "")
    log "本地版本号: $LOCAL_VERSION"
  fi
  
  # 不使用check_remote_version，直接实现检查逻辑以便更好控制变量
  TEMP_PAGE="${DOWNLOAD_DIR}/mihomo_page.html"
  
  if curl -s --connect-timeout 10 --max-time 15 "https://github.com/vernesong/OpenClash/releases/tag/mihomo" > "$TEMP_PAGE"; then
    # 提取版本号
    REMOTE_VERSION=$(grep -o 'alpha(smart)-g[0-9a-f]*' "$TEMP_PAGE" | head -1 || echo "")
    
    # 如果简单提取失败，再尝试更复杂的方法
    if [ -z "$REMOTE_VERSION" ]; then
      REMOTE_VERSION=$(grep -o 'Version: alpha(smart)-g[0-9a-f]*' "$TEMP_PAGE" | head -1 | sed 's/Version: //' || echo "")
    fi
    
    # 清理临时文件
    rm -f "$TEMP_PAGE"
    
    # 如果提取到版本号
    if [ -n "$REMOTE_VERSION" ]; then
      log "后台检查获取到远程版本号: $REMOTE_VERSION"
      
      # 将状态保存到文件，以便主进程获取
      echo "$REMOTE_VERSION" > "${DOWNLOAD_DIR}/smartcore_remote_version.txt"
      
      # 比较版本
      if [ -z "$LOCAL_VERSION" ] || [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        log "发现新版本: $REMOTE_VERSION (当前: $LOCAL_VERSION)"
        echo "1" > "${DOWNLOAD_DIR}/smartcore_update_available.txt"
        return 0  # 有更新
      else
        log "当前已是最新版本"
        echo "" > "${DOWNLOAD_DIR}/smartcore_update_available.txt"
        return 1  # 无更新
      fi
    else
      log "无法提取远程版本号"
      echo "" > "${DOWNLOAD_DIR}/smartcore_remote_version.txt"
      echo "" > "${DOWNLOAD_DIR}/smartcore_update_available.txt"
      return 2  # 提取失败
    fi
  else
    log "无法访问GitHub发布页面，请检查网络连接"
    echo "" > "${DOWNLOAD_DIR}/smartcore_remote_version.txt"
    echo "" > "${DOWNLOAD_DIR}/smartcore_update_available.txt"
    return 2  # 访问失败
  fi
}

# 主程序
main() {
  # 声明全局变量用于存储检测结果
  UPDATE_AVAILABLE=""
  REMOTE_VERSION_INFO=""
  
  # 检查命令行参数
  if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
    # 自动更新模式
    auto_update
    exit $?
  elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    # 显示帮助信息
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -a, --auto    自动检查并更新内核"
    echo "  -h, --help    显示此帮助信息"
    echo "  无参数        显示交互式菜单"
    exit 0
  fi
  
  # 检查是否在交互式终端
  if [ -t 0 ]; then
    # 清理旧的状态文件
    rm -f "${DOWNLOAD_DIR}/smartcore_remote_version.txt"
    rm -f "${DOWNLOAD_DIR}/smartcore_update_available.txt"
    
    # 先显示检查中的菜单
    show_initial_menu
    
    # 在后台检查更新
    background_check &
    
    # 等待后台检查完成，但最多等待5秒
    WAIT_COUNT=0
    while [ "$WAIT_COUNT" -lt 5 ]; do
      # 读取状态文件
      if [ -f "${DOWNLOAD_DIR}/smartcore_remote_version.txt" ]; then
        REMOTE_VERSION_INFO=$(cat "${DOWNLOAD_DIR}/smartcore_remote_version.txt")
      fi
      if [ -f "${DOWNLOAD_DIR}/smartcore_update_available.txt" ]; then
        UPDATE_AVAILABLE=$(cat "${DOWNLOAD_DIR}/smartcore_update_available.txt")
      fi
      
      # 如果状态文件存在且有内容，说明检查完成
      if [ -n "$REMOTE_VERSION_INFO" ] || [ "$WAIT_COUNT" -ge 4 ]; then
        break
      fi
      
      sleep 1
      WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    # 显示交互式菜单
    while true; do
      # 每次显示菜单前重新检查一下状态文件
      if [ -f "${DOWNLOAD_DIR}/smartcore_remote_version.txt" ]; then
        REMOTE_VERSION_INFO=$(cat "${DOWNLOAD_DIR}/smartcore_remote_version.txt")
      fi
      if [ -f "${DOWNLOAD_DIR}/smartcore_update_available.txt" ]; then
        UPDATE_AVAILABLE=$(cat "${DOWNLOAD_DIR}/smartcore_update_available.txt")
      fi
      
      show_menu
    done
  else
    # 非交互式模式下直接更新
    auto_update
  fi
}

# 运行主程序
main "$@" 