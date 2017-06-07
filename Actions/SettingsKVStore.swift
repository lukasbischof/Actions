//
//  SettingsKVStore.swift
//  Actions
//
//  Created by Lukas Bischof on 02.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

/*
 
 *************************************************************
 >                  SettingsKVStore Konzept                  <
 *************************************************************
 
 "Settings Key/Value Store" — Ein Container für alle Einstellungen in dieser App, basierend auf einem Key/Value Store: den NSUserDefaults.
 
 
 Der SettingsKVStore repräsentiert alle Optionen, welche man in dem Settings-Panel setzen kann. 
 Jedigliche Optionen werden in der Haupt-Klasse “SettingsKVStore“ gespeichert. Sie sind über Properties verfügbar.
 Um das Laden zu automatisieren, wird die sharedStore Property bereitgestellt.
 Die einzelnen Properties werden automatisch direkt nach dem Editieren über einen Setter gespeichert. 
 
 Die networkSettings-Property ist jedoch ein wenig anders als alle andere Properties:
 Sie ist eine Instanz der “NetworkingSettings“-Klasse, welche im Prinzip nur die TableView des Networking-Tabs in den Einstellunges repräsentiert. 
 Deshalb besitzt diese Klasse als Haupt-Funktion nur ein Array, welches NetworkOptions beinhaltet. Eine NetworkOption setzt sich aus folgenden Attributen zusammen:
    • enabled, boolean: Eine Flag, welche anzeigt, ob die Option aktiviert ist oder nicht.
    • displayName, String: Der Titel welche in dem TableView als Beschreibung zur Option angezeigt wird. Hat keinen Einfluss auf die Programmierung
    • bindingProperty, NetworkingOptionPropertyBinding: Diese Property verknüpft die Option mit dem effektivem Wert aus der NTWRKInfo Klasse (oder einer belibigen anderen Klasse). Die bindingProperty entspricht dabei einem Property-Namen von einem Objekt, welches dann mit der Funktion NetworkingSettings.getValueForOption(_:withObject:) gelesen wird und zurückgegeben wird. 
        Bsp.: Im AppDelegate wurde eine Instanz von NTWRKInfo erzeugt. Bei dem Updaten des Menus wird dann diese Funktion mit der NetworkInfo aufgerufen, um den aktuellen Wert zu bekommen, ohne dass dabei auf einen Key oder eine Referenz zurückgegriffen wird. Somit lassen sich die Optionen leicht verknüpfen. 
        ACHTUNG: Sobald man eine neue Option hinzufügt, muss sie in den Standard-Settings verknüpft werden. Dabei muss der Name identisch mit einer Property sein, ansonsten wird nil zurückgegeben.
 
 Die NetworkingOptionPropertyBinding ist generisch, damit bei der NetworkingSettings.getValueForOption(_:withObject:)-Funktion der Typ verglichen werden kann, 
 damit man mit immer den richtigen Wert bekommt. Im Moment ist dies einfach irgendein Objekt, 
 welches das NetworkingOptionType-Protokoll implementiert, was natürlich später abgeändert werden kann, 
 um mehr Flexibilität zu erlangen, ohne den Code gross zu verändern. 
 Um weitere Klassen NetworkingOptionType-konform zu machen, wird nur eine Extension benötigt.
 
 Im AppDelegate wird im Menu Item dann einfach die Beschreibung des Objekts, welches von NetworkingSettings.getValueForOption(_:withObject:) zurückgegeben wird angezeigt. 
 Es sie denn, es implementiert das CustomNetworkingMenuItem Protokoll. Dann wird der Wert der menuItemValue-Property im MenuItem angezeigt. 
 Ein Beispiel für das Protokoll ist die NTWRKInterface Klasse. Es ist kein "Standardtyp" wie NSString oder NSArray, 
 welcher direkt angezeigt werden kann, sondern ein eigenes Objekt, auf welches man auch binden ("verlinken") kann.
 Um jedoch eine programmierbezogene Description verwenden zu können, implementiert diese Klasse das CustomNetworkingProtokoll und kann so
 direkt in der Klasse ihr MenuItem-Text zusammenstellen.
 
 
 
  ****   HINZUFÜGEN VON NEUEN NETWORKING ITEMS ***
 
 1. In der loadSettings() Methode von der Klasse NetworkingSettings im defaultSettings-Array einen neuen Eintrag erstellen
     1.1: Der erste Parameter ist der DisplayName, welcher in den Einstellungen als Beschreibung zum Item angezeigt wird
     1.2: Der zweite Parameter ist irgendein Property Name, 
            welcher theoretisch in einer belibigen Klasse existiert (Hier vor allem die NTWRKInfo-Klasse),
            mit dem dann später der effektive Wert des MenuItems gesucht wird
 2. Im AppDelegate (oder wo auch immer) kann dann die [getValueForOption:withObject:]-Methode aufgerufen werden, 
        mit einer Instanz der Klasse, welche die Property besitzt, auf welche 1.2 zeigt, und das Rückgabeobjekt zwischenspeichern.
 3. Im Moment werden nur Objekte mit dem NetworkingOptionType-Protokoll zurückgegeben, welche NSString und NSArray sind 
        { Stand: 16.05.2016 }
     3.1: Neue Klassen können einfach mit einer extension hinzugefügt werden oder durch Änderung des generischen Wertes der NetworkingOptionPropertyBinding Klasse. 
            Dann muss jedoch ggf. das AppDelegate angepasst werden!
 4. Falls das Objekt das CustomNetworkingMenuItem-Protokoll implementiert, soll bitte der Wert aus der menuItemValue-Property verwendet werden.
 
*/

