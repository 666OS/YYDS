# --- 以下为 OneSmartPro 配置专用覆写 ---
[General]
DISABLE_UDP_QUIC = 1

#restart: true 代表更新后重启插件，false 代表不重启插件
#force: true 代表强制下载，false 代表不强制下载（当文件不存在时会自动下载）
#cron: 定时下载时间，格式为标准的 cron 表达式，0 代表不启用定时下载
#示例：每天凌晨6点下载一次
#cron=0 6 * * *
#示例：每周一凌晨6点下载一次
#cron=0 6 * * 1
DOWNLOAD_FILE = url=https://git.imee.me/https://github.com/666OS/YYDS/raw/main/mihomo/config/OneSmartPro.yaml, path=/etc/openclash/config/OneSmartPro.yaml, cron=0 6 * * *, force=false

#将模板作为默认配置文件
CONFIG_FILE = /etc/openclash/config/OneSmartPro.yaml

#指定展示订阅信息的 URL 地址
SUB_INFO_URL = $EN_KEY1

[Overwrite]
#EN_KEY 为对应模块需要用户指定的环境变量值, EN_KEY1=URL1;EN_KEY2=URL2;EN_KEY3=URL3
#其他 Ruby 编辑函数请参考 openclash_custom_overwrite.sh
ruby_map_edit "$CONFIG_FILE" "['proxy-providers']" "优质服务商" "['url']" "$EN_KEY1"
ruby_map_edit "$CONFIG_FILE" "['proxy-providers']" "备用服务商" "['url']" "$EN_KEY2"
ruby_map_edit "$CONFIG_FILE" "['proxy-providers']" "落地服务商" "['url']" "$EN_KEY3"
