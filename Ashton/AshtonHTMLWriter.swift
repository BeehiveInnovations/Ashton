//
//  AshtonHTMLWriter.swift
//  Ashton
//
//  Created by Michael Schwarz on 16.09.17.
//  Copyright © 2017 Michael Schwarz. All rights reserved.
//

import Foundation
import UIKit


final class AshtonHTMLWriter {

	func encode(_ attributedString: NSAttributedString) -> Ashton.HTML {
		let string = attributedString.string
		let paragraphRanges = self.getParagraphRanges(from: string)

		var html = String()
		for paragraphRange in paragraphRanges {
			var paragraphContent = String()
			let nsParagraphRange = NSRange(paragraphRange, in: string)
			var paragraphTag = HTMLTag(defaultName: .p, attributes: [:])
			attributedString.enumerateAttributes(in: nsParagraphRange,
			                                     options: .longestEffectiveRangeNotRequired, using: { attributes, nsrange, _ in
													if nsParagraphRange.length == nsrange.length {
														paragraphTag.addAttributes(attributes)
														paragraphContent += String(attributedString.string[paragraphRange])
													} else {
														guard let range = Range(nsrange, in: attributedString.string) else { return }

														let tag = HTMLTag(defaultName: .span, attributes: attributes)
														paragraphContent += tag.makeOpenTag()
														paragraphContent += String(attributedString.string[range])
														paragraphContent += tag.makeCloseTag()
													}
			})

			html += paragraphTag.makeOpenTag() + paragraphContent + paragraphTag.makeCloseTag()
		}

		return html
	}
}

// MARK: - Private

private extension AshtonHTMLWriter {

	func getParagraphRanges(from string: String) -> [Range<String.Index>] {
		var (paragraphStart, paragraphEnd, contentsEnd) = (string.startIndex, string.startIndex, string.startIndex)
		var ranges = [Range<String.Index>]()
		let length = string.endIndex

		while paragraphEnd < length {
			string.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: &contentsEnd, for: paragraphEnd...paragraphEnd)
			ranges.append(paragraphStart..<contentsEnd)
		}
		return ranges
	}
}

struct HTMLTag {

	enum Name: String {
		case p
		case span
		case a

		func wrapped(with attributes: String? = nil) -> String {
			if let attributes = attributes {
				return "<\(self.rawValue) \(attributes)>"
			} else {
				return "<\(self.rawValue)>"
			}
		}
	}

	let defaultName: Name
	var attributes: [NSAttributedStringKey: Any]

	mutating func addAttributes(_ attributes: [NSAttributedStringKey: Any]?) {
		attributes?.forEach { (key, value) in
			self.attributes[key] = value
		}
	}

	func makeOpenTag() -> String {
		guard !self.attributes.isEmpty else { return self.defaultName.wrapped() }

		var styles = ""
		var links = ""

		self.attributes.forEach { key, value in
			switch key {
			case .backgroundColor:
				guard let color = value as? UIColor else { return }

				styles += "background-color: " + self.makeCSSrgba(for: color)
			case .foregroundColor:
				guard let color = value as? UIColor else { return }

				styles += "color: " + self.makeCSSrgba(for: color)
			case .underlineStyle:
				guard let underlineStyle = self.underlineStyle(from: value) else { return }

				styles += "text-decoration: underline; -cocoa-underline: \(underlineStyle)"
			case .underlineColor:
				guard let color = value as? UIColor else { return }

				styles += "-cocoa-underline-color: " + self.makeCSSrgba(for: color)
			case .strikethroughColor:
				guard let color = value as? UIColor else { return }

				styles += "-cocoa-strikethrough-color: " + self.makeCSSrgba(for: color)
			case .strikethroughStyle:
				guard let underlineStyle = self.underlineStyle(from: value) else { return }

				styles += "text-decoration: line-through; -cocoa-strikethrough: \(underlineStyle)"
			case .font:
				guard let font = value as? UIFont else { return }

				let fontDescriptor = font.fontDescriptor

				styles += "font: "
				if fontDescriptor.symbolicTraits.contains(.traitBold) {
					styles += "bold "
				}
				if fontDescriptor.symbolicTraits.contains(.traitItalic) {
					styles += "italic "
				}

				styles += String(format: "%gpx ", fontDescriptor.pointSize)
				styles += "\"\(font.familyName)\"; "

				styles += "-cocoa-font-postscriptname: \"\(fontDescriptor.postscriptName)\""

				let uiUsageAttribute = UIFontDescriptor.AttributeName.init(rawValue: "NSCTFontUIUsageAttribute")
				if let uiUsage = fontDescriptor.fontAttributes[uiUsageAttribute] {
					styles += "; -cocoa-font-uiusage: \"\(uiUsage)\""
				}
			case .link:
				guard let url = value as? URL else { return }

				links = "href='\(url.absoluteString)'"
			default:
				assertionFailure("did not handle \(key)")
			}
			if !styles.isEmpty {
				styles += "; "
			}
		}

		if styles.isEmpty {
			if !links.isEmpty {
				return Name.a.wrapped(with: links)
			}
			return self.defaultName.wrapped()
		} else {
			var openingTag: String = ""
			if !links.isEmpty {
				openingTag += Name.a.wrapped(with: links)
			}
			let styleAttributes = "style='\(styles)'"
			return openingTag + self.defaultName.wrapped(with: styleAttributes)
		}
	}

	func makeCloseTag() -> String {
		let containsLinks = (self.attributes.first(where: { $0.key == .link }) != nil)
		if containsLinks {
			return "</\(Name.a)>"
		}
		return "</\(self.defaultName.rawValue)>"
	}

	// MARK: - Private

	private func makeCSSrgba(for color: UIColor) -> String {
		var red: CGFloat = 0.0
		var green: CGFloat = 0.0
		var blue: CGFloat = 0.0
		var alpha: CGFloat = 0.0
		color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

		return "rgba(\(Int(red * 255.0)), \(Int(green * 255.0)), \(Int(blue * 255.0)), \(String(format: "%.6f", alpha)))"
	}

	private func underlineStyle(from value: Any) -> String? {
		guard let rawValue = value as? Int else { return nil  }
		guard let underlineStyle = NSUnderlineStyle(rawValue: rawValue) else { return nil }

		let mapping: [NSUnderlineStyle: String] = [
			.styleSingle: "single",
			.styleDouble: "double",
			.styleThick: "thick"
		]

		return mapping[underlineStyle]
	}
}
