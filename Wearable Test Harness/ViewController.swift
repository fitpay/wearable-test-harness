//
//  ViewController.swift
//  BLE Test
//
//  Created by Scott Stevelinck on 1/26/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Cocoa
import CoreBluetooth
import SecurityFoundation

class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @IBOutlet weak var sequenceIdTextField: NSTextField!
    @IBOutlet weak var statusLabel: NSTextFieldCell!
    @IBOutlet weak var paymentAmount: NSTextField!
    @IBOutlet weak var continuationLabel: NSTextField!
    @IBOutlet weak var txProgress: NSLevelIndicator!
    @IBOutlet weak var apduRequest: NSTextField!
    @IBOutlet weak var apduResult: NSTextField!
    @IBOutlet weak var apduButton: NSButton!
    @IBOutlet weak var continuationStepper: NSStepper!
    
    @IBAction func sendApdu(sender: AnyObject) {
        print("sending apdu:  \(apduRequest.stringValue) with sequenceId: \(sequenceId)")
        if (apduRequest.stringValue.characters.count % 2 != 0) {
            apduRequest.stringValue = apduRequest.stringValue + "0";
        }

        var withContinuation = false;
        let data = NSMutableData()
        data.appendData(dataFromHexString(apduRequest.stringValue)!)
        if (data.length > 17) {
            debugPrint("APDU length : \(data.length) requires continuation")
            withContinuation = true
        }
        
        let apduPacket = NSMutableData()
        var sq16 = UInt16(bigEndian: sequenceId)
        apduPacket.appendData(RESERVED_FOR_FUTURE_USE)
        apduPacket.appendBytes(&sq16, length: sizeofValue(sequenceId))
        apduPacket.appendData(dataFromHexString(apduRequest.stringValue)!)
        
        self.apduResult.stringValue = ""
        
        if (withContinuation) {
            sendContinuation(apduPacket)
            return
        }
        
        debugPrint("... write apdu packet: \(apduPacket) to characteristic: \(apduControlCharacteristic.UUID), length: \(apduPacket.length)")
        
        wearablePeripheral.writeValue(apduPacket, forCharacteristic: apduControlCharacteristic, type: CBCharacteristicWriteType.WithResponse)
    }
    
    @IBAction func testContinuation(sender: AnyObject) {
        self.continuationLabel.stringValue = "starting continuation test"
        
        let bytesCount = continuationValue * 1000
        var randomBytes = [UInt8](count: bytesCount, repeatedValue: 0)
        
        SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        let hexString = NSMutableString()
        for byte in randomBytes {
            hexString.appendFormat("%02x", UInt(byte))
        }
        let stringValue = NSString(string: hexString)
        print("prepping to send: " + (stringValue as String))
        self.testButton.enabled = false
        sendContinuation(NSData(bytes: randomBytes, length: bytesCount))
        self.testButton.enabled = true
    }
    
    @IBOutlet weak var testButton: NSButton!
    
    var centralManager : CBCentralManager!
    var wearablePeripheral : CBPeripheral!
    var continuationValue: Int = 1
    
    var autoincrementSequenceId: Bool = true
    var sequenceId: UInt16 = 0
    var packetNumber: UInt16 = 0
    var totalPackets: Int = 0
    var sentPackets: Int = 0
    let MTU: Int = 20
    var continuationCharacteristicControl: CBCharacteristic!
    var continuationCharacteristicPacket: CBCharacteristic!
    var apduControlCharacteristic: CBCharacteristic!
    
    let START_CONTROL: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)
    let EOM_CONTROL: NSData = NSData(bytes: [0x01] as [UInt8], length: 1)
    let RESERVED_FOR_FUTURE_USE: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)
    
    let PaymentServiceUUID = CBUUID(string: "d7cc1dc2-3603-4e71-bce6-e3b1551633e0")
    
    let ContinuationControlCharacteristic = CBUUID(string: "cacc2825-0a2b-4cf2-a1a4-b9db27691382")
    let ContinuationPacketCharacteristic = CBUUID(string: "52d26993-6d10-4080-8166-35d11cf23c8c")
    
    let APDUControlCharacteristic = CBUUID(string: "0761f49b-5f56-4008-b203-fd2406db8c20")
    let APDUResultCharacteristic = CBUUID(string: "840f2622-ff4a-4a56-91ab-b1e6dd977db4")
    //TODO temp value for characteristic
    let NotificationCharacteristic = CBUUID(string: "37051cf0-d70e-4b3c-9e90-0f8e9278b4d3")
    
    var startTime: NSTimeInterval = 0
    
    
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

    
    func getDataRange(withData data: NSData, withBob start: Int, withEnd end: Int) -> NSData {
        let range : NSRange = NSMakeRange(start, end)
        var buffer = [UInt8](count: end - start, repeatedValue: 0x00)
        data.getBytes(&buffer, range: range)
        
        return NSData(bytes: buffer, length: end - start)
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
                uuid = CBUUID(data: data)
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

    var continuation: Continuation = Continuation()
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        self.apduRequest.stringValue = "FF"
        self.statusLabel.stringValue = ""
        self.continuationLabel.stringValue = ""
        self.disableUi()
        
        self.txProgress.doubleValue = 0.0
        self.txProgress.displayIfNeeded()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        debugPrint("centralManagerDidUpdateState invoked")
        if central.state == CBCentralManagerState.PoweredOn {
            self.statusLabel.stringValue = "Searching for FitPay Wearable"
            central.scanForPeripheralsWithServices(nil, options: nil)
        } else {
            self.statusLabel.stringValue = "Bluetooth not available"
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        //debugPrint("discovered peripheral: + \(peripheral)")
        let deviceName = "FitPay Wearable"
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        
        if (nameOfDeviceFound == deviceName) {
            debugPrint("found \(deviceName) peripheral: \(peripheral)")
            self.statusLabel.stringValue = "Found FitPay Wearable, Connecting..."
            self.centralManager.stopScan();
            self.wearablePeripheral = peripheral
            self.wearablePeripheral.delegate = self
            
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        debugPrint("connected to peripheral: \(peripheral)")
        self.statusLabel.stringValue = "Connected, Discovering Services..."
        peripheral.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        debugPrint("disconnected from peripheral: \(peripheral)")
        self.disableUi()
        self.statusLabel.stringValue = "Searching for FitPay Wearable"
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        debugPrint("discovered services from peripheral: \(peripheral), error: \(error)")
        for service in peripheral.services! {
            let thisService = service as CBService
            if thisService.UUID == PaymentServiceUUID {
                debugPrint("peripheral has PaymentService: \(PaymentServiceUUID)");
                self.statusLabel.stringValue = "FitPay Payment Service Found"
                peripheral.discoverCharacteristics(nil, forService: thisService)
                self.enableUi()
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        debugPrint("discovered characateristics for service: \(service.UUID), error: \(error)")
        for characteristic in service.characteristics! {
            debugPrint("service has characteristic: \(characteristic)")
            let thisCharacteristic = characteristic as CBCharacteristic
            debugPrint("cast as CBCharacteristic: \(thisCharacteristic), UUID: \(thisCharacteristic.UUID)")
            debugPrint(" .. writable: \(thisCharacteristic.properties.rawValue & CBCharacteristicProperties.Write.rawValue)")
            debugPrint(" .. writeWithoutResponse: \(thisCharacteristic.properties.rawValue & CBCharacteristicProperties.WriteWithoutResponse.rawValue)")
            debugPrint(" .. indicate: \(thisCharacteristic.properties.rawValue & CBCharacteristicProperties.Indicate.rawValue)")
            if thisCharacteristic.UUID == ContinuationControlCharacteristic {
                print(" ... found continuation control characteristic")
                self.continuationCharacteristicControl = thisCharacteristic
                //TODO resolve impl detail - should the device always subscribe
                // of subscribe only within context of an APDUControl
                print(" ... subscribing to continuation control characteristic")
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            } else if thisCharacteristic.UUID == ContinuationPacketCharacteristic {
                print(" ... found continuation packet characteristic")
                self.continuationCharacteristicPacket = thisCharacteristic
                //TODO resolve impl detail - should the device always subscribe
                // of subscribe only within context of an APDUControl
                print(" ... subscribing to continuation packet characteristic")
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            } else if (thisCharacteristic.UUID == APDUControlCharacteristic) {
                print(" ... found apdu control characteristic")
                self.apduControlCharacteristic = thisCharacteristic
            } else if (thisCharacteristic.UUID == APDUResultCharacteristic) {
                print(" ... found apdu result characteristic")
                print(" ... subscribing to apdu result notifications")
                //TODO resolve impl detail - should the device always subscribe
                // of subscribe only within context of an APDUControl
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            } else if (thisCharacteristic.UUID == NotificationCharacteristic) {
                print(" ... found transaction notification characteristic")
                print(" ... subscribing to transaction notifications")
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("didUpdateValueForCharacteristic: \(characteristic.UUID), error: \(error)")
        if characteristic.UUID == APDUResultCharacteristic {
            debugPrint("APDU Result characteristic update.   \(APDUResultCharacteristic)")
            let elapsedTime: Double = Double(NSDate.timeIntervalSinceReferenceDate() - startTime) * 1000
            let elapsedTimeStr: String = String(format: "%0.2f", elapsedTime)
            
            print("raw apdu result [\(hexString(characteristic.value))]")
            
            let apduResultMessage = ApduResultMessage(withMessage: characteristic.value!)
            
            postResult(apduResultMessage, elapsedTimeStr: elapsedTimeStr)
            
        } else if characteristic.UUID == ContinuationControlCharacteristic {
            debugPrint("Continuation control characteristic update.   \(characteristic.UUID) with value: \(hexString(characteristic.value))")
            
            let continuationControlMessage = ContinuationControlMessage(msg: characteristic.value!)
            if (continuationControlMessage.isBeginning) {
                debugPrint("continuation control start")
                if (continuation.uuid.UUIDString != CBUUID().UUIDString) {
                    debugPrint("Previous continuation item exists")
                }
                continuation.uuid = continuationControlMessage.uuid
                continuation.data.removeAll()
            
            } else {
                debugPrint("continuation control end")
                //TODO need to verify all packets received - change data structure to dictionary
                let completeResponse = NSMutableData()
                for packet in continuation.data {
                    completeResponse.appendData(packet)
                }
                debugPrint("complete response: \(hexString(completeResponse))")
                let crc = CRC32.init(data: completeResponse).hashValue
                let crc32 = UInt32(littleEndian: UInt32(crc))

                if (crc32 != continuationControlMessage.crc32) {
                    debugPrint("crcs are not equal.  expected: \(continuationControlMessage.crc32), calculated from continuation messages: \(crc32)")
                    self.continuationLabel.stringValue = "Continuation CRC check failed.  expected: \(continuationControlMessage.crc32), calculated from continuation messages: \(crc32)"
                    return;
                }
                let elapsedTime: Double = Double(NSDate.timeIntervalSinceReferenceDate() - startTime) * 1000
                let elapsedTimeStr: String = String(format: "%0.2f", elapsedTime)
                if (continuation.uuid.UUIDString == APDUResultCharacteristic.UUIDString) {
                    let apduResultMessage = ApduResultMessage(withMessage: completeResponse)
                    postResult(apduResultMessage, elapsedTimeStr: elapsedTimeStr)
                } else {
                    debugPrint("Do not know what to do with continuation for characteristic: \(continuation.uuid.UUIDString)")
                }
                // clear the continuation contents
                continuation.uuid = CBUUID()
                continuation.data.removeAll()
                
            }

        } else if characteristic.UUID == ContinuationPacketCharacteristic {
            debugPrint("Continuation packet characteristic update.   \(characteristic.UUID) with value: \(hexString(characteristic.value))")
            let msg : ContinuationPacketMessage = ContinuationPacketMessage(msg: characteristic.value!)
            debugPrint("continuation packet.  sortOrder: \(msg.sortOrder), data: \(hexString(msg.data))")
            let pos = Int(msg.sortOrder);
            continuation.data.insert(msg.data, atIndex: pos)
        } else if characteristic.UUID == NotificationCharacteristic {
            debugPrint("Transaction notification characteristic update.   \(characteristic.UUID) with value: \(hexString(characteristic.value))")
            self.continuationLabel.stringValue = "Received transaction notification:  \(hexString(characteristic.value))"
        }

    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("didUpdateNotificationStateForCharacteristic: \(characteristic), error: \(error)")
    }
    
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("didWriteValueForCharacteristic: \(characteristic.UUID), error: \(error)")
        if characteristic.UUID == ContinuationPacketCharacteristic {
            let d: Double = Double(Int(sentPackets++)) / Double(totalPackets) * 100
            print(d)
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.txProgress.doubleValue = d
                self.txProgress.displayIfNeeded()
                
                self.continuationLabel.stringValue = String(format: "%.1f completed", d)
            }
        } else if characteristic.UUID == ContinuationControlCharacteristic {
            let elapsedTime: Double = Double(NSDate.timeIntervalSinceReferenceDate() - startTime) * 1000
            let elapsedTimeStr: String = String(format: "%0.2f", elapsedTime)
            
           self.continuationLabel.stringValue = "control characteristic written, total time \(elapsedTimeStr)ms"
        } else if characteristic.UUID == APDUControlCharacteristic {
            if error != nil {
                self.continuationLabel.stringValue = "apdu send error [\(hexString(characteristic.value))]: \(error?.localizedDescription)"
            } else {
                self.continuationLabel.stringValue = "apdu sent [\(self.apduRequest.stringValue)], waiting for response..."
                self.startTime = NSDate.timeIntervalSinceReferenceDate()
            }
        }
    }
    
    func sendContinuation(dataToSend: NSData) {
        debugPrint("sendContinuation: \(dataToSend)")
        let CONTINUATION_MTU: Int = MTU - 2
        debugPrint("writing continuation control start to charactacteristic: \(continuationCharacteristicControl.UUID), value: \(hexString(START_CONTROL))")
        wearablePeripheral.writeValue(START_CONTROL, forCharacteristic: continuationCharacteristicControl, type: CBCharacteristicWriteType.WithResponse)

        var sendDataIndex: Int = 0

        sentPackets = 0
        packetNumber = 0
        totalPackets = dataToSend.length / CONTINUATION_MTU
        self.txProgress.doubleValue = 0.0
        self.txProgress.displayIfNeeded()
        self.startTime = NSDate.timeIntervalSinceReferenceDate()
        
        while (sendDataIndex < dataToSend.length) {
            var amountToSend:Int = dataToSend.length - sendDataIndex
            if amountToSend > CONTINUATION_MTU  {
                amountToSend = CONTINUATION_MTU
            }
            
            let chunk = NSData(bytes: dataToSend.bytes + sendDataIndex, length: amountToSend)
            
            let continuationPacket = NSMutableData()
            var pn16 = UInt16(bigEndian: packetNumber)
            continuationPacket.appendBytes(&pn16, length: sizeofValue(packetNumber))
            continuationPacket.appendData(chunk)
            
            debugPrint("writing continuation packet to charactacteristic: \(continuationCharacteristicPacket.UUID), value: \(hexString(continuationPacket))")
            wearablePeripheral.writeValue(continuationPacket, forCharacteristic: continuationCharacteristicPacket, type: CBCharacteristicWriteType.WithResponse)
            
            sendDataIndex = sendDataIndex + amountToSend
            packetNumber++
        }
        
        print("preparing continuation eom control - calculate checksum on \(dataToSend)")
        let crcValue = CRC32.init(data: dataToSend).hashValue
        var crc32 = UInt32(bigEndian: UInt32(crcValue))

        //let crcData = NSData(bytes: &crcValue, length: sizeof(Int))
        debugPrint("apdu checksum is \(crcValue)")
       // var iCrc = UInt32(crcValue)
        let msg = NSMutableData()
        msg.appendData(EOM_CONTROL)
        msg.appendBytes(&crc32, length: sizeofValue(crc32))
        //msg.appendData(crcData)
        
        debugPrint("writing continuation control end to charactacteristic: \(continuationCharacteristicControl.UUID), value: \(hexString(msg))")

        wearablePeripheral.writeValue(msg, forCharacteristic: continuationCharacteristicControl, type: CBCharacteristicWriteType.WithResponse)
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
    
    func disableUi() {
        self.testButton.enabled = false
        self.apduRequest.enabled = false
        self.apduButton.enabled = false
        self.sequenceIdTextField.enabled = false
    }
    
    func enableUi() {
        self.testButton.enabled = true
        self.apduRequest.enabled = true
        self.apduButton.enabled = true
        self.sequenceIdTextField.enabled = true
    }
    
    func postResult(apduResultMessage: ApduResultMessage, elapsedTimeStr: String) {
        
        self.apduResult.stringValue = "\(hexString(apduResultMessage.msg))"
        self.continuationLabel.stringValue = "apdu result code: \(apduResultMessage.resultCode), responseCode: \(apduResultMessage.responseCode) received for sequenceId: \(apduResultMessage.sequenceId), \(elapsedTimeStr)ms"
        
        if self.autoincrementSequenceId.boolValue {
            sequenceIdTextField.stringValue = String(++self.sequenceId)
            print("sequenceId incremented to: \(sequenceIdTextField.stringValue)")
        } else {
            print("skipping auto increment")
        }

    }
}

