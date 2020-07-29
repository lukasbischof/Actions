//
//  SettingsViewController.swift
//  Actions
//
//  Created by Lukas Bischof on 01.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

import Cocoa

let toggleNetworkingTabNotificationKey = "toggleNetworkingTab"

class SettingsViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
      self.tabView.tabViewType = NSTabView.TabType.noTabsNoBorder
        
        // update
        didReceiveShouldToggleNetworkingTabNotification(nil)
        
        // observers
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.didReceiveShouldToggleNetworkingTabNotification(_:)), name: NSNotification.Name(rawValue: toggleNetworkingTabNotificationKey), object: nil)
    }
    
  @objc func didReceiveShouldToggleNetworkingTabNotification(_ notification: Notification?) {
        toggleNetworkingTab(SettingsKVStore.sharedStore.showNetworkInformationEnabled && SettingsKVStore.sharedStore.systemWatchdogEnabled)
    }
    
    override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        if tabViewItem == nil {
            return false
        }
        
        if tabView.indexOfTabViewItem(tabViewItem!) == 2 && (!SettingsKVStore.sharedStore.showNetworkInformationEnabled || !SettingsKVStore.sharedStore.systemWatchdogEnabled) {
            return false
        } else {
            return true
        }
    }
    
    private func toggleNetworkingTab(_ enabled: Bool) -> Void {
        if enabled {
          tabView.tabViewItem(at: 2).image = NSImage(named: "networking")
        } else {
          tabView.tabViewItem(at: 2).image = NSImage(named: "networking-disabled")
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
