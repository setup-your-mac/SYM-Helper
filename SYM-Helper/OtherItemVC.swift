//
//  OtherItemVC.swift
//  SYM-Helper
//

import Cocoa
import Foundation

protocol OtherItemDelegate {
    func sendOtherItem(newItem: [String:String])
}

class OtherItemVC: NSViewController {

    var delegate: OtherItemDelegate? = nil
    
    @IBOutlet weak var otherItem_TabView: NSTabView!
    
    @IBOutlet weak var listitem_TextField: NSTextField!
    @IBOutlet weak var commandIcon_TextField: NSTextField!
    @IBOutlet weak var label_TextField: NSTextField!
    
    @IBOutlet weak var commandOrProgressText_Label: NSTextField!
    
    @IBOutlet weak var command_TextField: NSTextField!
    @IBOutlet weak var trigger_TextField: NSTextField!
    
    @IBOutlet weak var commandOrProgressText_TextField: NSTextField!
    @IBOutlet weak var icon_Label: NSTextField!
    @IBOutlet weak var validationIcon_TextField: NSTextField!
    
    @IBAction func cancel_Action(_ sender: Any) {
        dismiss(self)
    }
    
    var itemType = ""
    
    @IBAction func add_Action(_ sender: Any) {
        let commandAsArray = command_TextField.stringValue.components(separatedBy: " ")
        let theBinary = URL(string: commandAsArray[0])?.lastPathComponent ?? ""
        let validation = ( itemType == "validation" ) ? "Local":""
        let icon = ( itemType == "validation" ) ? validationIcon_TextField.stringValue:commandIcon_TextField.stringValue
        let commandDict = ["itemType": itemType,
                           "icon": icon,
                           "listitem": listitem_TextField.stringValue,
                           "progressText": commandOrProgressText_TextField.stringValue,
                           "theBinary": theBinary,
                           "command":command_TextField.stringValue,
                           "trigger":trigger_TextField.stringValue,
                           "validation":validation]
        if itemType == "validation" && trigger_TextField.stringValue == "" {
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
        if itemType == "validation" {
            otherItem_TabView.selectTabViewItem(withIdentifier: "local_validation")
            commandOrProgressText_Label.isHidden     = false
            commandOrProgressText_Label.stringValue  = "progress text:"
            commandOrProgressText_TextField.isHidden = false
            icon_Label.isHidden                      = false
            validationIcon_TextField.isHidden        = false
        } else {
            otherItem_TabView.selectTabViewItem(withIdentifier: "command")
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.title = "Add\(itemType)"
    }
    
}
