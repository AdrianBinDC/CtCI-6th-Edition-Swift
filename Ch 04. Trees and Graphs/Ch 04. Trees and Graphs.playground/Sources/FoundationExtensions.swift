//
//  FoundationExtensions.swift
//
//  Created by Matthew Carroll on 2/11/16.
//  Copyright © 2016 Third Cup lc. All rights reserved.
//

import Foundation


// MARK: - String - Appending an optional string

public extension String {
    
    func replacingOccurrences(of replacementMap: [Character: Character]) -> String {
        return String(characters.map { character in replacementMap[character] ?? character })
    }
    
    mutating func replaceOccurrences(of replacementMap: [Character: Character]) {
        withMutableCharacters { characterView in
            characterView = CharacterView(characterView.map { character -> Character in
                replacementMap[character] ?? character
            })
        }
    }
    
    func appending(string: String?) -> String {
        return self + (string ?? "")
    }
    
    var nonEmpty: String? {
        return self.isEmpty ? nil : self
    }
    
    init?(toJoin: [String?], seperator: String = " ") {
        var string = ""
        toJoin.forEach { s in
            guard let s = s else { return }
            string += s + seperator
        }
        guard !string.isEmpty else { return nil }
        string.dropLast()
        self = string
    }
}

// MARK: - Date - Comparing self with now

public extension Date {
    
    var startOfTheDay: Date {
        return Calendar.autoupdatingCurrent.startOfDay(for: self)
    }
    
    var startOfTheHour: Date {
        let seconds = Calendar.autoupdatingCurrent.component(.hour, from: self) * 3600
        return Calendar.autoupdatingCurrent.startOfDay(for: self) + TimeInterval(seconds)
    }
    
    var startOfTheMinute: Date {
        let seconds = TimeInterval(Calendar.autoupdatingCurrent.component(.second, from: self))
        let nanoSeconds = timeIntervalSince1970 - TimeInterval(Int(timeIntervalSince1970))
        return self - seconds - nanoSeconds
    }
    
    var isSameHourAsNow: Bool {
        guard Calendar.autoupdatingCurrent.isDateInToday(self) else { return false }
        let selfHour = Calendar.autoupdatingCurrent.component(.hour, from: self)
        let nowHour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
        return selfHour == nowHour
    }
    
    var shortStyle: String {
        return DateFormatter.localizedString(from: self, dateStyle: .short, timeStyle: .short)
    }
}

@available(iOS 10.0, *)
public extension ISO8601DateFormatter {
    
    convenience init(timeZone: TimeZone) {
        self.init()
        self.timeZone = timeZone
    }
}

public extension DateFormatter {
    
    convenience init(dateFormat: String?, timeZone: TimeZone?) {
        self.init()
        self.dateFormat = dateFormat
        self.timeZone = timeZone
    }
}

// MARK: - The hours in today in self; the timezone of an iso8601 or rfc 822 date string

public extension TimeZone {
    
    var hourOfTheDay: Int {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = self
        return calendar.component(.hour, from: Date())
    }
    
    var hoursRemainingInToday: Int {
        return 23 - hourOfTheDay
    }
    
    static func timeZoneFor(iso8601OrRFC822TimeZone dateString: String) -> TimeZone? {
        let iso8601OrRFC822TimeZonePattern = "([+-])(0\\d|1[0-4]):?([0-5]\\d)$"
        let regex = try! NSRegularExpression(pattern: iso8601OrRFC822TimeZonePattern, options: .anchorsMatchLines)
        guard let match = regex.firstMatch(in: dateString, options: [], range: NSRange(location: 0, length: dateString.utf16.count)),
            match.numberOfRanges == 4 else { return nil }
        
        let substrings = match.substrings(of: dateString)
        guard let sign = Int(substrings[1] + "1"), let hours = Int(substrings[2]), let minutes = Int(substrings[3]) else { return nil }
        let offset = (hours * 3600 + minutes * 60) * sign
        return TimeZone(secondsFromGMT: offset)
    }
    
    static func hoursRemainingInDay(of dateString: String) -> Int? {
        guard let timeZone = timeZoneFor(iso8601OrRFC822TimeZone: dateString) else { return nil }
        return timeZone.hoursRemainingInToday
    }
    
    static func hourOfTheDay(of dateString: String) -> Int? {
        guard let timeZone = timeZoneFor(iso8601OrRFC822TimeZone: dateString) else { return nil }
        return timeZone.hourOfTheDay
    }
}


// MARK: - Substrings of a result

public extension NSTextCheckingResult {
    
    func substrings(of checkedString: String) -> [String] {
        return (0..<numberOfRanges).map {
            checkedString.substring(at: rangeAt($0))
        }
    }
    
    func substrings(of checkedString: String, captureGroups: CountableRange<Int>) -> [String] {
        return captureGroups.map { index in 
            checkedString.substring(at: rangeAt(index))
        }
    }
}

// MARK: - Bridge an objective-c range

public extension String {
    
