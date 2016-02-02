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

    @IBOutlet weak var statusLabel: NSTextFieldCell!
    @IBOutlet weak var continuationLabel: NSTextField!
    @IBOutlet weak var txProgress: NSLevelIndicator!
    @IBOutlet weak var apduRequest: NSTextField!
    @IBOutlet weak var apduResult: NSTextField!
    @IBOutlet weak var apduButton: NSButton!
    
    @IBAction func sendApdu(sender: AnyObject) {
        print(apduRequest.stringValue)
        
        let data = dataFromHexString(apduRequest.stringValue);
        self.apduResult.stringValue = ""
        
        wearablePeripheral.writeValue(data!, forCharacteristic: apduControlCharacteristic, type: CBCharacteristicWriteType.WithResponse)
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
    
    var packetNumber: UInt16 = 0
    var totalPackets: Int = 0
    var sentPackets: Int = 0
    let MTU: Int = 20
    var continuationCharacteristicControl: CBCharacteristic!
    var continuationCharacteristicPacket: CBCharacteristic!
    var apduControlCharacteristic: CBCharacteristic!
    
    let START_CONTROL: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)
    let EOM_CONTROL: NSData = NSData(bytes: [0x01] as [UInt8], length: 1)
    
    let PaymentServiceUUID = CBUUID(string: "d7cc1dc2-3603-4e71-bce6-e3b1551633e0")
    let ContinuationControlCharacteristic = CBUUID(string: "cacc2825-0a2b-4cf2-a1a4-b9db27691382")
    let ContinuationPacketCharacteristic = CBUUID(string: "52d26993-6d10-4080-8166-35d11cf23c8c")
    let APDUControlCharacteristic = CBUUID(string: "0761f49b-5f56-4008-b203-fd2406db8c20")
    let APDUResultCharacteristic = CBUUID(string: "840f2622-ff4a-4a56-91ab-b1e6dd977db4")
    
    var startTime: NSTimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        self.apduRequest.stringValue = "FF"
        self.statusLabel.stringValue = ""
        self.continuationLabel.stringValue = ""
        self.testButton.enabled = false
        self.apduRequest.enabled = false
        self.apduButton.enabled = false
        
        self.txProgress.doubleValue = 0.0
        self.txProgress.displayIfNeeded()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            self.statusLabel.stringValue = "Searching for FitPay Wearable"
            central.scanForPeripheralsWithServices(nil, options: nil)
        } else {
            self.statusLabel.stringValue = "Bluetooth not available"
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let deviceName = "FitPay Wearable"
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        
        if (nameOfDeviceFound == deviceName) {
            self.statusLabel.stringValue = "Found FitPay Wearable, Connecting..."
            self.centralManager.stopScan();
            self.wearablePeripheral = peripheral
            self.wearablePeripheral.delegate = self
            
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.statusLabel.stringValue = "Connected, Discovering Services..."
        peripheral.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.testButton.enabled = false
        self.apduRequest.enabled = false
        self.apduButton.enabled = false
        self.statusLabel.stringValue = "Searching for FitPay Wearable"
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            if thisService.UUID == PaymentServiceUUID {
                self.statusLabel.stringValue = "FitPay Payment Service Found"
                self.testButton.enabled = true
                self.apduRequest.enabled = true
                self.apduButton.enabled = true
                peripheral.discoverCharacteristics(nil, forService: thisService)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            if thisCharacteristic.UUID == ContinuationControlCharacteristic {
                print("found continuation control characteristic")
                self.continuationCharacteristicControl = thisCharacteristic
            } else if thisCharacteristic.UUID == ContinuationPacketCharacteristic {
                print("found continuation packet characteristic")
                self.continuationCharacteristicPacket = thisCharacteristic
            } else if (thisCharacteristic.UUID == APDUControlCharacteristic) {
                self.apduControlCharacteristic = thisCharacteristic
            } else if (thisCharacteristic.UUID == APDUResultCharacteristic) {
                print("subscribing to apdu result notifications")
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("didUpdateValueForCharacteristic: \(characteristic)")
        if characteristic.UUID == APDUResultCharacteristic {
            let elapsedTime: Double = Double(NSDate.timeIntervalSinceReferenceDate() - startTime) * 1000
            let elapsedTimeStr: String = String(format: "%0.2f", elapsedTime)
            
            self.apduResult.stringValue = "\(hexString(characteristic.value))"
            self.continuationLabel.stringValue = "apdu result received, \(elapsedTimeStr)ms"
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("didUpdateNotificationStateForCharacteristic: \(characteristic)")
    }
    
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("write value \(characteristic.UUID)")
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
            self.continuationLabel.stringValue = "apdu sent [\(self.apduRequest.stringValue)], waiting for response..."
            self.startTime = NSDate.timeIntervalSinceReferenceDate()
        }
    }
    
    func sendContinuation(dataToSend: NSData) {
        let CONTINUATION_MTU: Int = MTU - 2
        print("writing start control")
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
            
            wearablePeripheral.writeValue(continuationPacket, forCharacteristic: continuationCharacteristicPacket, type: CBCharacteristicWriteType.WithResponse)
            
            sendDataIndex = sendDataIndex + amountToSend
            packetNumber++
        }
        
        print("writing eom control")
        wearablePeripheral.writeValue(EOM_CONTROL, forCharacteristic: continuationCharacteristicControl, type: CBCharacteristicWriteType.WithResponse)
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
}

