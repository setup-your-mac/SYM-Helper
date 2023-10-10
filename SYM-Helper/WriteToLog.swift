//
//  WriteToLog.swift
//  SYM-Helper
//

import Foundation
class WriteToLog {
    
    var logFileW: FileHandle? = FileHandle(forUpdatingAtPath: "")

    func message(stringOfText: String) {
        let logString = "\(getCurrentTime()) \(stringOfText)\n"

        self.logFileW = FileHandle(forUpdatingAtPath: (Log.path! + Log.file))
        let fullpath = Log.path! + Log.file
        
        let historyText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
        self.logFileW?.seekToEndOfFile()
        self.logFileW?.write(historyText!)
    }
}
