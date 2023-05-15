//
//  LoginVC.swift
//  SYM-Helper
//
//  Created by Leslie Helou on 2/18/23.
//

import Cocoa
import Foundation

protocol SendingLoginInfoDelegate {
    func sendLoginInfo(loginInfo: (String,String,String,Int))
}

class LoginVC: NSViewController, URLSessionDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var hideCreds_button: NSButton!
    
    @IBOutlet weak var jamfProServer_textfield: NSTextField!
    @IBOutlet weak var jamfProUsername_textfield: NSTextField!
    @IBOutlet weak var jamfProPassword_textfield: NSSecureTextField!
    
    @IBOutlet weak var username_label: NSTextField!
    @IBOutlet weak var password_label: NSTextField!
    
    @IBOutlet weak var saveCreds_button: NSButton!
    
//    @IBOutlet weak var upload_progressIndicator: NSProgressIndicator!
//    @IBOutlet weak var continueButton: NSButton!
    
    var delegate: SendingLoginInfoDelegate? = nil
    
    var sourcePlistsURL        = URL(string: "/")
    var xmlFileNames           = [String]()
        
    var currentServer          = ""
    var categoryName           = ""
    var uploadCount            = 0
    var totalObjects           = 0
    var uploadsComplete        = false

    
    @IBAction func hideCreds_action(_ sender: NSButton) {
        hideCreds_button.image = (hideCreds_button.state.rawValue == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
        defaults.set("\(hideCreds_button.state.rawValue)", forKey: "hideCreds")
        setWindowSize(setting: hideCreds_button.state.rawValue)
    }
    
    @IBAction func login_action(_ sender: Any) {
        JamfProServer.destination = jamfProServer_textfield.stringValue
        JamfProServer.username    = jamfProUsername_textfield.stringValue
        JamfProServer.userpass    = jamfProPassword_textfield.stringValue
        
        let dataToBeSent = (jamfProServer_textfield.stringValue, jamfProUsername_textfield.stringValue, jamfProPassword_textfield.stringValue,saveCreds_button.state.rawValue)
        delegate?.sendLoginInfo(loginInfo: dataToBeSent)
        dismiss(self)
        
    }
    
    @IBAction func quit_Action(_ sender: Any) {
        dismiss(self)
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func saveCredentials_Action(_ sender: Any) {
        if saveCreds_button.state.rawValue == 1 {
            defaults.set(1, forKey: "saveCreds")
        } else {
            defaults.set(0, forKey: "saveCreds")
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.identifier!.rawValue {
            case "server":
                let credentialsArray = Credentials().retrieve(service: "sym-helper-\(jamfProServer_textfield.stringValue.fqdnFromUrl)")
                
                if credentialsArray.count == 2 {
                    jamfProUsername_textfield.stringValue = credentialsArray[0]
                    jamfProPassword_textfield.stringValue = credentialsArray[1]
                    setWindowSize(setting: 0)
                } else {
                    setWindowSize(setting: 1)
                }
            default:
                break
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.identifier!.rawValue {
            case "server":
                if jamfProUsername_textfield.stringValue != "" || jamfProPassword_textfield.stringValue != "" {
                    let credentialsArray = Credentials().retrieve(service: "sym-helper-\(jamfProServer_textfield.stringValue.fqdnFromUrl)")
                    
                    if credentialsArray.count == 2 {
                        jamfProUsername_textfield.stringValue = credentialsArray[0]
                        jamfProPassword_textfield.stringValue = credentialsArray[1]
                        setWindowSize(setting: 0)
                    } else {
                        jamfProUsername_textfield.stringValue = ""
                        jamfProPassword_textfield.stringValue = ""
                        setWindowSize(setting: 1)
                    }
                }
            default:
                break
            }
        }
    }
    
    func setWindowSize(setting: Int) {
        if setting == 0 {
            preferredContentSize = CGSize(width: 450, height: 85)
            hideCreds_button.toolTip = "show username/password fields"
            jamfProUsername_textfield.isHidden = true
            jamfProPassword_textfield.isHidden = true
            username_label.isHidden            = true
            password_label.isHidden            = true
            saveCreds_button.isHidden          = true
        } else {
            preferredContentSize = CGSize(width: 450, height: 142)
            hideCreds_button.toolTip = "hide username/password fields"
            jamfProUsername_textfield.isHidden    = false
            jamfProPassword_textfield.isHidden    = false
            username_label.isHidden               = false
            password_label.isHidden               = false
            saveCreds_button.isHidden             = false
        }
        hideCreds_button.state = NSControl.StateValue(rawValue: setting)
        
        hideCreds_button.image = (setting == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        jamfProServer_textfield.delegate   = self
        jamfProUsername_textfield.delegate = self
        jamfProPassword_textfield.delegate = self
        
        jamfProServer_textfield.stringValue = defaults.string(forKey: "server") ?? ""
        saveCreds_button.state = NSControl.StateValue(defaults.integer(forKey: "saveCreds"))
        if jamfProServer_textfield.stringValue != "" {
            
            let credentialsArray = Credentials().retrieve(service: "sym-helper-\(jamfProServer_textfield.stringValue.fqdnFromUrl)")
            
            if credentialsArray.count == 2 {
                jamfProUsername_textfield.stringValue = credentialsArray[0]
                jamfProPassword_textfield.stringValue = credentialsArray[1]
                let windowState = (defaults.integer(forKey: "hideCreds") == 1) ? 1:0
                setWindowSize(setting: windowState)
            } else {
                jamfProUsername_textfield.stringValue = defaults.string(forKey: "username") ?? ""
                jamfProPassword_textfield.stringValue = ""
                setWindowSize(setting: 1)
            }
        } else {
            jamfProServer_textfield.stringValue = "https://"
            setWindowSize(setting: 1)
        }
        
        // bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)

    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}
