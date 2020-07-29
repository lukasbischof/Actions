//
//  AppDelegate.m
//  Actions
//
//  Created by Lukas Bischof on 22.12.14.
//  Copyright (c) 2014 Lukas. All rights reserved.
//

#import "AppDelegate.h"
#import "NSApplication+relaunch.h"
#import "NSArray+Reverse.h"
#import "NSURL+sandboxing.h"
#import "CPUUsageWatcher.h"
#import "CPUStaticInformation.h"
#import "SMCWrapper.h"
#import "NTWRKInfo.h"
#import "Actions-Swift.h"
#import "FastHTTPRequest.h"
#import "ExecutableFile.h"
#import <netinet/in.h>

/**
 @done Der Bonjour-Titel ist im Moment immer da => Wenn kein Service verfügbar ist: entfernen
 @partlyDone Sandboxing einrichten => SMC deaktivieren
 @todo (Bundles) und Automator files akzeptieren
 @todo Icon für die verschiedenen Skrip Typen verwenden
 @todo iOS App für die Fernsteuerung entwickeln
 @todo Socket in der Mac-App öffnen und per Bonjour verbreiten
 @todo Bei Erstverbindung Pairing-Code verlangen und dann nie mehr wieder
 @todo Einfache Verschlüsselung implementieren, angelehnt an das HTTPS Protokoll
 @todo IDEA Der Client (iPhone) und der Server (Mac) erstellen bei der Installation ein Zertifikat, dass sie dann beim Pairing austauschen
           Mit den Publikschlüsseln wird dann die Nachricht verschlüsselt und mit den Privatschlüsseln beim Partner wieder entschlüsselt.
           Zudem wird als Signatur die Nachricht zusammen mit dem Pairingcode als Hash (SHA256) mitgeschickt
 @todo OPTIONAL WatchKit extension für das Steuern direkt von der AppleWatch aus
 @todo OPTIONAL-REQUIRED Notification Widget für die iOS App (und Mac App?)
 @todo Mehr Networking-Optionen einbauen
*/

#define SCRIPTS_DIRECTORY @"/Users/Lukas/Desktop/Development/iOS & Mac OS X/Mac/Utilities/Actions/Scripts/"
#define SYSTEM_WATCHDOG_UPDATE_INTERVAL 3

// *** Tags für die Menuitems ***
static const NSInteger kCPUTempMenuItemTag = 2;

// Dies ist der Tag für die CPU Aktivität. Da die abhängig von der Anzahl von Kernen, gibt es keine Struktur wie kCPUCore1MenuItemTag, kCPUCore2MenuItemTag, ..., sondern der Kern 1 hat dieses Tag und danach hat der n-te Kern das Tag kCPUActivityBaseCoreMenuItemTag + n - 1
static const NSInteger kCPUActivityBaseCoreMenuItemTag = 3;

// Tag für die Lüfter, bzw. der Menu-Eintrag für das erste Lüfter-Element. Die Titel haben keinen Tag ("Fan"-Titel)
#define kFanBaseMenuItemTag (kCPUActivityBaseCoreMenuItemTag + self.cpuUsageWatcher.numberOfKerns)

static const NSInteger kSystemTotalDCINPowerMenuItemTag = 100;

static NSString *const kActionExecutablePredicate = @"(NOT path BEGINSWITH[cd] '.') AND (path ENDSWITH '.scpt' OR path ENDSWITH '.workflow' OR path ENDSWITH '.actn' OR pathExtension = '')";

// Dies ist der Block der als Completion-Handler dem ErrorViewController mit gegeben wird, falls beim Bonjour-Resolving ein Fehler aufgetreten ist
typedef void(^_Nullable errorViewControllerCompletionHandler)(enum ErrorViewControllerButton);

@interface AppDelegate () <NSObject, NSMenuDelegate, NSNetServiceDelegate, CPUUsageWatcherDelegate, NTWRKBonjourDelegate>
@property (strong, nonatomic) NSStatusItem *item;
@property (strong, nonatomic) NSThread *updateThread;
@property (strong, nonatomic) NSWindowController *settingsWindowController;

@property (nonatomic, readonly) NSInteger fanCount;
@property (strong, nonatomic) CPUUsageWatcher *cpuUsageWatcher;
@property (strong, nonatomic) SMCWrapper *smcWrapper;
@property (strong, nonatomic) NTWRKInfo *networkInformation;
@property (strong, nonatomic) CPUStaticInformation *cpuInformation;

@property (strong, nonatomic) NSMenuItem *bonjourMenuItem;
@property (readonly, nonatomic) BOOL shouldShowBonjourSection;
@end

@implementation AppDelegate

