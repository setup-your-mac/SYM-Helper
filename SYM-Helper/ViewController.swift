//
//  ViewController.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

class Policy: NSObject {
    @objc var name: String
    @objc var id: String
    
    init(name: String, id: String) {
        self.name = name
        self.id = id
    }
}
class SelectedPolicy: NSObject {
    @objc var name: String
    @objc var id: String
    
    init(name: String, id: String) {
        self.name = name
        self.id = id
    }
}

class ViewController: NSViewController, NSTableViewDelegate, URLSessionDelegate, SendingLoginInfoDelegate {
    
    @IBOutlet weak var connectedTo_TextField: NSTextField!
    
    @IBOutlet weak var policies_TableView: NSTableView!
    @IBOutlet weak var policyArray_TableView: NSTableView!
        
    @IBOutlet var policies_ArrayController: NSArrayController!
    @IBOutlet var selectedPolicies_ArrayController: NSArrayController!
    
    var policyArray:[String]?    // array of policies to add to SYM
    
    @objc func addToPolicyArray() {
        print("[\(#line)] doubleClicked Row: \(String(policies_TableView.clickedRow))")
        let doubleClicked = policies_ArrayController.arrangedObjects as! [Policy]
        print("[\(#line)] doubleClicked: \(doubleClicked[policies_TableView.clickedRow].name))")
        selectedPolicies_ArrayController.addObject(SelectedPolicy(name: "\(doubleClicked[policies_TableView.clickedRow].name)", id: "0"))
//        if policyArray?.count ?? 0 > 0 {
//            policyArray!.append("\(doubleClicked[policies_TableView.clickedRow].name))")
//        } else {
//            policyArray = ["\(doubleClicked[policies_TableView.clickedRow].name))"]
//        }

        policyArray_TableView.reloadData()
    }
    @objc func removeFromPolicyArray() {
        print("[\(#line)] doubleClicked Row: \(String(policyArray_TableView.clickedRow))")
        let doubleClicked = selectedPolicies_ArrayController.arrangedObjects as! [SelectedPolicy]
        print("[\(#line)] doubleClicked: \(doubleClicked[policyArray_TableView.clickedRow].name))")
        selectedPolicies_ArrayController.remove(atArrangedObjectIndex: policyArray_TableView.clickedRow)
//        selectedPolicies_ArrayController.addObject(SelectedPolicy(name: "\(doubleClicked[policies_TableView.clickedRow].name)", id: "0"))
//        if policyArray?.count ?? 0 > 0 {
//            policyArray!.append("\(doubleClicked[policies_TableView.clickedRow].name))")
//        } else {
//            policyArray = ["\(doubleClicked[policies_TableView.clickedRow].name))"]
//        }

        policyArray_TableView.reloadData()
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
                    var symScript = result
//                    print("getScript: \(symScript)")
                    let policy_array_regex = try! NSRegularExpression(pattern: "policy_array=\\('(.|\n|\r)*?'\\)", options:.caseInsensitive)
                    symScript = policy_array_regex.stringByReplacingMatches(in: symScript, range: NSRange(0..<symScript.utf16.count), withTemplate: "policy_array=('\n')")
//                    print("\ngetScript: \(symScript)")
                    
                    getAllPolicies() { [self]
                        (result: [String:Any]) in
                        var allPolicies = result["policies"] as! [[String:Any]]
//                        print("all policies: \(allPolicies)")
                        if allPolicies.count > 0 {
                            for i in 0..<allPolicies.count {
                                let aPolicy = allPolicies[i] as [String:Any]
//                                print("aPolicy: \(aPolicy)")
                                if let policyName = aPolicy["name"] as? String, let policyId = aPolicy["id"] as? Int {
//                                    print("\(policyName) (\(policyId))")
                                    policies_ArrayController.addObject(Policy(name: "\(policyName) (\(policyId))", id: "\(policyId)"))
                                }
                            }
                            policies_ArrayController.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                            policies_TableView.reloadData()
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
//                        print("response: \(responseData)")
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
        policies_TableView.delegate = self
        policies_TableView.doubleAction = #selector(addToPolicyArray)
//        let descriptorName = NSSortDescriptor(key: "name", ascending: true)
//        policies_TableView.tableColumns[0].sortDescriptorPrototype = descriptorName
        
        policyArray_TableView.delegate = self
        policyArray_TableView.doubleAction = #selector(removeFromPolicyArray)
        
        policyArray_TableView.registerForDraggedTypes([.string])
//        let registeredTypes:[String] = [NSPasteboard.PasteboardType.string.rawValue]
//        policyArray_TableView.registerForDraggedTypes(convertToNSPasteboardPasteboardTypeArray(registeredTypes))
//        policies_TableView.registerForDraggedTypes(convertToNSPasteboardPasteboardTypeArray(registeredTypes))

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
    
    
}

extension ViewController : NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return policyArray?.count ?? 0 // or whatever
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let pasteboard = NSPasteboardItem()
            
        // in this example I'm dragging the row index. Once dropped i'll look up the value that is moving by using this.
        // remember in viewdidload I registered strings so I must set strings to pasteboard
        pasteboard.setString("\(row)", forType: .string)
        return pasteboard
    }
    
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        let canDrop = (row > 2) // in this example you cannot drop on top two rows
        print("valid drop \(row)? \(canDrop)")
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
            print("from \(sourceRowString). dropping row \(row)")
            return true
        }
        
