#!/bin/sh

# Mihomo Smart内核更新脚本
# 根据系统架构自动下载对应的mihomo Smart内核并重启OpenClash服务

# 错误处理
set -e
trap 'echo "错误: 脚本执行失败，行 $LINENO"; exit 1' ERR

# 全局变量
OPENCLASH_DIR="/etc/openclash"
CORE_DIR="${OPENCLASH_DIR}/core"
TEMP_DIR="/tmp/smartcore_temp"
SOURCE_REPO="vernesong/mihomo" # 默认使用vernesong镜像版本
VERSION_TAG="Prerelease-Alpha"
OS="linux"
CHANGELOG_FILE="${TEMP_DIR}/changelog.txt"
SCRIPT_VERSION="1.1.0" # 脚本版本号

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 日志函数
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 清理临时文件
clean_temp() {
  # 检查目录是否存在再尝试删除
  if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true
  fi
}

# 信号处理
handle_interrupt() {
  echo ""
  echo "用户中断，正在清理..."
  clean_temp
  exit 130
}

# 设置中断信号处理
trap handle_interrupt INT TERM

# 检测系统架构并设置下载URL
detect_arch() {
  ARCH=$(uname -m)
  log "检测到系统架构: $ARCH"
  
  log "使用源代码仓库: $SOURCE_REPO"
  
  # 远程版本信息和兼容性设置
  REMOTE_VERSION=""
  USE_COMPATIBLE=""
  USE_GO_VERSION=""
  
  # 根据架构确定下载文件前缀
  case "$ARCH" in
    "x86_64"|"amd64")
      ARCH_NAME="amd64"
      
      # 检查CPU支持情况
      if ! grep -q "avx" /proc/cpuinfo 2>/dev/null; then
        log "CPU不支持AVX指令集，建议使用兼容版本"
        USE_COMPATIBLE="-compatible"
      fi
      
      # 检查glibc版本
      if [ -x "$(command -v ldd)" ]; then
        GLIBC_VERSION=$(ldd --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+$' || echo "")
        if [ -n "$GLIBC_VERSION" ]; then
          log "系统glibc版本: $GLIBC_VERSION"
          if [ "$(echo "$GLIBC_VERSION < 2.27" | bc 2>/dev/null)" = "1" ]; then
            log "glibc版本低于2.27，建议使用兼容版本"
            USE_COMPATIBLE="-compatible"
          fi
        fi
      fi
      
      # 交互式选择版本变体
      if [ -t 0 ] && [ -z "$AUTO_MODE" ]; then
        echo
        echo "检测到x86_64架构，请选择要下载的版本变体:"
        echo "1. 标准版本 (mihomo-linux-amd64)"
        echo "2. 兼容版本 (mihomo-linux-amd64-compatible)"
        echo "3. Go 1.20版本 (mihomo-linux-amd64-go120)"
        echo "4. Go 1.23版本 (mihomo-linux-amd64-go123)"
        echo "5. 兼容Go 1.20版本 (mihomo-linux-amd64-compatible-go120)"
        echo "6. 兼容Go 1.23版本 (mihomo-linux-amd64-compatible-go123)"
        printf "请输入选项 [1-6] (默认: 1): "
        read -r variant_choice
        
        case "$variant_choice" in
          2) USE_COMPATIBLE="-compatible" ;;
          3) USE_GO_VERSION="-go120" ;;
          4) USE_GO_VERSION="-go123" ;;
          5) USE_COMPATIBLE="-compatible"; USE_GO_VERSION="-go120" ;;
          6) USE_COMPATIBLE="-compatible"; USE_GO_VERSION="-go123" ;;
        esac
      fi
      ;;
    "i386"|"i686"|"x86")
      ARCH_NAME="386"
      
      # 交互式选择版本变体
      if [ -t 0 ] && [ -z "$AUTO_MODE" ]; then
        echo
        echo "检测到x86_32架构，请选择要下载的版本变体:"
        echo "1. 标准版本 (mihomo-linux-386)"
        echo "2. Go 1.20版本 (mihomo-linux-386-go120)"
        echo "3. Go 1.23版本 (mihomo-linux-386-go123)"
        echo "4. Softfloat版本 (mihomo-linux-386-softfloat)"
        printf "请输入选项 [1-4] (默认: 1): "
        read -r variant_choice
        
        case "$variant_choice" in
          2) USE_GO_VERSION="-go120" ;;
          3) USE_GO_VERSION="-go123" ;;
          4) USE_GO_VERSION="-softfloat" ;;
        esac
      fi
      ;;
    "aarch64"|"arm64") ARCH_NAME="arm64" ;;
    "armv7l"|"armv7"|"arm") ARCH_NAME="armv7" ;;
    "mips"|"mipsel") ARCH_NAME="mipsle" ;;
    *)
      log "错误: 不支持的系统架构: $ARCH"
      exit 1
      ;;
  esac
  
  # 构建文件基本名称前缀
  CLASH_BASE_FILENAME="mihomo-${OS}-${ARCH_NAME}${USE_COMPATIBLE:+$USE_COMPATIBLE}${USE_GO_VERSION:+$USE_GO_VERSION}"
  log "文件基础名称: $CLASH_BASE_FILENAME"
  
  # 更新下载基础URL
  BASE_URL="https://github.com/${SOURCE_REPO}/releases/download/${VERSION_TAG}"
  log "下载基础URL: $BASE_URL"
}