#pragma mark - Application Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Get Fan count
    if (![SettingsKVStore sharedStore].appIsSandboxed) {
        NSError *error;
        NSInteger count = [SMCWrapper getFanCountWithError:&error];

        if (error) {
            _fanCount = -1;
            NSLog(@"Can't get fan count: %@", error);
            /// @todo Handle error
        } else {
            _fanCount = count;
        }
    }

    // Setup CPUUsageWatcher
    self.cpuUsageWatcher = [[CPUUsageWatcher alloc] initWithUpdateInterval:SYSTEM_WATCHDOG_UPDATE_INTERVAL];
    self.cpuUsageWatcher.delegate = self;

    // Setup CPUInformation
    self.cpuInformation = [CPUStaticInformation sharedInfo];

    // Setup Network Information
    self.networkInformation = [NTWRKInfo new];
    self.networkInformation.bonjourDelegate = self; // automatically starts searching

    // Setup Statusbar Item
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.item.title = @"ACT";
    self.item.highlightMode = YES;

    // Misc
    [self updateMenu];
    [self setupObservers];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application

    [self menuDidClose:self.item.menu]; // release thread, if it hasn't been done yet
    [self removeObservers];
}

#pragma mark - Observers

- (void)setupObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveSettingsDidChangeNotification:)
                                                 name:[Constants kSettingsKVStoreDidChangeSettingsNotificationName]
                                               object:[SettingsKVStore sharedStore]];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveSettingsDidChangeNotification:(NSNotification *)notification {
    [self updateMenu];
}

#pragma mark - Menu Setup

- (NSArray<NSURL *> *)getDirectoryContents:(NSURL *)directory {
    NSError *error;
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory
                                                            includingPropertiesForKeys:nil
                                                                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                 error:&error];

    if (error) {
        #ifdef DEBUG
        NSLog(@"error: %@", error);
        #endif

        return nil;
    }

    // Ordner und Scripts herausfiltern
    files = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:kActionExecutablePredicate]];
    [files sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSURL *__nonnull url1 = (NSURL *) obj1;
        NSURL *__nonnull url2 = (NSURL *) obj2;

        return [url1.lastPathComponent compare:url2.lastPathComponent options:0];
    }];

    return files;
}

- (NSMenu *)menuForDirectory:(NSURL *)directory {
    NSMenu *__block menu;
    [directory accessResourceUsingBlock:^(void) {
        menu = [self menuForDirectory:directory isRoot:YES];
    }];

    return menu;
}

- (NSString *)removeFileExtension:(NSString *)path {
    if (path.length == 0) {
        WLog(@"path argument is empty (length==0)");
        return @"";
    }

    NSString *const separator = @".";
    NSMutableArray *components = [[path componentsSeparatedByString:separator] mutableCopy];

    if (components.count == 1)
        return path;
    else {
        [components removeObjectAtIndex:components.count - 1];
        return [components componentsJoinedByString:separator];
    }
}

- (NSMenu *)menuForDirectory:(NSURL *)directory isRoot:(BOOL)isRoot {
    if (!directory)
        return nil;

    NSArray *scripts = [self getDirectoryContents:directory];

    NSUInteger i = 0;
    NSMenu *menu = [[NSMenu alloc] init];
    for (NSURL *script in scripts) {
        NSString *extension = [script pathExtension];
        NSString *displayName = [self removeFileExtension:script.lastPathComponent];

        BOOL isDir;
        NSAssert([[NSFileManager defaultManager] fileExistsAtPath:SWF(@"%@", script.path) isDirectory:&isDir], @"For some reason the file %@%@ doesn't exist", directory, script);

        BOOL isScript = ([extension isEqualToString:@"scpt"] && !isDir) || ([extension isEqualToString:@"workflow"] && isDir) || ([extension isEqualToString:@"actn"] && isDir);
        BOOL enumerationEnabled = [SettingsKVStore sharedStore].enumeratedKeyboardShortcutsEnabled;

        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:displayName
                                                          action:isScript ? @selector(startAction:) : NULL
                                                   keyEquivalent:i < 10 && isRoot && isScript && enumerationEnabled ? SWF(@"%lu", (unsigned long) ++i) : @""];

        if (isScript) {
            ExecutableFile *file = [[ExecutableFile alloc] initWithURL:script];
            if (!file) {
                ELog(@"Can't create executable file");
                continue;
            }

            menuItem.representedObject = file;
        }

        if (!isScript && isDir) {
            NSMenu *submenu = [self menuForDirectory:script isRoot:NO];
            submenu.title = script.relativePath;

            // Empty directory
            if (submenu.itemArray.count <= 0)
                continue;

            [menuItem setSubmenu:submenu];
        } else if (!isScript && !isDir) {
            // An unknown file, probably a hidden one
            continue;
        }

        [menu addItem:menuItem];
    }

    return menu;
}

