//
//  Conversions.swift
//  Wearable Test Harness
//
//  Created by Tim Shanahan on 3/15/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Foundation

// Reverse the endianess of the data
func reverseData(data: NSData) -> NSData {
    var inData = [UInt8](count: data.length, repeatedValue: 0)
    data.getBytes(&inData, length: data.length)
    var outData = [UInt8](count: data.length, repeatedValue: 0)
    var outPos = inData.count;
    for i in 0 ..< inData.count {
        outPos--
        outData[i] = inData[outPos]
    }
    let out = NSData(bytes: outData, length: outData.count)
    return out
}

func dataFromHexString(value: NSString!) -> NSData? {
    let trimmedString = value.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<> ")).stringByReplacingOccurrencesOfString(" ", withString: "")
    
    let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$", options: .CaseInsensitive)
    
    let found = regex.firstMatchInString(trimmedString, options: [], range: NSMakeRange(0, trimmedString.characters.count))
    
    if found == nil || found?.range.location == NSNotFound || trimmedString.characters.count % 2 != 0 {
        return nil
    }
    
    let data = NSMutableData(capacity: trimmedString.characters.count / 2)
    
    for var index = trimmedString.startIndex; index < trimmedString.endIndex; index = index.successor().successor() {
        let byteString = trimmedString.substringWithRange(Range<String.Index>(start: index, end: index.successor().successor()))
        let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
        data?.appendBytes([num] as [UInt8], length: 1)
    }
    
    return data
}

func hexString(value: NSData!) -> String {
    var s = ""
    
    if value == nil {
        return s
    }
    
    var byte: UInt8 = 0
    for i in 0 ..< value.length {
        value.getBytes(&byte, range: NSMakeRange(i, 1))
        s += String(format: "%02x", byte)
    }
    
    return s
}
