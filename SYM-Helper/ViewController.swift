//
//  ViewController.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import AppKit
import Cocoa
import Foundation


 class Policy: NSObject {
     @objc var name: String
     @objc var id: String
     @objc var configs: [String]    // minimum, standard, full config, custom name
     @objc var grouped: Bool
     @objc var groupId: String
     
     init(name: String, id: String, configs: [String], grouped: Bool, groupId: String) {
         self.name = name
         self.id = id
         self.configs = configs
         self.grouped = grouped
         self.groupId = groupId
     }
 }

class EnrollmentActions: NSObject {
    @objc var name: String
    @objc var id: String
    @objc var icon: String?
    @objc var label: String?
    @objc var trigger: String?
    @objc var command: String?
    @objc var arguments: [String]?
    @objc var objectType: String // policy or command
    @objc var timeout: String?
    
    init(name: String, id: String, icon: String?, label: String?, trigger: String?, command: String?, arguments: [String]?, objectType: String, timeout: String?) {
        self.name = name
        self.id = id
        self.icon = icon
        self.label = label
        self.trigger = trigger
        self.command = command
        self.arguments = arguments
        self.objectType = objectType // policy or command
        self.timeout = timeout
    }
}

public class Settings {
    public var dict: [String:Any]
    init(dict: [String:Any]) {
        self.dict = dict
    }
    public static let shared = Settings(dict: [:])
}

class ViewController: NSViewController, NSTextFieldDelegate, URLSessionDelegate, OtherItemDelegate, SendingLoginInfoDelegate, SendNewConfigInfoDelegate, SendClonedConfigInfoDelegate {
    
    @IBOutlet weak var connectedTo_TextField: NSTextField!
    @IBOutlet weak var filter_SearchField: NSSearchField!

    @IBAction func filter_action(_ sender: Any) {
        let filter = filter_SearchField.stringValue
        
        policiesArray.removeAll()
        var addToArray = false
        for i in 0..<staticAllPolicies.count {
            if staticAllPolicies[i].name.lowercased().contains("\(filter.lowercased())") || filter == "" {
                addToArray = true
                for j in 0..<selectedPoliciesArray.count {
                    if selectedPoliciesArray[j].name.lowercased().contains("\(staticAllPolicies[i].name.lowercased())") {
                        addToArray = false
                        break
                    }
                }
                if addToArray {
                    policiesArray.append(staticAllPolicies[i])
                }
            }
        }
        policies_TableView.reloadData()
    }
    
    @IBOutlet weak var configuration_Button: NSPopUpButton!
    @IBOutlet weak var configuration_Menu: NSMenu!
    @IBOutlet weak var clearRemove_Button: NSPopUpButton!
    
    @IBAction func clearRemove_Action(_ sender: NSButton) {
        let currentConfig = configuration_Button.titleOfSelectedItem!
        if clearRemove_Button.titleOfSelectedItem == "Clear" {
            let reply = alert.display(header: "", message: "Are you sure you want to remove all items from \(currentConfig)?", secondButton: "Cancel")
            if reply == "OK" {
                clearSelected(currentConfig: currentConfig)
            }
        } else {
            if configuration_Button.titleOfSelectedItem! == "Default" {
                _ = alert.display(header: "", message: "Cannot remove the default configuration", secondButton: "")
            } else {
                let reply = alert.display(header: "", message: "Are you sure you want to remove \(currentConfig)?", secondButton: "Cancel")
                if reply == "OK" {
                    clearSelected(currentConfig: currentConfig)
                    configuration_Button.removeItem(withTitle: currentConfig)
                    configsDict[currentConfig]          = nil
                    policiesDict[currentConfig]         = nil
                    selectedPoliciesDict[currentConfig] = nil
                    configurationsArray.removeAll(where: { $0 == currentConfig })
                    config_Action("Default")
                }
            }
        }
        clearRemove_Button.selectItem(at: 0)
    }
    private func clearSelected(currentConfig: String) {
        for i in (0..<selectedPoliciesArray.count).reversed() {
            let thePolicy = selectedPoliciesArray[i]
            selectedPoliciesArray.remove(at: i)
            enrollmentActions.remove(at: i)
            selectedPolicies_TableView.reloadData()

            if let _ = Int(thePolicy.id) {
                policiesArray.append(thePolicy)
                policiesDict[currentConfig] = policiesArray
                policies_TableView.reloadData()
                sortPoliciesTableView(theRow: -1)
            }
        }
            
        configsDict[currentConfig] = [:]
        selectedPoliciesDict[currentConfig] = []
        progressText_TextField.stringValue = ""
        validation_TextField.stringValue   = ""
    }
    
    
    @IBAction func config_Action(_ sender: Any) {
//        print("title: \(String(describing: sender.titleOfSelectedItem))")
        var selectedConfiguration = "Default"
        if let _ = sender as? NSPopUpButton {
            selectedConfiguration = (sender as! NSPopUpButton).titleOfSelectedItem!
        } else if let _ = sender as? String {
            selectedConfiguration = sender as! String
        }
        // build enrollmentActions - start
        /*
         var transformedConfig = [String:[Policy]]()
         var policyArray = [Policy]()
         for (theConfig, configInfo) in theDict {
             policyArray.removeAll()
             for theConfigInfo in configInfo {
                 policyArray.append(Policy(name: theConfigInfo["name"] as! String, id: theConfigInfo["id"] as! String, configs: theConfigInfo["configs"] as! [String], grouped: theConfigInfo["grouped"] as! Bool, groupId: theConfigInfo["groupId"] as! String))
             }
             transformedConfig[theConfig] = policyArray
         }
         */
        enrollmentActions.removeAll()
        let currentPolicies = configsDict[configuration_Button.titleOfSelectedItem!]!
        for (policyId, policyInfo) in currentPolicies {
            enrollmentActions.append(EnrollmentActions(name: policyInfo["listitem"]!, id: policyId, icon: policyInfo["icon"]!, label: policyInfo["progresstext"]!, trigger: policyInfo["trigger"]!, command: policyInfo["command"]!, arguments: [], objectType: policyInfo["objectType"]!, timeout: policyInfo["timeout"]!))
        }
        // build enrollmentActions - end
        policiesArray = policiesDict[selectedConfiguration] ?? staticAllPolicies
        selectedPoliciesArray = selectedPoliciesDict[selectedConfiguration] ?? []
        selectedPolicies_TableView.deselectAll(self)
        progressText_TextField.stringValue = ""
        validation_TextField.stringValue   = ""
        policies_TableView.reloadData()
        selectedPolicies_TableView.reloadData()
    }
    