- (void)updateMenu {
    // Setzt das ganze Menu neu auf

    NSMenu *menu;
    if (self.item.menu) {
        menu = self.item.menu;
        [menu removeAllItems];
    } else {
        menu = [NSMenu new];
    }

    // ACTIONS MENU
    NSURL *scriptsDirectory = [SettingsKVStore sharedStore].scriptsDirectory;
    if (!scriptsDirectory) {
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Can't get scripts folder" action:nil keyEquivalent:@""]];
    } else {
        menu = [self menuForDirectory:scriptsDirectory]; // this method requires a tailing "/"
    }

    NSMenuItem *mainTitle = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    mainTitle.attributedTitle = [[NSAttributedString alloc] initWithString:@"Actions" attributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:14]}];
    [menu insertItem:mainTitle atIndex:0];

    // BONJOUR
    if (self.shouldShowBonjourSection) {
        NSMenuItem *bonjourTitle = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        bonjourTitle.attributedTitle = [[NSAttributedString alloc] initWithString:@"\nBonjour" attributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:14]}];
        [menu addItem:bonjourTitle];

        self.bonjourMenuItem = [[NSMenuItem alloc] initWithTitle:@"Websites" action:nil keyEquivalent:@""];
        [menu addItem:self.bonjourMenuItem];
    }

    // SYSTEM WATCHDOG
    [menu addItem:[NSMenuItem separatorItem]];
    [self addSystemWatchdogItems:&menu];
    [menu addItem:[NSMenuItem separatorItem]];

    // APP CONTROLS
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Settings"
                                             action:@selector(openSettings:)
                                      keyEquivalent:@","]];

    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit"
                                             action:@selector(quit:)
                                      keyEquivalent:@"q"]];

    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Relaunch"
                                             action:@selector(relaunch:)
                                      keyEquivalent:@"r"]];

    menu.delegate = self;

    self.item.menu = menu;
}

- (void)updateBonjourMenuItem {
    static NSImage *bonjourImage;
    if (!bonjourImage) {
        bonjourImage = [NSImage imageNamed:NSImageNameBonjour];
        [bonjourImage setSize:NSMakeSize(15, 15)];
    }

    if (self.networkInformation.activeServices.count > 0) {
        NSMenu *submenu = [[NSMenu alloc] init];

        for (NSNetService *netService in self.networkInformation.activeServices) {
            NSMenuItem *serviceItem = [[NSMenuItem alloc] initWithTitle:netService.name action:@selector(bonjourServiceClicked:) keyEquivalent:@""];
            serviceItem.image = bonjourImage;
            serviceItem.representedObject = netService;
            [submenu addItem:serviceItem];
        }

        self.bonjourMenuItem.submenu = submenu;
    } else {
        self.bonjourMenuItem.hidden = YES;
    }
}

- (void)addSystemWatchdogItems:(NSMenu **)menu {
    if (![SettingsKVStore sharedStore].systemWatchdogEnabled)
        return;

    NSMenuItem *titleItem; // generally used variable

    BOOL isSandboxed = [SettingsKVStore sharedStore].appIsSandboxed;
    BOOL showCPUTitleItem = ([SettingsKVStore sharedStore].showCPUTemperatureEnabled && !isSandboxed) ||
        [SettingsKVStore sharedStore].showCPUUsageEnabled ||
        [SettingsKVStore sharedStore].showCPUInfo;
    BOOL showFansSegment = [SettingsKVStore sharedStore].showFansEnabled && !isSandboxed;
    BOOL showPowerSegment = [SettingsKVStore sharedStore].showLineInPowerEnabled && !isSandboxed;
    BOOL showNetworkingSegment = [SettingsKVStore sharedStore].showNetworkInformationEnabled;

    // *** TITLE ***
    titleItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    titleItem.attributedTitle = [[NSAttributedString alloc] initWithString:@"System Watchdog" attributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:14]}];
    [*menu addItem:titleItem];


    // *** CPU TEMP ***
    if (showCPUTitleItem) {

        // Nur wenn auch ein CPU Control-Item angezeigt wird einen Titel hinzufügen
        titleItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        titleItem.attributedTitle = [[NSAttributedString alloc] initWithString:@"CPU" attributes:@{}];
        [*menu addItem:titleItem];
    }

    if ([SettingsKVStore sharedStore].showCPUTemperatureEnabled && !isSandboxed) {
        NSMenuItem *cpuTempItem = [[NSMenuItem alloc] initWithTitle:@"##CPU_TEMP##" action:nil keyEquivalent:@""];
        cpuTempItem.enabled = NO;
        cpuTempItem.tag = kCPUTempMenuItemTag;

        [*menu addItem:cpuTempItem];
    }

    // *** CPU INFO ***
    if ([SettingsKVStore sharedStore].showCPUInfo) {
        NSMenuItem *frequency = [[NSMenuItem alloc] initWithTitle:SWF(@"Frequency: %.2f GHz", self.cpuInformation.frequency) action:nil keyEquivalent:@""];
        frequency.enabled = NO;

        [*menu addItem:frequency];

        NSMenuItem *brand = [[NSMenuItem alloc] initWithTitle:SWF(@"Brand: %@", self.cpuInformation.brand) action:nil keyEquivalent:@""];
        frequency.enabled = NO;

        [*menu addItem:brand];
    }


    // *** CPU ACTIVITY ***
    if ([SettingsKVStore sharedStore].showCPUUsageEnabled) {
        for (NSUInteger i = 0; i < self.cpuUsageWatcher.numberOfKerns; i++) {
            NSMenuItem *cpuActivityItem = [[NSMenuItem alloc] initWithTitle:SWF(@"Core %lu Activity: 0%%", (unsigned long) i + 1) action:nil keyEquivalent:@""];
            cpuActivityItem.enabled = NO;
            cpuActivityItem.tag = kCPUActivityBaseCoreMenuItemTag + i;

            [*menu addItem:cpuActivityItem];
        }
    }


    // *** FANS ***
    if (showFansSegment && !isSandboxed) {
        if (self.fanCount < 0) {
            [*menu addItem:[[NSMenuItem alloc] initWithTitle:@"Can't get fan information" action:nil keyEquivalent:@""]];
        } else {
            const NSArray *strings = @[@"ID", @"ACTUAL_SPEED", @"MINIMUM_SPEED", @"MAXIMUM_SPEED", @"TARGET_SPEED", @"MODE"];

            for (NSUInteger i = 0; i < self.fanCount; i++) {
                // Fan-Abschnitt Titel
                titleItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
                titleItem.attributedTitle = [[NSAttributedString alloc] initWithString:SWF(@"%@FAN %lu", showCPUTitleItem ? @"\n" : @"", (unsigned long) i + 1) attributes:@{}];
                [*menu addItem:titleItem];

                // Die einzelenen Einträge
                NSUInteger j = 0;
                for (NSString *string in strings) {
                    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:SWF(@"##FAN_%lu_%@##", (unsigned long) i + 1, string) action:nil keyEquivalent:@""];
                    item.tag = kFanBaseMenuItemTag + (i * strings.count) + j++;

                    [*menu addItem:item];
                }
            }
        }
    }


    // *** POWER ***
    if (showPowerSegment && !isSandboxed) {
        titleItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        titleItem.attributedTitle = [[NSAttributedString alloc] initWithString:SWF(@"%@POWER", showFansSegment || showCPUTitleItem ? @"\n" : @"") attributes:@{}];
        [*menu addItem:titleItem];

        NSMenuItem *totalDCIN = [[NSMenuItem alloc] initWithTitle:@"##TOTAL_DC-IN##" action:nil keyEquivalent:@""];
        totalDCIN.tag = kSystemTotalDCINPowerMenuItemTag;
        [*menu addItem:totalDCIN];
    }



    // *** NETWORK ***
    if (showNetworkingSegment) {
        titleItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        titleItem.attributedTitle = [[NSAttributedString alloc] initWithString:SWF(@"%@NETWORKING", showFansSegment || showCPUTitleItem || showPowerSegment ? @"\n" : @"") attributes:@{}];
        [*menu addItem:titleItem];

        NetworkingSettings *settings = [SettingsKVStore sharedStore].networkingSettings;
        for (NetworkingOption *option in [settings getEnabledOptions]) {
            [self addMenuItemsForNetworkingOption:option intoMenu:menu];
        }
    }
}