# 获取当前内核信息
get_current_info() {
  if [ ! -f "${CORE_DIR}/clash_meta" ]; then
    echo "未安装"
    return
  fi
  
  if [ -x "${CORE_DIR}/clash_meta" ]; then
    VERSION_FULL=$("${CORE_DIR}/clash_meta" -v 2>/dev/null || echo "无法获取版本")
    INSTALL_DATE=$(date -r "${CORE_DIR}/clash_meta" "+%Y-%m-%d %H:%M:%S")
    
    # 提取内核版本和系统信息
    CORE_INFO=$(echo "$VERSION_FULL" | head -n 1 | awk '{print $1, $2, $3}')
    SYS_INFO=$(echo "$VERSION_FULL" | head -n 1 | cut -d' ' -f4-)
    
    # 保存完整版本号以供其他函数使用
    LOCAL_VERSION=$(echo "$CORE_INFO" | grep -o 'alpha-[0-9a-zA-Z]*' || echo "")
    
    echo "$CORE_INFO"
    echo "$SYS_INFO"
    echo "安装于: $INSTALL_DATE"
  else
    echo "已安装但无法执行"
  fi
}

# 检查版本并决定是否需要更新
check_version() {
  log "检查版本信息..."
  
  # 确保临时目录存在
  mkdir -p "$TEMP_DIR"
  
  # 获取本地版本号
  if [ -z "$LOCAL_VERSION" ] && [ -f "${CORE_DIR}/clash_meta" ] && [ -x "${CORE_DIR}/clash_meta" ]; then
    LOCAL_VERSION_FULL=$("${CORE_DIR}/clash_meta" -v 2>/dev/null || echo "")
    LOCAL_VERSION=$(echo "$LOCAL_VERSION_FULL" | head -n 1 | grep -o 'alpha-[0-9a-zA-Z]*' || echo "")
  fi
  
  # 获取远程版本号
  TEMP_VERSION="${TEMP_DIR}/version.txt"
  VERSION_URL="https://github.com/${SOURCE_REPO}/releases/download/${VERSION_TAG}/version.txt"
  
  if curl -s -L --connect-timeout 10 --max-time 15 "$VERSION_URL" > "$TEMP_VERSION"; then
    REMOTE_VERSION=$(cat "$TEMP_VERSION" | tr -d '\r\n')
    
    if [ -n "$REMOTE_VERSION" ]; then
      # 构建下载URL和文件名
      CLASH_FILENAME="${CLASH_BASE_FILENAME}-${REMOTE_VERSION}.gz"
      CLASH_URL="${BASE_URL}/${CLASH_FILENAME}"
      log "下载URL: $CLASH_URL"
      
      # 检查URL是否有效
      if curl -s -L --head --fail "$CLASH_URL" >/dev/null; then
        log "URL验证成功"
      else
        log "警告: URL验证失败，但仍将尝试下载"
      fi
      
      # 显示版本信息
      echo "远程版本: $REMOTE_VERSION"
      echo "本地版本: ${LOCAL_VERSION:-未知}"
      
      # 比较版本
      if [ -z "$LOCAL_VERSION" ] || [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        HAS_UPDATE="true"
        return 0  # 有更新可用
      else
        HAS_UPDATE="false"
        return 1  # 无需更新
      fi
    else
      log "无法提取远程版本号"
      return 2  # 提取失败
    fi
  else
    log "无法访问版本信息，请检查网络连接"
    return 2  # 访问失败
  fi
}

# 下载并更新内核
update_core() {
  # 确保已获取版本信息
  if [ -z "$CLASH_FILENAME" ] || [ -z "$CLASH_URL" ]; then
    check_version
    ret_val=$?
    
    if [ $ret_val -eq 1 ]; then
      log "当前已是最新版本，无需更新"
      return 0
    elif [ $ret_val -eq 2 ]; then
      log "错误: 无法获取版本信息"
      return 1
    fi
  fi
  
  # 确保临时目录存在
  mkdir -p "$TEMP_DIR"
  mkdir -p "$CORE_DIR"
  
  # 下载内核文件
  echo -ne "下载内核中..."
  if wget -q -O "${TEMP_DIR}/${CLASH_FILENAME}" "$CLASH_URL" 2>/dev/null || 
     curl -s -L -o "${TEMP_DIR}/${CLASH_FILENAME}" "$CLASH_URL" 2>/dev/null; then
    echo "完成"
  else
    echo "失败"
    log "错误: 无法下载内核文件，请检查网络连接"
    return 1
  fi
  
  # 解压文件
  echo -ne "解压内核文件..."
  if gzip -d -c "${TEMP_DIR}/${CLASH_FILENAME}" > "${TEMP_DIR}/clash"; then
    echo "完成"
  else
    echo "失败"
    log "错误: 解压文件失败"
    return 1
  fi
  
  # 备份旧内核文件
  if [ -f "${CORE_DIR}/clash_meta" ]; then
    echo -ne "备份现有内核文件..."
    cp "${CORE_DIR}/clash_meta" "${CORE_DIR}/clash_meta.bak"
    echo "完成"
  fi
  
  # 移动新内核文件
  echo -ne "安装新内核..."
  if cp "${TEMP_DIR}/clash" "${CORE_DIR}/clash_meta"; then
    chmod 755 "${CORE_DIR}/clash_meta"
    echo "完成"
  else
    echo "失败"
    log "错误: 无法复制新内核文件"
    return 1
  fi
  
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
  
  # 备份当前版本
  if [ -f "${CORE_DIR}/clash_meta" ]; then
    cp "${CORE_DIR}/clash_meta" "${CORE_DIR}/clash_meta.current"
    log "当前版本已备份为 clash_meta.current"
  fi
  
  # 恢复备份
  cp "${CORE_DIR}/clash_meta.bak" "${CORE_DIR}/clash_meta" && chmod 755 "${CORE_DIR}/clash_meta" || {
    log "错误: 无法恢复备份文件"
    return 1
  }
  
  # 重启OpenClash服务
  log "重启OpenClash服务..."
  /etc/init.d/openclash restart || {
    log "错误: 重启OpenClash服务失败"
    return 1
  }
  
  log "成功回滚到备份版本！"
  return 0
}

# 获取最新的更新日志
get_latest_changelog() {
  log "获取最新更新日志..."
  
  # 确保临时目录存在
  mkdir -p "$TEMP_DIR"
  
  # 获取发布标签页内容
  if curl -s -L --connect-timeout 10 --max-time 20 "https://github.com/vernesong/OpenClash/releases/tag/mihomo" > "${TEMP_DIR}/release_page.html"; then
    # 尝试简单提取第一个Date行开始的内容
    echo "Changelog" > "$CHANGELOG_FILE"

    # 使用lynx或w3m提取纯文本（如果安装了的话）
    if command -v lynx >/dev/null 2>&1; then
      lynx -dump -nolist "${TEMP_DIR}/release_page.html" > "${TEMP_DIR}/page_text.txt"
    elif command -v w3m >/dev/null 2>&1; then
      w3m -dump "${TEMP_DIR}/release_page.html" > "${TEMP_DIR}/page_text.txt"
    else
      # 回退到简单的HTML清理
      cat "${TEMP_DIR}/release_page.html" | 
        sed 's/<[^>]*>//g' | 
        sed 's/&nbsp;/ /g' | 
        sed 's/&lt;/</g' | 
        sed 's/&gt;/>/g' | 
        sed 's/&#39;/'"'"'/g' > "${TEMP_DIR}/page_text.txt"
    fi

    # 提取第一个Date行到下一个Date行之前的内容（即只提取最新的一条更新日志）
    # 1. 获取所有Date行的行号
    DATE_LINES=$(grep -n "Date: " "${TEMP_DIR}/page_text.txt" | cut -d: -f1)
    
    # 2. 获取第一个和第二个Date行的行号
    FIRST_DATE_LINE=$(echo "$DATE_LINES" | head -n 1)
    SECOND_DATE_LINE=$(echo "$DATE_LINES" | head -n 2 | tail -n 1)
    
    # 如果找到了第一个Date行
    if [ -n "$FIRST_DATE_LINE" ]; then
      # 如果找到了第二个Date行，则提取第一个到第二个之间的内容
      if [ -n "$SECOND_DATE_LINE" ]; then
        sed -n "${FIRST_DATE_LINE},$(($SECOND_DATE_LINE - 1))p" "${TEMP_DIR}/page_text.txt" >> "$CHANGELOG_FILE"
      else
        # 如果没有找到第二个Date行，则提取第一个Date行到文件末尾
        sed -n "${FIRST_DATE_LINE},\$p" "${TEMP_DIR}/page_text.txt" >> "$CHANGELOG_FILE"
      fi
      
      # 检查是否成功提取了日志
      if grep -q "Date: " "$CHANGELOG_FILE"; then
        return 0
      fi
    fi
    
    log "无法提取Changelog内容"
    return 1
  else
    log "无法获取发布页面，请检查网络连接"
    return 1
  fi
}

# 显示最新的更新日志
show_changelog() {
  clear
  echo "==========================================="
  echo "      Mihomo Smart 最新更新日志     "
  echo "==========================================="
  echo
  
  # 重定向日志到/dev/null，不显示在屏幕上
  if [ ! -f "$CHANGELOG_FILE" ] || [ ! -s "$CHANGELOG_FILE" ]; then
    { get_latest_changelog; } > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo -e "${RED}无法获取更新日志，提取失效${NC}"
      echo -e "请前往 https://github.com/vernesong/OpenClash/releases/tag/mihomo 查看"
      echo
      read -p "按回车键返回主菜单..." dummy
      return
    fi
  fi
  
  # 优化显示，跳过Changelog标题行，从Date:开始显示
  sed -n '/Date:/,$p' "$CHANGELOG_FILE" | grep -v "Assets" | grep -v "Loading" | grep -v "Uh oh!" | grep -v "There was an error" > "${TEMP_DIR}/clean_log.txt"
  cat "${TEMP_DIR}/clean_log.txt"
  echo
  echo "==========================================="
  read -p "按回车键返回主菜单..." dummy
}

# 显示菜单
show_menu() {
  clear
  
  echo "==========================================="
  echo "   Mihomo Smart 内核管理脚本 v${SCRIPT_VERSION}   "
  echo "==========================================="
  echo "当前内核: "
  get_current_info
  echo
  
  # 显示更新提示（如果有）
  if [ "$HAS_UPDATE" = "true" ]; then
    echo -e "${RED}发现新版本: $REMOTE_VERSION !${NC}"
  elif [ -n "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}当前已是最新版本: $LOCAL_VERSION${NC}"
  fi
  echo
  
  # 添加说明区域
  echo -e "说明: "
  echo -e "- 本工具用于管理OpenClash的Mihomo Smart内核"
  echo -e "- 更新前会自动备份当前内核"
  echo -e "- 如更新后出现问题，可使用回滚功能还原"
  echo -e "- 可添加计划任务自动更新：0 3 * * * ./smartcore.sh --auto"
  echo -e "- 也可以使用: ./smartcore.sh -c 仅查看更新日志"
  echo
  
  echo "请选择操作:"
  echo "1. 检查并更新内核"
  echo "2. 仅检查更新"
  echo "3. 回滚到上一版本"
  echo "4. 查看最新更新日志"
  echo "0. 退出"
  echo "==========================================="
  
  printf "请输入选项 [0-4]: "
  read -r choice
  
  case $choice in
    1)
      detect_arch
      check_version
      if [ "$HAS_UPDATE" = "true" ]; then
        echo -e "${GREEN}发现新版本！准备更新内核...${NC}"
        update_core
      else
        echo -e "${GREEN}当前已是最新版本，无需更新${NC}"
      fi
      echo
      read -p "按回车键继续..." dummy
      ;;
    2)
      detect_arch
      if check_version; then
        echo -e "${GREEN}发现新版本！${NC}"
        echo -n "是否立即更新？[y/N]: "
        read -r update_now
        if [ "$update_now" = "y" ] || [ "$update_now" = "Y" ]; then
          update_core
        fi
      else
        echo -e "${GREEN}当前已是最新版本，无需更新${NC}"
      fi
      echo
      read -p "按回车键继续..." dummy
      ;;
    3)
      rollback
      echo
      read -p "按回车键继续..." dummy
      ;;
    4)
      show_changelog
      ;;
    0)
      echo "感谢使用！"
      # 提前清理临时文件，避免EXIT陷阱重复调用时出错
      clean_temp
      # 使用trap '' EXIT来移除之前的EXIT陷阱
      trap '' EXIT
      exit 0
      ;;
    *)
      echo "无效的选择，请重试"
      sleep 2
      ;;
  esac
}