    @IBOutlet weak var policies_TableView: NSTableView!
    @IBOutlet weak var selectedPolicies_TableView: NSTableView!
    @IBAction func group_Action(_ sender: Any) {
        let selectedRows = selectedPolicies_TableView.selectedRowIndexes
        if selectedRows.count > 1 {
            let firstRow = selectedRows.min()
//            var groupMembers = [String]()
            var i = 0
            for theRow in selectedRows {
                let selectedPolicy = selectedPoliciesArray[theRow]
                let theAction      = enrollmentActions[theRow]
                selectedPolicy.grouped = true
                selectedPolicy.groupId = "\(groupNumber)"
//                groupMembers.append(selectedPolicy.id)
                
                configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy.id]?.updateValue("\(selectedPolicy.grouped)", forKey: "grouped")
                configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy.id]?.updateValue("\(groupNumber)", forKey: "groupId")
                
                // put grouped objects together
                selectedPoliciesArray.remove(at: theRow)
                selectedPoliciesArray.insert(selectedPolicy, at: firstRow!+i)
                enrollmentActions.remove(at: theRow)
                enrollmentActions.insert(theAction, at: firstRow!+i)
                i += 1
                                
            }
//            groupsDict[configuration_Button.titleOfSelectedItem!] = ["\(groupNumber)":groupMembers]
            groupNumber += 1
            selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray
            selectedPolicies_TableView.reloadData()
            selectedPolicies_TableView.selectRowIndexes(IndexSet(integer: firstRow!), byExtendingSelection: false)
        } else {
            _ = alert.display(header: "Attention:", message: "At least 2 policies must be selected", secondButton: "")
        }
    }
    
    @IBAction func refresh_Action(_ sender: Any) {
        sendLoginInfo(loginInfo: (JamfProServer.destination, JamfProServer.username, JamfProServer.userpass,saveCredsState))
    }
    
    
    @IBAction func selectValidation_Action(_ sender: Any) {
        
        let dialog = NSOpenPanel()

        dialog.title                   = "Select an item for the validation criteria";
        dialog.directoryURL            = URL(string: "/Applications")
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.allowsMultipleSelection = false
        dialog.canChooseFiles          = true
        dialog.canChooseDirectories    = true
        dialog.resolvesAliases         = true
        dialog.treatsFilePackagesAsDirectories = false

        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            if (result != nil) {
                if result!.path.suffix(4) == ".app" && NSEvent.modifierFlags.contains(.option) {
                    viewAppBundle(appBundleURL: result!)
                } else {
                    validation_TextField.stringValue = "\(result!.path)"
                    updateValidation(validationString: validation_TextField.stringValue)
                }
            }
        }
    }
    private func viewAppBundle(appBundleURL: URL) {
        let dialog = NSOpenPanel()

        dialog.title                   = "Select an item for the validation criteria";
        dialog.directoryURL            = appBundleURL
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.allowsMultipleSelection = false
        dialog.canChooseFiles          = true
        dialog.canChooseDirectories    = true
        dialog.resolvesAliases         = true
        dialog.treatsFilePackagesAsDirectories = false

        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            if (result != nil) {
                validation_TextField.stringValue = "\(result!.path)"
                updateValidation(validationString: validation_TextField.stringValue)
            }
        }
    }
    func updateValidation(validationString: String) {
        let theRow = selectedPolicies_TableView.selectedRow
        let policyId = selectedPoliciesArray[theRow].id
        policy_array_dict[policyId]?.updateValue(validationString, forKey: "validation")
        configsDict[configuration_Button.titleOfSelectedItem!]![policyId]?.updateValue(validationString, forKey: "validation")

        // needed? todo
        let selectedPolicyIndex = enrollmentActions.firstIndex(where: { $0.id == policyId })
        enrollmentActions[selectedPolicyIndex!].command = validationString
    }
    
    @IBAction func showSettings(_ sender: Any) {
        if NSEvent.modifierFlags.contains(.option) {
//            isDir = true
            let settingsFolder = AppInfo.appSupport
            if (FileManager.default.fileExists(atPath: settingsFolder)) {
//                NSWorkspace.shared.openFile(settingsFolder)
                NSWorkspace.shared.open(URL(fileURLWithPath: settingsFolder))
            } else {
                _ = alert.display(header: "Alert", message: "Unable to open \(settingsFolder)", secondButton: "")
            }
        } else {
            performSegue(withIdentifier: "settings", sender: nil)
        }
    }
    
    @IBOutlet weak var allPolicies_Spinner: NSProgressIndicator!
    @IBOutlet weak var policyArray_Spinner: NSProgressIndicator!
    
    @IBOutlet weak var progressText_TextField: NSTextField!
    @IBOutlet weak var validation_Label: NSTextField!
    @IBOutlet weak var validation_TextField: NSTextField!
    
    var policiesArray = [Policy]()
    var policiesDict  = [String:[Policy]]()
    var staticAllPolicies = [Policy]()
    var selectedPoliciesArray = [Policy]()
    var selectedPoliciesDict  = [String:[Policy]]()
    
    // remove policy_array_dict? - todo
    var policy_array_dict = [String:[String:String]]()      // [policy id: [attribute: value]]]
    var enrollmentActions = [EnrollmentActions]()
    var configsDict = [String:[String:[String:String]]]()   // [config name: [policy id: [attribute: value]]]
//    var groupsDict  = [String:[String:[String]]]()          // [config name: [group id: [members]]]
    var configurationsArray = [String]()
    var policy_array = ""
    var saveCredsState = 0
    
    var saveInfo     = [String:Any]()
