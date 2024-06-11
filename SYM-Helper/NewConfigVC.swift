//
//  NewConfigVC.swift
//  SYM-Helper
//

import Cocoa
import Foundation

protocol SendNewConfigInfoDelegate {
    func sendNewConfigInfo(newConfig: String)
}

class NewConfigVC: NSViewController {
    
    var delegate: SendNewConfigInfoDelegate? = nil
    
    @IBAction func ok_Action(_ sender: NSButton) {
//        print("[copy config] newConfig: \(newConfigName_TextField.stringValue)")
        if currentConfigs.firstIndex(of: newConfigName_TextField.stringValue) == nil && newConfigName_TextField.stringValue != "" {
//            print("[ok_Action] send newConfig: \(newConfigName_TextField.stringValue)")
            delegate?.sendNewConfigInfo(newConfig: newConfigName_TextField.stringValue)
            dismiss(self)
        } else {
            _ = Alert.shared.display(header: "Attention:", message: "\(newConfigName_TextField.stringValue) already exists, or is blank.  Please edit the name so that it is unique.", secondButton: "")
        }
    }
    
    @IBAction func cancel_Action(_ sender: Any) {
        dismiss(self)
    }
    
    var currentConfigs         = [String]()
        
    @IBOutlet weak var newConfigName_TextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

    }
}
