//
//  NetworkInformationViewController.swift
//  Actions
//
//  Created by Lukas Bischof on 12.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

import Cocoa

class NetworkInformationViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    /// @todo NetworkInformation Settings Panel implementieren & mehr Informationen zur Verfügung stellen

    @IBOutlet weak var showHostNameCheckboxButton: NSButton!
    @IBOutlet weak var showAllAddressesCheckboxButton: NSButton!
    @IBOutlet weak var tableView: NSTableView!

    // MARK: - View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerForDraggedTypes([NSPasteboard.PasteboardType.init("drag")])
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return SettingsKVStore.sharedStore.networkingSettings!.getSettings().count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let tableColumn = tableColumn {
            guard let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn) else {
                return nil
            }

            let tableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "networkCell\(columnIndex + 1)"), owner: self) as! NSTableCellView

            do {
                let option = try SettingsKVStore.sharedStore.networkingSettings!.getOptionAtIndex(row)

                switch columnIndex {
                case 0:
                    let checkbox = tableCellView.subviews[0] as? NSButton
                    if checkbox?.identifier == NSUserInterfaceItemIdentifier(rawValue: "checkbox") {
                        checkbox?.action = #selector(NetworkInformationViewController.checkboxButtonPressed(_:))
                        checkbox?.tag = row
                        checkbox?.target = self
                        checkbox?.state = option.enabled ? NSControl.StateValue.on : NSControl.StateValue.off
                    } else {
                        fatalError("Can't get checkbox button in NetworkInformationViewController")
                    }

                case 1:
                    tableCellView.textField?.stringValue = option.displayName

                default:
                    break
                }

                return tableCellView
            } catch NetworkingSettingsError.indexOutOfBounds(_) {
                fatalError("NetworkInformationVC: Can't set up table view cell, because an index out of bounds was accessed")
            } catch {
                return nil
            }
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
        pboard.setData(data, forType: NSPasteboard.PasteboardType(rawValue: "drag"))

        return true
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard let types = info.draggingPasteboard.types else {
            return NSDragOperation()
        }

        if types.contains(NSPasteboard.PasteboardType(rawValue: "drag")) && dropOperation == .above {
            return .move
        } else {
            return NSDragOperation()
        }
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        if let types = info.draggingPasteboard.types {
            if types.contains(NSPasteboard.PasteboardType(rawValue: "drag")) && dropOperation == .above {
                if let indexData = info.draggingPasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: "drag")) {
                    if let indexes = NSKeyedUnarchiver.unarchiveObject(with: indexData) as? IndexSet {
                        for index in indexes {
                            do {
                                try SettingsKVStore.sharedStore.networkingSettings!
                                                               .moveOptionAtIndex(UInt(index), toIndex: UInt(row))
                                tableView.reloadData()

                                return true
                            } catch (NetworkingSettingsError.indexOutOfBounds(_)) {
                                print("Can't move option at index \(index) to index \(row): Index out of bounds")
                            } catch {
                                print("Can't move option at index \(index) to index \(row)")
                            }
                        }
                    }
                }
            }
        }

        return false
    }

    // MARK: - User actions & Interface Builder related methods
    @objc func checkboxButtonPressed(_ sender: NSButton) -> Void {
        do {
            let index = sender.tag
            let option = try SettingsKVStore.sharedStore.networkingSettings!.getOptionAtIndex(index)
            option.enabled = sender.state == NSControl.StateValue.on

            try SettingsKVStore.sharedStore.networkingSettings!.alterOption(option, atIndex: index)
        } catch {
            print("Can't alter option")
        }
    }

    @IBAction func showHostNameCheckboxButtonPressed(_ sender: NSButton) {
        // todo: wtf, why is this empty?
    }

    @IBAction func showAllAddressesCheckboxButtonPressed(_ sender: NSButton) {

    }
}
