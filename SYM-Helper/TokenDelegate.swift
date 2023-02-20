//
//  TokenDelegate.swift
//  Last Run
//
//  Created by Leslie Helou on 11/26/21
//

import Cocoa

class TokenDelegate: NSObject, URLSessionDelegate {
    
    var renewQ = DispatchQueue(label: "com.token_refreshQ", qos: DispatchQoS.background)   // running background process for refreshing token
        
    func getToken(whichServer: String, serverUrl: String, base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {
       
        let forceBasicAuth = (defaults.integer(forKey: "forceBasicAuth") == 1) ? true:false
        WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Force basic authentication on \(serverUrl): \(forceBasicAuth)")
       
        URLCache.shared.removeAllCachedResponses()
                
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
    //        print("\(tokenUrlString)")
        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        let (_, minutesOld, _) = timeDiff(forWhat: "destTokenAge")
//        print("[JamfPro] \(whichServer) tokenAge: \(minutesOld) minutes")
        if !JamfProServer.validToken || (JamfProServer.base64Creds != base64creds) || (minutesOld > 25) {
            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Attempting to retrieve token from \(String(describing: tokenUrl!)) for version look-up")
            
            configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpSuccess.contains(httpResponse.statusCode) {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json! as? [String: Any], let _ = endpointJSON["token"], let _ = endpointJSON["expires"] {
                            JamfProServer.validToken  = true
                            JamfProServer.authCreds   = (endpointJSON["token"] as? String)!
//                            JamfProServer.authExpires = "\(endpointJSON["expires"] ?? "")"
                            JamfProServer.authType    = "Bearer"
                            JamfProServer.base64Creds = base64creds
                            
                            tokenTimeCreated = Date()
                            
    //                      if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Retrieved token: \(token)") }
    //                      print("[JamfPro] result of token request: \(endpointJSON)")
                            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] new token created for \(serverUrl)")
                            
                            if JamfProServer.version == "" {
                                // get Jamf Pro version - start
                                self.getVersion(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.authCreds, method: "GET") {
                                    (result: [String:Any]) in
                                    if let versionString = result["version"] as? String {
                                        
                                        if versionString != "" {
                                            WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] Jamf Pro Version: \(versionString)")
                                            JamfProServer.version = versionString
                                            let tmpArray = versionString.components(separatedBy: ".")
                                            if tmpArray.count > 2 {
                                                for i in 0...2 {
                                                    switch i {
                                                    case 0:
                                                        JamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                                    case 1:
                                                        JamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                                    case 2:
                                                        let tmp = tmpArray[i].components(separatedBy: "-")
                                                        JamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                                        if tmp.count > 1 {
                                                            JamfProServer.build = tmp[1]
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                if ( JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34 ) && !forceBasicAuth {
                                                    JamfProServer.authType = "Bearer"
                                                    JamfProServer.validToken = true
                                                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] \(serverUrl) set to use Bearer Token")
                                                    
                                                } else {
                                                    JamfProServer.authType  = "Basic"
                                                    JamfProServer.validToken = false
                                                    JamfProServer.authCreds = base64creds
                                                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] \(serverUrl) set to use Basic Authentication")
                                                }
                                                if JamfProServer.authType == "Bearer" {
                                                    self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: JamfProServer.base64Creds)
                                                }
                                                completion((200, "success"))
                                                return
                                            }
                                        }
                                    } else {   // if let versionString - end
                                        WriteToLog().message(stringOfText: "[TokenDelegate.getToken] failed to get version information from \(String(describing: serverUrl))")
                                        JamfProServer.validToken = false
                                        _ = Alert().display(header: "Attention", message: "Failed to get version information from \(String(describing: serverUrl))", secondButton: "")
                                        completion((httpResponse.statusCode, "failed"))
                                        return
                                    }
                                }
                                // get Jamf Pro version - end
                            } else {
                                if JamfProServer.authType == "Bearer" {
                                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] call token refresh process for \(serverUrl)")
                                    self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: JamfProServer.base64Creds)
                                }
                                completion((200, "success"))
                                return
                            }
                        } else {    // if let endpointJSON error
                            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] JSON error.\n\(String(describing: json))")
                            JamfProServer.validToken  = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Failed to authenticate to \(serverUrl).  Response error: \(httpResponse.statusCode).")

                        _ = Alert().display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)", secondButton: "")
                        
                        JamfProServer.validToken = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
                    _ = Alert().display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.", secondButton: "")
                    WriteToLog().message(stringOfText: "[TokenDelegate.getToken] token response error from \(serverUrl).  Verify url and port.")
                    JamfProServer.validToken = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Use existing token from \(String(describing: tokenUrl!))")
            completion((200, "success"))
            return
        }
        
    }
    
    func getVersion(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        if method.lowercased() == "skip" {
//            if LogLevel.debug { WriteToLog().message(stringOfText: "[Jpapi.action] skipping \(endpoint) endpoint with id \(id).") }
            let JPAPI_result = (endpoint == "auth/invalidate-token") ? "no valid token":"failed"
            completion(["JPAPI_result":JPAPI_result, "JPAPI_response":000])
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version", "auth/invalidate-token":
            path = "v1/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
        }

        var urlString = "\(serverUrl)/api/\(path)"
        urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
        if id != "" && id != "0" {
            urlString = urlString + "/\(id)"
        }
//        print("[Jpapi] urlString: \(urlString)")
        
        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: url!)
        switch method.lowercased() {
        case "get":
            request.httpMethod = "GET"
        case "create", "post":
            request.httpMethod = "POST"
        default:
            request.httpMethod = "PUT"
        }
        
        if apiData.count > 0 {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
            } catch let error {
                print(error.localizedDescription)
            }
        }
        
        WriteToLog().message(stringOfText: "[Jpapi.action] Attempting \(method) on \(urlString).")
//        print("[Jpapi.action] Attempting \(method) on \(urlString).")
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
        
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {

                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json as? [String:Any] {
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        if httpResponse.statusCode == 204 && endpoint == "auth/invalidate-token" {
                            completion(["JPAPI_result":"token terminated", "JPAPI_response":httpResponse.statusCode])
                        } else {
                            completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        }
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] Response error: \(httpResponse.statusCode).")
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] GET response error.  Verify url and port.")
                completion([:])
                return
            }
        })
        task.resume()
        
    }   // func getVersion - end
    
    func refresh(server: String, whichServer: String, b64Creds: String) {
        DispatchQueue.main.async { [self] in
            if runComplete {
                JamfProServer.validToken = false
                WriteToLog().message(stringOfText: "[TokenDelegate.refresh] terminated token refresh")
                return
            }
            WriteToLog().message(stringOfText: "[TokenDelegate.refresh] queue token refresh for \(server)")
            renewQ.async { [self] in
                sleep(refreshInterval)
                JamfProServer.validToken = false
                getToken(whichServer: whichServer, serverUrl: server, base64creds: JamfProServer.base64Creds) {
                    (result: (Int, String)) in
//                    print("[JamfPro.refresh] returned: \(result)")
                }
            }
        }
    }
}