//    var settingsDict = [String:Any]()
    
    @IBOutlet weak var generateScript_Button: NSButton!
    //    var policyArray:[String]?    // array of policies to add to SYM
    @IBOutlet weak var addOther_Button: NSPopUpButton!
    
    @IBAction func addOther_Action(_ sender: NSPopUpButton) {
        performSegue(withIdentifier: "addOther", sender: nil)
    }
    
    // selectors - start
    @objc func addNewSelector() {
        performSegue(withIdentifier: "addNewConfig", sender: nil)
    }
    @objc func cloneExistingSelector() {
        performSegue(withIdentifier: "cloneExistingConfig", sender: nil)
    }
    @objc func addToPolicyArray() {
        let rowClicked = policies_TableView.clickedRow
//        let doubleClicked = policiesArray[rowClicked]
        
        if rowClicked < policiesArray.count && rowClicked != -1 {
//            print("[addToPolicyArray] policiesArray: \(policiesArray[rowClicked].name)")
            let doubleClicked = policiesArray[rowClicked]

            selectedPoliciesArray.append(doubleClicked)
            selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray

            selectedPoliciesArray.last!.configs.append(configuration_Button.titleOfSelectedItem!)

            getPolicy(id: doubleClicked.id) { [self]
                (result: String) in
                updatePoliciesDict(xml: result, policyId: doubleClicked.id, grouped: doubleClicked.grouped, groupId: doubleClicked.groupId)
                policiesArray.remove(at: rowClicked)
                policiesDict[configuration_Button.titleOfSelectedItem!] = policiesArray
                
                policies_TableView.reloadData()
                selectedPolicies_TableView.reloadData()
            }
            
            progressText_TextField.stringValue = ""
            validation_TextField.stringValue   = ""
        }
    }
    @objc func removeFromPolicyArray() {
        if selectedPolicies_TableView.clickedRow != -1 {
            var doubleClickedRow = selectedPolicies_TableView.clickedRow

            let doubleClicked = selectedPoliciesArray[doubleClickedRow]
//            doubleClicked.isSelected = false
            // get groupId if present
            var groupMembers = [Int]()
            let theGroupId = doubleClicked.groupId
            if let _ = Int(theGroupId) {
                for i in 0..<selectedPoliciesArray.count {
                    if selectedPoliciesArray[i].groupId == theGroupId {
                        groupMembers.append(i)
                    }
                }
                if groupMembers.count < 3 {
                    for thePolicyIndex in groupMembers {
                        selectedPoliciesArray[thePolicyIndex].grouped = false
                        selectedPoliciesArray[thePolicyIndex].groupId = ""
                    }
                } else {
                    doubleClicked.grouped = false
                    doubleClicked.groupId = ""
                }
            }
                        
            configsDict[configuration_Button.titleOfSelectedItem!]![doubleClicked.id] = nil

            selectedPoliciesArray.remove(at: doubleClickedRow)
            enrollmentActions.remove(at: doubleClickedRow)
            
            progressText_TextField.stringValue = ""
            validation_TextField.stringValue   = ""
            
            selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray

//            doubleClickedRow = (doubleClickedRow > selectedPoliciesArray.count-1) ? doubleClickedRow-1:doubleClickedRow
//            if selectedPoliciesArray.count > 0 {
//                selectedPolicies_TableView.selectRowIndexes(IndexSet(integer: doubleClickedRow), byExtendingSelection: false)
//                let selectedPolicy = selectedPoliciesArray[doubleClickedRow].id
//
//                progressText_TextField.stringValue = "\(enrollmentActions[doubleClickedRow].label ?? "Processing policy \(String(describing: enrollmentActions[doubleClickedRow].name))")"
//                validation_TextField.stringValue = "\(enrollmentActions[doubleClickedRow].command ?? "")"
//            }
            selectedPolicies_TableView.reloadData()
            if let _ = Int(doubleClicked.id) {
                policiesArray.append(doubleClicked)
                policiesDict[configuration_Button.titleOfSelectedItem!] = policiesArray
                policies_TableView.reloadData()
//                sortPoliciesTableView(theRow: doubleClickedRow)
                sortPoliciesTableView(theRow: -1)
            }
        }
    }
    // selectors - end
    
    @IBAction func generateScript_Action(_ sender: Any) {
//        var id = ""
        generateScript_Button.isEnabled = false
        let whichConfig = configuration_Button.titleOfSelectedItem
        var idArray = [[String]]()
        var selectedPolicy: Policy?
        var i = 0
//        for selectedPolicy in selectedPoliciesArray {
        while i < selectedPoliciesArray.count {
            selectedPolicy = selectedPoliciesArray[i]
//            print("is group member: \(selectedPolicy!.grouped)")
//            print("id: \(id.replacingOccurrences(of: ")", with: ""))")
            if selectedPolicy!.grouped {
                var groupArray = [String]()
                while selectedPolicy!.grouped {
                    groupArray.append(selectedPolicy!.id)
                    i += 1
                    if i < selectedPoliciesArray.count {
                        selectedPolicy = selectedPoliciesArray[i]
                    } else {
                        break
                    }
                }
                idArray.append(groupArray)
            } else {
                idArray.append([selectedPolicy!.id])
                i += 1
            }
        }
        if idArray.count > 0 {
            policyArray_Spinner.maxValue = Double(idArray.count-1)
            policyArray_Spinner.startAnimation(self)
            policyArray_Spinner.isHidden = false
            processPolicies(whichId: 0, theConfigIndex: 0)
        } else {
            generateScript_Button.isEnabled = true
        }
    }
    
    private func updatePoliciesDict(xml: String, policyId: String, grouped: Bool, groupId: String) {
        
        let general = betweenTags(xmlString: xml, startTag: "<general>", endTag: "</general>")
//                let policyId = betweenTags(xmlString: general, startTag: "<id>", endTag: "</id>")
        let policyName = betweenTags(xmlString: general, startTag: "<name>", endTag: "</name>")
        let self_service = betweenTags(xmlString: xml, startTag: "<self_service>", endTag: "</self_service>")
        var icon = betweenTags(xmlString: self_service, startTag: "<uri>", endTag: "</uri>")
        icon = icon.replacingOccurrences(of: "https://ics.services.jamfcloud.com/icon/hash_", with: "")
        var progresstext = betweenTags(xmlString: self_service, startTag: "<self_service_description>", endTag: "</self_service_description>")
        progresstext = progresstext.xmlDecode
        if progresstext == "" {
            progresstext = "Processing policy: \(String(describing: policyName))"
        }
        var customTrigger = betweenTags(xmlString: general, startTag: "<trigger_other>", endTag: "</trigger_other>")
            // set custom trigger to policy id
            let updateXml = """
<?xml version="1.0" encoding="UTF-8"?>
    <policy>
        <general>
          <trigger_other>\(policyId)</trigger_other>
        </general>
    </policy>
"""
        updatePolicyCustomeTrigger(xml: updateXml, id: policyId, customTrigger: customTrigger) { [self]
                (result: String) in
                customTrigger = result
//            progressText_TextField.stringValue = progresstext
            let validation = ( validation_TextField.stringValue == "" ) ? "None":validation_TextField.stringValue
                
            policy_array_dict[policyId] = ["listitem": policyName, "icon": icon, "progresstext": progresstext, "trigger": customTrigger, "validation": validation]
            configsDict[configuration_Button.titleOfSelectedItem!]![policyId] = ["listitem": policyName, "id": policyId, "icon": icon, "progresstext": progresstext, "trigger": customTrigger, "validation": validation, "command": "", "arguments": "", "objectType": "policy", "timeout": "", "grouped": "\(grouped)", "groupId": "\(groupId)"]
            
            // command same as validation? todo
            enrollmentActions.append(EnrollmentActions(name: policyName, id: policyId, icon: icon, label: progresstext, trigger: customTrigger, command: "", arguments: [], objectType: "policy", timeout: ""))
            }
//        let trigger = (customTrigger == "recon") ? customTrigger:policyId
        
    }
    
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let whichField = obj.object as? NSTextField {
            let theRow = selectedPolicies_TableView.selectedRow
            if theRow != -1 {
                let selectedPolicyId = selectedPoliciesArray[theRow].id
                switch whichField.identifier!.rawValue {
                    //            case "icon_TextField":
                    //                policy_array_dict[selectedPolicyId]!["icon"] = icon_TextField.stringValue
//                    enrollmentActions[theRow].icon = icon_TextField.stringValue
                case "progressText_TextField":
//                    policy_array_dict[selectedPolicyId]!["progresstext"] = progressText_TextField.stringValue
                    configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["progresstext"] = progressText_TextField.stringValue
                    enrollmentActions[theRow].label = progressText_TextField.stringValue
                case "validation_TextField":
//                    policy_array_dict[selectedPolicyId]!["thePath"] = validation_TextField.stringValue
                    configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["validation"] = validation_TextField.stringValue
                    enrollmentActions[theRow].command = validation_TextField.stringValue

                default:
                    break
                }
            }
        }
    }
    
    private func updatePolicyCustomeTrigger(xml: String, id: String, customTrigger: String, completion: @escaping (_ result: String) -> Void ) {
        if customTrigger != "" {
            completion(customTrigger)
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var policyUrlString = "\(JamfProServer.destination)/JSSResource/policies/id/\(id)"
        policyUrlString = policyUrlString.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
        policyUrlString = policyUrlString.replacingOccurrences(of: "/?failover", with: "")
        let policyUrl      = URL(string: policyUrlString)
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: policyUrl!)
        request.httpMethod = "PUT"
        request.httpBody   = xml.data(using: String.Encoding.utf8)

        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.authCreds)", "Content-Type" : "application/xml", "Accept" : "application/xml", "User-Agent" : AppInfo.userAgentHeader]
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                writeToLog.message(stringOfText: "[updatePolicy] A custom trigger of \"\(id)\" has been added to policy id \(id).")
                if httpSuccess.contains(httpResponse.statusCode) {
                    completion(id)
                    return
                } else {
                    writeToLog.message(stringOfText: "[updatePolicy] No data was returned trying to set the custom trigger.  Verify/edit the custome trigger \"\(id)\" on the server manually.")
                }
            } else {
                print("could not read response or no response")
            }
            writeToLog.message(stringOfText: "[updatePolicy] No data was returned trying to set the custom trigger.  Verify/edit the custome trigger \"\(id)\" on the server manually.")
            completion(id)
        })
        task.resume()
    }
    
    private func processPolicies(id: [[String]] = [], whichId: Int, theConfigIndex: Int) {
        
        // move the default config to the end of the array
        if let index = configurationsArray.firstIndex(of: "Default") {
            configurationsArray.remove(at: index)
            configurationsArray.append("Default")
        } else {
            _ = alert.display(header: "Attention:", message: "'Default' configuration must be defined.", secondButton: "")
            policyArray_Spinner.isHidden = true
            generateScript_Button.isEnabled = true
            return
        }

        var configCases = ""
        
        for theConfig in configurationsArray {
            let configDetails = configsDict[theConfig]!
            if theConfig == "Default" && configDetails.count == 0 {
                _ = alert.display(header: "Attention:", message: "'Default' configuration must be defined.", secondButton: "")
                policyArray_Spinner.isHidden = true
                generateScript_Button.isEnabled = true
                return
            }
            if selectedPoliciesDict[theConfig]?.count ?? 0 > 0 {
                var firstPolicy = true
                policy_array = ""
                var i = 0
//                print("selectedPoliciesDict[theConfig]: \(selectedPoliciesDict[theConfig])")
                while i < selectedPoliciesDict[theConfig]!.count {
//                    print("item \(i): \(selectedPoliciesDict[theConfig]![i].id)")
//
                    let thePolicy = selectedPoliciesDict[theConfig]![i]
                    var policyId = selectedPoliciesDict[theConfig]![i].id
                    
//                    print("[processPolicies] configsDict[\(theConfig)]!: \(configsDict[theConfig]!)")
                    
                   let result = configsDict[theConfig]![policyId]!
//                   print("[processPolicies] result: \(result)")
                    
                    
                    let policyName = result["listitem"]
                    let icon = result["icon"]
                    let progresstext = result["progresstext"]
                    var customTrigger = result["trigger"]
                    var validation = result["validation"] ?? ""
                    
                    var isGrouped = result["grouped"]
                    let theGroupId = result["groupId"]
                    var newGroupId = theGroupId
                    
                    var triggerListArray = """
             {
                                            "trigger": "\(customTrigger!)",
                                            "validation": "\(validation)"
                                         }
"""
                    while isGrouped == "true" && theGroupId == newGroupId {
                        i += 1
                        if i < selectedPoliciesDict[theConfig]!.count {
                            policyId = selectedPoliciesDict[theConfig]![i].id
                        } else {
                            break
                        }

                        let result = configsDict[theConfig]![policyId]!
//                        print("[processPolicies-group] result: \(result)")
                        
                        customTrigger = result["trigger"]
                        validation = result["validation"] ?? ""
                        
                        isGrouped = result["grouped"]
                        newGroupId = result["groupId"]
                        
                        if theGroupId == newGroupId {
                            triggerListArray.append("""
,
                                         {
                                            "trigger": "\(customTrigger!)",
                                            "validation": "\(validation)"
                                         }
""")
                        } else {
                            i -= 1
                            break
                        }
                    }
                    
                    policyArray_Spinner.increment(by: 1.0)
                    usleep(1000)
                
                    if firstPolicy {
                        policy_array.append("\n")
                        firstPolicy = false
                    } else {
                        policy_array.append(",\n")
                    }
                    policy_array.append("""
                        {
                            "listitem": "\(String(describing: policyName!))",
                            "icon": "\(String(describing: icon!))",
                            "progresstext": "\(progresstext ?? "Processing policy \(String(describing: policyName!))")",
                            "trigger_list": [
                                \(triggerListArray)
                            ]
                        }
    """)
                    i += 1
                }   // for (policyId, _) in configDetails - end
                if configDetails.count > 0 {
                    // close off the policy array and generate script
                    
                    let whichConfig = (theConfig == "Default") ? "* ) # Catch-all":"\"\(theConfig)\""
                    policy_array = """
        \(whichConfig) )

                policyJSON='
                {
                    "steps": [
            \(policy_array)
                    ]
                }
                '
                ;;\n\n
    """
                    configCases.append(policy_array)
                }   // if configDetails.count > 0 - end
            }
        }   // for theConfig in configurationsArray - end
        var finalScript = ""
        
        setPrompt(whichPrompt: "promptForUsername")
        setPrompt(whichPrompt: "prefillUsername")
        setPrompt(whichPrompt: "promptForRealName")
        setPrompt(whichPrompt: "prefillRealname")
        setPrompt(whichPrompt: "promptForEmail")
        setPrompt(whichPrompt: "promptForComputerName")
        setPrompt(whichPrompt: "promptForAssetTag")
        setPrompt(whichPrompt: "promptForRoom")
        setPrompt(whichPrompt: "promptForBuilding")
        setPrompt(whichPrompt: "promptForDepartment")
        setPrompt(whichPrompt: "promptForConfiguration")
        setPrompt(whichPrompt: "moveableInProduction")
        
        setLocation(type: "buildingsListRaw")
        setLocation(type: "departmentListRaw")
        
        // write out configurations
        let policy_array_regex = try! NSRegularExpression(pattern: "case \\$\\{symConfiguration\\} in(.|\n|\r)*?esac", options:.caseInsensitive)
        finalScript = policy_array_regex.stringByReplacingMatches(in: symScript, range: NSRange(0..<symScript.utf16.count), withTemplate: "case \\$\\{symConfiguration\\} in\n\n    \(configCases)    esac")
        
        policyArray_Spinner.isHidden = true
        
        // fix - don't save until we've hit all configs
        let saveDialog = NSSavePanel()
        saveDialog.canCreateDirectories = true
        saveDialog.nameFieldStringValue = "Setup-Your-Mac.bash"
        saveDialog.beginSheetModal(for: self.view.window!){ result in
            if result == .OK {
                let scriptName = saveDialog.nameFieldStringValue
                let exportURL            = saveDialog.url!
//                print("fileName", scriptName)
                
                do {
                    try "\(finalScript)".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write script to \(exportURL.path)")
                }
                    
                // copy to clipboard
//                    do {
//                        let manifest = try String(contentsOf: exportURL)
//    //                    print("manifest: \(manifest)")
//                        // copy manifest to clipboard - start
//                        let clipboard = NSPasteboard.general
//                        clipboard.clearContents()
//                        clipboard.setString(manifest, forType: .string)
//                        // copy manifest to clipboard - end
//                    } catch {
//                        print("file not found.")
//                    }

            }
        }
        generateScript_Button.isEnabled = true
    }
    
    private func setPrompt(whichPrompt: String) {
        let regex = try! NSRegularExpression(pattern: "\(whichPrompt)=\".*?\"")
        symScript = (regex.stringByReplacingMatches(in: symScript, range: NSRange(0..<symScript.utf16.count), withTemplate: "\(whichPrompt)=\"\(Settings.shared.dict["\(whichPrompt)"] ?? "true")\""))
    }
    private func setLocation(type: String) {
        let regex = try! NSRegularExpression(pattern: "\(type)=\".*?\"", options:.caseInsensitive)
        symScript = (regex.stringByReplacingMatches(in: symScript, range: NSRange(0..<symScript.utf16.count), withTemplate: "\(type)=\"\(Settings.shared.dict["\(type)"] ?? "")\""))
    }
    
    // Delegate Method
    func sendLoginInfo(loginInfo: (String,String,String,Int)) {
        
        var saveCredsState: Int?
        (JamfProServer.destination, JamfProServer.username, JamfProServer.userpass,saveCredsState) = loginInfo
        let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.userpass)".data(using: String.Encoding.utf8)
        JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!

        writeToLog.message(stringOfText: "[ViewController] Running SYM-Helper v\(AppInfo.version)")
        TokenDelegate().getToken(whichServer: "destination", serverUrl: JamfProServer.destination, base64creds: JamfProServer.base64Creds) { [self]
            authResult in
            let (statusCode,theResult) = authResult
            if theResult == "success" {
                defaults.set(JamfProServer.destination, forKey: "server")
                defaults.set(JamfProServer.username, forKey: "username")
                if saveCredsState == 1 {
                    Credentials().save(service: "sym-helper-\(JamfProServer.destination.fqdnFromUrl)", account: JamfProServer.username, data: JamfProServer.userpass)
                }
                let lastChar = "\(JamfProServer.destination)".last
                connectedTo_TextField.stringValue = ( JamfProServer.destination.last == "/" ) ? String("Connected to: \(JamfProServer.destination)".dropLast()):"Connected to: \(JamfProServer.destination)"
                scriptSource = defaults.string(forKey: "scriptSource") ?? defaultScriptSource
                
                // read settings, if they exist
                Settings.shared.dict = ConfigsSettings().retrieve(dataType: "settings")
                
//                var scriptSource = settingsDict["scriptSource"] as? String ?? defaultScriptSource
                var scriptSource = Settings.shared.dict["scriptSource"] as? String ?? defaultScriptSource
                if scriptSource == "" { scriptSource = defaultScriptSource }
                print("fetch script from: \(scriptSource)")
                SYMScript().get(scriptURL: scriptSource) { [self]
                    (result: String) in
                    symScript = result
//                    print("getScript: \(symScript)")
                    
                    if !symScript.contains("# Setup Your Mac via swiftDialog") || !symScript.contains("# https://snelson.us/sym") {
                        _ = alert.display(header: "Attention:", message: "Set-Up-Your-Mac script was not found.  Verify the server URL listed in Settings.", secondButton: "")
                        allPolicies_Spinner.stopAnimation(self)
//                        return
                    }
                    
                    getAllPolicies() { [self]
                        (result: [String:Any]) in
                        let allPolicies = result["policies"] as! [[String:Any]]
//                        print("all policies: \(allPolicies)")
                        if allPolicies.count > 0 {
                            for i in 0..<allPolicies.count {
                                let aPolicy = allPolicies[i] as [String:Any]
//                                print("aPolicy: \(aPolicy)")
                                
                                if let policyName = aPolicy["name"] as? String, let policyId = aPolicy["id"] as? Int {
//                                    print("\(policyName) (\(policyId))")
                                    // filter out policies created from casper remote - start
                                    if policyName.range(of:"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] at", options: .regularExpression) == nil {
                                        policiesArray.append(Policy(name: "\(policyName) (\(policyId))", id: "\(policyId)", configs: [], grouped: false, groupId: ""))
                                    }
                                    // filter out policies created from casper remote - end
                                }
                            }
                            // sort policies - to do
//                            policies_ArrayController.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                            staticAllPolicies = policiesArray
                            policies_TableView.reloadData()
                            allPolicies_Spinner.stopAnimation(self)
                            
                            
                            // create app support path if not present
                            if !FileManager.default.fileExists(atPath: AppInfo.appSupport) {
                                do {
                                    try FileManager.default.createDirectory(atPath: AppInfo.appSupport, withIntermediateDirectories: true)
                                } catch {
                                    _ = alert.display(header: "Attention:", message: "Unable to create '\(AppInfo.appSupport)'.  Configurations will not be saved.", secondButton: "")
                                }
                            } else {
                                // look for existing configs
                                let existingConfigsDict = ConfigsSettings().retrieve(dataType: "configs")
                                
                                configurationsArray =  existingConfigsDict["configurationsArray"] as? [String] ?? []
//                                print("available configs: \(configurationsArray)")
                                
                                
                                // set the configurations button - start
                                configuration_Menu.removeAllItems()
                                var validatedConfigs = [String]()
                                
                                let cd = existingConfigsDict["configsDict"] as? [String:Any] ?? [:]
                                let pd = existingConfigsDict["policiesDict"] as? [String:Any] ?? [:]
                                let spd = existingConfigsDict["selectedPoliciesDict"] as? [String:Any] ?? [:]
                                
                                // make sure Default configureation is listed
                                if configurationsArray.firstIndex(of: "Default") == nil { configurationsArray.append("Default") }
                                
                                for theConfig in configurationsArray.sorted() {
//                                    print("spd[\(theConfig)]: \(String(describing: (spd[theConfig] as? [[String:Any]])?.count))")
//                                    if (spd[theConfig] as? [[String:Any]])?.count ?? 0 > 0 || theConfig == "Default" {
                                        configuration_Menu.addItem(NSMenuItem(title: theConfig, action: nil, keyEquivalent: ""))
                                        validatedConfigs.append(theConfig)
//                                    }
                                }
                                configurationsArray = validatedConfigs
                                
                                let lastWorkingConfig = existingConfigsDict["currentConfig"] ?? "Default"
                                configuration_Button.selectItem(withTitle: "\(String(describing: lastWorkingConfig))")
                                configuration_Menu.addItem(.separator())
                                configuration_Menu.addItem(NSMenuItem(title: "Add New...", action: #selector(addNewSelector), keyEquivalent: ""))
                                configuration_Menu.addItem(NSMenuItem(title: "Clone Existing...", action: #selector(cloneExistingSelector), keyEquivalent: ""))
                                // set the configurations button - end
                                
                                // reload configurations settings - start
                                if let _ = existingConfigsDict["configsDict"] {
                                    configsDict = existingConfigsDict["configsDict"] as! [String:[String:[String:String]]]
                                    
                                    let policiesDictSave         = existingConfigsDict["policiesDict"] as! [String:[[String:Any]]]
                                    let selectedPoliciesDictSave = existingConfigsDict["selectedPoliciesDict"] as! [String:[[String:Any]]]
                                    
                                    policiesDict         = dictToClass(theDict: policiesDictSave)
                                    selectedPoliciesDict = dictToClass(theDict: selectedPoliciesDictSave)
                                }
                                
                                config_Action(existingConfigsDict["currentConfig"] ?? "Default")
//
                            }
                        }
                    }
                    
                }
            } else {
                DispatchQueue.main.async { [self] in
                    writeToLog.message(stringOfText: "Failed to authenticate, status code: \(statusCode)")
                    performSegue(withIdentifier: "loginView", sender: nil)
//                        working(isWorking: false)
                }
            }
        }
        
    }
    func dictToClass(theDict: [String:[[String:Any]]]) -> [String:[Policy]] {
        // selectedPoliciesArray.append(Policy(name: theLabel, id: theId, configs: [configuration_Button.titleOfSelectedItem!], grouped: false, groupId: ""))
        var transformedConfig = [String:[Policy]]()
        var policyArray = [Policy]()
        for (theConfig, configInfo) in theDict {
            policyArray.removeAll()
            for theConfigInfo in configInfo {
                policyArray.append(Policy(name: theConfigInfo["name"] as! String, id: theConfigInfo["id"] as! String, configs: theConfigInfo["configs"] as! [String], grouped: theConfigInfo["grouped"] as! Bool, groupId: theConfigInfo["groupId"] as! String))
            }
            transformedConfig[theConfig] = policyArray
        }
        return transformedConfig
    }
    
    func sendClonedConfigInfo(newConfig: String, existingConfig: String) {
//        print("[sendClonedConfigInfo] newConfig: \(newConfig)     existingConfig: \(existingConfig)")
        configuration_Menu.removeAllItems()
        configurationsArray.append(newConfig)
        for theConfig in configurationsArray.sorted() {
            configuration_Menu.addItem(NSMenuItem(title: theConfig, action: nil, keyEquivalent: ""))
        }
        configuration_Button.selectItem(withTitle: newConfig)
        configuration_Menu.addItem(.separator())
        configuration_Menu.addItem(NSMenuItem(title: "Add New...", action: #selector(addNewSelector), keyEquivalent: ""))
        configuration_Menu.addItem(NSMenuItem(title: "Clone Existing...", action: #selector(cloneExistingSelector), keyEquivalent: ""))
        configsDict[newConfig]          = configsDict[existingConfig]
        policiesDict[newConfig]         = policiesDict[existingConfig] ?? staticAllPolicies
        selectedPoliciesDict[newConfig] = selectedPoliciesDict[existingConfig] ?? []
        config_Action(existingConfig)
//        print("existing config \(existingConfig): \(String(describing: configsDict[existingConfig]))")
        
        
    }
    func sendNewConfigInfo(newConfig: String) {
//        print("[sendNewConfigInfo] newConfig: \(newConfig)")
        
        configuration_Menu.removeAllItems()
        configurationsArray.append(newConfig)
        for theConfig in configurationsArray.sorted() {
            configuration_Menu.addItem(NSMenuItem(title: theConfig, action: nil, keyEquivalent: ""))
        }
        configuration_Menu.addItem(.separator())
        configuration_Menu.addItem(NSMenuItem(title: "Add New...", action: #selector(addNewSelector), keyEquivalent: ""))
        configuration_Menu.addItem(NSMenuItem(title: "Clone Existing...", action: #selector(cloneExistingSelector), keyEquivalent: ""))
        configuration_Button.selectItem(withTitle: newConfig)
        configsDict[newConfig]          = [:]
        policiesDict[newConfig]         = staticAllPolicies
        selectedPoliciesDict[newConfig] = []
        enrollmentActions.removeAll()
        config_Action(newConfig)
    }
    
    // Delegate Method - Other
    func sendOtherItem(newItem: [String:String]) {
//        print("command: \(newItem)")
//        print("selected policy index: \(selectedPolicies_TableView.selectedRow)")
        
        if newItem["itemType"] == " Local Validation" {
            // add local validation
//            print("add local validation: \(newItem)")
            
            let theId = "\(UUID())"
            let theName = "Local Validation - \(String(describing: newItem["trigger"]!))"
            selectedPoliciesArray.append(Policy(name: theName, id: "\(theId)", configs: [configuration_Button.titleOfSelectedItem!], grouped: false, groupId: ""))
            selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray
            
            configsDict[configuration_Button.titleOfSelectedItem!]![theId] = ["listitem": "", "id": theId, "icon": "", "progresstext": "", "trigger": newItem["trigger"]!, "validation": "Local", "command": "", "arguments": "", "objectType": "Local Validation", "timeout": "", "grouped": "false", "groupId": ""]
            
            enrollmentActions.append(EnrollmentActions(name: theName, id: theId, icon: "", label: theName, trigger: "", command: "", arguments: [], objectType: "Local Validation", timeout: ""))

            selectedPoliciesArray.last!.configs.append(configuration_Button.titleOfSelectedItem!)
            selectedPolicies_TableView.reloadData()
            
        } else {
            // add new command
            if let commandToArray = newItem["command"]?.components(separatedBy: " ") {
                let theLabel = newItem["label"] ?? "shell script"
                let theId    = "\(UUID())"
                progressText_TextField.stringValue = theLabel
    //             thePath_TextField.stringValue = newItem["command"] ?? ""
                 let icon = newItem["icon"] ?? "system:clock"
    //             icon_TextField.stringValue = icon
                 
                 var argumentArray = [String]()
                 for i in 1..<commandToArray.count {
                     argumentArray.append(commandToArray[i])
                 }
                
                selectedPoliciesArray.append(Policy(name: theLabel, id: theId, configs: [configuration_Button.titleOfSelectedItem!], grouped: false, groupId: ""))
                selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray
                selectedPoliciesArray.last!.configs.append(configuration_Button.titleOfSelectedItem!)
                
                policy_array_dict[theId] = ["listitem": theLabel, "icon": icon, "progresstext": theLabel, "trigger": "", "thePath": newItem["command"] ?? ""]
                
                configsDict[configuration_Button.titleOfSelectedItem!]![theId] = ["listitem": theLabel, "id": theId, "icon": icon, "progresstext": theLabel, "trigger": "", "validation": "None", "command": newItem["command"]!, "objectType": "command", "timeout": "", "grouped": "", "groupId": ""]
                
                enrollmentActions.append(EnrollmentActions(name: theLabel, id: theId, icon: icon, label: theLabel, trigger: "", command: commandToArray[0], arguments: argumentArray, objectType: "command", timeout: ""))
                 
                selectedPolicies_TableView.reloadData()
                 
             } else {
                 writeToLog.message(stringOfText: "[sendCommand] Unable to add command: \(newItem).")
             }
        }

        
    }
        
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "loginView" {
            let loginVC: LoginVC = segue.destinationController as! LoginVC
            loginVC.delegate = self
            loginVC.uploadsComplete = false
        } else if segue.identifier == "addNewConfig" {
            let newConfigVC: NewConfigVC = segue.destinationController as! NewConfigVC
            newConfigVC.delegate = self
            newConfigVC.currentConfigs = configurationsArray
        } else if segue.identifier == "cloneExistingConfig" {
            let cloneConfigVC: CloneConfigVC = segue.destinationController as! CloneConfigVC
            cloneConfigVC.delegate = self
            cloneConfigVC.currentConfigs = configurationsArray
        } else if segue.identifier == "addOther" {
            let otherItemVC: OtherItemVC = segue.destinationController as! OtherItemVC
            otherItemVC.delegate = self
            otherItemVC.itemType = addOther_Button.selectedItem!.title
        } else if segue.identifier == "settings" {
            let settingsVC: SettingsVC = segue.destinationController as! SettingsVC
//            settingsVC.delegate = self
            settingsVC.currentConfig = configuration_Button.titleOfSelectedItem!
//            settingsVC.settingsDict = Settings.shared.dict
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // initialize configDict for each config
        for i in 0..<configuration_Button.numberOfItems {
            configuration_Button.selectItem(at: i)
            let theConfig = configuration_Button.titleOfSelectedItem!
            if theConfig != "" && theConfig != "Add New..." && theConfig != "Clone Existing..." {
                configurationsArray.append(theConfig)
                configsDict[theConfig] = [:]
            }
        }
        
//        icon_TextField.delegate         = self
        progressText_TextField.delegate = self
        validation_TextField.delegate   = self
        
        allPolicies_Spinner.startAnimation(self)
        policies_TableView.delegate = self
        policies_TableView.dataSource = self
        policies_TableView.doubleAction = #selector(addToPolicyArray)
        
        policies_TableView.tableColumns.forEach { (column) in
            column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 16)])
        }
        let descriptorName = NSSortDescriptor(key: "name", ascending: true)
        policies_TableView.tableColumns[0].sortDescriptorPrototype = descriptorName
        
        selectedPolicies_TableView.delegate = self
        selectedPolicies_TableView.dataSource = self
        selectedPolicies_TableView.doubleAction = #selector(removeFromPolicyArray)
        
        selectedPolicies_TableView.tableColumns.forEach { (column) in
            column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 16)])
        }
        
        selectedPolicies_TableView.registerForDraggedTypes([.string])
        
        configuration_Button.selectItem(at: 0)

    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if showLoginWindow {
            performSegue(withIdentifier: "loginView", sender: nil)
            showLoginWindow = false
        }
    }
    
    func policyClasstoDict(toConvert: [String:[Policy]]) -> [String:[[String:Any]]] {
        var classToDict = [String:[[String:Any]]]()
        var policyArray = [[String:Any]]()
        for (configName, policies) in toConvert {
            for thePolicy in policies {
                policyArray.append(["name": thePolicy.name, "id": thePolicy.id, "configs": thePolicy.configs, "grouped": thePolicy.grouped, "groupId": thePolicy.groupId])
            }
            classToDict[configName] = policyArray
            policyArray.removeAll()
        }
        return classToDict
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        let theServer = JamfProServer.destination.fqdnFromUrl
        saveInfo["theServer"]            = theServer as Any
        saveInfo["currentConfig"]        = configuration_Button.titleOfSelectedItem! as Any
        saveInfo["configurationsArray"]  = configurationsArray as Any
        saveInfo["configsDict"]          = configsDict as Any
        
        let policiesDictSave         = policyClasstoDict(toConvert: policiesDict)
        let selectedPoliciesDictSave = policyClasstoDict(toConvert: selectedPoliciesDict)
        saveInfo["policiesDict"]         = policiesDictSave as Any
        saveInfo["selectedPoliciesDict"] = selectedPoliciesDictSave as Any

        ConfigsSettings().save(theServer: theServer, dataType: "configs", data: saveInfo)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    private func getAllPolicies(completion: @escaping (_ result: [String:Any]) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        
        var endpoint = "\(JamfProServer.destination)/JSSResource/policies"
        endpoint = endpoint.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
//        endpoint = endpoint.replacingOccurrences(of: "/?failover", with: "")
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
                   print("policy statusCode: \(httpResponse.statusCode)")
                   
                    let responseData = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                       if let endpointJSON = responseData! as? [String: Any] {
                           completion(endpointJSON)
                           return
                       } else {
                           writeToLog.message(stringOfText: "\n[getScript] No data was returned from post/put.")
                       }
               }
           } else {
               print("could not read response or no response")
           }
           completion([:])
        })
    task.resume()
    }
    
    private func getPolicy(id: String, completion: @escaping (_ result: String) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        
        var endpoint = "\(JamfProServer.destination)/JSSResource/policies/id/\(id)"
        endpoint = endpoint.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
//        endpoint = endpoint.replacingOccurrences(of: "/?failover", with: "")
        let endpointUrl      = URL(string: "\(endpoint)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: endpointUrl!)
        request.httpMethod = "GET"
        configuration.httpAdditionalHeaders = ["Authorization" : "\(String(describing: JamfProServer.authType)) \(String(describing: JamfProServer.authCreds))", "Content-Type" : "application/xml", "Accept" : "application/xml", "User-Agent" : AppInfo.userAgentHeader]
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
           (data, response, error) -> Void in
           session.finishTasksAndInvalidate()
           if let httpResponse = response as? HTTPURLResponse {
               if httpSuccess.contains(httpResponse.statusCode) {
                   if let _ = String(data: data!, encoding: .utf8) {
                       completion(String(data: data!, encoding: .utf8)!)
                       return
                    } else {
                        writeToLog.message(stringOfText: "\n[getScript] No data was returned from post/put.")
                    }
               }
           } else {
               print("could not read response or no response")
           }
           completion("")
        })
    task.resume()
    }
    
    
    private func sortPoliciesTableView(theRow: Int) {
        if selectedPoliciesArray.count > 0 && theRow != -1 {
            let selectedPolicy = selectedPoliciesArray[theRow].id
//            icon_TextField.stringValue = "\(policy_array_dict[selectedPolicy]!["icon"] ?? "")"
            progressText_TextField.stringValue = "\(configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy]!["progresstext"] ?? "Processing policy \(String(describing: configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy]!["listitem"]))")"
            validation_TextField.stringValue = "\(configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy]!["thePath"] ?? "")"
        } else if selectedPoliciesArray.count == 0 {
//            icon_TextField.stringValue = ""
            progressText_TextField.stringValue = ""
            validation_TextField.stringValue = ""
        }
        let isAscending = policies_TableView.sortDescriptors.first?.ascending ?? true
    //        let isAscending = sortDescriptor.ascending
    //        print("isAsc: \(isAscending)")
        if isAscending {
            policiesArray = policiesArray.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        } else {
            policiesArray = policiesArray.sorted(by: { $0.name.lowercased() > $1.name.lowercased() })
        }
        policies_TableView.reloadData()
    }
}

