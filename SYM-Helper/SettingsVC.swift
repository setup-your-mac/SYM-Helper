//
//  SettingsVC.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

class SYMSetting: NSObject {
    @objc var name: String
    @objc var tab: String
    
    init(name: String, tab: String) {
        self.name = name
        self.tab  = tab
    }
}

class SettingsVC: NSViewController, NSTextFieldDelegate, NSTextViewDelegate {
    
    var whichTab = ""
    
    @IBOutlet weak var scriptSource_TextField: NSTextField!
    
    @IBOutlet weak var pfu_Button: NSPopUpButton!
    @IBOutlet weak var pu_Button: NSPopUpButton!
    @IBOutlet weak var pfcn_Button: NSPopUpButton!
    @IBOutlet weak var pfat_Button: NSPopUpButton!
    @IBOutlet weak var pfr_Button: NSPopUpButton!
    @IBOutlet weak var pfb_Button: NSPopUpButton!
    @IBOutlet weak var pfd_Button: NSPopUpButton!
    @IBOutlet weak var pfc_Button: NSPopUpButton!
    @IBOutlet weak var mip_Button: NSPopUpButton!
    
    @IBOutlet var buildings_TextField: NSTextView!
    @IBOutlet var departments_TextField: NSTextView!
    
    @IBAction func fetch_Action(_ sender: NSButton) {
        spinner_Progress.startAnimation(self)
        sender.isEnabled = false
        let theRow = settings_TableView.selectedRow
        whichTab = settingsArray[theRow].tab
        ClassicAPI().getAll(endpoint: whichTab) { [self]
            (result: [String:Any]) in
            var allObjects = [String]()
            let allObjectsDict = result[whichTab] as! [[String:Any]]
            //                        print("all policies: \(allPolicies)")
            for object in allObjectsDict {
                let objectName = object["name"] as? String ?? ""
                if objectName != "" {
                    allObjects.append(objectName)
                }
            }
            switch whichTab {
            case "buildings":
                buildings_TextField.string = arrayToList(theArray: allObjects)
                Settings.shared.dict["buildingsListRaw"] = buildings_TextField.string.replacingOccurrences(of: "\n", with: ",").listToString
            default:
                departments_TextField.string = arrayToList(theArray: allObjects)
                Settings.shared.dict["departmentListRaw"] = departments_TextField.string.replacingOccurrences(of: "\n", with: ",").listToString
            }
            
            sender.isEnabled = true
            spinner_Progress.stopAnimation(self)
        }
    }
    private func arrayToList(theArray: [String]) -> String {
        var theString = ""
        for object in theArray.sorted() {
            theString = "\(theString)\(object)\n"
        }
        if theString.last == "\n" {
            theString = String(theString.dropLast(1))
        }
        return theString
    }
    
    @IBOutlet weak var cancel_Button: NSButton!
    @IBOutlet weak var ok_Button: NSButton!
    @IBOutlet weak var spinner_Progress: NSProgressIndicator!
    
    @IBOutlet weak var settings_TableView: NSTableView!
    @IBOutlet var settings_AC: NSArrayController!
    @IBOutlet weak var settings_TabView: NSTabView!
    
    var settingsArray = [SYMSetting(name: "Script Source", tab: "scriptSource"),
                         SYMSetting(name: "Prompt For...", tab: "promptFor"),
                         SYMSetting(name: "Buildings", tab: "buildings"),
                         SYMSetting(name: "Departments", tab: "departments")]
    
//    var settingsDict      = [String:Any]()
    var currentConfig     = ""
    var validScriptSource = ""
    