import Cocoa

@objc
class Constants: NSObject {
    static let kScriptsDirectoryKey: NSString = NSString(string: "kScriptsDirectory")
    static let kScriptsBookmarkKey: NSString = NSString(string: "kScriptsBookmark")
    static let kEnumeratedKeyboardShortcutsEnabledKey: NSString = NSString(string: "kEnumeratedKeyboardShortcutsEnabled")
    static let kSystemWatchdogEnabledKey: NSString = NSString(string: "kSystemWatchdogEnabled")
    static let kShowCPUTemperatureEnabledKey: NSString = NSString(string: "kShowCPUTemperatureEnabled")
    static let kShowCPUInfo: NSString = NSString(string: "kShowCPUInfo")
    static let kShowCPUUsageEnabledKey: NSString = NSString(string: "kShowCPUUsageEnabled")
    static let kShowFansEnabledKey: NSString = NSString(string: "kShowFansEnabled")
    static let kShowLineInPowerEnabledKey: NSString = NSString(string: "kShowPowerEnabled")
    static let kShowNetworkInformationEnabledKey: NSString = NSString(string: "kShowNetworkInformationEnabled")
    
    static let kSettingsKVStoreDidChangeSettingsNotificationName = NSString(string: "kSettingsKVStoreDidChangeSettingsNotificationName")
}

@objc
protocol NetworkingOptionType {
    
}

extension NSString: NetworkingOptionType {}
extension NSArray: NetworkingOptionType {}


internal class NetworkingOptionPropertyBinding<T>: NSObject {
    var propertyName: String
    
    init(name: String) {
        self.propertyName = name
    }
    
    func isKindOfSelf(_ type: Any) -> Bool {
        return type is T
    }
}

internal class NetworkingOption: NSObject, NSCoding {
    var enabled: Bool = true
    var displayName: String!
    var bindingProperty: NetworkingOptionPropertyBinding<NetworkingOptionType>
    
    init(displayName: String, enabled: Bool, bindingPropertyName propertyName: String) {
        self.enabled = enabled
        self.displayName = displayName
        self.bindingProperty = NetworkingOptionPropertyBinding(name: propertyName)
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.enabled = aDecoder.decodeBool(forKey: "enabled")
        
        guard let displayName = aDecoder.decodeObject(forKey: "displayName") as? String else {
            return nil
        }
        
        guard let bindingPropertyName = aDecoder.decodeObject(forKey: "binding") as? String else {
            return nil
        }
        
        self.bindingProperty = NetworkingOptionPropertyBinding(name: bindingPropertyName)
        self.displayName = displayName
        
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(enabled, forKey: "enabled")
        aCoder.encode(displayName, forKey: "displayName")
        aCoder.encode(bindingProperty.propertyName, forKey: "binding")
    }
}

enum NetworkingSettingsError: Error {
    case indexOutOfBounds(maxIndex: Int)
    case targetIndexOutOfBounds(maxTargetIndex: Int)
    case optionDoesNotExist(option: NetworkingOption)
}

let networkingSettingsUserDefaultsKey: String = "networkingSettings"

/// represents the settings of the NETWORKING section
internal class NetworkingSettings: NSObject, NSCoding {
    private var settings: Array<NetworkingOption> = []
    
    var didChangeNetworkSettingsListner: (() -> Void)?
    
