//
//  ApiRequest.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import Alamofire



class ApiRequest{
    static let shared = ApiRequest()
    private init(){
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 604800
        configuration.timeoutIntervalForResource = 604800
        alamoFireManager = Alamofire.SessionManager(configuration: configuration)
        
    }
    
    var trafficReq:DataRequest? = nil
    var logReq:DataRequest? = nil
    var alamoFireManager:SessionManager!
    

    static func requestConfig(completeHandler:@escaping ((ClashConfig)->())){
        request(ConfigManager.apiUrl + "/configs", method: .get).responseData{
            res in
            guard let data = res.result.value else {return}
            let config = ClashConfig.fromData(data)
            completeHandler(config)
        }
    }
    
    func requestTrafficInfo(callback:@escaping ((Int,Int)->()) ){
        trafficReq?.cancel()
        
        trafficReq =
            alamoFireManager
                .request(ConfigManager.apiUrl + "/traffic")
                .stream {(data) in
                    if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String:Int] {
                        callback(jsonData!["up"] ?? 0, jsonData!["down"] ?? 0)
                    }
                }.response { res in
                    guard let err = res.error else {return}
                    if (err as NSError).code != -999 {
                        Logger.log(msg: "Traffic Api.\(err.localizedDescription)")
                        // delay 1s,prevent recursive
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                            self.requestTrafficInfo(callback: callback)
                        })
                    }
        }
    }
    
    func requestLog(callback:@escaping ((String,String)->()) ){
        logReq?.cancel()
        logReq =
            alamoFireManager
                .request(ConfigManager.apiUrl + "/logs")
                .stream {(data) in
                    if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String:String] {
                        let type = jsonData!["type"] ?? "info"
                        let payload = jsonData!["payload"] ?? ""
                        callback(type,payload)
                    }
                }
                .response { res in
                    guard let err = res.error else {return}
                    if (err as NSError).code != -999 {
                        Logger.log(msg: "Loging api disconnected.\(err.localizedDescription)")
                        // delay 1s,prevent recursive
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                            self.requestLog(callback: callback)
                        })
                    }
        }
    }
    
    static func requestConfigUpdate(callback:@escaping ((Bool)->())){
        let success = updateAllConfig()
        callback(success==0)
    }
    
    static func updateOutBoundMode(mode:ClashProxyMode, callback:@escaping ((Bool)->())) {
        request(ConfigManager.apiUrl + "/configs", method: .put, parameters: ["mode":mode.rawValue], encoding: JSONEncoding.default)
            .responseJSON{ response in
            switch response.result {
            case .success(_):
                callback(true)
            case .failure(_):
                callback(false)
            }
        }
    }
    
    
    static func requestProxyGroupList(completeHandler:@escaping (([String:[String:Any]])->())){
        request(ConfigManager.apiUrl + "/proxies", method: .get).responseJSON{
            res in
            guard let data = res.result.value as? [String:[String:[String:Any]]] else {return}
            completeHandler(data["proxies"]!)
        }
    }
    
    static func updateProxyGroup(group:String,selectProxy:String,callback:@escaping ((Bool)->())) {
        request(ConfigManager.apiUrl + "/proxies/\(group)", method: .put, parameters: ["name":selectProxy], encoding: JSONEncoding.default).responseJSON { (response) in
            callback(response.response?.statusCode == 204)
        }
    }
}
