
import Foundation
import UIKit
import SwifterSwift

// MARK: - Properties
extension String {

    /// Returns true if the string contains Arabic
    var isArabic: Bool {
        NSPredicate(format: "SELF MATCHES %@", "(?s).*\\p{Arabic}.*").evaluate(with: self)
    }
    
    /// Returns true if the string contains an URL
    var containsURLs: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        
        for match in matches {
            guard let _ = Range(match.range, in: self) else { continue }
            return true
        }
        
        return false
    }
    
    /// Returns true if the text is a single Character  AND is an emojy
    var isSingleEmoji: Bool { count == 1 && containsEmoji }
    
    /// Returns true if the text contains Emojy
    var containsEmoji: Bool { contains { $0.isEmoji } }
    
    /// Return true if text contains only emojy
    var containsOnlyEmoji: Bool { !isEmpty && !contains { !$0.isEmoji } }
    
    /// Remove every NON emojy character from a string
    var emojiString: String { emojis.map { String($0) }.reduce("", +) }
    
    /// Returns all the Emojis
    var emojis: [Character] { filter { $0.isEmoji } }
    
    /// Returns the Emojis unicode scalar value
    var emojiScalars: [UnicodeScalar] { filter { $0.isEmoji }.flatMap { $0.unicodeScalars } }
    
}

