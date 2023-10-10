//
//  KbPopoverVC.swift
//  SYM-Helper
//

import Cocoa
import Foundation

protocol SendingKbInfoDelegate {
    func sendKbInfo(KbInfo: (String,String))
}

class KbPopoverVC: NSViewController, NSWindowDelegate {
    
    var delegate: SendingKbInfoDelegate? = nil
    
    @IBOutlet weak var info_TextField: NSTextField!
    var whichField = ""
    var details    = ""
    var kbInfo = [String:String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        whichField = kbInfo["whichField"] ?? "unknown"
        details    = kbInfo["details"] ?? ""
        info_TextField.stringValue = details
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        delegate?.sendKbInfo(KbInfo: (whichField, info_TextField.stringValue))
    }
}
