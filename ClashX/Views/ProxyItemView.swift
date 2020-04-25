//
//  ProxyItemView.swift
//  ClashX
//
//  Created by yicheng on 2019/11/2.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyItemView: MenuItemBaseView {
    let nameLabel: NSTextField
    let delayLabel: NSTextField
    let imageView: NSImageView?

    static let fixedPlaceHolderWidth: CGFloat = 20 + 50 + 25

    init(proxy: ClashProxy, selected: Bool) {
        nameLabel = VibrancyTextField(labelWithString: proxy.name)
        delayLabel = VibrancyTextField(labelWithString: "")
        let cell = PaddedNSTextFieldCell()
        cell.widthPadding = 2
        cell.heightPadding = 1
        delayLabel.cell = cell
        if selected {
            imageView = NSImageView(image: NSImage(named: NSImage.menuOnStateTemplateName)!)
        } else {
            imageView = nil
        }
        super.init(autolayout: false)
        effectView.addSubview(nameLabel)
        effectView.addSubview(delayLabel)
        if let imageView = imageView {
            effectView.addSubview(imageView)
        }

        imageView?.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        delayLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = type(of: self).labelFont
        delayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        nameLabel.alignment = .left
        delayLabel.alignment = .right

        delayLabel.wantsLayer = true
        delayLabel.layer?.cornerRadius = 2
        delayLabel.textColor = NSColor.white

        update(str: proxy.history.last?.delayDisplay, value: proxy.history.last?.delay)
    }

    override func layout() {
        super.layout()
        nameLabel.sizeToFit()
        delayLabel.sizeToFit()
        imageView?.frame = CGRect(x: 5, y: bounds.height / 2 - 6, width: 12, height: 12)
        nameLabel.frame = CGRect(x: 18,
                                 y: (bounds.height - nameLabel.bounds.height) / 2,
                                 width: nameLabel.bounds.width,
                                 height: nameLabel.bounds.height)
        delayLabel.frame = CGRect(x: bounds.width - delayLabel.bounds.width - 8,
                                  y: (bounds.height - delayLabel.bounds.height) / 2,
                                  width: delayLabel.bounds.width,
                                  height: delayLabel.bounds.height)
    }

    func update(str: String?, value: Int?) {
        delayLabel.stringValue = str ?? ""
        needsLayout = true

        guard let delay = value, str != nil else {
            delayLabel.layer?.backgroundColor = NSColor.clear.cgColor
            return
        }
        switch delay {
        case 0:
            delayLabel.layer?.backgroundColor = CGColor.fail
        case 0..<300:
            delayLabel.layer?.backgroundColor = CGColor.good
        default:
            delayLabel.layer?.backgroundColor = CGColor.meduim
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didClickView() {
        (enclosingMenuItem as? ProxyMenuItem)?.didClick()
    }

    override var cells: [NSCell?] {
        return [nameLabel.cell, imageView?.cell]
    }
}

fileprivate extension CGColor {
    static let good = CGColor(red: 30.0/255, green: 181.0 / 255, blue: 30.0/255, alpha: 1)
    static let meduim = CGColor(red: 1, green: 135.0 / 255, blue: 0, alpha: 1)
    static let fail = CGColor(red: 218.0 / 255, green: 0.0, blue: 3.0 / 255, alpha: 1)
}