- (void)addMenuItemsForNetworkingOption:(NetworkingOption *_Nonnull)option intoMenu:(NSMenu *__autoreleasing _Nonnull

*_Null_unspecified)menu
{
    NSObject <NetworkingOptionType> *val = (NSObject <NetworkingOptionType> *) [[SettingsKVStore sharedStore].networkingSettings getValueForOption:option withObject:self.networkInformation];

    if ([val isKindOfClass:[NSArray class]]) {
        NSMenuItem *title = [[NSMenuItem alloc] initWithTitle:SWF(@"%@:", option.displayName)
                                                       action:nil
                                                keyEquivalent:@""];
        [*menu addItem:title];

        for (id <NSObject> i in (NSArray *) val) {
            NSMenuItem *item;
            if ([i conformsToProtocol:@protocol(CustomNetworkingMenuItem)]) {
                __kindof NSObject <CustomNetworkingMenuItem> *i2 = (NSObject <CustomNetworkingMenuItem> *) i;
                item = [[NSMenuItem alloc] initWithTitle:SWF(@"\t%@", i2.menuItemValue)
                                                  action:nil
                                           keyEquivalent:@""];
            } else {
                item = [[NSMenuItem alloc] initWithTitle:SWF(@"\t%@", i)
                                                  action:nil
                                           keyEquivalent:@""];
            }

            [*menu addItem:item];
        }
    } else {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:SWF(@"%@: %@", option.displayName, val)
                                                      action:nil
                                               keyEquivalent:@""];
        [*menu addItem:item];
    }
}

#pragma mark - User Interaction

- (void)startAction:(id)sender {
    NSMenuItem *item = (NSMenuItem *) sender;

    ExecutableFile *file = item.representedObject;
    if (file) {
        NSError *error = [file runAction];
        if (error) {
            NSString *type = file.type == ExecutableFileTypeAppleScript ? @"script" : @"workflow";
            NSError *newError = [NSError errorWithDomain:error.domain code:error.code userInfo:@{
                [Constants kErrorViewControllerTitleKey]: SWF(@"Can't execute %@", type),
                NSLocalizedDescriptionKey: error.localizedDescription,
                NSLocalizedRecoverySuggestionErrorKey: @"Check your script/workflow"
            }];

            ErrorViewController *errorVC = [ErrorViewController viewControllerWithError:newError];
            [errorVC presentViewControllerAsModalWindow:errorVC];
            WLog(@"error: %@", error); /// @todo Handle error!
        }
    }

    /*NSLog(@"%@", item.representedObject);

    NSMutableString *path = [NSMutableString stringWithString:SCRIPTS_DIRECTORY];
    NSMutableArray *directories = [@[] mutableCopy];
    NSMenu *currentMenu = item.menu;
    while (currentMenu != nil) {
        [directories addObject:currentMenu.title];
        currentMenu = currentMenu.supermenu;
    }

    [directories invert];
    [directories enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [path appendString:SWF(@"%@%@", obj, idx > 0 ? @"/" : @"")]; // Makro SCRIPTS_DIRECTORY hat bereits ein "/"
    }];

    [path appendString:SWF(@"%@.scpt", item.title)];

    NSURL *url = [NSURL fileURLWithPath:path];
    NSDictionary *errors;
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:url
                                                                        error:&errors];
    if (errors && errors.count > 0) {
        NSLog(@"ERROR: %@", errors);
        return;
    }

    errors = nil;
    [appleScript executeAndReturnError:&errors];

    if (errors && errors.count > 0) {
        NSLog(@"ERROR WHEN EXECUTING: %@", errors);
        return;
    }*/
}

