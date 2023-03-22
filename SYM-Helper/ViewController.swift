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
//    @objc var isSelected = false
    @objc var configs: [String]
    
    init(name: String, id: String, configs: [String]) {
        self.name = name
        self.id = id
        self.configs = configs
    }
}

class ViewController: NSViewController, NSTextFieldDelegate, URLSessionDelegate, SendingLoginInfoDelegate {
    
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
    
    @IBAction func config_Action(_ sender: NSPopUpButton) {
//        print("title: \(String(describing: sender.titleOfSelectedItem))")
        policiesArray = policiesDict[sender.titleOfSelectedItem!] ?? staticAllPolicies
        selectedPoliciesArray = selectedPoliciesDict[sender.titleOfSelectedItem!] ?? []
        selectedPolicies_TableView.deselectAll(self)
        progressText_TextField.stringValue = ""
        validation_TextField.stringValue   = ""
        policies_TableView.reloadData()
        selectedPolicies_TableView.reloadData()
    }
    
    @IBOutlet weak var policies_TableView: NSTableView!
    @IBOutlet weak var selectedPolicies_TableView: NSTableView!
    
    @IBOutlet weak var allPolicies_Spinner: NSProgressIndicator!
    @IBOutlet weak var policyArray_Spinner: NSProgressIndicator!
    
    @IBOutlet weak var progressText_TextField: NSTextField!
    @IBOutlet weak var validation_TextField: NSTextField!
    
    var policiesArray = [Policy]()
    var policiesDict  = [String:[Policy]]()
    var staticAllPolicies = [Policy]()
    var selectedPoliciesArray = [Policy]()
    var selectedPoliciesDict  = [String:[Policy]]()
    var policy_array_dict = [String:[String:String]]()   // [policy id: [attribute: value]]]
    var configsDict = [String:[String:[String:String]]]()   // [config name: [policy id: [attribute: value]]]
    var configurationsArray = [String]()
    var symScript = ""
    var policy_array = ""
    
    @IBOutlet weak var generateScript_Button: NSButton!
    //    var policyArray:[String]?    // array of policies to add to SYM
    
