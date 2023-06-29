//
//  SYMScript.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 6/27/23.
//

import Foundation

class SYMScript: NSObject, URLSessionDelegate {
    func get(scriptURL: String,completion: @escaping (_ authResult: String) -> Void) {
        print("enter getScript")
        print("script source: \(scriptURL)")
        var responseData = ""
        URLCache.shared.removeAllCachedResponses()
        //        let scriptUrl      = URL(string: "\(scriptSource)")
        let scriptUrl      = URL(string: "\(scriptURL)")
        let configuration  = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        var request        = URLRequest(url: scriptUrl!)
        request.httpMethod = "GET"
        configuration.httpAdditionalHeaders = ["User-Agent" : AppInfo.userAgentHeader]
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpSuccess.contains(httpResponse.statusCode) {
                    print("statusCode: \(httpResponse.statusCode)")
                    
                    if let _ = String(data: data!, encoding: .utf8) {
                        responseData = String(data: data!, encoding: .utf8)!
//                        WriteToLog().message(stringOfText: "[CreateEndpoints] \n\nfull response from create:\n\(responseData)") }
//                        print("response: \(responseData)")
                        print("[SYMScript] done fetching script")
                    } else {
                        WriteToLog().message(stringOfText: "\n[getScript] No data was returned from post/put.")
                    }
                    completion(responseData)
                    return
                }
            } else {
                print("could not read response or no response")
            }
            completion(responseData)
        })
        task.resume()
    }
}