- (void)bonjourServiceClicked:(NSMenuItem *)sender {
    NSAssert([sender.representedObject isKindOfClass:[NSNetService class]], @"representedObject isn't a NSNetService in %s", __PRETTY_FUNCTION__);

    [self resolveNetService:sender.representedObject];
}

- (void)openSettings:(NSMenuItem *)sender {
    if (![sender isKindOfClass:[NSMenuItem class]])
        return;

    //NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Settings" bundle:nil];
    self.settingsWindowController = [storyboard instantiateInitialController];
    [self.settingsWindowController loadWindow];
    [self.settingsWindowController showWindow:self];
    [self.settingsWindowController.window makeKeyAndOrderFront:nil];
    [self.settingsWindowController.window setLevel:NSStatusWindowLevel];



    /*NSViewController *viewController = [storyboard instantiateInitialController];
    //[viewController presentViewController:viewController asPopoverRelativeToRect:self.item.button.bounds ofView:self.item.button preferredEdge:NSRectEdgeMinY behavior:NSPopoverBehaviorApplicationDefined];
    [viewController presentViewControllerAsModalWindow:viewController];*/
}

- (void)relaunch:(id)sender {
    [[NSApplication sharedApplication] relaunchAfterDelay:.5];
}

- (void)quit:(id)sender {
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.1];
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    if ([SettingsKVStore sharedStore].systemWatchdogEnabled) {
        if ([SettingsKVStore sharedStore].showCPUUsageEnabled)
            [self.cpuUsageWatcher startWatching];

        if (![SettingsKVStore sharedStore].appIsSandboxed) {
            if ([SettingsKVStore sharedStore].showCPUTemperatureEnabled ||
                [SettingsKVStore sharedStore].showFansEnabled ||
                [SettingsKVStore sharedStore].showLineInPowerEnabled) {

                // Der SMC wird im update thread benötigt
                self.smcWrapper = [SMCWrapper wrapper];

                self.updateThread = [[NSThread alloc] initWithTarget:self selector:@selector(updateThreadMain) object:nil];
                self.updateThread.name = @"Update Thread";
                [self.updateThread start];
            }
        }
    }
}