    @objc func addToPolicyArray() {
        let rowClicked = policies_TableView.clickedRow
//        let doubleClicked = policiesArray[rowClicked]
        
        if rowClicked < policiesArray.count && rowClicked != -1 {
            let doubleClicked = policiesArray[rowClicked]
//            doubleClicked.isSelected = true
            selectedPoliciesArray.append(doubleClicked)
            selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray
//            print("configuration_Button.titleOfSelectedItem: \(String(describing: configuration_Button.titleOfSelectedItem))")
            selectedPoliciesArray.last!.configs.append(configuration_Button.titleOfSelectedItem!)
//            print("selectedPoliciesArray.last: \(String(describing: selectedPoliciesArray.last?.configs))")
            getPolicy(id: doubleClicked.id) { [self]
                (result: String) in
                updatePoliciesDict(xml: result, policyId: doubleClicked.id)
                policiesArray.remove(at: rowClicked)
                policiesDict[configuration_Button.titleOfSelectedItem!] = policiesArray
                
                policies_TableView.reloadData()
                selectedPolicies_TableView.reloadData()
            }
        }
    }
    @objc func removeFromPolicyArray() {
        if selectedPolicies_TableView.clickedRow != -1 {
            var doubleClickedRow = selectedPolicies_TableView.clickedRow

            let doubleClicked = selectedPoliciesArray[doubleClickedRow]
//            doubleClicked.isSelected = false

            selectedPoliciesArray.remove(at: doubleClickedRow)
            selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray

            doubleClickedRow = (doubleClickedRow > selectedPoliciesArray.count-1) ? doubleClickedRow-1:doubleClickedRow
            if selectedPoliciesArray.count > 0 {
                selectedPolicies_TableView.selectRowIndexes(IndexSet(integer: doubleClickedRow), byExtendingSelection: false)
                let selectedPolicy = selectedPoliciesArray[doubleClickedRow].id
//                icon_TextField.stringValue = "\(policy_array_dict[selectedPolicy]!["icon"] ?? "")"
                progressText_TextField.stringValue = "\(configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy]!["progresstext"] ?? "Processing policy \(String(describing: configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy]!["listitem"]))")"
                validation_TextField.stringValue = "\(configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicy]!["thePath"] ?? "")"
            }
            selectedPolicies_TableView.reloadData()
            if let _ = Int(doubleClicked.id) {
                policiesArray.append(doubleClicked)
                policiesDict[configuration_Button.titleOfSelectedItem!] = policiesArray
                policies_TableView.reloadData()
                sortPoliciesTableView(theRow: doubleClickedRow)
            }
        }
    }
    
    @IBAction func generateScript_Action(_ sender: Any) {
//        var id = ""
        generateScript_Button.isEnabled = false
        let whichConfig = configuration_Button.titleOfSelectedItem
        var idArray = [String]()
        for selectedPolicy in selectedPoliciesArray {
//            print("id: \(id.replacingOccurrences(of: ")", with: ""))")
            idArray.append(selectedPolicy.id)
        }
        if idArray.count > 0 {
            policyArray_Spinner.maxValue = Double(idArray.count-1)
            policyArray_Spinner.startAnimation(self)
            policyArray_Spinner.isHidden = false
            processPolicies(id: idArray, whichId: 0, theConfigIndex: 0)
        } else {
            generateScript_Button.isEnabled = true
        }
    }
    
    private func updatePoliciesDict(xml: String, policyId: String) {
        
        let general = betweenTags(xmlString: xml, startTag: "<general>", endTag: "</general>")
//                let policyId = betweenTags(xmlString: general, startTag: "<id>", endTag: "</id>")
        let policyName = betweenTags(xmlString: general, startTag: "<name>", endTag: "</name>")
        let self_service = betweenTags(xmlString: xml, startTag: "<self_service>", endTag: "</self_service>")
        var icon = betweenTags(xmlString: self_service, startTag: "<uri>", endTag: "</uri>")
        icon = icon.replacingOccurrences(of: "https://ics.services.jamfcloud.com/icon/hash_", with: "")
        var progresstext = betweenTags(xmlString: self_service, startTag: "<self_service_description>", endTag: "</self_service_description>")
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
                
                progressText_TextField.stringValue = progresstext
                
                policy_array_dict[policyId] = ["listitem": policyName, "icon": icon, "progresstext": progresstext, "trigger": customTrigger, "validation": "None"]
            configsDict[configuration_Button.titleOfSelectedItem!]![policyId] = ["listitem": policyName, "icon": icon, "progresstext": progresstext, "trigger": customTrigger, "validation": "None"]
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
                case "progressText_TextField":
//                    policy_array_dict[selectedPolicyId]!["progresstext"] = progressText_TextField.stringValue
                    configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["progresstext"] = progressText_TextField.stringValue
                case "validation_TextField":
//                    policy_array_dict[selectedPolicyId]!["thePath"] = validation_TextField.stringValue
                    configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["validation"] = validation_TextField.stringValue
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
                WriteToLog().message(stringOfText: "[updatePolicy] A custom trigger of \"\(id)\" has been added to policy id \(id).")
                if httpSuccess.contains(httpResponse.statusCode) {
                    
//                    if let _ = String(data: data!, encoding: .utf8) {
//                        responseData = String(data: data!, encoding: .utf8)!
////                        WriteToLog().message(stringOfText: "[CreateEndpoints] \n\nfull response from create:\n\(responseData)") }
////                        print("response: \(responseData)")
//                    } else {
//                        WriteToLog().message(stringOfText: "\n[updatePolicy] No data was returned trying to set the custom trigger.  Verify on the server manually.")
//                    }
                    completion(id)
                    return
                } else {
                    WriteToLog().message(stringOfText: "[updatePolicy] No data was returned trying to set the custom trigger.  Verify/edit the custome trigger \"\(id)\" on the server manually.")
                }
            } else {
                print("could not read response or no response")
            }
            WriteToLog().message(stringOfText: "[updatePolicy] No data was returned trying to set the custom trigger.  Verify/edit the custome trigger \"\(id)\" on the server manually.")
            completion(id)
        })
        task.resume()
    }
    
    private func processPolicies(id: [String], whichId: Int, theConfigIndex: Int) {
        
        // move the default config to the end of the array
        if let index = configurationsArray.firstIndex(of: "Default") {
            configurationsArray.remove(at: index)
            configurationsArray.append("Default")
        } else {
            _ = Alert().display(header: "Attention:", message: "'Default' configuration must be defined.", secondButton: "")
            policyArray_Spinner.isHidden = true
            generateScript_Button.isEnabled = true
            return
        }

        var configCases = ""
        
        for theConfig in configurationsArray {
            let configDetails = configsDict[theConfig]!
            if theConfig == "Default" && configDetails.count == 0 {
                _ = Alert().display(header: "Attention:", message: "'Default' configuration must be defined.", secondButton: "")
                policyArray_Spinner.isHidden = true
                generateScript_Button.isEnabled = true
                return
            }
            if selectedPoliciesDict[theConfig]?.count ?? 0 > 0 {
                var firstPolicy = true
                policy_array = ""
                for thePolicy in selectedPoliciesDict[theConfig]! {
                    let policyId = thePolicy.id

                    let result = configsDict[theConfig]![policyId]!
    //                let result = configsDict[theConfig]![id[whichId]]!
                    let policyName = result["listitem"]
                    let icon = result["icon"]
                    let progresstext = result["progresstext"]
                    let validation = result["validation"] ?? ""
                    let customTrigger = result["trigger"]
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
                                {
                                    "trigger": "\(customTrigger!)",
                                    "validation": "\(validation)"
                                }
                            ]
                        }
    """)
    //                processPolicies(id: id, whichId: whichId+1, theConfigIndex: theConfigIndex+1)
                }   // for (policyId, _) in configDetails - end
                if configDetails.count > 0 {
                    // close off the policy array and generate script
                    
                    let whichConfig = (theConfig == "Default") ? "* ) # Catch-all":"\"\(theConfig)\""
                    policy_array = """
        \(whichConfig) )

                policyJSON'
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
        let policy_array_regex = try! NSRegularExpression(pattern: "case \\$\\{symConfiguration\\} in(.|\n|\r)*?esac", options:.caseInsensitive)
        var finalScript = policy_array_regex.stringByReplacingMatches(in: symScript, range: NSRange(0..<symScript.utf16.count), withTemplate: "case \\$\\{symConfiguration\\} in\n\n    \(configCases)    esac")
        
        policyArray_Spinner.isHidden = true
        
        // fix - don't save until we've hit all configs
        let saveDialog = NSSavePanel()
        saveDialog.canCreateDirectories = true
        saveDialog.nameFieldStringValue = "Setup-Your-Mac.bash"
        saveDialog.beginSheetModal(for: self.view.window!){ result in
            if result == .OK {
                let scriptName = saveDialog.nameFieldStringValue
                let exportURL            = saveDialog.url!
                print("fileName", scriptName)
                
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
    
    // Delegate Method
    func sendLoginInfo(loginInfo: (String,String,String,Int)) {
        
        var saveCredsState: Int?
        (JamfProServer.destination, JamfProServer.username, JamfProServer.userpass,saveCredsState) = loginInfo
        let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.userpass)".data(using: String.Encoding.utf8)
        JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!

        WriteToLog().message(stringOfText: "[ViewController] Running SYM-Helper v\(AppInfo.version)")
        TokenDelegate().getToken(whichServer: "destination", serverUrl: JamfProServer.destination, base64creds: JamfProServer.base64Creds) { [self]
            authResult in
            let (statusCode,theResult) = authResult
            if theResult == "success" {
                defaults.set(JamfProServer.destination, forKey: "server")
                defaults.set(JamfProServer.username, forKey: "username")
                if saveCredsState == 1 {
                    Credentials().save(service: "sym-helper-\(JamfProServer.destination.fqdnFromUrl)", account: JamfProServer.username, data: JamfProServer.userpass)
                }
                connectedTo_TextField.stringValue = "Connected to: \(JamfProServer.destination)"
                getScript() { [self]
                    (result: String) in
                    symScript = result
//                    print("getScript: \(symScript)")
                    
//                    let policy_array_regex = try! NSRegularExpression(pattern: "policy_array=\\('(.|\n|\r)*?'\\)", options:.caseInsensitive)
//                    symScript = policy_array_regex.stringByReplacingMatches(in: symScript, range: NSRange(0..<symScript.utf16.count), withTemplate: "policy_array=('\n')")
//
                    print("\ngetScript: \(symScript)")
                    
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
                                        policiesArray.append(Policy(name: "\(policyName) (\(policyId))", id: "\(policyId)", configs: []))
                                    }
                                    // filter out policies created from casper remote - end
                                }
                            }
                            // sort policies - to do
//                            policies_ArrayController.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                            staticAllPolicies = policiesArray
                            policies_TableView.reloadData()
                            allPolicies_Spinner.stopAnimation(self)
                        }
                    }
                    
                }
            } else {
                DispatchQueue.main.async { [self] in
                    WriteToLog().message(stringOfText: "Failed to authenticate, status code: \(statusCode)")
                    performSegue(withIdentifier: "loginView", sender: nil)
//                        working(isWorking: false)
                }
            }
        }
        
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "loginView" {
            let loginVC: LoginVC = segue.destinationController as! LoginVC
            loginVC.delegate = self
            loginVC.uploadsComplete = false
        }
    }
    
    private func getScript(completion: @escaping (_ authResult: String) -> Void) {
        print("enter getScript")
        print("script source: \(scriptSource)")
        var responseData = ""
        URLCache.shared.removeAllCachedResponses()
        let scriptUrl      = URL(string: "\(scriptSource)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: scriptUrl!)
        request.httpMethod = "GET"
        configuration.httpAdditionalHeaders = ["User-Agent" : AppInfo.userAgentHeader]
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpSuccess.contains(httpResponse.statusCode) {
                    print("statusCode: \(httpResponse.statusCode)")
                    
                    if let _ = String(data: data!, encoding: .utf8) {
                        responseData = String(data: data!, encoding: .utf8)!
//                        WriteToLog().message(stringOfText: "[CreateEndpoints] \n\nfull response from create:\n\(responseData)") }
                        print("response: \(responseData)")
                    } else {
                        WriteToLog().message(stringOfText: "\n[getScript] No data was returned from post/put.")
                    }
                    completion(responseData)
                    return
                }
            } else {
                print("could not read response or no response")
            }
            completion(responseData)
        })
        task.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // initialize configDict for each config
        for i in 0..<configuration_Button.numberOfItems {
            configuration_Button.selectItem(at: i)
            let theConfig = configuration_Button.titleOfSelectedItem!
            configurationsArray.append(theConfig)
            configsDict[theConfig] = [:]
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
//        let registeredTypes:[String] = [NSPasteboard.PasteboardType.string.rawValue]
//        policyArray_TableView.registerForDraggedTypes(convertToNSPasteboardPasteboardTypeArray(registeredTypes))
//        policies_TableView.registerForDraggedTypes(convertToNSPasteboardPasteboardTypeArray(registeredTypes))
        
        configuration_Button.selectItem(at: 0)

    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if showLoginWindow {
            performSegue(withIdentifier: "loginView", sender: nil)
            showLoginWindow = false
        }
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
        endpoint = endpoint.replacingOccurrences(of: "/?failover", with: "")
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
                           WriteToLog().message(stringOfText: "\n[getScript] No data was returned from post/put.")
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
        endpoint = endpoint.replacingOccurrences(of: "/?failover", with: "")
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
                        WriteToLog().message(stringOfText: "\n[getScript] No data was returned from post/put.")
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
            progressText_TextField.stringValue = configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["progresstext"] ?? "Processing policy \(String(describing: configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["listitem"]))"
            validation_TextField.stringValue = configsDict[configuration_Button.titleOfSelectedItem!]![selectedPolicyId]!["validation"] ?? ""
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        //        print("tableView: \(tableView)\t\ttableColumn: \(tableColumn)\t\trow: \(row)")
        var newString:String = ""
        if (tableView == policies_TableView)
        {
            let name = policiesArray[row].name
            newString = "\(name)"
        }
        else if (tableView == selectedPolicies_TableView)
        {
            let name = selectedPoliciesArray[row].name
            newString = "\(name)"
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
//            print("from \(sourceRowString). dropping row \(row)")
            if ((info.draggingSource as? NSTableView == selectedPolicies_TableView) && (tableView == selectedPolicies_TableView)) {
                let value:Policy = selectedPoliciesArray[Int(sourceRowString)!]
                selectedPoliciesArray.remove(at: Int(sourceRowString)!)
                if (row > Int(sourceRowString)!)
                {
                    selectedPoliciesArray.insert(value, at: row-1)
                }
                else
                {
                    selectedPoliciesArray.insert(value, at: row)
                }
                selectedPoliciesDict[configuration_Button.titleOfSelectedItem!] = selectedPoliciesArray
                selectedPolicies_TableView.reloadData()
                return true
            } else {
                return false
            }
        }
        
        return false
    }
}
 
