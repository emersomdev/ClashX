//
//  ClashProxy.swift
//  ClashX
//
//  Created by CYC on 2019/3/17.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

enum ClashProxyType: String, Codable {
    case urltest = "URLTest"
    case fallback = "Fallback"
    case loadBalance = "LoadBalance"
    case select = "Selector"
    case direct = "Direct"
    case reject = "Reject"
    case shadowsocks = "Shadowsocks"
    case socks5 = "Socks5"
    case http = "Http"
    case vmess = "Vmess"
    case snell = "Snell"
    case unknown = "Unknown"

    static let proxyGroups: [ClashProxyType] = [.select, .urltest, .fallback, .loadBalance]

    static func isProxyGroup(_ proxy: ClashProxy) -> Bool {
        switch proxy.type {
        case .select, .urltest, .fallback, .loadBalance: return true
        default: return false
        }
    }

    static func isBuiltInProxy(_ proxy: ClashProxy) -> Bool {
        switch proxy.name {
        case "DIRECT", "REJECT": return true
        default: return false
        }
    }
}

typealias ClashProxyName = String

class ClashProxySpeedHistory: Codable {
    let time: Date
    let delay: Int

    class hisDateFormaterInstance {
        static let shared = hisDateFormaterInstance()
        lazy var formater: DateFormatter = {
            var f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()
    }

    lazy var delayDisplay: String = {
        switch delay {
        case 0: return "fail"
        default: return "\(delay) ms"
        }
    }()

    lazy var dateDisplay: String = {
        return hisDateFormaterInstance.shared.formater.string(from: time)
    }()
}

class ClashProxy: Codable {
    let name: ClashProxyName
    let type: ClashProxyType
    let all: [ClashProxyName]?
    let history: [ClashProxySpeedHistory]
    let now: ClashProxyName?
    var providerProxy = false
    weak var enclosingResp: ClashProxyResp? = nil

    lazy var speedtestAble: [ClashProxyName] = {
        guard let resp = enclosingResp, let allProxys = all else { return all ?? [] }
        var proxys = [ClashProxyName]()
        for proxy in allProxys {
            if let p = resp.proxiesMap[proxy], !ClashProxyType.isProxyGroup(p) {
                if !p.providerProxy {
                    proxys.append(proxy)
                }
            }
        }
        return proxys
    }()

    private enum CodingKeys: String, CodingKey {
        case type, all, history, now, name
    }

    lazy var maxProxyName: String = {
        return all?.max { $1.count > $0.count } ?? ""
    }()

    lazy var maxProxyNameLength: CGFloat = {
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
        let attr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 14)]
        return (self.maxProxyName as NSString)
            .boundingRect(with: rect,
                          options: .usesLineFragmentOrigin,
                          attributes: attr).width
    }()
}

class ClashProxyResp {
    let proxies: [ClashProxy]
    var proxiesMap: [ClashProxyName: ClashProxy]

    init(_ data: Any?) {
        guard
            let data = data as? [String: [String: Any]],
            let proxies = data["proxies"]
        else {
            self.proxiesMap = [:]
            self.proxies = []
            return
        }

        var proxiesModel = [ClashProxy]()

        var proxiesMap = [ClashProxyName: ClashProxy]()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.js)
        for value in proxies.values {
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted) else {
                continue
            }
            guard let proxy = try? decoder.decode(ClashProxy.self, from: data) else {
                continue
            }
            proxiesModel.append(proxy)
            proxiesMap[proxy.name] = proxy
        }
        self.proxiesMap = proxiesMap
        self.proxies = proxiesModel

        for proxy in self.proxies {
            proxy.enclosingResp = self
        }
    }

    func updateProvider(_ providerResp: ClashProviderResp) {
        for provider in providerResp.providers.values {
            for proxy in provider.proxies {
                proxy.providerProxy = true
                proxiesMap[proxy.name] = proxy
            }
        }
    }

    lazy var proxiesSortMap: [ClashProxyName: Int] = {
        var map = [ClashProxyName: Int]()
        for (idx, proxy) in (self.proxiesMap["GLOBAL"]?.all ?? []).enumerated() {
            map[proxy] = idx
        }
        return map
    }()

    lazy var proxyGroups: [ClashProxy] = {
        return proxies.filter {
            ClashProxyType.isProxyGroup($0)
        }.sorted(by: { proxiesSortMap[$0.name] ?? -1 < proxiesSortMap[$1.name] ?? -1 })
    }()

    lazy var longestProxyGroupName = {
        return proxyGroups.max { $1.name.count > $0.name.count }?.name ?? ""
    }()

    lazy var maxProxyNameLength: CGFloat = {
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
        let attr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 0)]
        return (self.longestProxyGroupName as NSString)
            .boundingRect(with: rect,
                          options: .usesLineFragmentOrigin,
                          attributes: attr).width
    }()
}
