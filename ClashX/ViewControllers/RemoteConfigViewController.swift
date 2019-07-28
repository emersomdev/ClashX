//
//  RemoteConfigViewController.swift
//  ClashX
//
//  Created by 称一称 on 2019/7/28.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class RemoteConfigViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var deleteButton: NSButton!
    @IBOutlet var updateButton: NSButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateButtonStatus()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        RemoteConfigManager.shared.saveConfigs()
    }
    
    
    // MARK: Actions

    @IBAction func actionAdd(_ sender: Any) {
        showAdd()
    }
    
    @IBAction func actionDelete(_ sender: Any) {
        RemoteConfigManager.shared.configs.remove(at: tableView.selectedRow)
        tableView.reloadData()
    }
    
    @IBAction func actionUpdate(_ sender: Any) {
        let model = RemoteConfigManager.shared.configs[tableView.selectedRow]
        requestUpdate(config: model)
    }
}

extension RemoteConfigViewController {
    
    func updateButtonStatus() {
        let selectIdx = tableView.selectedRow
        if selectIdx == -1 {
            deleteButton.isEnabled = false
            updateButton.isEnabled = false
            return
        }
        
        deleteButton.isEnabled = true
        updateButton.isEnabled = !RemoteConfigManager.shared.configs[selectIdx].updating
    }
    
    func showAdd() {
        let alertView = NSAlert()
        alertView.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alertView.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alertView.messageText = NSLocalizedString("Add a remote config", comment: "")
        let remoteConfigInputView = RemoteConfigAddView.createFromNib()!
        alertView.accessoryView = remoteConfigInputView
        let response = alertView.runModal()
        
        guard response == .alertFirstButtonReturn else {return}
        guard remoteConfigInputView.isVaild() else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Remote Config Vaild Fail", comment: "")
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let configName = remoteConfigInputView.getConfigName()
        let isDup = RemoteConfigManager.shared.configs.contains { $0.name == configName }
        
        guard !isDup else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("the remote config name is duplicated", comment: "")
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let remoteConfig = RemoteConfigModel(url: remoteConfigInputView.getUrlString(),
                                             name: remoteConfigInputView.getConfigName(),
                                             updateTime: nil)
        RemoteConfigManager.shared.configs.append(remoteConfig)
        tableView.reloadData()
    }
    
    func requestUpdate(config: RemoteConfigModel) {
        guard !config.updating else {return}
        config.updating = true
        RemoteConfigManager.updateConfig(config: config) { [weak self] errorString in
            config.updating = false
            if let errorString = errorString {
                let alert = NSAlert()
                alert.messageText = errorString
                alert.alertStyle = .warning
                alert.runModal()
            } else {
                config.updateTime = Date()
                self?.tableView.reloadData()
                RemoteConfigManager.shared.saveConfigs()
            }
        }
    }
}

extension RemoteConfigViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStatus()
    }
}

extension RemoteConfigViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return RemoteConfigManager.shared.configs.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let config = RemoteConfigManager.shared.configs[row]

        func setupCell(withIdentifier:String, string:String, textFieldtag:Int = 1) -> NSView? {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: withIdentifier), owner: nil)
            if let textField = cell?.viewWithTag(1) as? NSTextField {
                textField.stringValue = string
            } else {
                assertionFailure()
            }
            
            return cell
        }
        
        switch tableColumn?.identifier.rawValue ?? "" {
        case "url":
            return setupCell(withIdentifier: "urlCell", string: config.url)
        case "configName":
            return setupCell(withIdentifier: "nameCell", string: config.name)
        case "updateTime":
            return setupCell(withIdentifier: "timeCell", string: config.displayingTimeString())

        default: assertionFailure()
        }
        return nil
    }
}



class RemoteConfigAddView: NSView, NibLoadable {
    @IBOutlet private var urlTextField: NSTextField!
    @IBOutlet private var configNameTextField: NSTextField!
    
    func getUrlString() -> String {
        return urlTextField.stringValue
    }
    
    func getConfigName() -> String {
        if configNameTextField.stringValue.count > 0 {
            return configNameTextField.stringValue
        }
        return configNameTextField.placeholderString ?? ""
    }
    
    func isVaild() -> Bool {
        return isUrlVaild() && getConfigName().count > 0
    }
    
    private func isUrlVaild() -> Bool {
        let urlString = urlTextField.stringValue
        guard let url = URL(string: urlString) else {return false}
        
        guard url.host != nil,
            let scheme = url.scheme else {
            return false
        }
        return ["http","https"].contains(scheme)
    }
    

}

extension RemoteConfigAddView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard isUrlVaild() else {return}
        let urlString = urlTextField.stringValue
        configNameTextField.placeholderString = URL(string: urlString)?.host ?? "unknown"
    }
}