// MARK: - Methods
extension String {
    
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }
    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else { return nil }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
    
    /// Convert the string to an Unsafe Mutable Pointer Int8.
    ///
    ///   **String.random(ofLength: 18) -> "u7MMZYvGo9obcOcPj8"**
    ///
    /// - Returns: UnsafeMutablePointer<Int8>
    func toMutablePointer() -> UnsafeMutablePointer<Int8>! {
        return strdup(self)
    }
    
    /// Parse all the Tags contained in a string and convert it to an NSAttributesString
    /// - Parameter fontSize: font size
    /// - Returns: Parse the string tags and convert it to NSAttributesString
    func getAttributedText(fontSize: CGFloat = 17.0) -> NSAttributedString? {
        guard count > 0 else { return nil }
        
        var attributedString = NSMutableAttributedString(string: self)
        // *** Create instance of `NSMutableParagraphStyle`
        let paragraphStyle = NSMutableParagraphStyle()
        
        // *** set LineSpacing property in points ***
        paragraphStyle.lineSpacing = 2 // Whatever line spacing you want in points
        //    paragraphStyle.baseWritingDirection = AppUtility.isArabic ? .rightToLeft : .leftToRight
        
        // *** Apply attribute to string ***
        attributedString.addAttributes([
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.font: UIFont.appFont(ofSize: fontSize, textStyle: .body)
        ], range: NSRange(location: 0, length: attributedString.length))
        
        
        attributedString = attributedString.string.replaceTagWithBold(attributedString: attributedString, fontSize: fontSize)
        attributedString = attributedString.string.replaceTagWithItalic(attributedString: attributedString, fontSize: fontSize)
        attributedString = attributedString.string.replaceTagWithUnderline(attributedString: attributedString, fontSize: fontSize)
        attributedString = attributedString.string.replaceTagWithStrikethrough(attributedString: attributedString)
        attributedString = attributedString.string.replaceTagWithColor(attributedString: attributedString)
        
        return attributedString
    }
    
    /// Returns a new string in which the first occurrence of a string is replaced by another given string
    ///
    ///    **"2017-01-15".date(withFormat: "yyyy-MM-dd") -> Date set to Jan 15, 2017**
    ///    **"not date string".date(withFormat: "yyyy-MM-dd") -> nil**
    ///
    /// - Parameters:
    ///   - target: The string you want to replace
    ///   - replaceString: The string you want to use
    /// - Returns: Returns a new string in which the first occurrence of a string is replaced by another given string
    func replacingFirstOccurrenceOfString(target: String, withString replaceString: String) -> String {
        if let range = self.range(of: target) {
            return self.replacingCharacters(in: range, with: replaceString)
        }
        return self
    }
    
    
    /// Return the string size (usually used for 1 line string) using the given font
    /// - Parameter font: UIFont
    /// - Returns: CGSize of a given string
    func size(usingFont font: UIFont) -> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: fontAttributes as [NSAttributedString.Key : Any])
        return size
    }
    
    var attributedForChat: NSAttributedString {
        var attributedString = NSMutableAttributedString(string: self)
        // *** Create instance of `NSMutableParagraphStyle`
        let paragraphStyle = NSMutableParagraphStyle()
        
        // *** set LineSpacing property in points ***
        paragraphStyle.lineSpacing = 2 // Whatever line spacing you want in points
        
        // *** Apply attribute to string ***
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range: NSMakeRange(0, attributedString.length))
        
        attributedString = attributedString.string.replaceTagWithBold(attributedString: attributedString)
        attributedString = attributedString.string.replaceTagWithItalic(attributedString: attributedString)
        attributedString = attributedString.string.replaceTagWithStrikethrough(attributedString: attributedString)
        attributedString = attributedString.string.replaceTagWithColor(attributedString: attributedString)
        
        return attributedString
    }
    
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }
    
    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
    
    /// Return a RTL NSAttributedString if string contains is in Arabic
    func fixTextDirection() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = isArabic ? .rightToLeft : .leftToRight
        // *** Apply attribute to string ***
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range:  NSRange(location: 0, length: attributedString.length))
        
        return attributedString
    }
    
    /// Returns a new string as RTL direction
    /// - Returns: Returns a new string as RTL direction
    func toRTL() -> String {
        // "\u{200F}" = RTL
        return "\u{200F}\(self)"
    }
    
    /// Returns a new string as LTR direction
    /// - Returns: Returns a new string as LTR direction
    func toLTR() -> String {
        // "\u{200E}" = LTR
        return "\u{200E}\(self)"
    }
    
    /// Convert a string to Date using the given format and TimeZone
    /// - Parameters:
    ///   - format: Date format string -->  *"yyyy-MM-dd HH:mm:ss"*
    ///   - timeZone: TimeZone --> TimeZone(abbreviation: "UTC")
    /// - Returns: Date object from string (if applicable).
    func date(withFormat format: String, timeZone: TimeZone?) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        return dateFormatter.date(from: self)
    }
    
    
    // MARK: - Boyer Moore String Search Algorithm
    fileprivate var skipTable: [Character: Int] {
        var skipTable: [Character: Int] = [:]
        for (i, c) in enumerated() {
            skipTable[c] = count - i - 1
        }
        return skipTable
    }
    
    fileprivate func match(from currentIndex: Index, with pattern: String) -> Index? {
        guard currentIndex >= startIndex && currentIndex < endIndex && pattern.last == self[currentIndex]
        else { return nil }
        if pattern.count == 1 && self[currentIndex] == pattern.first { return currentIndex }
        
        return match(from: index(before: currentIndex), with: "\(pattern.dropLast())")
    }
    
    func index(of pattern: String) -> Index? {
        // 1
        let patternLength = pattern.count
        guard patternLength > 0, patternLength <= count else { return nil }
        
        // 2
        let skipTable = pattern.skipTable
        let lastChar = pattern.last!
        
        // 3
        var i = index(startIndex, offsetBy: patternLength - 1)
        
        // 1
        while i < endIndex {
            let c = self[i]
            
            // 2
            if c == lastChar {
                if let k = match(from: i, with: pattern) { return k }
                i = index(after: i)
            } else {
                // 3
                i = index(i, offsetBy: skipTable[c] ?? patternLength, limitedBy: endIndex) ?? endIndex
            }
        }
        
        return nil
    }
    
    func index(of pattern: String, startIndex: Index) -> Index? {
        // 1
        let patternLength = pattern.count
        guard patternLength > 0, patternLength <= count else { return nil }
        
        // 2
        let skipTable = pattern.skipTable
        let lastChar = pattern.last!
        
        // 3
        var i = index(startIndex, offsetBy: patternLength - 1)
        
        // 1
        while i < endIndex {
            let c = self[i]
            
            // 2
            if c == lastChar {
                if let k = match(from: i, with: pattern) { return k }
                i = index(after: i)
            } else {
                // 3
                i = index(i, offsetBy: skipTable[c] ?? patternLength, limitedBy: endIndex) ?? endIndex
            }
        }
        
        return nil
    }
    
    func indexes(of pattern: String) -> [Index]? {
        var str = self
        var indexes: [Index] = []
        while let index = str.index(of: pattern) {
            indexes.append(index)
            str = String(str[str.index(index, offsetBy: pattern.count)...])
        }
        return indexes.count > 0 ? indexes : nil
    }
    
    /// Return the string height using a specific width contrainment and UIFont
    /// - Parameters:
    ///   - maxWidth: the max width
    ///   - font: string font
    /// - Returns: return the string height
    func height(maxWidth: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect,
                                       options: .usesLineFragmentOrigin,
                                       attributes: [.font: font],
                                       context: nil)
        return ceil(boundingBox.height)
    }
    
    /// Return the string width using a specific height contrainment and UIFont
    /// - Parameters:
    ///   - maxWidth: the max height
    ///   - font: string font
    /// - Returns: return the string width
    func width(maxHeight: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: maxHeight)
        let boundingBox = self.boundingRect(with: constraintRect,
                                            options: .usesLineFragmentOrigin,
                                            attributes: [.font: font],
                                            context: nil)
        
        return ceil(boundingBox.width)
    }
    
}

