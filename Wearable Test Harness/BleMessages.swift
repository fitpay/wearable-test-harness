//
//  BleMessages.swift
//  Wearable Test Harness
//
//  Created by Tim Shanahan on 3/15/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Foundation
import CoreBluetooth

let RESERVED_FOR_FUTURE_USE: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)


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
    let message: NSData
    init(msg: NSData) {
        message = msg
        if (msg.length == 0) {
            sortOrder = 0
            data = NSData()
            return
        }
        let sortOrderRange : NSRange = NSMakeRange(0, 2)
        var buffer = [UInt8](count: 2, repeatedValue: 0x00)
        msg.getBytes(&buffer, range: sortOrderRange)
        
        let sortOrderData = NSData(bytes: buffer, length: 2)
        var u16 : UInt16 = 0
        sortOrderData.getBytes(&u16, length: 2)
        sortOrder = UInt16(littleEndian: u16)
        
        let range : NSRange = NSMakeRange(2, msg.length - 2)
        buffer = [UInt8](count: (msg.length) - 2, repeatedValue: 0x00)
        msg.getBytes(&buffer, range: range)
        
        data = NSData(bytes: buffer, length: (msg.length) - 2)
    }
    init(withSortOrder: UInt16, withData: NSData) {
        sortOrder = withSortOrder
        data = withData
        let continuationPacket = NSMutableData()
        var pn16 = UInt16(littleEndian: sortOrder)
        continuationPacket.appendBytes(&pn16, length: sizeofValue(sortOrder))
        continuationPacket.appendData(withData)
        message = continuationPacket
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
        if (msg.length == 0) {
            type = 0x00
            isBeginning = false
            isEnd = false
            data = NSData()
            uuid = CBUUID()
            crc32 = UInt32()
            return
        }
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
            crc32 = UInt32(littleEndian: u32)
        } else {
            print("Continuation control data is not the correct length");
            uuid = CBUUID()
            crc32 = UInt32()
        }
        
    }
}

struct ApduControlMessage {
    
    let sequenceId : UInt16
    let data : NSData
    let msg : NSMutableData
    
    init(withSequenceId: UInt16, withData: NSData) {
        sequenceId = withSequenceId
        data = withData
        msg = NSMutableData()
        var sq16 = UInt16(littleEndian: sequenceId)
        msg.appendData(RESERVED_FOR_FUTURE_USE)
        msg.appendBytes(&sq16, length: sizeofValue(sequenceId))
        msg.appendData(withData)
    }

}

struct ApduResultMessage {
    let msg : NSData
    let resultCode : UInt8
    let sequenceId : UInt16
    let responseCode: NSData
    init(withMessage: NSData) {
        if (withMessage.length == 0) {
            msg=withMessage
            resultCode = 0
            sequenceId = 0
            responseCode = NSData()
            return
        }
        msg = withMessage
        var buffer = [UInt8](count: (withMessage.length), repeatedValue: 0x00)
        withMessage.getBytes(&buffer, length: buffer.count)
        
        resultCode = UInt8(buffer[0])
        
        var recvSeqId:UInt16?
        recvSeqId = UInt16(buffer[2]) << 8
        recvSeqId = recvSeqId! | UInt16(buffer[1])
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

    struct DeviceResetMessage {
        
        let op : UInt8
        let msg : NSMutableData
        
        init(withOp: UInt8) {
            op = withOp
            msg = NSMutableData()
            var sq16 = UInt8(op)
            msg.appendBytes(&sq16, length: sizeofValue(op))
        }
        
    }

struct NotificationMessage {
    
    let date: NSDate
    let data: NSData
    let message: NSData
    
    init() {
        date = NSDate()
        data = NSData()
        message = dateMessageFrag(date)
    }
    
    init(withData : NSData) {
        data = withData
        date = NSDate()
        
        let msg = dateMessageFrag(date)
        msg.appendData(withData)
        message = msg

    }
    
    init(withMessage: NSData) {
        date = NSDate()  //TODO this needs to be populated via the parsed date
        data = NSData()  // TODO this needs to be populated from the parsed message
        message = withMessage
    }
}

func dateMessageFrag(date: NSDate) -> NSMutableData {
    let calendar = NSCalendar.currentCalendar()
    let components = calendar.components([NSCalendarUnit.Year, NSCalendarUnit.Month, NSCalendarUnit.Day, NSCalendarUnit.Hour, NSCalendarUnit.Minute, NSCalendarUnit.Second], fromDate: date)

    let msg = NSMutableData()
    var sq16 = UInt16(Int(components.year))
    msg.appendBytes(&sq16, length: 2)
    var sq8 = UInt8(Int(components.month))
    msg.appendBytes(&sq8, length: 1)
    sq8 = UInt8(Int(components.day))
    msg.appendBytes(&sq8, length: 1)
    sq8 = UInt8(Int(components.hour))
    msg.appendBytes(&sq8, length: 1)
    sq8 = UInt8(Int(components.minute))
    msg.appendBytes(&sq8, length: 1)
    sq8 = UInt8(Int(components.second))
    msg.appendBytes(&sq8, length: 1)
    return msg
    
}


