//
//  WriteToLog.swift
//  SYM-Helper
//

import Foundation
class WriteToLog {
    
    static let shared = WriteToLog()
    private init() { }
    
    var logFileW: FileHandle? = FileHandle(forUpdatingAtPath: "")

    func message(stringOfText: String) {
        /*
        let logString = "\(getCurrentTime()) \(stringOfText)\n"

        self.logFileW = FileHandle(forUpdatingAtPath: (Log.path! + Log.file))
//        let fullpath = Log.path! + Log.file
        
        let logText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
        self.logFileW?.seekToEndOfFile()
        self.logFileW?.write(logText!)
         */
        
        let logString = "\(getCurrentTime()) \(stringOfText)\n"

        guard let logData = logString.data(using: .utf8) else { return }
        let logURL = URL(fileURLWithPath: Log.path! + Log.file)
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logURL)
            defer { fileHandle.closeFile() } // Ensure file is closed
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
        } catch {
            print("[Log Error] Failed to write to log file: \(error.localizedDescription)")
        }
    }
}
