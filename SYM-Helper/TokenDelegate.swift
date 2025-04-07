//
//  TokenDelegate.swift
//  SYM-Helper
//

import Cocoa

// MARK: - Token Response Types
enum TokenResponse: Codable {
    case tokenData(TokenData)
    case accessTokenData(AccessTokenData)

    enum CodingKeys: String, CodingKey {
        case expires, token
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case accessToken = "access_token"
        case scope
    }

    // Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.expires) {
            let data = try TokenData(from: decoder)
            self = .tokenData(data)
        } else if container.contains(.expiresIn) {
            let data = try AccessTokenData(from: decoder)
            self = .accessTokenData(data)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown token format")
            )
        }
    }

    // Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .tokenData(let data):
            try container.encode(data.expires, forKey: .expires)
            try container.encode(data.token, forKey: .token)
        case .accessTokenData(let data):
            try container.encode(data.expiresIn, forKey: .expiresIn)
            try container.encode(data.tokenType, forKey: .tokenType)
            try container.encode(data.accessToken, forKey: .accessToken)
            try container.encodeIfPresent(data.scope, forKey: .scope)
        }
    }
}

// MARK: - First JSON Format
struct TokenData: Codable {
    let expires: Date
    let token: String

    enum CodingKeys: String, CodingKey {
        case expires
        case token
    }
}

// MARK: - Second JSON Format
struct AccessTokenData: Codable {
    let expiresIn: Double
    let tokenType: String
    let accessToken: String
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case accessToken = "access_token"
        case scope
    }
}

// MARK: - Custom Date Formatter for ISO 8601 Strings
extension DateFormatter {
    static let customISO8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

class TokenDelegate: NSObject, URLSessionDelegate {
    
    static let shared = TokenDelegate()
    
    var components   = DateComponents()
    