    @IBAction func pfu_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForUsername"] = sender.title
    }
    @IBAction func pu_Action(_ sender: NSButton) {
        Settings.shared.dict["prefillUsername"] = sender.title
    }
    @IBAction func pfcn_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForComputerName"] = sender.title
    }
    @IBAction func pfat_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForAssetTag"] = sender.title
    }
    @IBAction func pfr_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForRoom"] = sender.title
    }
    @IBAction func pfb_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForBuilding"] = sender.title
    }
    @IBAction func pfd_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForDepartment"] = sender.title
    }
    @IBAction func pfc_Action(_ sender: NSButton) {
        Settings.shared.dict["promptForConfiguration"] = sender.title
    }
    @IBAction func mip_Action(_ sender: NSButton) {
        Settings.shared.dict["moveableInProduction"] = sender.title
    }
    
    
    @IBAction func resetToDefault(_ sender: Any) {
        scriptSource_TextField.stringValue = defaultScriptSource
    }
    
    @IBAction func cancel_Button(_ sender: Any) {
        dismiss(self)
    }
    
    @IBAction func ok_Button(_ sender: Any) {
        spinner_Progress.startAnimation(self)
        ok_Button.isEnabled = false
        cancel_Button.isEnabled = false
        
        let theRow = settings_TableView.selectedRow
        whichTab = settingsArray[theRow].tab
        let theNotification = Notification(name: Notification.Name(rawValue: "\(whichTab)"), object: NSButton.self)
        controlTextDidEndEditing(theNotification)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print("keyPath: \(String(describing: keyPath))")
        guard let keyPath = keyPath else { return }
        switch keyPath {
        case "selectedObjects":
            if settings_TableView.selectedRowIndexes.count > 0 {
                let theRow = settings_TableView.selectedRow
                whichTab = settingsArray[theRow].tab
//                print("whichTab: \(whichTab)")
                settings_TabView.selectTabViewItem(withIdentifier: whichTab)
            }
        default:
            break
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        print("[controlTextDidEndEditing] obj: \(obj)")
        print("[controlTextDidEndEditing] obj.name.rawValue: \(obj.name.rawValue)")
        var whichField = ""
        if let textField = obj.object as? NSTextField {
            whichField = textField.identifier!.rawValue
        } else {
            whichField = obj.name.rawValue
        }
        
        print("[controlTextDidEndEditing] whichField: \(whichField)")
        switch whichField {
        case "scriptSource":
            spinner_Progress.startAnimation(self)
            SYMScript().get(scriptURL: scriptSource_TextField.stringValue) { [self]
                (result: String) in
                symScript = result
//                        print("[Settings] getScript: \(symScript)")
                spinner_Progress.stopAnimation(self)
                if symScript == "" {
                    let scriptReply = alert.display(header: "Attention:", message: "Set-Up-Your-Mac script was not found.  Verify the server URL listed in Settings.", secondButton: "Use Anyway")
                    if scriptReply == "Use Anyway" {
                        validScriptSource = scriptSource_TextField.stringValue
                        Settings.shared.dict["scriptSource"] = validScriptSource
                        if obj.name.rawValue != "NSControlTextDidEndEditingNotification" {
                            self.dismiss(self)
                        }
                    } else {
                        ok_Button.isEnabled = true
                        cancel_Button.isEnabled = true
                        scriptSource_TextField.stringValue = validScriptSource
                        settings_TableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                        settings_TabView.selectTabViewItem(withIdentifier: "scriptSource")
                        return
                    }
                } else {
                    validScriptSource = scriptSource_TextField.stringValue
                    Settings.shared.dict["scriptSource"] = validScriptSource
                    if obj.name.rawValue != "NSControlTextDidEndEditingNotification" {
                        self.dismiss(self)
                    }
                }
            }
        case "promptFor":
            if obj.name.rawValue != "NSControlTextDidEndEditingNotification" {
                self.dismiss(self)
            }
        case "buildings":
            if obj.name.rawValue != "NSControlTextDidEndEditingNotification" {
                Settings.shared.dict["buildingsListRaw"] = buildings_TextField.string.replacingOccurrences(of: "\n", with: ",").listToString
                self.dismiss(self)
            }
        case "departments":
            if obj.name.rawValue != "NSControlTextDidEndEditingNotification" {
                Settings.shared.dict["departmentListRaw"] = departments_TextField.string.replacingOccurrences(of: "\n", with: ",").listToString
                self.dismiss(self)
            }

        default:
            break
        }
    }
    
    func textDidEndEditing(_ obj: Notification) {
        if let textView = obj.object as? NSTextView {
            switch textView.identifier!.rawValue {
            case "buildings":
                Settings.shared.dict["buildingsListRaw"] = buildings_TextField.string.replacingOccurrences(of: "\n", with: ",").listToString
               
            case "departments":
                Settings.shared.dict["departmentListRaw"] = departments_TextField.string.replacingOccurrences(of: "\n", with: ",").listToString
               
            default:
                break
            }
        }
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("currentConfig: \(currentConfig)")
        print("settingsDict: \(Settings.shared.dict)")
        
        pfu_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForUsername"] as? String ?? "true")")
        pu_Button.selectItem(withTitle: "\(Settings.shared.dict["prefillUsername"] as? String ?? "true")")
        pfcn_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForComputerName"] as? String ?? "true")")
        pfat_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForAssetTag"] as? String ?? "true")")
        pfr_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForRoom"] as? String ?? "true")")
        pfb_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForBuilding"] as? String ?? "true")")
        pfd_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForDepartment"] as? String ?? "true")")
        pfc_Button.selectItem(withTitle: "\(Settings.shared.dict["promptForConfiguration"] as? String ?? "true")")
        mip_Button.selectItem(withTitle: "\(Settings.shared.dict["moveableInProduction"] as? String ?? "true")")
        
        let buildingsList = Settings.shared.dict["buildingsListRaw"] as? String ?? ""
        buildings_TextField.string = buildingsList.replacingOccurrences(of: ",", with: "\n")
        let departmentsList = Settings.shared.dict["departmentListRaw"] as? String ?? ""
        departments_TextField.string = departmentsList.replacingOccurrences(of: ",", with: "\n")
        
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        settings_TableView.tableColumns.forEach { (column) in
            column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 16), .paragraphStyle: style])
        }
        
        settings_TableView.delegate = self
        settings_TableView.dataSource = self
        
        scriptSource_TextField.delegate = self
        buildings_TextField.delegate    = self
        departments_TextField.delegate  = self
        
        
        settings_AC.add(contentsOf: settingsArray)
        settings_TableView.selectRowIndexes(.init(integer: 0), byExtendingSelection: false)
        whichTab = settingsArray[0].tab
        settings_TabView.selectTabViewItem(withIdentifier: whichTab)
        validScriptSource = Settings.shared.dict["scriptSource"] as? String ?? defaultScriptSource
