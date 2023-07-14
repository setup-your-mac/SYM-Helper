//
//  CloneConfigVC.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

protocol SendClonedConfigInfoDelegate {
    func sendClonedConfigInfo(newConfig: String, existingConfig: String)
}

class CloneConfigVC: NSViewController {
    
    var delegate: SendClonedConfigInfoDelegate? = nil
    
    
    @IBAction func ok_Action(_ sender: NSButton) {
//        print("[copy config] newConfig: \(clonedConfigName_TextField.stringValue)")
        if currentConfigs.firstIndex(of: clonedConfigName_TextField.stringValue) == nil {
//            print("[ok_Action] send newConfig: \(clonedConfigName_TextField.stringValue)")
            delegate?.sendClonedConfigInfo(newConfig: clonedConfigName_TextField.stringValue, existingConfig: configs_Button.titleOfSelectedItem!)
            dismiss(self)
        } else {
            _ = alert.display(header: "Attention:", message: "\(clonedConfigName_TextField.stringValue) already exists.  Please edit the name so that it is unique.", secondButton: "")
        }
    }
    
    var currentConfigs         = [String]()
        

    @IBOutlet weak var clonedConfigName_TextField: NSTextField!
    @IBOutlet weak var configs_Button: NSPopUpButton!
    @IBOutlet weak var configs_menu: NSMenu!
    
    @IBAction func cloneConfig_Action(_ sender: Any) {
        clonedConfigName_TextField.stringValue = "\(String(describing: configs_Button.titleOfSelectedItem!))_copy"
    }
    
    @IBAction func cancel_Action(_ sender: Any) {
        dismiss(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for theConfig in currentConfigs.sorted() {
            configs_menu.addItem(NSMenuItem(title: theConfig, action: nil, keyEquivalent: ""))
        }
        configs_Button.selectItem(withTitle: "Default")
        clonedConfigName_TextField.stringValue = "Default_copy"
            
        
    }
}