- (void)updateThreadMain {
    // Wird nie ausgeführt, falls AppSandboxing aktiviert ist, weil dann der Thread in der -[AppDelegate menuWillOpen:] Methode nie initialisiert wird

    @autoreleasepool {
        do {
            if ([[NSThread currentThread] isCancelled])
                return;


            __weak typeof(self) weakSelf = self;
            __block SMCCPUInfo *cpuInfo = [weakSelf.smcWrapper getCPUInformation];
            __block NSArray<SMCFanInfo *> *fanInfos = [weakSelf.smcWrapper getFanInformation];
            __block SMCPowerInfo *powerInfo = [weakSelf.smcWrapper getPowerInformation];

            dispatch_async(dispatch_get_main_queue(), ^{
                NSMenuItem *item;

                // CPU
                if ([SettingsKVStore sharedStore].showCPUTemperatureEnabled) {
                    item = [weakSelf.item.menu itemWithTag:kCPUTempMenuItemTag];
                    item.title = SWF(@"Temperature: %.2f °C", cpuInfo.temperature);
                }

                // Fans
                if ([SettingsKVStore sharedStore].showFansEnabled) {
                    const NSArray<NSArray<NSString *> *> *labels = @[
                        @[@"Id", @""],
                        @[@"Actual Speed", @"RPM"],
                        @[@"Minimum Speed", @"RPM"],
                        @[@"Maximum Speed", @"RPM"],
                        @[@"Target Speed", @"RPM"],
                        @[@"Mode", @""]
                    ];

                    // Iterate over every fan
                    for (NSUInteger i = 0; i < self.fanCount; i++) {
                        SMCFanInfo *fanInfo = fanInfos[i];
                        NSArray<NSString *> *values = @[
                            fanInfo.ID,
                            SWF(@"%.2f", fanInfo.actualSpeed),
                            SWF(@"%.2f", fanInfo.minimumSpeed),
                            SWF(@"%.2f", fanInfo.maximumSpeed),
                            SWF(@"%.2f", fanInfo.targetSpeed),
                            NSStringFromSMCFanMode(fanInfo.mode)
                        ];

                        // Iterate over fields of the SMCFanInfo class
                        for (NSUInteger j = 0; j < labels.count; j++) {
                            item = [weakSelf.item.menu itemWithTag:kFanBaseMenuItemTag + (i * labels.count) + j];
                            item.title = SWF(@"%@: %@ %@", labels[j][0], values[j], labels[j][1]);
                        }
                    }
                }

                // Power
                if ([SettingsKVStore sharedStore].showLineInPowerEnabled) {
                    NSMenuItem *item = [self.item.menu itemWithTag:kSystemTotalDCINPowerMenuItemTag];
                    item.title = SWF(@"System Total DC-IN: %.2f W", powerInfo.totalSystemDC_IN);
                }
            });

            [NSThread sleepForTimeInterval:SYSTEM_WATCHDOG_UPDATE_INTERVAL];
        } while (true);
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    if (self.updateThread) {
        [self.updateThread cancel];
        self.updateThread = nil;
        self.smcWrapper = nil; // deallokiert den SMC automatisch (Dank ARC :))
    }

    if (self.cpuUsageWatcher.isWatching)
        [self.cpuUsageWatcher stopWatching];
}

#pragma mark - CPUUsageWatcherDelegate

- (void)cpuUsageWatcher:(CPUUsageWatcher *)watcher didReceiveError:(NSError *)error {
    /// @todo handle error
    NSLog(@"CPU USAGE WATCHER ERROR: %@", error);
}

- (void)cpuUsageWatcher:(CPUUsageWatcher *)watcher didUpdateUsageInformation:(CPUUsageInformation *)information {
    if (information.cores.count <= 0) {
        NSLog(@"CAN'T GET CPU ACTIVITY INFO: NO INFOTMATION IN %s", __PRETTY_FUNCTION__);
        return;
    } else if (information.cores.count != watcher.numberOfKerns) {
        NSLog(@"CAN'T GET CPU ACTIVITY INFO: NUMBER OF KERNS ISN'T EQUAL TO THE COUNT OF THE INFORMATION ARRAY IN %s", __PRETTY_FUNCTION__);
        return;
    }

    for (NSUInteger i = 0; i < information.cores.count; i++) {
        CPUCore *core = information.cores[i];
        NSMenuItem *item = [self.item.menu itemWithTag:kCPUActivityBaseCoreMenuItemTag + i];
        item.title = SWF(@"Core %lu Activity: %.2f%%", (unsigned long) i + 1, core.percent * 100.0);
    }
}

#pragma mark - NTWRKBonjourDelegate

- (void)networkInfo:(NTWRKInfo *)info cantSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"cant search: %@", errorDict);
}

- (void)networkInfo:(NTWRKInfo *)info didFindServices:(NSArray<NSNetService *> *)services previousActiveServicesCount:(NSNumber *)count {
    NSUInteger previousCount = [count unsignedIntegerValue];

    if (services.count > 0 && previousCount <= 0) {
        // found completely new services

        [self updateMenu];
        [self updateBonjourMenuItem]; // Must be seperately called, because updateMenu sets only the title and menuItem up, but not the submenu
    } else if (services.count > 0 && previousCount > 0) {
        // add new services

        [self updateBonjourMenuItem];
    } else {
        ILog(@"called delegate method, but no new services were found");
    }

    /*if (self.shouldShowBonjourSection)
        [self updateBonjourMenuItem];
    else
        [self updateMenu];

    NSLog(@"did find services: %@", services);*/
}

- (void)networkInfo:(NTWRKInfo *)info didRemoveServices:(NSArray<NSNetService *> *_Nonnull)services previousActiveServicesCount:(NSNumber *)count {
    NSUInteger previousCount = [count unsignedIntegerValue];
    if (services.count == previousCount) {
        // all services were removed

        [self updateMenu]; // hide the entire bonjour section
    } else {
        // Just some services were removed

        [self updateBonjourMenuItem];
    }

    /*if (self.shouldShowBonjourSection)
        [self updateBonjourMenuItem];
    else
        [self updateMenu];
    NSLog(@"did remove services: %@", services);*/
}

#pragma mark - NSNetServiceDelegate & common bonjour options

- (void)resolveNetService:(NSNetService *_Nonnull)netService {
    if (!netService.delegate || ![netService.delegate isEqual:self]) {
        netService.delegate = self;
    }

    [netService resolveWithTimeout:10];
}

static inline void presentError(NSDictionary *__nonnull userInfo, NSUInteger code) {
    NSError *errorObj = [[NSError alloc] initWithDomain:NSNetServicesErrorDomain code:code userInfo:userInfo];

    ErrorViewController *errorVC = [ErrorViewController viewControllerWithError:errorObj];
    [errorVC presentViewControllerAsModalWindow:errorVC];
}

static inline void presentErrorWithAdditionalButton(NSString *__nullable additionalButtonText,
    BOOL showsAdditionalButton,
    NSDictionary *__nonnull userInfo,
    NSUInteger code,
    errorViewControllerCompletionHandler completionHandler) {
    NSError *errorObj = [[NSError alloc] initWithDomain:NSNetServicesErrorDomain code:code userInfo:userInfo];

    ErrorViewController *errorVC = [ErrorViewController viewControllerWithError:errorObj];
    errorVC.showAdditionalButton = showsAdditionalButton;
    errorVC.additionalButton.title = additionalButtonText;
    errorVC.completionHandler = completionHandler;

    [errorVC presentViewControllerAsModalWindow:errorVC];
}