// MARK: - Private Methods
fileprivate extension String {
    
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
    
    func replaceTagWithBold(attributedString: NSMutableAttributedString, fontSize: CGFloat = 17.0) -> NSMutableAttributedString {
        if attributedString.string.count(of: "*") < 2 {
            return attributedString
        }
        
        let boldCount = attributedString.string.count(of: "*") / 2
        var stringToParse = self
        
        for _ in 0..<boldCount {
            var startIndex = -1
            for (index, char) in stringToParse.enumerated() {
                if char == "*" {
                    if startIndex == -1 {
                        startIndex = index
                    } else {
                        let subStrLenght = index-(startIndex+1)
                        let substringRange = NSRange(location: startIndex+1, length: subStrLenght)
                        
                        
                        // Add Bold to italic if present
                        let attributes = attributedString.attributedSubstring(from: substringRange)
                        attributes.enumerateAttribute(NSAttributedString.Key.font, in: NSRange(0..<attributes.length), options: .longestEffectiveRangeNotRequired) {
                            value, range, stop in
                            // Confirm the attribute value is actually a font
                            // AND
                            // Check if the font is bold or not
                            if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                                attributedString.addAttributes(
                                    [NSAttributedString.Key.font: UIFont.appFontBoldItalic(ofSize: fontSize, textStyle: .body)],
                                    range: NSRange(location: substringRange.location + range.location, length: range.length)
                                )
                            } else {
                                attributedString.addAttributes(
                                    [NSAttributedString.Key.font: UIFont.appFontBold(ofSize: fontSize, textStyle: .body)],
                                    range: NSRange(location: substringRange.location + range.location, length: range.length)
                                )
                            }
                        }
                        
                        // remove the symbols when showing them in the chat bubble
                        stringToParse.removeFirst { $0 == "*" }
                        stringToParse.removeFirst { $0 == "*" }
                        attributedString.deleteCharacters(in: NSRange(location: startIndex, length: 1))
                        attributedString.deleteCharacters(in: NSRange(location: index-1, length: 1)) // We remove 1 from the location because we just remove 1 character with the previous line
                        
                        break
                    }
                }
            }
        }
        
        
        return attributedString
    }
    
    func replaceTagWithItalic(attributedString: NSMutableAttributedString, fontSize: CGFloat = 17.0) -> NSMutableAttributedString {
        if attributedString.string.count(of: "_") < 2 {
            return attributedString
        }
        
        let italicsCount = attributedString.string.count(of: "_") / 2
        
        var stringToParse = self
        for _ in 0..<italicsCount {
            var startIndex = -1
            for (index, char) in stringToParse.enumerated() {
                if char == "_" {
                    if startIndex == -1 {
                        startIndex = index
                    } else {
                        let subStrLenght = index-(startIndex+1)
                        let substringRange = NSRange(location: startIndex+1, length: subStrLenght)
                        
                        // Add Italic to Bold if present
                        let attributes = attributedString.attributedSubstring(from: substringRange)
                        attributes.enumerateAttribute(NSAttributedString.Key.font, in: NSRange(0..<attributes.length), options: .longestEffectiveRangeNotRequired) {
                            value, range, stop in
                            // Confirm the attribute value is actually a font
                            // AND
                            // Check if the font is bold or not
                            if let font = value as? UIFont, font.isBold {
                                attributedString.addAttributes(
                                    [NSAttributedString.Key.font:  UIFont.appFontBoldItalic(ofSize: fontSize, textStyle: .body)],
                                    range: NSRange(location: substringRange.location + range.location, length: range.length)
                                )
                            } else if let font = value as? UIFont, font.isSemiBold {
                                attributedString.addAttributes(
                                    [NSAttributedString.Key.font: UIFont.appFontSemiBoldItalic(ofSize: fontSize, textStyle: .body)],
                                    range: NSRange(location: substringRange.location + range.location, length: range.length)
                                )
                            } else {
                                attributedString.addAttributes(
                                    [NSAttributedString.Key.font: UIFont.appFontItalic(ofSize: fontSize, textStyle: .body)],
                                    range: NSRange(location: substringRange.location + range.location, length: range.length)
                                )
                            }
                        }
                        
                        // remove the symbols when showing them in the chat bubble
                        stringToParse.removeFirst { $0 == "_" }
                        stringToParse.removeFirst { $0 == "_" }
                        attributedString.deleteCharacters(in: NSRange(location: startIndex, length: 1))
                        attributedString.deleteCharacters(in: NSRange(location: index-1, length: 1)) // We remove 1 from the location because we just remove 1 character with the previous line
                        
                        break
                    }
                }
            }
        }
        
        return attributedString
    }
    
    func replaceTagWithUnderline(attributedString: NSMutableAttributedString, fontSize: CGFloat = 17.0) -> NSMutableAttributedString {
        if attributedString.string.count(of: "•") < 2 {
            return attributedString
        }
        
        let italicsCount = attributedString.string.count(of: "•") / 2
        
        var stringToParse = self
        for _ in 0..<italicsCount {
            var startIndex = -1
            for (index, char) in stringToParse.enumerated() {
                if char == "•" {
                    if startIndex == -1 {
                        startIndex = index
                    } else {
                        let subStrLenght = index-(startIndex+1)
                        let substringRange = NSRange(location: startIndex+1, length: subStrLenght)
                        attributedString.addAttributes([NSAttributedString.Key.underlineStyle: 1], range: substringRange)
                        
                        // remove the symbols when showing them in the chat bubble
                        stringToParse.removeFirst { $0 == "•" }
                        stringToParse.removeFirst { $0 == "•" }
                        attributedString.deleteCharacters(in: NSRange(location: startIndex, length: 1))
                        attributedString.deleteCharacters(in: NSRange(location: index-1, length: 1)) // We remove 1 from the location because we just remove 1 character with the previous line
                        
                        break
                    }
                }
            }
        }
        
        return attributedString
    }
    
    func replaceTagWithStrikethrough(attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
        if attributedString.string.count(of: "~") < 2 {
            return attributedString
        }
        
        var startIndex = -1
        for (index, char) in self.enumerated() {
            if char == "~" {
                if startIndex == -1 {
                    startIndex = index
                } else {
                    let subStrLenght = index-(startIndex+1)
                    let range = NSRange(location: startIndex+1, length: subStrLenght)
                    let strokeEffect: [NSAttributedString.Key : Any] = [
                        NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        NSAttributedString.Key.strikethroughColor: UIColor.black,
                    ]
                    attributedString.addAttributes(strokeEffect, range: range)
                    
                    // remove the symbols when showing them in the chat bubble
                    attributedString.deleteCharacters(in: NSRange(location: startIndex, length: 1))
                    attributedString.deleteCharacters(in: NSRange(location: index-1, length: 1)) // We remove 1 from the location because we just remove 1 character with the previous line
                    
                    startIndex = -1
                }
            }
        }
        return attributedString
    }
    
    func replaceTagWithColor(attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
        var sourceString = attributedString.string
        
        while let colorTagStartIndex = sourceString.index(of: "<color hex=\""),
              let colorTagStartClosureIndex = sourceString.index(of: "\">", startIndex: colorTagStartIndex),
              let endTagStartIndex = sourceString.index(of: "</color>", startIndex: colorTagStartClosureIndex) {
            
            let hexString = String(sourceString[sourceString.index(colorTagStartIndex, offsetBy: 12)..<sourceString.index(colorTagStartIndex, offsetBy: 19)])
            
            if let color = UIColor(hexString: hexString) {
                let endTagRange = NSRange(endTagStartIndex..<sourceString.index(endTagStartIndex, offsetBy: 8), in: sourceString)
                let startTagRange = NSRange(colorTagStartIndex..<sourceString.index(colorTagStartIndex, offsetBy: 21), in: sourceString)
                
                let innerStringDistance = sourceString.distance(from: sourceString.index(colorTagStartIndex, offsetBy: 21), to: endTagStartIndex)
                
                // remove the characters from the attributes string
                attributedString.deleteCharacters(in: endTagRange)
                attributedString.deleteCharacters(in: startTagRange)
                
                // remove the characters from the source string that we are parsing
                sourceString.replaceSubrange(endTagStartIndex..<sourceString.index(endTagStartIndex, offsetBy: 8), with: "")
                sourceString.replaceSubrange(colorTagStartIndex..<sourceString.index(colorTagStartIndex, offsetBy: 21), with: "")
                
                // Add the color
                let colorRange = NSRange(colorTagStartIndex..<sourceString.index(colorTagStartIndex, offsetBy: innerStringDistance), in: sourceString)
                
                attributedString.addAttribute(.foregroundColor, value: color, range: colorRange)
            }
            
        }
        
        return attributedString
    }
    
}

