//
//  OtherItemVC.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

protocol OtherItemDelegate {
    func sendOtherItem(newItem: [String:String])
}

class OtherItemVC: NSViewController {

    var delegate: OtherItemDelegate? = nil
    
    @IBOutlet weak var otherItem_TabView: NSTabView!
    
    @IBOutlet weak var icon_TextField: NSTextField!
    @IBOutlet weak var label_TextField: NSTextField!
    @IBOutlet weak var command_TextField: NSTextField!
    @IBOutlet weak var trigger_TextField: NSTextField!
    
    @IBOutlet weak var commandOrValidation: NSTextField!
    @IBOutlet weak var timeout_Label: NSTextField!
    @IBOutlet weak var timeout_TextField: NSTextField!
    
    @IBAction func cancel_Action(_ sender: Any) {
        dismiss(self)
    }
    
    var itemType = ""
    
    @IBAction func add_Action(_ sender: Any) {
        let commandAsArray = command_TextField.stringValue.components(separatedBy: " ")
        let theBinary = URL(string: commandAsArray[0])?.lastPathComponent ?? ""
        let validation = ( itemType == "Validation" ) ? "Local":""
        let commandDict = ["itemType": itemType,
                           "icon": icon_TextField.stringValue,
                           "label": trigger_TextField.stringValue,
                           "theBinary": theBinary,
                           "command":command_TextField.stringValue,
                           "trigger":trigger_TextField.stringValue,
                           "validation":validation]
        if itemType == "Validation" && trigger_TextField.stringValue == "" {
            _ = alert.display(header: "", message: "A trigger must be specified for local validation", secondButton: "")
            return
        } else {
            delegate?.sendOtherItem(newItem: commandDict)
            dismiss(self)
        }
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[OtherItemVC.viewDidLoad] itemType: \(itemType)")
        if itemType == "Validation" {
            otherItem_TabView.selectTabViewItem(withIdentifier: "local_validation")
        } else {
            otherItem_TabView.selectTabViewItem(withIdentifier: "command")
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.title = "Add\(itemType)"
    }
    
}