# 自动更新模式
auto_update() {
  log "开始自动更新检查..."
  detect_arch
  
  if check_version; then
    log "检测到新版本，开始更新..."
    # 获取并显示更新日志
    if get_latest_changelog; then
      echo "==========================================="
      echo "      新版本更新日志     "
      echo "==========================================="
      cat "$CHANGELOG_FILE"
      echo "==========================================="
    else
      echo "==========================================="
      echo "      无法获取更新日志，提取失效     "
      echo "==========================================="
    fi
    update_core
    clean_temp
    return 0
  else
    log "当前已是最新版本，无需更新"
    clean_temp
    return 1
  fi
}

# 主函数
main() {
  # 创建临时目录
  mkdir -p "$TEMP_DIR"
  
  # 注册退出清理
  trap clean_temp EXIT
  
  # 检查命令行参数
  if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
    AUTO_MODE="1"
    auto_update
    exit $?
  elif [ "$1" = "--debug" ] || [ "$1" = "-d" ]; then
    DEBUG_MODE="1"
    log "开启调试模式"
  elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Mihomo Smart 内核管理脚本 v${SCRIPT_VERSION}"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -a, --auto    自动检查并更新内核"
    echo "  -d, --debug   显示调试信息"
    echo "  -h, --help    显示此帮助信息"
    echo "  -c, --changelog  仅显示最新更新日志"
    echo "  无参数        显示交互式菜单"
    exit 0
  elif [ "$1" = "--changelog" ] || [ "$1" = "-c" ]; then
    get_latest_changelog && cat "$CHANGELOG_FILE" || echo -e "${RED}无法获取更新日志，提取失效${NC}"
    exit $?
  fi
  
  # 如果没有提供参数，进入交互式模式
  if [ -z "$1" ]; then
    # 设置为交互式模式
    INTERACTIVE_MODE="1"
    log "进入交互式模式，直接显示主菜单"
    
    # 循环显示交互式菜单，无需先检测版本
    while true; do
      show_menu
    done
  else
    # 非交互式模式下直接更新
    AUTO_MODE="1"
    auto_update
  fi
}

# 运行主程序
main "$@" 