#define __dict(...) (@{__VA_ARGS__})
#define perr(...) presentError(@{__VA_ARGS__}, error)
#define perrc(addButtTxt, showsAddButt, dict, complHandler) presentErrorWithAdditionalButton((addButtTxt), (showsAddButt), (dict), error, complHandler)

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSNetServicesError error = [errorDict[NSNetServicesErrorCode] integerValue];
    NSInteger domain = [errorDict[NSNetServicesErrorDomain] integerValue];

    switch (error) {
        case NSNetServicesTimeoutError: {
            NSDictionary *dict = __dict(
                    NSLocalizedDescriptionKey:
                    SWF(@"Can't resolve the service %@: timeout reached", sender.name),
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Check your network connection",
                [Constants kErrorViewControllerTitleKey]: @"Timeout"
            );

            perrc(@"try again", YES, dict, ^(enum ErrorViewControllerButton buttonPressed) {
                if (buttonPressed == ErrorViewControllerButtonAdditional) {
                    [self resolveNetService:sender];
                }
            });
        }
            break;

        case NSNetServicesActivityInProgress: {
            perr(
                [Constants kErrorViewControllerTitleKey]: @"Activity in progress",
                    NSLocalizedDescriptionKey:
                    @"The request cannot be processed at this time. No additional information about the network state is known.",
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Try again later"
            );
        }
            break;

        case NSNetServicesInvalidError: {
            perr(
                [Constants kErrorViewControllerTitleKey]: @"Invalid service",
                    NSLocalizedDescriptionKey:
                    @"The service, to which you wanted to connect, was improperly configured",
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Try a different service"
            );
        }
            break;

        case NSNetServicesUnknownError: {
            NSDictionary *dict = __dict(
                [Constants kErrorViewControllerTitleKey]: @"Unknown error",
                    NSLocalizedDescriptionKey:
                    @"An unknown error occurred",
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Try again or choose a different service"
            );

            perrc(@"try again", YES, dict, ^(enum ErrorViewControllerButton buttonPressed) {
                if (buttonPressed == ErrorViewControllerButtonAdditional) {
                    [self resolveNetService:sender];
                }
            });
        }
            break;

        case NSNetServicesNotFoundError: {
            perr(
                [Constants kErrorViewControllerTitleKey]: @"Service not found",
                    NSLocalizedDescriptionKey:
                    @"The service couldn't be found on the network",
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Check your network connection and the service's network connection. Try to reconnect if the service was disconnected from the network"
            );
        }
            break;

        case NSNetServicesCancelledError: {
            NSDictionary *dict = __dict(
                [Constants kErrorViewControllerTitleKey]: @"Action cancelled",
                    NSLocalizedDescriptionKey:
                    @"The action was cancelled by the client"
            );

            perrc(@"try again", YES, dict, ^(enum ErrorViewControllerButton buttonPressed) {
                if (buttonPressed == ErrorViewControllerButtonAdditional) {
                    [self resolveNetService:sender];
                }
            });
        }
            break;

        case NSNetServicesBadArgumentError: {
            NSDictionary *dict = __dict(
                [Constants kErrorViewControllerTitleKey]: @"Internal error",
                    NSLocalizedDescriptionKey:
                    @"An internal error occurred",
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Please report this bug to the developer. The description, error code and internal debug info will be submitted, but no personal information. Thank you very much :)"
            );

            perrc(@"report", YES, dict, (^(enum ErrorViewControllerButton buttonPressed) {
                if (buttonPressed == ErrorViewControllerButtonAdditional) {
                    NSError *err = [NSError errorWithDomain:SWF(@"domain_%ld", (long) domain) code:error userInfo:@{NSLocalizedDescriptionKey: @"bad argument", NSLocalizedRecoverySuggestionErrorKey: @"review code"}];

                    [self reportError:err userInfo:@{@"errorDict": errorDict, @"service": sender.description} withCompletionHandler:nil];
                }
            }));
        }
            break;

        default: {
            NSDictionary *dict = __dict(
                [Constants kErrorViewControllerTitleKey]: @"Fatal error",
                    NSLocalizedDescriptionKey:
                    @"An error occurred, which hasn't been expected by the application",
                    NSLocalizedRecoverySuggestionErrorKey:
                    @"Please report this bug to the developer using description and error code. Thank you very much :)"
            );

            perrc(@"report", YES, dict, (^(enum ErrorViewControllerButton buttonPressed) {
                if (buttonPressed == ErrorViewControllerButtonAdditional) {
                    NSError *err = [NSError errorWithDomain:SWF(@"domain_%ld", (long) domain) code:error userInfo:@{NSLocalizedDescriptionKey: @"unknown error"}];

                    [self reportError:err userInfo:@{@"errorDict": errorDict, @"service": sender.description} withCompletionHandler:nil];
                }
            }));
        }
            break;
    }

    NSLog(@"did not resolve: %@", errorDict);
}

#undef perr
#undef perrc

