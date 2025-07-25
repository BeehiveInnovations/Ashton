//
//  CrossPlatformCompatibility.swift
//  Ashton
//
//  Created by Michael Schwarz on 11.12.17.
//  Copyright © 2017 Michael Schwarz. All rights reserved.
//

#if os(iOS) || (compiler(>=5.9) && os(visionOS))
import UIKit
public typealias Font = UIFont
public typealias FontDescriptor = UIFontDescriptor
public typealias FontDescriptorSymbolicTraits = UIFontDescriptor.SymbolicTraits
public typealias Color = UIColor

extension UIFont {
    class var cpFamilyNames: [String] { return UIFont.familyNames }
    var cpFamilyName: String { return self.familyName }

    class func cpFontNames(forFamilyName familyName: String) -> [String] {
        return UIFont.fontNames(forFamilyName: familyName)
    }
}

extension UIFontDescriptor {
    var cpPostscriptName: String { return self.postscriptName }
}

extension NSAttributedString.Key {
    static let superscript = NSAttributedString.Key(rawValue: "NSSuperScript")
}

extension FontDescriptor.FeatureKey {
    static let selectorIdentifier = FontDescriptor.FeatureKey("CTFeatureSelectorIdentifier")
    static let cpTypeIdentifier = FontDescriptor.FeatureKey("CTFeatureTypeIdentifier")
}

#elseif os(macOS)
import AppKit
public typealias Font = NSFont
public typealias FontDescriptor = NSFontDescriptor
public typealias FontDescriptorSymbolicTraits = NSFontDescriptor.SymbolicTraits
public typealias Color = NSColor

extension NSFont {
    class var cpFamilyNames: [String] { return NSFontManager.shared.availableFontFamilies }
    var cpFamilyName: String { return self.familyName ?? "" }

    class func cpFontNames(forFamilyName familyName: String) -> [String] {
        let fontManager = NSFontManager.shared
        let availableMembers = fontManager.availableMembers(ofFontFamily: familyName)
        return availableMembers?.compactMap { member in
            let memberArray = member as Array<Any>
            return memberArray.first as? String
            } ?? []
    }
}

extension NSFontDescriptor {
    var cpPostscriptName: String { return self.postscriptName ?? "" }
}

extension FontDescriptor.FeatureKey {
    static let cpTypeIdentifier = FontDescriptor.FeatureKey("CTFeatureTypeIdentifier")
}
#endif