    func getToken(serverUrl: String, whichServer: String = "source", base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {

        URLCache.shared.removeAllCachedResponses()
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"

        var apiClient = false
        if useApiClient == 1 {
            tokenUrlString = "\(serverUrl)/api/oauth/token"
            apiClient = true
        }

        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
        //        print("[getToken] tokenUrlString: \(tokenUrlString)")

        let tokenUrl = URL(string: "\(tokenUrlString)")
        guard let _  = URL(string: "\(tokenUrlString)") else {
            print("problem constructing the URL from \(tokenUrlString)")
            WriteToLog.shared.message(stringOfText: "[getToken] problem constructing the URL from \(tokenUrlString)")
            completion((500, "failed"))
            return
        }
        //        print("[getToken] tokenUrl: \(tokenUrl!)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"

        let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: JamfProServer.tokenCreated)

        //        print("[getToken] JamfProServer.validToken[\(whichServer)]: \(String(describing: JamfProServer.validToken[whichServer]))")
        //        print("[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
        //        print("[getToken] \(whichServer)  token exipres in: \((JamfProServer.authExpires[whichServer] ?? 30)*60)")
        //        print("[getToken] JamfProServer.currentCred[\(whichServer)]: \(String(describing: JamfProServer.currentCred[whichServer]))")
//        print("[getToken] JamfProServer.authExpires: \(JamfProServer.authExpires*60)")
        if !(JamfProServer.validToken && tokenAgeInSeconds < JamfProServer.authExpires) {
            WriteToLog.shared.message(stringOfText: "[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
            WriteToLog.shared.message(stringOfText: "[getToken] Attempting to retrieve token from \(tokenUrlString)")
            
            if apiClient {
                let clientId = JamfProServer.username
                let secret   = JamfProServer.password
                let clientString = "grant_type=client_credentials&client_id=\(String(describing: clientId))&client_secret=\(String(describing: secret))"
        //                print("[getToken] \(whichServer) clientString: \(clientString)")

                let requestData = clientString.data(using: .utf8)
                request.httpBody = requestData
                configuration.httpAdditionalHeaders = ["Content-Type" : "application/x-www-form-urlencoded", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = clientString
            } else {
                configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = base64creds
            }
            
            let authType = apiClient ? "API client / secret" : "username / password"
            WriteToLog.shared.message(stringOfText: "[getToken] authenticating with \(authType)")
//            print("[getToken] tokenUrlString: \(tokenUrlString)")
//            print("[getToken] configuration.httpAdditionalHeaders: \(String(describing: configuration.httpAdditionalHeaders))")
            
//            print("[getToken] \(whichServer) tokenUrlString: \(tokenUrlString)")
//            print("[getToken]    \(whichServer) base64creds: \(base64creds)")
            
            let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpSuccess.contains(httpResponse.statusCode) {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .formatted(DateFormatter.customISO8601)
                            
                            let tokenResponse = try decoder.decode(TokenResponse.self, from: data!)
                            
                            switch tokenResponse {
                            case .tokenData(let data):
                                JamfProServer.accessToken = data.token
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                if let date = data.expires as? Date {
                                    // Convert the Date object to local time with a readable format
                                    let localFormatter = DateFormatter()
                                    localFormatter.timeZone = .current // Automatically uses the local time zone
                                    localFormatter.dateStyle = .medium
                                    localFormatter.timeStyle = .medium
                                    let renewIn = timeDiff(startTime: date)
                                    JamfProServer.authExpires = renewIn.3
                                    
                                } else {
                                    JamfProServer.authExpires = 20*60
                                }
                            case .accessTokenData(let data):
                                JamfProServer.accessToken = data.accessToken
                                JamfProServer.authExpires = data.expiresIn
                                //                                if let scope = data.scope {
                                //                                    //print("Scope: \(scope)")
                                //                                }
                            }
                            
                            
                            JamfProServer.authExpires  = Double(Int((JamfProServer.authExpires*0.75)/10)*10)
                            WriteToLog.shared.message(stringOfText: "[getToken] renewal interval: \(String(describing: JamfProServer.authExpires ?? -1)) seconds")
                            
                            JamfProServer.tokenCreated = Date()
                            JamfProServer.validToken   = true
                            JamfProServer.authType     = "Bearer"
                            
                            if JamfProServer.version == "" {
                                // get Jamf Pro version - start
                                getVersion(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.accessToken, method: "GET") {
                                    (result: [String:Any]) in
                                    let versionString = result["version"] as! String
                                    
                                    if versionString != "" {
                                        WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
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
                                            if ( JamfProServer.majorVersion > 10 || (JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34) ) {
                                                JamfProServer.authType = "Bearer"
                                                WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] \(serverUrl) set to use OAuth")
                                                
                                            } else {
                                                JamfProServer.authType    = "Basic"
                                                JamfProServer.accessToken = base64creds
                                                WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] \(serverUrl) set to use Basic")
                                            }
                                            completion((200, "success"))
                                            return
                                        }
                                    }
                                }
                                // get Jamf Pro version - end
                            } else {
                                completion((200, "success"))
                                return
                            }
                        } catch {
                            let tokenResponseString = String(data: data ?? Data(), encoding: .utf8) ?? "No data returned"
                            WriteToLog.shared.message(stringOfText: "[getToken] Problem decoding token response: \(tokenResponseString)")
                            JamfProServer.validToken  = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        _ = Alert.shared.display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)", secondButton: "")
                        WriteToLog.shared.message(stringOfText: "[getToken] Failed to authenticate to \(serverUrl).  Response error: \(httpResponse.statusCode)")
                        JamfProServer.validToken = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
                    _ = Alert.shared.display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.", secondButton: "")
                    WriteToLog.shared.message(stringOfText: "[getToken] token response error from \(serverUrl).  Verify url and port")
                    JamfProServer.validToken = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
//            WriteToLog.shared.message(stringOfText: "[getToken] Use existing token from \(String(describing: tokenUrl))")
            completion((200, "success"))
            return
        }
    }
    
    func getVersion(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        if method.lowercased() == "skip" {
//            if LogLevel.debug { WriteToLog.shared.message(stringOfText: "[Jpapi.action] skipping \(endpoint) endpoint with id \(id).") }
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
        
        WriteToLog.shared.message(stringOfText: "[getVersion] Attempting \(method) on \(urlString).")
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
                    WriteToLog.shared.message(stringOfText: "[getVersion] Response error: \(httpResponse.statusCode)")
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                WriteToLog.shared.message(stringOfText: "[getVersion] GET response error.  Verify url and port")
                completion([:])
                return
            }
        })
        task.resume()
        
    }   // func getVersion - end

}
