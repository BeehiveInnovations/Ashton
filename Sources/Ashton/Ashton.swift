//
//  Ashton.swift
//  Ashton
//
//  Created by Michael Schwarz on 16.09.17.
//  Copyright © 2017 Michael Schwarz. All rights reserved.
//

import Foundation

/// Transforms NSAttributedString <--> HTML
@objc
public final class Ashton: NSObject {

    public typealias HTML = String

    // Shared thread-safe caches
    private static let sharedFontCache = FontBuilder.FontCache()
    private static let sharedStyleCache = AshtonXMLParser.StyleAttributesCache()
    
    // Thread-local storage keys
    private static let readerKey = "com.ashton.thread-local-reader"
    private static let writerKey = "com.ashton.thread-local-writer"
    
    // Generic helper for thread-local storage
    private static func threadLocal<T: NSObject>(key: String, create: () -> T) -> T {
        let threadDict = Thread.current.threadDictionary
        if let existingObject = threadDict[key] as? T {
            return existingObject
        } else {
            let newObject = create()
            threadDict[key] = newObject
            return newObject
        }
    }
    
    // Thread-local reader instance
    internal static var reader: AshtonHTMLReader {
        threadLocal(key: readerKey) {
            AshtonHTMLReader(fontBuilderCache: sharedFontCache, styleCache: sharedStyleCache)
        }
    }
    
    // Thread-local writer instance
    internal static var writer: AshtonHTMLWriter {
        threadLocal(key: writerKey) {
            AshtonHTMLWriter()
        }
    }

    /// Encodes an NSAttributedString into a HTML representation
    ///
    /// - Parameter attributedString: The NSAttributedString to encode
    /// - Returns: The HTML representation
    /// - Note: Convenience interface which isn't threadsafe. If you use Ashton from multiple threads use AshtonHTMLReader/AshtonHTMLWriter directly
    @objc
    public static func encode(_ attributedString: NSAttributedString) -> HTML {
        return Ashton.writer.encode(attributedString)
    }

    /// Decodes a HTML representation into an NSAttributedString
    ///
    /// - Parameter html: The HTML representation to encode
    /// - Parameter defaultAttributes: Attributes which are used if no attribute is specified in the HTML
    /// - Returns: The decoded NSAttributedString
    /// - Note: Convenience interface which isn't threadsafe. If you use Ashton from multiple threads use AshtonHTMLReader/AshtonHTMLWriter directly
    @objc
    public static func decode(_ html: HTML, defaultAttributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
        self.decode(html, defaultAttributes: defaultAttributes) { _ in }
    }

    /// Decodes a HTML representation into an NSAttributedString
    ///
    /// - Parameter html: The HTML representation to encode.
    /// - Parameter defaultAttributes: Attributes which are used if no attribute is specified in the HTML.
    /// - Parameter completionHandler: Called when the receiver did finish parsing. A result type containing parsing information gets passed in. This is called synchronously right before returning.
    /// - Returns: The decoded NSAttributedString.
    public static func decode(_ html: HTML, defaultAttributes: [NSAttributedString.Key: Any] = [:], completionHandler: AshtonHTMLReadCompletionHandler) -> NSAttributedString {
        return Ashton.reader.decode(html, defaultAttributes: defaultAttributes, completionHandler: completionHandler)
    }

    /// Clears decoding caches (e.g. already parsed and converted html style attribute strings are cached)
    @objc
    public static func clearCaches() {
        sharedFontCache.clear()
        sharedStyleCache.clear()
    }
}
