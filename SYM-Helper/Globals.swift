//
//  Globals.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

// for saving servers, shared settings - LoginVC
var saveServers            = true
var maxServerList          = 40
var appsGroupId            = "group.PS2F6S478M.jamfie.SharedJPMA"
let sharedDefaults         = UserDefaults(suiteName: appsGroupId)
let sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appsGroupId)
let sharedSettingsPlistUrl = (sharedContainerUrl?.appendingPathComponent("Library/Preferences/\(appsGroupId).plist"))!

var showLoginWindow = true
let defaults        = UserDefaults.standard
var groupNumber     = 0
let httpSuccess     = 200...299
let refreshInterval: UInt32 = 25*60 // 25 minutes
var runComplete     = false
var symScript       = ""
var tokenTimeCreated: Date?

var useApiClient    = 0

let alert: Alert           = Alert()
let writeToLog: WriteToLog = WriteToLog()

var scriptSource        = ""
var defaultScriptSource = "https://raw.githubusercontent.com/dan-snelson/Setup-Your-Mac/main/Setup-Your-Mac-via-Dialog.bash"
//var scriptSource       = "https://recipes.hickoryhillseast.net/sym/Setup-Your-Mac-via-Dialog.bash"

struct AppInfo {
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let build   = dict["CFBundleVersion"] as! String
    static let name    = dict["CFBundleExecutable"] as! String
    static var stopUpdates = false

    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(AppInfo.version)"
    
    static var bundlePath   = Bundle.main.bundleURL
    
    static let appSupport       = NSHomeDirectory() + "/Library/Application Support"
    static var logPath: String? = NSHomeDirectory() + "/Library/Logs/sym-helper/"
    static var logFile          = ""
    static var startTime        = Date()
}

struct JamfProServer {
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var build        = ""
    static var version      = ""
    static var authType     = "Basic"
    static var destination  = ""
    static var displayName  = ""
    static var username     = ""
    static var userpass     = ""
    static var authCreds    = ""
    static var base64Creds  = ""        // used if we want to auth with a different account
    static var validToken   = false
    static var tokenExpires = ""
}

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/sym-helper/")
    static var file          = "sym-helper.log"
    static var maxFiles      = 10
    static var maxSize       = 10000000 // 10MB
}

struct Token {
    static var refreshInterval:UInt32 = 15*60  // 15 minutes
    static var sourceServer  = ""
    static var sourceExpires = ""
}

func betweenTags(xmlString:String, startTag:String, endTag:String) -> String {
    var rawValue = ""
    if let start = xmlString.range(of: startTag),
        let end  = xmlString.range(of: endTag, range: start.upperBound..<xmlString.endIndex) {
        rawValue.append(String(xmlString[start.upperBound..<end.lowerBound]))
    } else {
        writeToLog.message(stringOfText: "[betweenTags] Start, \(startTag), and end, \(endTag), not found.")
    }
    return rawValue
}

func timeDiff(forWhat: String) -> (Int,Int,Int) {
    var components:DateComponents?
    switch forWhat {
    case "runTime":
        components = Calendar.current.dateComponents([.second, .nanosecond], from: AppInfo.startTime, to: Date())
    case "tokenAge":
        components = Calendar.current.dateComponents([.second, .nanosecond], from: (tokenTimeCreated ?? Date())!, to: Date())
    default:
        break
    }
//          let timeDifference = Double(components.second!) + Double(components.nanosecond!)/1000000000
//          writeToLog.message(stringOfText: "[Migration Complete] runtime: \(timeDifference) seconds\n")
    let timeDifference = Int(components?.second! ?? 0)
    let (h,r) = timeDifference.quotientAndRemainder(dividingBy: 3600)
    let (m,s) = r.quotientAndRemainder(dividingBy: 60)
    return(h,m,s)
}

// get current time
func getCurrentTime() -> String {
    let current = Date()
    let localCalendar = Calendar.current
    let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let dateTime = localCalendar.dateComponents(dateObjects, from: current)
    let currentMonth  = leadingZero(value: dateTime.month!)
    let currentDay    = leadingZero(value: dateTime.day!)
    let currentHour   = leadingZero(value: dateTime.hour!)
    let currentMinute = leadingZero(value: dateTime.minute!)
    let currentSecond = leadingZero(value: dateTime.second!)
    let stringDate = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
    return stringDate
}

// add leading zero to single digit integers
func leadingZero(value: Int) -> String {
    var formattedValue = ""
    if value < 10 {
        formattedValue = "0\(value)"
    } else {
        formattedValue = "\(value)"
    }
    return formattedValue
}

extension String {
    var failoverFix: String {
        get {
            var serverUrlString = ""
            let toArray = self.components(separatedBy: "/?failover")
            serverUrlString = toArray[0]
            return serverUrlString
        }
    }
    var fqdnFromUrl: String {
        get {
            var fqdn = ""
            let nameArray = self.components(separatedBy: "://")
            if nameArray.count > 1 {
                fqdn = nameArray[1]
            } else {
                fqdn =  self
            }
            if fqdn.contains(":") {
                let fqdnArray = fqdn.components(separatedBy: ":")
                fqdn = fqdnArray[0]
            }
            return fqdn
        }
    }
    var xmlDecode: String {
        get {
            let newString = self.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&#13;", with: "\n")
            return newString
        }
    }
    var xmlEncode: String {
        get {
            var newString = self
            newString = newString.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "'", with: "&apos;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            
            return newString
        }
    }
    var listToString: String {
        get {
                var theList = self.replacingOccurrences(of: "\n", with: ",")
                while theList.last == "," {
                    theList = "\(theList.dropLast(1))"
                }
            return theList
        }
    }
}
