//
//  WriteToLog.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Foundation
class WriteToLog {
    
    var logFileW: FileHandle? = FileHandle(forUpdatingAtPath: "")
//    let writeToLogQ = DispatchQueue(label: "com.jamf.writeToLogQ", qos: DispatchQoS.background)

    func message(stringOfText: String) {
        let logString = "\(getCurrentTime()) \(stringOfText)\n"

        self.logFileW = FileHandle(forUpdatingAtPath: (Log.path! + AppInfo.logFile))

        self.logFileW?.seekToEndOfFile()
        let historyText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
        self.logFileW?.write(historyText!)
    }
}
