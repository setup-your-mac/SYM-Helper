//
//  ClassicAPI.swift
//  Setup-Your-Mac-Helper
//
//  Created by Leslie Helou on 7/12/23.
//

import Foundation

class ClassicAPI: NSObject, URLSessionDelegate {
    
    func getAll(endpoint: String, completion: @escaping (_ result: [String:Any]) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        
        var endpoint = "\(JamfProServer.destination)/JSSResource/\(endpoint)"
        endpoint = endpoint.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
        endpoint = endpoint.replacingOccurrences(of: "/?failover", with: "")
        let endpointUrl      = URL(string: "\(endpoint)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: endpointUrl!)
        request.httpMethod = "GET"
        configuration.httpAdditionalHeaders = ["Authorization" : "\(String(describing: JamfProServer.authType)) \(String(describing: JamfProServer.authCreds))", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
           (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpSuccess.contains(httpResponse.statusCode) {
                //                   print("getAllPolicies statusCode: \(httpResponse.statusCode)")
                   
                    let responseData = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = responseData! as? [String: Any] {
                       completion(endpointJSON)
                       return
                    } else {
                       writeToLog.message(stringOfText: "[getAllPolicies] No data was returned from post/put.")
                    }
                }
            } else {
               print("could not read response or no response")
            }
            completion([:])
        })
    task.resume()
    }
    
}