        return false
    }
    
    /*
    func tableView(_ aTableView: NSTableView,
                   writeRowsWith rowIndexes: IndexSet,
                   to pboard: NSPasteboard) -> Bool
    {
        if (aTableView == policyArray_TableView) {
//            let data:Data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
            let indexArray = Array(rowIndexes)
//            guard let data:Data =  try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false) else {
//                return false
//            }
            let selectedRow = Int(rowIndexes.first!)
            guard let data:Data =  try? NSKeyedArchiver.archivedData(withRootObject: selectedRow, requiringSecureCoding: false) else {
                return false
            }
//            guard let data:Data =  try? NSKeyedArchiver.archivedData(withRootObject: indexArray, requiringSecureCoding: false) else {
//                return false
//            }
            let registeredTypes:[String] = [NSPasteboard.PasteboardType.string.rawValue]
            pboard.declareTypes(convertToNSPasteboardPasteboardTypeArray(registeredTypes), owner: self)
            pboard.setData(data, forType: convertToNSPasteboardPasteboardType(NSPasteboard.PasteboardType.string.rawValue))
            return true
            
        }
        else
        {
            return false
        }
    }
    
    func tableView(_ aTableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation
    {
        if operation == .above {
            return .move
        }
        return .all
        
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        print("drag stuff")
        let data:Data = info.draggingPasteboard.data(forType: convertToNSPasteboardPasteboardType(NSPasteboard.PasteboardType.string.rawValue))!
//        let rowIndexes:IndexSet = NSKeyedUnarchiver.unarchiveObject(with: data) as! IndexSet
        
//        guard let rowIndexes:IndexSet = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSObject.IndexSet, from: data) else {
//            return false
//        }
        guard let rowIndex:NSNumber = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSNumber.self, from: data) else {
            return false
        }
        let theRow = NumberFormatter().string(for: rowIndex as NSNumber) ?? "0"
        let finalIndex = Int(theRow)
//        let rowIndexes:IndexSet = IndexSet(rowArray)
        
        
        if ((info.draggingSource as? NSTableView == policyArray_TableView) && (tableView == policyArray_TableView))
        {
            let value:String = policyArray![finalIndex!]
            policyArray!.remove(at: finalIndex!)
            if (row > policyArray!.count)
            {
                policyArray!.insert(value, at: row-1)
            }
            else
            {
                policyArray!.insert(value, at: row)
            }
            policyArray_TableView.reloadData()
            return true
        }
//        else if ((info.draggingSource as! NSTableView == srcSrvTableView) && (tableView == policyArray_TableView))
//        {
//            let value:String = sourceDataArray[rowIndexes.first!]
//            sourceDataArray.remove(at: rowIndexes.first!)
//            targetDataArray.append(value)
//            srcSrvTableView.reloadData()
//            policyArray_TableView.reloadData()
//            return true
//        }
        else
        {
            return false
        }
        
    }

    */
}
   
// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardTypeArray(_ input: [String]) -> [NSPasteboard.PasteboardType] {
    return input.map { key in NSPasteboard.PasteboardType(key) }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSPasteboardPasteboardTypeArray(_ input: [NSPasteboard.PasteboardType]) -> [String] {
    return input.map { key in key.rawValue }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardType(_ input: String) -> NSPasteboard.PasteboardType {
    return NSPasteboard.PasteboardType(rawValue: input)
}