    // MARK: class functions
    class func loadSettings() -> NetworkingSettings {
        if let data = UserDefaults.standard.data(forKey: networkingSettingsUserDefaultsKey) {
            if let val = NSKeyedUnarchiver.unarchiveObject(with: data) as? NetworkingSettings {
                // successfully loaded networking settings from user defaults
                
                if val.settings.count > 0 {
                    return val
                }
            }
        }
        
        // can't load settings from user defaults => return settings with default values
        let defaultSettings: [NetworkingOption] = [
            NetworkingOption(displayName: "Host Name", enabled: true, bindingPropertyName: "hostName"),
            NetworkingOption(displayName: "Addresses", enabled: true, bindingPropertyName: "interfaces")
        ]
        
        let settings = NetworkingSettings(settings: defaultSettings)
        settings.synchronize()
        return settings
    }
    
    // MARK: initialize methods & NSCoding
    init(settings: [NetworkingOption]) {
        self.settings = settings
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        
        if let settings = aDecoder.decodeObject(forKey: "settings") as? [NetworkingOption] {
            self.settings = settings
        } else {
            return nil
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.settings, forKey: "settings")
    }
    
    // MARK: Settings modification methods
    func synchronize() {
        UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: self), forKey: networkingSettingsUserDefaultsKey)
        UserDefaults.standard.synchronize()
    }
    
    private func didChangeSettings() {
        synchronize()
        didChangeNetworkSettingsListner?()
    }
    
    
    func alterOption(_ option: NetworkingOption, atIndex index: Int) throws {
        if settings.count > index && index >= 0 {
            settings[index] = option
            didChangeSettings()
        } else {
            throw NetworkingSettingsError.indexOutOfBounds(maxIndex: settings.count - 1)
        }
    }
    
    func moveOptionAtIndex(_ index: UInt, toIndex: UInt) throws {
        if index >= UInt(settings.count) {
            throw NetworkingSettingsError.indexOutOfBounds(maxIndex: settings.count - 1)
        } else if toIndex > UInt(settings.count) {
            throw NetworkingSettingsError.targetIndexOutOfBounds(maxTargetIndex: settings.count)
        }
        
        settings.moveItemAtIndex(Int(index), toIndex: Int(toIndex))
        didChangeSettings()
    }
    
    func moveOption(_ option: NetworkingOption, afterOption targetOption: NetworkingOption) throws -> Void {
        if let fromIndex = settings.index(of: option) {
            if let targetIndex = settings.index(of: targetOption) {
                try moveOptionAtIndex(UInt(fromIndex), toIndex: UInt(targetIndex))
            } else {
                throw NetworkingSettingsError.optionDoesNotExist(option: targetOption)
            }
        } else {
            throw NetworkingSettingsError.optionDoesNotExist(option: option)
        }
    }
    
    func getOptionAtIndex(_ index: Int) throws -> NetworkingOption {
        if index >= settings.count || index < 0 {
            throw NetworkingSettingsError.indexOutOfBounds(maxIndex: settings.count - 1)
        }
        
        return settings[index]
    }
    
    func getSettings() -> [NetworkingOption] {
        return settings
    }
    
    func getEnabledOptions() -> [NetworkingOption] {
        return settings.filter {
            $0.enabled
        }
    }
    
    func getDisabledOptions() -> Array<NetworkingOption> {
        return settings.filter({
            !$0.enabled
        })
    }
    
    func addOption(_ option: NetworkingOption) {
        defer {
            didChangeSettings()
        }
        
        settings.append(option)
    }
    
    func getValueForOption(_ option: NetworkingOption, withObject object: AnyObject) -> NetworkingOptionType? {
        var outCount: UInt32 = 0
        let properties: UnsafeMutablePointer<objc_property_t?>! = class_copyPropertyList(type(of: object), &outCount)
        
        for i in 0..<Int(outCount) {
            let property = properties.advanced(by: i).pointee
            let namePtr: UnsafePointer<Int8> = property_getName(property)
            let name = NSString(format: "%s", namePtr) as String
            
            if name == option.bindingProperty.propertyName {
                if let val = object.value?(forKey: name) {
                    if option.bindingProperty.isKindOfSelf(val) {
                        return val as? NetworkingOptionType
                    }
                }
            }
        }
        
        return nil
    }
}

internal class SettingsKVStore: NSObject {
    // *** HELPER FUNCTIONS ***
    private func getBool(_ key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.dictionaryRepresentation().keys.contains(key) {
            return UserDefaults.standard.bool(forKey: key)
        } else {
            return defaultValue
        }
    }
    
