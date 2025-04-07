//
//  SettingsVC.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

class SettingsVC: NSViewController {
    
    @IBOutlet weak var scriptSource_TextField: NSTextField!
    @IBOutlet weak var cancel_Button: NSButton!
    @IBOutlet weak var ok_Button: NSButton!
    @IBOutlet weak var spinner_Progress: NSProgressIndicator!
    
    @IBAction func resetToDefault(_ sender: Any) {
        scriptSource_TextField.stringValue = defaultScriptSource
//        defaults.set(defaultScriptSource, forKey: "scriptSource")
    }
    
    @IBAction func cancel_Button(_ sender: Any) {
        dismiss(self)
    }
    
    @IBAction func ok_Button(_ sender: Any) {
        spinner_Progress.startAnimation(self)
        ok_Button.isEnabled = false
        cancel_Button.isEnabled = false
        ViewController().getScript(theSource: scriptSource_TextField.stringValue) { [self]
            (result: String) in
            symScript = result
            print("[Settings] getScript: \(symScript)")
            spinner_Progress.stopAnimation(self)
            if symScript == "" {
                let scriptReply = Alert().display(header: "Attention:", message: "Set-Up-Your-Mac script was not found.  Verify the server URL listed in Settings.", secondButton: "Use Anyway")
                if scriptReply == "Use Anyway" {
                    defaults.set(scriptSource_TextField.stringValue, forKey: "scriptSource")
                    self.dismiss(self)
                } else {
                    ok_Button.isEnabled = true
                    cancel_Button.isEnabled = true
                    return
                }
            } else {
                defaults.set(scriptSource_TextField.stringValue, forKey: "scriptSource")
                self.dismiss(self)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scriptSource_TextField.stringValue = defaults.string(forKey: "scriptSource") ?? defaultScriptSource

    }
    
}
