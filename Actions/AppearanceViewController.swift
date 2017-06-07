//
//  AppearanceViewController.swift
//  Actions
//
//  Created by Lukas Bischof on 03.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

import Cocoa

class AppearanceViewController: NSViewController {

    @IBOutlet weak var enumeratedKeyboardShortcutsCheckboxButton: NSButton!
    @IBOutlet weak var showSystemWatchdogCheckboxButton: NSButton!
    @IBOutlet weak var showCPUTemperatureCheckboxButton: NSButton!
    @IBOutlet weak var showCPUInfoCheckboxButton: NSButton!
    @IBOutlet weak var showCPUUsageCheckboxButton: NSButton!
    @IBOutlet weak var showFansCheckboxButton: NSButton!
    @IBOutlet weak var showTotalDCINCheckboxButton: NSButton!
    @IBOutlet weak var showNetworkInformationCheckboxButton: NSButton!
    
    private func systemWatchdogRelatedOutlets() -> [NSButton] {
        
        // @important Bei hinzufügen von weiteren SystemWatchdog funktionalitäten: Hier unbedingt ein weiterer Eintrag im Array hinterlassen!
        return [
            showCPUTemperatureCheckboxButton,
            showCPUUsageCheckboxButton,
            showFansCheckboxButton,
            showTotalDCINCheckboxButton,
            showNetworkInformationCheckboxButton
        ]
    }
    
    private func setSystemWatchdogRelatedOutletsEnabled(_ enabled: Bool) {
        for button in systemWatchdogRelatedOutlets() {
            button.isEnabled = enabled
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        enumeratedKeyboardShortcutsCheckboxButton.state = SettingsKVStore.sharedStore.enumeratedKeyboardShortcutsEnabled ? NSOnState : NSOffState
        showSystemWatchdogCheckboxButton.state = SettingsKVStore.sharedStore.systemWatchdogEnabled ? NSOnState : NSOffState
        showCPUTemperatureCheckboxButton.state = SettingsKVStore.sharedStore.showCPUTemperatureEnabled ? NSOnState : NSOffState
        showCPUInfoCheckboxButton.state = SettingsKVStore.sharedStore.showCPUInfo ? NSOnState : NSOffState
        showCPUUsageCheckboxButton.state = SettingsKVStore.sharedStore.showCPUUsageEnabled ? NSOnState : NSOffState
        showFansCheckboxButton.state = SettingsKVStore.sharedStore.showFansEnabled ? NSOnState : NSOffState
        showTotalDCINCheckboxButton.state = SettingsKVStore.sharedStore.showLineInPowerEnabled ? NSOnState : NSOffState
        showNetworkInformationCheckboxButton.state = SettingsKVStore.sharedStore.showNetworkInformationEnabled ? NSOnState : NSOffState
        
        setSystemWatchdogRelatedOutletsEnabled(SettingsKVStore.sharedStore.systemWatchdogEnabled)
    }
    
    @IBAction func enumeratedKeyboardShortcutsCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.enumeratedKeyboardShortcutsEnabled = sender.state == NSOnState
    }
    
    @IBAction func showSystemWatchdogCheckboxButtonPressed(_ sender: NSButton) {
        let enabled = sender.state == NSOnState
        SettingsKVStore.sharedStore.systemWatchdogEnabled = enabled
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: toggleNetworkingTabNotificationKey), object: self) // enable/disable tab
        setSystemWatchdogRelatedOutletsEnabled(enabled)
    }
    
    @IBAction func showCPUTemperatureCheckboxButtonPressed(_ sender: AnyObject) {
        SettingsKVStore.sharedStore.showCPUTemperatureEnabled = sender.state == NSOnState
    }
    
    @IBAction func showCPUInfoCheckboxButtonPressed(_ sender: AnyObject) {
        SettingsKVStore.sharedStore.showCPUInfo = sender.state == NSOnState
    }
    
    @IBAction func showCPUUsageCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showCPUUsageEnabled = sender.state == NSOnState
    }
    
    @IBAction func showFansCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showFansEnabled = sender.state == NSOnState
    }
    
    @IBAction func showTotalDCINCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showLineInPowerEnabled = sender.state == NSOnState
    }
    
    @IBAction func showNetworkInformationCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showNetworkInformationEnabled = sender.state == NSOnState
        NotificationCenter.default.post(name: Notification.Name(rawValue: toggleNetworkingTabNotificationKey), object: self) // enable/disable tab
    }
}
