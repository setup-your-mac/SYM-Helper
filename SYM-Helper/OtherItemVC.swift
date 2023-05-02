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
    
    @IBOutlet weak var icon_TextField: NSTextField!
    @IBOutlet weak var label_TextField: NSTextField!
    @IBOutlet weak var command_TextField: NSTextField!
    
    @IBOutlet weak var commandOrWatchPath: NSTextField!
    @IBOutlet weak var timeout_Label: NSTextField!
    @IBOutlet weak var timeout_TextField: NSTextField!
    
    @IBAction func cancel_Action(_ sender: Any) {
        dismiss(self)
    }
    
    var itemType = ""
    
    @IBAction func add_Action(_ sender: Any) {
        let commandAsArray = command_TextField.stringValue.components(separatedBy: " ")
        let theBinary = URL(string: commandAsArray[0])?.lastPathComponent ?? ""
        let commandDict = ["icon": icon_TextField.stringValue,
                           "label": label_TextField.stringValue,
                           "theBinary": theBinary,
                           "command":command_TextField.stringValue]
        delegate?.sendOtherItem(newItem: commandDict)
        dismiss(self)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()

        if itemType == " Watch Item" {
            commandOrWatchPath.stringValue = "Watch Path"
            timeout_Label.isHidden = false
            timeout_TextField.isHidden = false
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.title = "Add\(itemType)"
    }
    
}