    private func setBool(_ value: Bool, forKey key: String) -> Void {
        UserDefaults.standard.set(value, forKey: key)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.kSettingsKVStoreDidChangeSettingsNotificationName as String), object: self, userInfo: [
            NSString(string: "key"): NSString(string: key),
            NSString(string: "value"): NSNumber(value: value)
        ])
    }
    
    private func getVal(_ key: String) -> AnyObject? {
        return UserDefaults.standard.object(forKey: key) as AnyObject?
    }
    
    private func setVal(_ key: String, value: AnyObject) {
        UserDefaults.standard.set(value, forKey: key)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.kSettingsKVStoreDidChangeSettingsNotificationName as String), object: self, userInfo: [
            NSString(string: "key"): NSString(string: key),
            NSString(string: "value"): value
        ])
    }
    
    private func sync() {
        UserDefaults.standard.synchronize()
    }
    
    
    
    // *** MAIN CLASS ***
    
    static let sharedStore: SettingsKVStore = SettingsKVStore()
    
    internal var enumeratedKeyboardShortcutsEnabled: Bool = true {
        didSet(oldValue) {
            if enumeratedKeyboardShortcutsEnabled != oldValue {
                setBool(enumeratedKeyboardShortcutsEnabled, forKey: Constants.kEnumeratedKeyboardShortcutsEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var systemWatchdogEnabled: Bool = true {
        didSet(oldValue) {
            if systemWatchdogEnabled != oldValue {
                setBool(systemWatchdogEnabled, forKey: Constants.kSystemWatchdogEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var showCPUTemperatureEnabled: Bool = true {
        didSet(oldValue) {
            if showCPUTemperatureEnabled != oldValue {
                setBool(showCPUTemperatureEnabled, forKey: Constants.kShowCPUTemperatureEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var showCPUInfo: Bool = true {
        didSet(oldValue) {
            if showCPUInfo != oldValue {
                setBool(showCPUInfo, forKey: Constants.kShowCPUInfo as String)
                sync()
            }
        }
    }
    
    internal var showCPUUsageEnabled: Bool = true {
        didSet(oldValue) {
            if showCPUUsageEnabled != oldValue {
                setBool(showCPUUsageEnabled, forKey: Constants.kShowCPUUsageEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var showFansEnabled: Bool = true {
        didSet(oldValue) {
            if showFansEnabled != oldValue {
                setBool(showFansEnabled, forKey: Constants.kShowFansEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var showLineInPowerEnabled: Bool = true {
        didSet(oldValue) {
            if showLineInPowerEnabled != oldValue {
                setBool(showLineInPowerEnabled, forKey: Constants.kShowLineInPowerEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var showNetworkInformationEnabled: Bool = true {
        didSet(oldValue) {
            if showNetworkInformationEnabled != oldValue {
                setBool(showNetworkInformationEnabled, forKey: Constants.kShowNetworkInformationEnabledKey as String)
                sync()
            }
        }
    }
    
    internal var networkingSettings: ImplicitlyUnwrappedOptional<NetworkingSettings>
    
    private var _scriptsDir: URL!
    internal var scriptsDirectory: URL? {
        get {
            if let dir = self._scriptsDir {
                // *** WENN DIE PROPERTY BEREITS GESETZT WURDE, SOLL SIE EINFACH ZURÜCKGEGEBEN WERDEN ***
                return dir
            } else {
                // *** PROPERTY VON DEN NSUSERDEFAULTS LESEN ***
                if self.appIsSandboxed {
                    if let bookmark = getVal(Constants.kScriptsBookmarkKey as String) as? Data {
                        do {
                            var isStale: ObjCBool = false
                            let url = try NSURL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) as URL
                            
                            self._scriptsDir = url
                            return url
                        } catch (let exception) {
                            print("Exception \(exception)") /// @todo Handle exception
                        }
                    }
                } else {
                    if let data = getVal(Constants.kScriptsDirectoryKey as String) as? Data {
                        
                        if let val = NSKeyedUnarchiver.unarchiveObject(with: data) as? URL {
                            // *** WERT AUS DEN USER-DEFAULTS AUF KORREKTHEIT PRÜFEN ***
                            var isDirectory: ObjCBool = false
                            if FileManager.default.fileExists(atPath: val.path, isDirectory: &isDirectory) {
                                if isDirectory.boolValue {
                                    // Alles korrekt
                                    
                                    self._scriptsDir = val // Direktes setzen, da wir einen vorhandenen Wert nicht wieder in die Defaults schreiben müssen
                                    return val
                                }
                            }
                        }
                    }
                    // else: Wert aus den NSUserDefaults war nicht valid => Vorgehen als ob keiner da gewesen wäre
                }
                
                // ~/Documents/Scripts Pfad bekommen
                let documents = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
                let path = NSString(string: documents).appendingPathComponent("Scripts") as String
                if let url = URL(fileURLWithPath: path, isDirectory: true) as URL! {
                    let finalPath = url.path
                    
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: finalPath, isDirectory: &isDirectory) {
                        // *** ~/Documents/Scripts ORDNER EXISTIERT BEREITS => DIESE URL AUCH ZURÜCKGEBEN ***
                        if isDirectory.boolValue {
                            self.scriptsDirectory = url // Über den Setter dieser Property, damit auch die User-Defaults gesetzt werden
                            return self._scriptsDir
                        }
                    }
                    
                    // *** Scripts ORDNER EXISTERT NOCH NICHT => ERSTELLEN UND DANN DEN PFAD ZURÜCKGEBEN ***
                    do {
                        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
                        
                        // Ein eigenes Ordner-Icon erstellen
                        let icon = NSImage(named: "scriptsDir")
                        NSWorkspace.shared().setIcon(icon, forFile: finalPath, options: NSWorkspaceIconCreationOptions(rawValue: 0))
                        
                        self.scriptsDirectory = url // Über den Setter dieser Property, damit auch die User-Defaults gesetzt werden
                        return url
                    } catch (let exception) {
                        print(exception)
                        return nil
                    }
                } else {
                    fatalError("Can't create URL") // Should also never happen that we can't create a URL
                }
            }
        }
        
        set {
            if newValue == nil {
                fatalError("Can't set a nil value for the scripts directory")
            }
            
            self._scriptsDir = newValue
            
            if self.appIsSandboxed {
                do {
                    let bookmark = try newValue!.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    /*var isStale: ObjCBool = false
                    let url = try (NSURL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) as URL)*/
                    setVal(Constants.kScriptsBookmarkKey as String, value: bookmark as AnyObject)
                } catch (let e) {
                    print("EXCEPTION \(e)") /// @todo Handle exception
                }
            } else {
                setVal(Constants.kScriptsDirectoryKey as String, value: NSKeyedArchiver.archivedData(withRootObject: self._scriptsDir) as AnyObject)
            }
            
            sync()
        }
    }
    
    internal var appIsSandboxed: Bool {
        get {
            let environment = ProcessInfo.processInfo.environment
            return environment.keys.contains("APP_SANDBOX_CONTAINER_ID")
        }
    }
    
    override init() {
        super.init()
        
        self.enumeratedKeyboardShortcutsEnabled = getBool(Constants.kEnumeratedKeyboardShortcutsEnabledKey as String, defaultValue: false)
        self.systemWatchdogEnabled = getBool(Constants.kSystemWatchdogEnabledKey as String, defaultValue: true)
        self.showCPUTemperatureEnabled = getBool(Constants.kShowCPUTemperatureEnabledKey as String, defaultValue: true)
        self.showCPUInfo = getBool(Constants.kShowCPUInfo as String, defaultValue: true)
        self.showCPUUsageEnabled = getBool(Constants.kShowCPUUsageEnabledKey as String, defaultValue: true)
        self.showFansEnabled = getBool(Constants.kShowFansEnabledKey as String, defaultValue: false)
        self.showLineInPowerEnabled = getBool(Constants.kShowLineInPowerEnabledKey as String, defaultValue: true)
        self.showNetworkInformationEnabled = getBool(Constants.kShowNetworkInformationEnabledKey as String, defaultValue: true)
        
        self.networkingSettings = NetworkingSettings.loadSettings()
        self.networkingSettings.didChangeNetworkSettingsListner = { _ -> Void in
            print("Did change networking settings")
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.kSettingsKVStoreDidChangeSettingsNotificationName as String), object: self, userInfo: [
                NSString(string: "key"): NSString(string: "networkingInformation"),
                NSString(string: "value"): self.networkingSettings
            ])
        }
    }
    
    internal func accessScriptsURLContents(handler: (() -> Void)!) -> Void {
        (self.scriptsDirectory as NSURL?)?.accessResource(handler)
    }
}


// MARK: Helper extensions / functions
extension Array {
    public mutating func moveItemAtIndex(_ fromIndex: Int, toIndex: Int) {
        if fromIndex == toIndex {
            return
        }
        
        self.insert(self.remove(at: fromIndex), at: toIndex > self.count ? self.count : toIndex)
    }
}

