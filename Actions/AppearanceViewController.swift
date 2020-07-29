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

        let onState = NSControl.StateValue.on
        let offState = NSControl.StateValue.off

        enumeratedKeyboardShortcutsCheckboxButton.state = SettingsKVStore.sharedStore.enumeratedKeyboardShortcutsEnabled ? onState : offState
        showSystemWatchdogCheckboxButton.state = SettingsKVStore.sharedStore.systemWatchdogEnabled ? onState : offState
        showCPUTemperatureCheckboxButton.state = SettingsKVStore.sharedStore.showCPUTemperatureEnabled ? onState : offState
        showCPUInfoCheckboxButton.state = SettingsKVStore.sharedStore.showCPUInfo ? onState : offState
        showCPUUsageCheckboxButton.state = SettingsKVStore.sharedStore.showCPUUsageEnabled ? onState : offState
        showFansCheckboxButton.state = SettingsKVStore.sharedStore.showFansEnabled ? onState : offState
        showTotalDCINCheckboxButton.state = SettingsKVStore.sharedStore.showLineInPowerEnabled ? onState : offState
        showNetworkInformationCheckboxButton.state = SettingsKVStore.sharedStore.showNetworkInformationEnabled ? onState : offState

        setSystemWatchdogRelatedOutletsEnabled(SettingsKVStore.sharedStore.systemWatchdogEnabled)
    }

    @IBAction func enumeratedKeyboardShortcutsCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.enumeratedKeyboardShortcutsEnabled = sender.state == NSControl.StateValue.on
    }

    @IBAction func showSystemWatchdogCheckboxButtonPressed(_ sender: NSButton) {
        let enabled = sender.state == NSControl.StateValue.on
        SettingsKVStore.sharedStore.systemWatchdogEnabled = enabled

        NotificationCenter.default.post(name: Notification.Name(rawValue: toggleNetworkingTabNotificationKey), object: self) // enable/disable tab
        setSystemWatchdogRelatedOutletsEnabled(enabled)
    }

    @IBAction func showCPUTemperatureCheckboxButtonPressed(_ sender: AnyObject) {
        SettingsKVStore.sharedStore.showCPUTemperatureEnabled = sender.state == NSControl.StateValue.on
    }

    @IBAction func showCPUInfoCheckboxButtonPressed(_ sender: AnyObject) {
        SettingsKVStore.sharedStore.showCPUInfo = sender.state == NSControl.StateValue.on
    }

    @IBAction func showCPUUsageCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showCPUUsageEnabled = sender.state == NSControl.StateValue.on
    }

    @IBAction func showFansCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showFansEnabled = sender.state == NSControl.StateValue.on
    }

    @IBAction func showTotalDCINCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showLineInPowerEnabled = sender.state == NSControl.StateValue.on
    }

    @IBAction func showNetworkInformationCheckboxButtonPressed(_ sender: NSButton) {
        SettingsKVStore.sharedStore.showNetworkInformationEnabled = sender.state == NSControl.StateValue.on
        NotificationCenter.default.post(name: Notification.Name(rawValue: toggleNetworkingTabNotificationKey), object: self) // enable/disable tab
    }
}
