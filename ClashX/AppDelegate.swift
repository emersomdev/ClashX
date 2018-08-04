//
//  AppDelegate.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/10.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import LetsMove
import Alamofire
import RxCocoa
import RxSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    static let StatusItemIconWidth: CGFloat = NSStatusItem.variableLength * 2

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var proxySettingMenuItem: NSMenuItem!
    @IBOutlet weak var autoStartMenuItem: NSMenuItem!
    
    @IBOutlet weak var proxyModeGlobalMenuItem: NSMenuItem!    
    @IBOutlet weak var proxyModeDirectMenuItem: NSMenuItem!
    @IBOutlet weak var proxyModeRuleMenuItem: NSMenuItem!
    
    @IBOutlet weak var separatorLineTop: NSMenuItem!
    
    var disposeBag = DisposeBag()
    let ssQueue = DispatchQueue(label: "com.w2fzu.ssqueue", attributes: .concurrent)

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        
        _ = ProxyConfigManager.install()
        PFMoveToApplicationsFolderIfNecessary()
        self.startProxy()

        statusItem = NSStatusBar.system.statusItem(withLength: 57)
        let view = StatusItemView.create(statusItem: statusItem,statusMenu: statusMenu)
        statusItem.view = view
        setupData()
        setupProxyList()
        
    }
    

    func applicationWillTerminate(_ aNotification: Notification) {
        if ConfigManager.shared.proxyPortAutoSet {
            _ = ProxyConfigManager.setUpSystemProxy(port: nil,socksPort: nil)
        }
    }

    func setupData() {
        NotificationCenter.default.rx.notification(kShouldUpDateConfig).bind {
            [unowned self] (note)  in
            self.syncConfig(){
                self.resetTrafficMonitor()
            }
            }.disposed(by: disposeBag)
        
        ConfigManager.shared.proxyPortAutoSetObservable
            .distinctUntilChanged()
            .bind{ [unowned self]
                enable in
                self.proxySettingMenuItem.state = (enable ?? false) ? .on : .off
                let image = (enable ?? false) ?
                    NSImage(named: NSImage.Name(rawValue: "menu_icon"))! :
                    NSImage(named: NSImage.Name(rawValue: "menu_icon_disabled"))!
                ((self.statusItem.view) as! StatusItemView).imageView.image = image
            }.disposed(by: disposeBag)
        
        ConfigManager.shared.currentConfigVariable
            .asObservable()
            .filter{$0 != nil}
            .bind {[unowned self] (config) in
                self.proxyModeDirectMenuItem.state = .off
                self.proxyModeGlobalMenuItem.state = .off
                self.proxyModeRuleMenuItem.state = .off
                
                switch config!.mode {
                case .direct:self.proxyModeDirectMenuItem.state = .on
                case .global:self.proxyModeGlobalMenuItem.state = .on
                case .rule:self.proxyModeRuleMenuItem.state = .on
                }
        }.disposed(by: disposeBag)
        
        LaunchAtLogin.shared.isEnableVirable
            .asObservable()
            .subscribe(onNext: { (enable) in
                self.autoStartMenuItem.state = enable ? .on : .off
            }).disposed(by: disposeBag)
    }
    
    func setupProxyList() {
        ProxyMenuItemFactory.menuItems { [unowned self] (menus) in
            let index = self.statusMenu.items.index(of: self.separatorLineTop)! + 1
            var items = self.statusMenu.items
            for each in menus {
                items.insert(each, at: index)
            }
            self.statusMenu.removeAllItems()
            for each in items.reversed() {
                self.statusMenu.insertItem(each, at: 0)
            }
        }
    }
    
    func startProxy() {
        ssQueue.async {
            run()
        }
        syncConfig(){
            self.resetTrafficMonitor()
        }
    }
    
    func syncConfig(completeHandler:(()->())?=nil){
        ApiRequest.requestConfig{ (config) in
            guard config.port > 0 else {return}
            ConfigManager.shared.currentConfig = config
            
            if ConfigManager.shared.proxyPortAutoSet {
                _ = ProxyConfigManager.setUpSystemProxy(port: config.port,socksPort: config.socketPort)
                completeHandler?()
            }
        }
    }
    
    func resetTrafficMonitor() {
        ApiRequest.shared.requestTrafficInfo(){ [weak self] up,down in
            guard let `self` = self else {return}
            ((self.statusItem.view) as! StatusItemView).updateSpeedLabel(up: up, down: down)
        }
    }

    
//Actions:
    
    @IBAction func actionQuit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
        
    @IBAction func actionSetSystemProxy(_ sender: Any) {
        ConfigManager.shared.proxyPortAutoSet = !ConfigManager.shared.proxyPortAutoSet
        if ConfigManager.shared.proxyPortAutoSet {
            let port = ConfigManager.shared.currentConfig?.port ?? 0
            let socketPort = ConfigManager.shared.currentConfig?.socketPort ?? 0
            _ = ProxyConfigManager.setUpSystemProxy(port: port,socksPort:socketPort)
        } else {
            _ = ProxyConfigManager.setUpSystemProxy(port: nil,socksPort: nil)
        }

    }
    
    @IBAction func actionCopyExportCommand(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let port = ConfigManager.shared.currentConfig?.port ?? 0
        pasteboard.setString("export https_proxy=http://127.0.0.1:\(port);export http_proxy=http://127.0.0.1:\(port)", forType: .string)
    }
    
    @IBAction func actionStartAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.shared.isEnabled = !LaunchAtLogin.shared.isEnabled
    }
    
    var genConfigWindow:NSWindowController?=nil
    @IBAction func actionGenConfig(_ sender: Any) {
        let ctrl = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
            .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "sampleConfigGenerator")) as! NSWindowController
        
        genConfigWindow?.close()
        genConfigWindow=ctrl
        ctrl.window?.title = ctrl.contentViewController?.title ?? ""
        ctrl.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)

    }
    
    @IBAction func openConfigFolder(_ sender: Any) {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/config.ini")
        NSWorkspace.shared.openFile(path)
    }
    
    @IBAction func actionUpdateConfig(_ sender: Any) {
        ApiRequest.requestConfigUpdate() { [unowned self] success in
            self.syncConfig(){
                self.resetTrafficMonitor()
            }
        }
    }
    
    @IBAction func actionSwitchProxyMode(_ sender: NSMenuItem) {
        let mode:ClashProxyMode
        switch sender {
        case proxyModeGlobalMenuItem:
            mode = .global
        case proxyModeDirectMenuItem:
            mode = .direct
        case proxyModeRuleMenuItem:
            mode = .rule
        default:
            return
        }
        let config = ConfigManager.shared.currentConfig?.copy()
        config?.mode = mode
        ApiRequest.requestUpdateConfig(newConfig: config) { (success) in
            if (success) {
                ConfigManager.shared.currentConfig = config
            }
        }
        
    }
    
}


