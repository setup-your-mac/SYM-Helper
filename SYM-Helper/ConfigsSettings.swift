//
//  ConfigsSettings.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 6/26/23.
//

import Foundation

class ConfigsSettings: NSObject {
    
    func retrieve(dataType: String) -> [String: Any] {
        var existingConfigsDict = [String: Any]()
        // migrate configs to new naming
        if FileManager.default.fileExists(atPath: AppInfo.appSupport + "/\(JamfProServer.destination.fqdnFromUrl).json") && dataType == "configs" {
            do {
                try FileManager.default.moveItem(atPath: AppInfo.appSupport + "/\(JamfProServer.destination.fqdnFromUrl).json", toPath: AppInfo.appSupport + "/\(JamfProServer.destination.fqdnFromUrl).configs.json")
            } catch {
                
            }
            do {
                try FileManager.default.moveItem(atPath: AppInfo.appSupport + "/\(JamfProServer.destination.fqdnFromUrl).plist", toPath: AppInfo.appSupport + "/\(JamfProServer.destination.fqdnFromUrl).configs.plist")
            } catch {
                
            }
        }
        
        // look for existing configs/settingd
        do {
            if FileManager.default.fileExists(atPath: AppInfo.appSupport + "/\(JamfProServer.destination.fqdnFromUrl).\(dataType).json") {
//                print("found existing config for \(JamfProServer.destination.fqdnFromUrl)")
                let existingConfigs = try FileManager.default
                    .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    .appendingPathComponent("/\(JamfProServer.destination.fqdnFromUrl).\(dataType).json")
                
                let data = try Data(contentsOf: existingConfigs)
                existingConfigsDict = try JSONSerialization.jsonObject(with: data) as! [String:Any]
//
            }
        } catch {
            print("issue retrieving existing config/settings")
        }
        return existingConfigsDict
    }
    
    func save(theServer: String, dataType: String, data: [String:Any]) {
//        var saveInfo = [String:Any]()

        do {
            let saveURL = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("\(theServer).\(dataType).json")

            try JSONSerialization.data(withJSONObject: data)
                .write(to: saveURL)
        } catch {
            _ = alert.display(header: "Attention:", message: "Current configurations could not be saved.\n\(error)", secondButton: "")
        }
        
        do {
            let saveData = try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0)
            try saveData.write(to: URL(fileURLWithPath: AppInfo.appSupport + "/\(theServer).\(dataType).plist"))
        } catch {
            _ = alert.display(header: "Attention:", message: "Current configurations could not be saved.", secondButton: "")
        }
    }
}