    func substring(at range: NSRange) -> String {
        let start = index(startIndex, offsetBy: range.location)
        let end = index(start, offsetBy: range.length)
        return substring(with: start..<end)
    }
    
    var nsRange: NSRange {
        return NSRange(location: 0, length: utf16.count)
    }
    
    func nsRangeOf(range: Range<Index>) -> NSRange {
        let location = distance(from: startIndex, to: range.lowerBound)
        let length = distance(from: range.lowerBound, to: range.upperBound)
        return NSRange(location: location, length: length)
    }
}

public extension String.CharacterView {
    
    func distanceTo(character: Character) -> IndexDistance? {
        var distance = 0
        for c in self {
            if c == character {
                return distance
            }
            distance += 1
        }
        return nil
    }
}

public extension String.CharacterView {
    
    func rangeOf(range: NSRange) -> Range<Index> {
        let start = index(startIndex, offsetBy: range.location)
        let end = index(start, offsetBy: range.length)
        return start..<end
    }
}

// MARK: - Enumerate matches of `regExPattern` in self and return a string of applying `result` to self

public extension String {
    
    func replacingMatches(of regExPattern: String, options: NSRegularExpression.Options = [], replacement: @escaping (_ match: String) -> String?) -> String? {
        return replacingMatches(of: regExPattern, options: options, range: startIndex..<endIndex) { match, _, _ in
            replacement(match)
        }
    }
    
    func replacingMatches(of pattern: String, options: NSRegularExpression.Options = [], range: Range<Index>, replacement: @escaping (_ match: String, _ result: NSTextCheckingResult, _ stop: UnsafeMutablePointer<ObjCBool>) -> String?) -> String? {
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        var selfCopy = self
        let nsRange = self.nsRangeOf(range: range)
        
        regex.enumerateMatches(in: self, options: [], range: nsRange) { checkingResult, _, stop in
            guard let checkingResult = checkingResult else { return }
            let match = substring(at: checkingResult.range)
            guard let replacement = replacement(match, checkingResult, stop) else { return }
            
            let minLength = min(replacement.characters.count, match.characters.count)
            var replacementString = replacement.substring(to: replacement.index(startIndex, offsetBy: minLength))
            
            let offset = selfCopy.characters.count - characters.count
            let start = selfCopy.index(startIndex, offsetBy: checkingResult.range.location + offset)
            let end = selfCopy.index(start, offsetBy: checkingResult.range.length)
            selfCopy.replaceSubrange(start..<end, with: replacementString)
            
            if replacementString.characters.count < replacement.characters.count {
                replacementString = replacement.substring(from: replacementString.endIndex)
                selfCopy.insert(contentsOf: replacementString.characters, at: end)
            }
        }
        return selfCopy
    }
}


// MARK: - Drop the last character

public extension String {
    
    mutating func dropLast() {
        withMutableCharacters { $0 = $0.dropLast() }
    }
    
    mutating func replaceAtIndex(i: Index, c: Character) {
        guard i < endIndex else { return }
        withMutableCharacters { cv in
            cv.replaceSubrange(i...i, with: [c])
        }
    }
}

public extension String {
    
    func droppingFirst() -> String {
        return substring(from: index(after: startIndex))
    }
}


public extension String {
    
    func rangeDistanceOfString(string: String) -> Range<IndexDistance>? {
        guard let range = range(of: string) else { return nil }
        let start = distance(from: startIndex, to: range.lowerBound)
        let end = start + distance(from: range.lowerBound, to: range.upperBound)
        return start..<end
    }
}

public extension String {
    
    func distance(to predicate: (_: Character) -> Bool) -> IndexDistance? {
        return characters.reduceWhile(0) { distance, c -> Int? in
            guard !predicate(c) else { return nil }
            return distance + 1
        }
    }
}


// MARK: - OperationQueue - Completion operation for a list of operations

public extension OperationQueue {
    
    convenience init(qualityOfService: QualityOfService) {
        self.init()
        self.qualityOfService = qualityOfService
    }
    
    func addOperations(operations: [Operation], completionOperation: Operation) {
        operations.forEach {
            completionOperation.addDependency($0)
            addOperation($0)
        }
        addOperation(completionOperation)
    }
    
    func add(_ block: @escaping () ->()) {
        addOperation(block)
    }
}



// MARK: - Converting self for optional chaining:

public extension Integer {
    
    var asString: String {
        return "\(self)"
    }
}

public extension FloatingPoint {
    
    var asString: String {
        return "\(self)"
    }
}

public extension Collection {
    
    var asString: String {
        return "\(self)"
    }
}

public extension Double {
    
    var asInt: Int {
        return Int(self)
    }
}

public extension NSNumber {
    
    var asString: String {
        return "\(self)"
    }
}

public extension IntegerArithmetic {
    
    var absv: Self {
        let zero: Self = self - self
        return self < zero ? zero - self : self
    }
}


// MARK: - Shortened NSLocalizedString

func NSLocalizedString(key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

public extension Array {
    
    var dropFirst: Array {
        return Array(dropFirst())
    }
}

var mainQueue: OperationQueue { return OperationQueue.main }

