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
    
    @IBOutlet weak var txProgress: NSLevelIndicator!
    
    @IBAction func testContinuation(sender: AnyObject) {
        self.statusLabel.stringValue = "Testing Continuation"
        
        let bytesCount = 1000
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
    
    let PaymentServiceUUID = CBUUID(string: "d7cc1dc2-3603-4e71-bce6-e3b1551633e0")
    let ContinuationControlCharacteristic = CBUUID(string: "cacc2825-0a2b-4cf2-a1a4-b9db27691382")
    let ContinuationPacketCharacteristic = CBUUID(string: "52d26993-6d10-4080-8166-35d11cf23c8c")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        self.statusLabel.stringValue = ""
        self.testButton.enabled = false
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
        self.statusLabel.stringValue = "Searching for FitPay Wearable"
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            if thisService.UUID == PaymentServiceUUID {
                self.statusLabel.stringValue = "FitPay Payment Service Found"
                self.testButton.enabled = true
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
            }
        }
    }
    
    var packetNumber: UInt16 = 0
    var totalPackets: Int = 0
    var sentPackets: Int = 0
    let MTU: Int = 20
    var continuationCharacteristicControl: CBCharacteristic!
    var continuationCharacteristicPacket: CBCharacteristic!
    
    let START_CONTROL: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)
    let EOM_CONTROL: NSData = NSData(bytes: [0x01] as [UInt8], length: 1)
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if characteristic.UUID == ContinuationPacketCharacteristic {
            let d: Double = Double(Int(sentPackets++)) / Double(totalPackets) * 100
            print(d)
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.txProgress.doubleValue = d
                self.txProgress.displayIfNeeded()
            }
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
}