extension ViewController : NSTableViewDataSource, NSTableViewDelegate {
    
    
    fileprivate enum CellIdentifiers {
        static let NameCell    = "policyName"
        static let GroupIdCell = "groupId"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if (tableView == policies_TableView) {
//            print("numberOfRows: \(policiesArray.count)")
            return policiesArray.count
        } else {
//            print("numberOfRows: \(selectedPoliciesArray.count)")
            return selectedPoliciesArray.count
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if selectedPolicies_TableView.selectedRowIndexes.count > 0 {
            let theRow = selectedPolicies_TableView.selectedRow
            let selectedPolicyId = selectedPoliciesArray[theRow].id
            
            if let _ = Int(selectedPolicyId) {
                validation_Label.stringValue = "Validation:"
            } else {
                validation_Label.stringValue = "Command:"
            }
            
            progressText_TextField.stringValue = configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["progresstext"] ?? "Processing policy \(String(describing: configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["listitem"]))"
            validation_TextField.stringValue = configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["validation"] ?? ""

        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        //        print("tableView: \(tableView)\t\ttableColumn: \(tableColumn)\t\trow: \(row)")
        var newString:String = ""
            if (tableView == policies_TableView) {
                let name = policiesArray[row].name
                newString = "\(name)"
            }
            else if (tableView == selectedPolicies_TableView) {
                if tableColumn == selectedPolicies_TableView.tableColumns[0] {
                    let name = selectedPoliciesArray[row].name
                    newString = "\(name)"
                } else {
                    let groupId = selectedPoliciesArray[row].groupId
                    newString = "\(groupId)"
                }
            }
        return newString;
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        if (tableView == policies_TableView) {
            sortPoliciesTableView(theRow: -1)
        }
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let pasteboard = NSPasteboardItem()
            
        // in this example I'm dragging the row index. Once dropped i'll look up the value that is moving by using this.
        // remember in viewdidload I registered strings so I must set strings to pasteboard
        pasteboard.setString("\(row)", forType: .string)
        return pasteboard
    }
    
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        let canDrop = (row >= 0) // in this example you cannot drop on top two rows
//        print("valid drop \(row)? \(canDrop)")
        if (canDrop) {
            return .move //yes, you can drop on this row
        }
        else {
            return [] // an empty array is the equivalent of nil or 'cannot drop'
        }
    }
    
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let pastboard = info.draggingPasteboard
        if let sourceRowString = pastboard.string(forType: .string) {
            let selectionArray = sourceRowString.components(separatedBy: "\n")
//            print("\(selectionArray.count) items selected")
//            print("from \(sourceRowString). dropping row \(row)")
            if ((info.draggingSource as? NSTableView == selectedPolicies_TableView) && (tableView == selectedPolicies_TableView)) {
                var objectsMoved = 0
                var indexAdjustment = 0
                for thePolicy in selectionArray {
                    let value:Policy = selectedPoliciesArray[Int(thePolicy)!-indexAdjustment]
                    let theAction:EnrollmentActions = enrollmentActions[Int(thePolicy)!-indexAdjustment]
                    
                    selectedPoliciesArray.remove(at: Int(thePolicy)! - indexAdjustment)
                    enrollmentActions.remove(at: Int(thePolicy)! - indexAdjustment)
                    if (row > Int(thePolicy)!)
                    {
                        selectedPoliciesArray.insert(value, at: (row - 1 - objectsMoved + objectsMoved))
                        enrollmentActions.insert(theAction, at: (row - 1 - objectsMoved + objectsMoved))
                        indexAdjustment += 1
                    }
                    else
                    {
                        selectedPoliciesArray.insert(value, at: (row + objectsMoved))
                        enrollmentActions.insert(theAction, at: (row + objectsMoved))
                    }
                    objectsMoved += 1
                    selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray
                    selectedPolicies_TableView.reloadData()
                }
                
                return true
            } else {
                return false
            }
        }
        
        return false
    }
}
 
