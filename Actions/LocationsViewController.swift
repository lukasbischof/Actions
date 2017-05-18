//
//  LocationsViewController.swift
//  Actions
//
//  Created by Lukas Bischof on 02.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

import Cocoa

class LocationsViewController: NSViewController {

    @IBOutlet weak var scriptsLocationTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        updateScriptsLocationTextField()
    }
    
    func updateScriptsLocationTextField() -> Void {
        var scriptsLabelValue: String!
        
        if let scriptsLocation = SettingsKVStore.sharedStore.scriptsDirectory {
            let components = scriptsLocation.pathComponents
            if components.count >= 2 {
                let last = components.last!
                let second = components[components.count - 2]
                
                scriptsLabelValue = "\(second) ▸ \(last)"
            } else {
                if components.count == 0 {
                    scriptsLabelValue = "No Path"
                } else {
                    scriptsLabelValue = components[0]
                }
            }
        } else {
            scriptsLabelValue = "No Path"
        }
        
        self.scriptsLocationTextField.stringValue = scriptsLabelValue
    }
    
    @IBAction func cangeButtonPressed(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canDownloadUbiquitousContents = false
        
        openPanel.beginSheetModal(for: self.view.window!) { (result) in
            if (result == NSFileHandlingPanelOKButton) {
                let url = openPanel.urls[0]
                
                if SettingsKVStore.sharedStore.appIsSandboxed {
                    let _ = url.startAccessingSecurityScopedResource()
                }
                
                SettingsKVStore.sharedStore.scriptsDirectory = url
                self.updateScriptsLocationTextField()
            }
        }
        
        /*openPanel.beginWithCompletionHandler { (result) in
            if (result == NSFileHandlingPanelOKButton) {
                let url = openPanel.URLs[0]
                
                SettingsKVStore.sharedStore.scriptsDirectory = url
                self.updateScriptsLocationTextField()
            }
        }*/
    }
}
