//
//  Parrot.swift
//  MiniChat
//
//  Created by Dondrey Taylor on 8/7/15.
//  Copyright (c) 2015 MiniChat, Inc. All rights reserved.
//

import Foundation

class Parrot {
    
    var offset:Int = 0
    var isPolling = false
    var queueURL:[String] = []
    var queueParameters:[[String:AnyObject]?] = []
    var queueCallback:[(data:NSDictionary, error:NSError?, index:Int, next:(()->Void))->Void] = []
    var requests:[Request] = []
    var mgr: Manager!
    var implementation:((url:String, params:[String:AnyObject]?, cb: (data:NSDictionary, error:NSError?, index:Int, next:(()->Void))->Void, index:Int) -> Request)!
    
    init() {
        let cfg = NSURLSessionConfiguration.defaultSessionConfiguration()
        cfg.HTTPCookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        cfg.timeoutIntervalForRequest = 30
        cfg.HTTPMaximumConnectionsPerHost = 100
        mgr = Manager(configuration: cfg)
        implementation = { (url:String, params:[String:AnyObject]?, cb: (data:NSDictionary, error:NSError?, index:Int, next:(()->Void))->Void, index:Int) -> Request in
            return self.mgr.request(.POST, url + "?offset=\(self.offset)", parameters: params)
                .responseJSON { response in
                    if (response.result.error == nil)
                    {
                        cb(data: response.result.value as! NSDictionary, error: nil, index: index, next: { () -> Void in
                            if self.isPolling {
                                self.requests[index] = self.implementation(url: url , params: params, cb: cb, index: index)
                            }
                        })
                    }
                    else
                    {
                        cb(data: NSDictionary(), error: response.result.error!, index: index, next: { () -> Void in
                            if self.isPolling {
                                self.requests[index] = self.implementation(url: url , params: params, cb: cb, index: index)
                            }
                        })
                    }
                }
        }
    }
    
    func poll(url:String, params:[String:AnyObject]?, cb: (data:NSDictionary, error:NSError?, index:Int, next:(()->Void))->Void) {
        queueURL.append(url)
        queueParameters.append(params)
        queueCallback.append(cb)
        if isPolling {
            requests.append(implementation(url: url, params: params, cb: cb, index: queueURL.count))
        }
    }
    
    func start() {
        if !isPolling {
            isPolling = true
            for (index,url) in queueURL.enumerate() {
                requests.append(implementation(url: url, params: queueParameters[index], cb: queueCallback[index], index: index))
            }
        }
    }
    
    func stop() {
        for request in requests {
            request.cancel()
        }
        requests = []
        isPolling = false
    }
    
    func clear() {
        queueURL = []
        queueParameters = []
        queueCallback = []
    }
}