//        validScriptSource = defaults.string(forKey: "scriptSource") ?? defaultScriptSource
        scriptSource_TextField.stringValue = validScriptSource

        settings_AC.addObserver(self, forKeyPath: "selectedObjects", options: .new, context: nil)

    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        print("[viewWillDisappear] settingsDict: \(Settings.shared.dict)")
        ConfigsSettings().save(theServer: "\(JamfProServer.destination.fqdnFromUrl)", dataType: "settings", data: Settings.shared.dict)
    }
    
}

extension SettingsVC: NSTableViewDataSource, NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NameCell = "name"
        static let TabCell  = "tab"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
//            print("numberOfRows: \(policiesArray.count)")
            return settingsArray.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if settings_TableView.selectedRowIndexes.count > 0 {
            let theRow = settings_TableView.selectedRow
            whichTab = settingsArray[theRow].tab
            print("whichTab: \(whichTab)")
            settings_TabView.selectTabViewItem(withIdentifier: whichTab)
            
        }
    }
    
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        //        print("tableView: \(tableView)\t\ttableColumn: \(tableColumn)\t\trow: \(row)")
        var newString:String = ""
        if (tableView == settings_TableView)
        {
            let name = settingsArray[row].name
            newString = "\(name)"
        }
        return newString;
    }
}
