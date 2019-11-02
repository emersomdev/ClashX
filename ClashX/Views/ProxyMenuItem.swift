//
//  ProxyMenuItem.swift
//  ClashX
//
//  Created by CYC on 2019/2/18.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyMenuItem: NSMenuItem {
    let proxyName: String
    var maxProxyNameLength: CGFloat

    var isSelected: Bool = false {
        didSet {
            state = isSelected ? .on : .off
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    init(proxy: ClashProxy, action selector: Selector?, maxProxyNameLength: CGFloat) {
        self.maxProxyNameLength = maxProxyNameLength
        proxyName = proxy.name
        super.init(title: proxy.name, action: selector, keyEquivalent: "")

        if let his = proxy.history.last {
            attributedTitle = getAttributedTitle(name: proxyName, delay: his.delayDisplay)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateDelayNotification(note:)), name: kSpeedTestFinishForProxy, object: nil)
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func getAttributedTitle(name: String, delay: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: maxProxyNameLength + 90, options: [:]),
        ]

        let str = "\(name.replacingOccurrences(of: "\t", with: " "))\t\(delay)"

        let attributed = NSMutableAttributedString(
            string: str,
            attributes: [NSAttributedString.Key.paragraphStyle: paragraph]
        )

        let delayAttr = [NSAttributedString.Key.font: NSFont.menuFont(ofSize: 12)]
        attributed.addAttributes(delayAttr, range: NSRange(name.utf16.count + 1..<str.utf16.count))
        return attributed
    }

    @objc private func updateDelayNotification(note: Notification) {
        guard let name = note.userInfo?["proxyName"] as? String, name == proxyName else {
            return
        }
        if let delay = note.userInfo?["delay"] as? String {
            attributedTitle = getAttributedTitle(name: proxyName, delay: delay)
        }
    }
}
