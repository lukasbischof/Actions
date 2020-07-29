//
//  ErrorViewController.swift
//  Actions
//
//  Created by Lukas Bischof on 19.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

import Cocoa

extension Constants {
    class func kErrorViewControllerTitleKey() -> NSString {
        return NSString(string: "kErrorViewControllerTitleKey")
    }
}

@objc
enum ErrorViewControllerType: UInt {
    case error = 0
    case info
}

@objc
enum ErrorViewControllerButton: UInt {
    case done = 0
    case additional
}

typealias completionBlock = ((_ buttonPressed: ErrorViewControllerButton) -> Void)?

@objc
class ErrorViewController: NSViewController {
    var error: NSError!
    @objc var type: ErrorViewControllerType = .error
    @objc var completionHandler: completionBlock = nil
    @objc var additionalButtonText: NSString = NSString(string: "try again")
    @objc var showAdditionalButton: Bool = false

    @IBOutlet weak var errorTitleTextField: NSTextField!
    @IBOutlet weak var errorDescriptionTextField: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var additionalButton: NSButton!

    @objc class func viewControllerWithError(_ error: NSError) -> ErrorViewController? {
        let viewController = ErrorViewController(nibName: "ErrorViewController", bundle: nil)

        viewController.error = error

        return viewController
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        print("\(#function)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        self.title = "Error \(error.code)"

        if let desc = self.error.userInfo[NSLocalizedDescriptionKey] as? String {
            self.errorDescriptionTextField.stringValue = desc
        }

        if let title = self.error.userInfo[Constants.kErrorViewControllerTitleKey() as String] as? String {
            self.errorTitleTextField.stringValue = title
        }

        if let recovery = self.error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String {
            self.errorDescriptionTextField.stringValue += "\n\n\(recovery)"
        }

        switch type {
        case .error:
            imageView.image = NSImage(named: NSImage.cautionName)

        case .info:
            imageView.image = NSImage(named: NSImage.infoName)
        }

        additionalButton.title = additionalButtonText as String
        additionalButton.isHidden = !showAdditionalButton
    }

    override func viewDidAppear() {
        self.view.window?.styleMask = NSWindow.StyleMask(rawValue: self.view.window!.styleMask.rawValue & ~NSWindow.StyleMask.resizable.rawValue)
    }

    @IBAction func okButtonPressed(_ sender: NSButton) {
        dismiss(self)
        completionHandler?(.done)
    }

    @IBAction func additionalButtonPressed(_ sender: NSButton) {
        dismiss(self)
        completionHandler?(.additional)
    }
}
