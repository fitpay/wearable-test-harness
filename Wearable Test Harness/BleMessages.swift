//
//  BleMessages.swift
//  Wearable Test Harness
//
//  Created by Tim Shanahan on 3/15/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Foundation
import CoreBluetooth

struct Continuation {
    var uuid : CBUUID
    var data : [NSData]
    init()  {
        uuid = CBUUID()
        data = [NSData]()
    }
    init(uuidValue: CBUUID) {
        uuid = uuidValue
        data = [NSData]()
    }
}


struct ContinuationPacketMessage {
    let sortOrder: UInt16
    let data: NSData
    init(msg: NSData) {
        let sortOrderRange : NSRange = NSMakeRange(0, 2)
        var buffer = [UInt8](count: 2, repeatedValue: 0x00)
        msg.getBytes(&buffer, range: sortOrderRange)
        
        let sortOrderData = NSData(bytes: buffer, length: 2)
        var u16 : UInt16 = 0
        sortOrderData.getBytes(&u16, length: 2)
        sortOrder = UInt16(bigEndian: u16)
        
        let range : NSRange = NSMakeRange(2, msg.length - 2)
        buffer = [UInt8](count: (msg.length) - 2, repeatedValue: 0x00)
        msg.getBytes(&buffer, range: range)
        
        data = NSData(bytes: buffer, length: (msg.length) - 2)
    }
}

struct ContinuationControlMessage {
    let type: UInt8
    let isBeginning: Bool
    let isEnd: Bool
    let data: NSData
    let uuid: CBUUID
    let crc32: UInt32
    init(withUuid: CBUUID) {
        type = 0
        isBeginning = true
        isEnd = false
        uuid = withUuid
        data = NSData()
        crc32 = UInt32()
    }
    init(msg: NSData) {
        var buffer = [UInt8](count: (msg.length), repeatedValue: 0x00)
        msg.getBytes(&buffer, length: buffer.count)
        
        type = buffer[0]
        if (buffer[0] == 0x00) {
            isBeginning = true
            isEnd = false
        } else {
            isBeginning = false
            isEnd = true
        }
        
        let range : NSRange = NSMakeRange(1, msg.length - 1)
        buffer = [UInt8](count: (msg.length) - 1, repeatedValue: 0x00)
        msg.getBytes(&buffer, range: range)
        
        data = NSData(bytes: buffer, length: (msg.length) - 1)
        if (data.length == 16) {
            //reverse bytes for little endian representation
            var inData = [UInt8](count: data.length, repeatedValue: 0)
            data.getBytes(&inData, length: data.length)
            var outData = [UInt8](count: data.length, repeatedValue: 0)
            var outPos = inData.count;
            for i in 0 ..< inData.count {
                outPos--
                outData[i] = inData[outPos]
            }
            let out = NSData(bytes: outData, length: outData.count)
            uuid = CBUUID(data: out)
            crc32 = UInt32()
        } else if (data.length == 4) {
            uuid = CBUUID()
            var u32 : UInt32 = 0
            data.getBytes(&u32, length: 4)
            crc32 = UInt32(bigEndian: u32)
        } else {
            print("Continuation control data is not the correct length");
            uuid = CBUUID()
            crc32 = UInt32()
        }
        
    }
}

struct ApduResultMessage {
    let msg : NSData
    let resultCode : UInt8
    let sequenceId : UInt16
    let responseCode: NSData
    init(withMessage: NSData) {
        msg = withMessage
        var buffer = [UInt8](count: (withMessage.length), repeatedValue: 0x00)
        withMessage.getBytes(&buffer, length: buffer.count)
        
        resultCode = UInt8(buffer[0])
        
        var recvSeqId:UInt16?
        recvSeqId = UInt16(buffer[1]) << 8
        recvSeqId = recvSeqId! | UInt16(buffer[2])
        sequenceId = recvSeqId!
        
        let range : NSRange = NSMakeRange(withMessage.length - 2, 2)
        buffer = [UInt8](count: 2, repeatedValue: 0x00)
        msg.getBytes(&buffer, range: range)
        responseCode = NSData(bytes: buffer, length: 2)
    }
    
}

struct SecurityWriteMessage {
    let msg: NSData
    init(withEnabled: Bool) {
        let tempData = NSMutableData()
        if (withEnabled) {
            tempData.appendData(NSData(bytes: [0x01] as [UInt8], length: 1))
        } else {
            tempData.appendData(NSData(bytes: [0x00] as [UInt8], length: 1))
        }
        msg = NSData(data: tempData)
    }
}

struct SecurityStateMessage {
    let isNfcEnabled: Bool
    let nfcErrorCode: UInt8
    init(withMessage: NSData) {
        if (withMessage.length == 0) {
            isNfcEnabled = false
            nfcErrorCode = 0x00
            return
        }
        var buffer = [UInt8](count: (withMessage.length), repeatedValue: 0x00)
        withMessage.getBytes(&buffer, length: buffer.count)
        if (buffer.count > 0 && buffer[0] == 0x01) {
            isNfcEnabled = true
        } else {
            isNfcEnabled = false
        }
        if (buffer.count > 1) {
            nfcErrorCode = buffer[1]
        } else {
            nfcErrorCode = 0x00
        }
    }
}

