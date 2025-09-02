//
//  Globals.swift
//  SYM-Helper
//

import Cocoa
import Foundation

// for saving servers, shared settings - LoginVC
var saveServers            = true
var maxServerList          = 40
var appsGroupId            = "PS2F6S478M.jamfie.SharedJPMA"
let sharedDefaults         = UserDefaults(suiteName: appsGroupId)
let sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appsGroupId)
let sharedSettingsPlistUrl = (sharedContainerUrl?.appendingPathComponent("Library/Preferences/\(appsGroupId).plist"))!

var didRun          = false
var showLoginWindow = true
let defaults        = UserDefaults.standard
var groupNumber     = 0
let httpSuccess     = 200...299
let refreshInterval: UInt32 = 20*60 // 20 minutes
var runComplete     = false
var symScript       = ""
var symScriptRaw    = ""
var scriptVersion   = (0,0,0,"")
var tokenTimeCreated: Date?

var useApiClient    = 0

var scriptSource           = ""

// icon default
var defaultIcon = ""

// script defaults
//old defaultScriptSource: https://raw.githubusercontent.com/dan-snelson/Setup-Your-Mac/main/Setup-Your-Mac-via-Dialog.bash
var defaultScriptSource = "https://raw.githubusercontent.com/setup-your-mac/Setup-Your-Mac/main/Setup-Your-Mac-via-Dialog.bash"

// brandng defaults
var defaultBannerImage = "https://img.freepik.com/free-vector/green-abstract-geometric-wallpaper_52683-29623.jpg"
var defaultDisplayText = 1 // true
var defaultLightIcon   = "https://cdn-icons-png.flaticon.com/512/979/979585.png"
var defaultDarkIcon    = "https://cdn-icons-png.flaticon.com/512/740/740878.png"

// support defaults
var defaultTeamName      = "Support Team Name"
var defaultTeamPhone     = "+1 (801) 555-1212"
var defaultTeamEmail     = "support@domain.com"                                    // added in v1.13.0
var defaultTeamHyperlink = "[\(defaultTeamWebsite)](https://\(defaultTeamWebsite))" // added in v1.13.0
var defaultKb            = "KB8675309"
var defaultErrorKb       = ", and mention [\(defaultKb)](https://servicenow.company.com/support?id=kb_article_view&sysparm_article=\(defaultKb)#Failures)"
var defaultErrorKb2      = "[\(defaultKb)](https://servicenow.company.com/support?id=kb_article_view&sysparm_article=\(defaultKb)#Failures)"
var defaultHelpKb        = "\n- **Knowledge Base Article:** \(defaultKb)"   // dropped in v1.13.0
var defaultTeamWebsite   = "support.domain.com" 


struct AppInfo {
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let build   = dict["CFBundleVersion"] as! String
    static let name    = dict["CFBundleExecutable"] as! String
    static var stopUpdates = false

    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(AppInfo.version)"
    
    static var bundlePath   = Bundle.main.bundleURL
    
    static let appSupport       = NSHomeDirectory() + "/Library/Application Support"
    static var startTime        = Date()
}

struct JamfProServer {
    static var accessToken  = ""
    static var authExpires  = 30.0
    static var currentCred  = ""
    static var tokenCreated = Date()
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var build        = ""
    static var version      = ""
    static var authType     = "Basic"
    static var destination  = ""
    static var displayName  = ""
    static var username     = ""
    static var password     = ""
//    static var userpass     = ""
    static var authCreds    = ""
    static var base64Creds  = ""        // used if we want to auth with a different account
    static var validToken   = false
    static var tokenExpires = ""
}

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/")
    static var file          = "sym-helper.log"
    static var maxFiles      = 42
}

struct Token {
    static var refreshInterval:UInt32 = 15*60  // 15 minutes
    static var sourceServer  = ""
    static var sourceExpires = ""
}

// func cleanup - start
func cleanup() {
    var logArray: [String] = []
    var logCount: Int = 0
    do {
        let logFiles = try FileManager.default.contentsOfDirectory(atPath: Log.path!)
        
        for logFile in logFiles {
            let filePath: String = Log.path! + logFile
//            print("filePath: \(filePath)")
            logArray.append(filePath)
        }
        logArray.sort()
        logCount = logArray.count
        if didRun {
            // remove old history files
            if logCount > Log.maxFiles {
                for i in (0..<logCount-Log.maxFiles) {
//                    if LogLevel.debug { WriteToLog.shared.message(stringOfText: "Deleting log file: " + logArray[i] + "\n") }
                    
                    do {
                        try FileManager.default.removeItem(atPath: logArray[i])
                    }
                    catch let error as NSError {
                        WriteToLog.shared.message(stringOfText: "Error deleting log file:\n    " + logArray[i] + "\n    \(error)")
                    }
                }
            }
        } else {
            // delete empty log file
            if logCount > 0 {
                
            }
            do {
                try FileManager.default.removeItem(atPath: logArray[0])
            }
            catch let error as NSError {
                WriteToLog.shared.message(stringOfText: "Error deleting log file:    \n" + Log.path! + logArray[0] + "    \(error)")
            }
        }
    } catch {
        WriteToLog.shared.message(stringOfText: "no log files found")
    }
}

func betweenTags(xmlString:String, startTag:String, endTag:String) -> String {
    var rawValue = ""
    if let start = xmlString.range(of: startTag),
        let end  = xmlString.range(of: endTag, range: start.upperBound..<xmlString.endIndex) {
        rawValue.append(String(xmlString[start.upperBound..<end.lowerBound]))
    } else {
        WriteToLog.shared.message(stringOfText: "[betweenTags] Start, \(startTag), and end, \(endTag), not found.")
    }
    return rawValue
}

public func timeDiff(startTime: Date) -> (Int, Int, Int, Double) {
    let endTime = Date()
//                    let components = Calendar.current.dateComponents([.second, .nanosecond], from: startTime, to: endTime)
//                    let timeDifference = Double(components.second!) + Double(components.nanosecond!)/1000000000
//                    WriteToLog.shared.message(stringOfText: "[ViewController.download] time difference: \(timeDifference) seconds")
    let components = Calendar.current.dateComponents([
        .hour, .minute, .second, .nanosecond], from: startTime, to: endTime)
    var diffInSeconds = Double(components.hour!)*3600 + Double(components.minute!)*60 + Double(components.second!) + Double(components.nanosecond!)/1000000000
    diffInSeconds = Double(round(diffInSeconds * 1000) / 1000)
//    let timeDifference = Int(components.second!) //+ Double(components.nanosecond!)/1000000000
//    let (h,r) = timeDifference.quotientAndRemainder(dividingBy: 3600)
//    let (m,s) = r.quotientAndRemainder(dividingBy: 60)
//    WriteToLog.shared.message(stringOfText: "[ViewController.download] download time: \(h):\(m):\(s) (h:m:s)")
    return (Int(components.hour!), Int(components.minute!), Int(components.second!), diffInSeconds)
//    return (h, m, s)
}
/*
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
//          WriteToLog.shared.message(stringOfText: "[Migration Complete] runtime: \(timeDifference) seconds\n")
    let timeDifference = Int(components?.second! ?? 0)
    let (h,r) = timeDifference.quotientAndRemainder(dividingBy: 3600)
    let (m,s) = r.quotientAndRemainder(dividingBy: 60)
    return(h,m,s)
}
 */

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
            let nameArray = self.components(separatedBy: "/")
            if nameArray.count > 2 {
                fqdn = nameArray[2]
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