- (void)netServiceWillResolve:(NSNetService *)sender {
    NSLog(@"Will resolve");
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {
    NSLog(@"did update TXT record data for sender %@: %@", sender, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSString *localizedErorDescription;
    if (sender.addresses.count > 0) {
        @try {
            // TXT Record data
            NSDictionary<NSString *, NSData *> *TXTRecordData = [NSNetService dictionaryFromTXTRecordData:sender.TXTRecordData];
            NSString *path = @"";

            if ([[TXTRecordData allKeys] containsObject:@"path"]) {
                NSString *dataStr = [[NSString alloc] initWithData:TXTRecordData[@"path"] encoding:NSUTF8StringEncoding];

                if (dataStr)
                    path = dataStr;
            }

            // IP address
            NSData *addressData = sender.addresses[0];
            if (addressData.length <= 0) {
                localizedErorDescription = @"Bonjour returned an empty address";
                goto error;
            }

            struct sockaddr_in sock;
            void *data = malloc(addressData.length);

            [addressData getBytes:data length:addressData.length];

            memcpy(&sock, (const void *) data, addressData.length);

            if (ntohs(sock.sin_addr.s_addr) <= 0) {
                localizedErorDescription = @"Can't get the address";
                goto error;
            }

            const char *addressStr = iptostr(sock.sin_addr.s_addr);
            NSString *address = [[NSString alloc] initWithCString:addressStr encoding:NSUTF8StringEncoding];
            NSURL *url = [[NSURL alloc] initWithString:SWF(@"http://%@:%ld%@", address, (long) sender.port, path)];

            if (url) {
                if (![[NSWorkspace sharedWorkspace] openURL:url]) {
                    localizedErorDescription = @"Can't open address";
                    goto error;
                }
            } else {
                localizedErorDescription = @"Unable to construct URL";
                goto error;
            }
        } @catch (NSException *exception) {
            localizedErorDescription = @"Unexpected error";
            goto error;
        }
    }

    error:
    if (localizedErorDescription) {
        NSLog(@"ERROR: %@", localizedErorDescription); /// @todo present error
    }
}

- (BOOL)shouldShowBonjourSection {
    return self.networkInformation.activeServices.count > 0;
}

#pragma mark - Error reporting

- (BOOL)reportError:(NSError *_Nonnull)error userInfo:(NSDictionary<NSString *, NSObject *> *_Nullable)userInfo withCompletionHandler:(void (^ _Nullable)(BOOL success))completionHandler {
    NSData *reportData = [self dataFromError:error withUserInfo:userInfo];

    if (!reportData) {
        return NO;
    }

    // HTTPS can fail when certificate is self-signed
    NSURL *url = [NSURL URLWithString:@"https://aseider.pf-control.de/support/error/report/?appl=actions"];
    [FastHTTPRequest sendRequestWithURL:url httpMethod:@"POST" httpBody:reportData andResponse:^(NSData *data, NSHTTPURLResponse *httpResponse) {
        if (!data || !httpResponse) {
            if (completionHandler)
                completionHandler(NO);

            return; // Will be logged by FastHTTPRequest
        }

        BOOL success = NO;
        NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef) httpResponse.textEncodingName));
        NSString *response = [[NSString alloc] initWithData:data encoding:encoding];
        if (httpResponse.statusCode == 200) {
            if ([response isEqualToString:@"1.0::success"]) {
                DLog(@"successfully reported error");
                success = YES;
            } else {
                WLog(@"The server returned a success error code, but no success body code. It returned instead “%@”", response);
            }
        } else {
            ELog(@"Can't report error to server: %@", response);
        }

        if (completionHandler)
            completionHandler(success);
    }];

    return YES;
}

const NSString *kErrorCodeKey = @"errorCode";
const NSString *kLocalizedDescriptionKey = @"localizedDescription";
const NSString *kLocalizedRecoverySuggestionKey = @"localizedRecoverySuggestion";
const NSString *kLocalizedFailureReasonKey = @"localizedFailureKey";
const NSString *kCallStackKey = @"callStack";
const NSString *kUserInfoKey = @"userInfo";

- (NSData *_Nonnull)dataFromError:(NSError *)error withUserInfo:(NSDictionary<NSString *, NSObject *> *_Nullable)userInfo {
    NSArray<NSString *> *callStack = [NSThread callStackSymbols];

    NSMutableDictionary *dict = [@{
        kErrorCodeKey: @(error.code),
        kLocalizedDescriptionKey: error.localizedDescription ?: @"",
        kLocalizedRecoverySuggestionKey: error.localizedRecoverySuggestion ?: @"",
        kLocalizedFailureReasonKey: error.localizedFailureReason ?: @"",
        kCallStackKey: callStack
    } mutableCopy];

    if (userInfo) {
        dict[kUserInfoKey] = userInfo;
    }

    NSError *err;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&err];

    if (error && !data) {
        WLog(@"Can't generate report data for error \"%@\": %@", error, err);
        return nil;
    }

    NSString *encodedData = [data base64EncodedStringWithOptions:0];

    return [SWF(@"error=%@", encodedData) dataUsingEncoding:NSUTF8StringEncoding];
}

@end
