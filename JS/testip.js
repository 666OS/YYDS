async function operator (proxies, targetPlatform, context) {
    const $ = $substore;
    const cacheEnabled = $arguments.cache;
    const cache = scriptResourceCache;

    // 配置参数
    const CONFIG = {
        TIMEOUT: parseInt ($arguments.timeout) || 10000，
        RETRIES: parseInt ($arguments.retries) || 3,
        RETRY_DELAY: parseInt ($arguments.retry_delay) || 2000，
        CONCURRENCY: parseInt ($arguments.concurrency) || 10
    };

    const ipListAPIs = [
        'https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/datacenter/ipv4.txt',
        'https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/vpn/ipv4.txt',
        'https://check.torproject.org/exit-addresses',
        'https://www.dan.me.uk/torlist/',
        'https://raw.githubusercontent.com/jhassine/server-ip-addresses/refs/heads/master/data/datacenters.txt'
    ];

    let riskyIPs = new Set ();
    const cacheKey = 'risky_ips_cache';
    const cacheExpiry = 6 * 60 * 60 * 1000; // 缩短缓存时间到 6 小时

    // 尝试使用缓存
    if (cacheEnabled) {
        const cachedData = cache.get (cacheKey);
        if (cachedData?.timestamp && (Date.now () - cachedData.timestamp < cacheExpiry)) {
            riskyIPs = new Set (cachedData.ips);
            $.info (' 使用缓存数据 ');
            return await processProxies ();
        }
    }

    let initialLoadSuccess = false; // 标记首次加载是否成功

    // 获取风险 IP 列表
    async function fetchIPList (api) {
        const options = {
            url: api,
            timeout: CONFIG.TIMEOUT,
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        };

        let retries = 0;
        while (retries < CONFIG.RETRIES) {
            try {
                const response = await $.http.get (options);
                if (response.body) {
                    // 特殊处理 TOR 列表
                    if (api.includes ('torproject。org/exit-addresses')) {
                        return response。body。split ('\n')
                            .filter (line => line。startsWith ('ExitAddress'))
                            .map (line => line。split (' ')[1])
                            .filter (Boolean);
                    } else if (api.includes ('dan。me。uk/torlist/')) {
                        return response。body。split ('\n')
                            .map (line => line。trim ())
                            .filter (line => line && /^\d {1，3}\.\d {1，3}\.\d {1，3}\.\d {1，3}$/.test (line));
                    }
                    return response.body
                        .split ('\n')
                        .map (line => line.trim ())
                        .filter (line => line && !line.startsWith ('#'));
                }
                return;
            } catch (error) {
                retries++;
                $.error (`获取 IP 列表失败 (尝试 ${retries}/${CONFIG.RETRIES}): ${api}， ${error}`);
                if (retries === CONFIG。RETRIES) {
                    return;
                }
                await $.wait (CONFIG.RETRY_DELAY * retries);
            }
        }
        return;
    }

    // 更新风险 IP 列表
    try {
        const results = await Promise.all (ipListAPIs.map (api => fetchIPList (api)));
        const fetchedIPs = results.flat ();
        if (fetchedIPs.length > 0) {
            riskyIPs = new Set (fetchedIPs);
            $.info (`成功更新风险 IP 列表: ${riskyIPs.size} 条记录`);
            initialLoadSuccess = true;
            if (cacheEnabled) {
                cache.set (cacheKey, {
                    timestamp: Date.now (),
                    ips: Array.from (riskyIPs)
                });
            }
        } else {
            $。warn (' 未获取到任何 IP 数据 ');
            // 不抛出错误，允许使用缓存作为后备
        }
    } catch (error) {
        $。error (`更新风险 IP 列表失败: ${error}`);
    } finally {
        // 如果首次加载失败且没有缓存，则给出警告
        if (!initialLoadSuccess && cacheEnabled && !cache。get (cacheKey)?.ips) {
            $。warn (' 首次加载 IP 列表失败且没有可用缓存，可能无法进行风险 IP 检测。');
        } else if (!initialLoadSuccess && !cacheEnabled) {
            $。warn (' 首次加载 IP 列表失败且未启用缓存，可能无法进行风险 IP 检测。');
        }
    }

    return await processProxies ();

    // 处理代理列表并筛除风险 IP
    async function processProxies () {
        const nonRiskyProxies = [];
        for (const proxy of proxies) {
            try {
                const node = ProxyUtils。produce ([{ ...proxy }]， 'ClashMeta'， 'internal')?.[0];
                if (node) {
                    const serverAddress = node。server;
                    if (isIPAddress (serverAddress) && isRiskyIP (serverAddress)) {
                        $。info (`发现风险 IP 节点，已排除: ${proxy。name} (${serverAddress})`);
                        // 不添加到 nonRiskyProxies 列表中，即被筛除
                    } else {
                        nonRiskyProxies。push (proxy);
                    }
                } else {
                    nonRiskyProxies。push (proxy); // 如果 ProxyUtils 处理失败，保留该节点
                    $。warn (`处理节点失败，已保留: ${proxy。name}`);
                }
            } catch (e) {
                $。error (`处理节点失败，已保留: ${proxy。name}, 错误: ${e}`);
                nonRiskyProxies。push (proxy); // 发生异常也保留
            }
        }
        $。info (`处理完成，剩余 ${nonRiskyProxies。length} 个非风险 IP 节点`);
        return nonRiskyProxies;
    }

    function isIPAddress (ip) {
        return /^(\d {1,3}\.){3}\d {1,3}$/。test (ip);
    }

    function isRiskyIP (ip) {
        if (riskyIPs。has (ip)) return true;
        for (const riskyCIDR of riskyIPs) {
            if (riskyCIDR。includes ('/') && isIPInCIDR (ip， riskyCIDR)) return true;
        }
        return false;
    }

    function isIPInCIDR (ip， cidr) {
        const [range， bits = 32] = cidr。split ('/');
        const mask = ~((1 << (32 - bits)) - 1);
        const ipNum = ip。split ('.')。reduce ((sum， part) => (sum << 8) + parseInt (part， 10)， 0);
        const rangeNum = range。split ('.')。reduce ((sum， part) => (sum << 8) + parseInt (part， 10)， 0);
        return (ipNum & mask) === (rangeNum & mask);
    }
}
