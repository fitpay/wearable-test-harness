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

class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    let START_CONTROL: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)
    let EOM_CONTROL: NSData = NSData(bytes: [0x01] as [UInt8], length: 1)
    let RESERVED_FOR_FUTURE_USE: NSData = NSData(bytes: [0x00] as [UInt8], length: 1)
    
    let ContinuationControlCharacteristic = CBUUID(string: FitpayPaymentCharacteristicUUID.ContinuationControlCharacteristic.rawValue)
    let ContinuationPacketCharacteristic = CBUUID(string: FitpayPaymentCharacteristicUUID.ContinuationPacketCharacteristic.rawValue)
    
    let APDUControlCharacteristic = CBUUID(string: FitpayPaymentCharacteristicUUID.APDUControlCharacteristic.rawValue)
    let APDUResultCharacteristic = CBUUID(string: FitpayPaymentCharacteristicUUID.APDUResultCharacteristic.rawValue)
    let SecureElementIdCharacteristicUUID = CBUUID(string: FitpayPaymentCharacteristicUUID.SecureElementIdCharacteristic.rawValue)
    let NotificationCharacteristicUUID = CBUUID(string: FitpayPaymentCharacteristicUUID.NotificationCharacteristic.rawValue)
    let SecurityWriteCharacteristicUUID = CBUUID(string: FitpayPaymentCharacteristicUUID.SecurityWriteCharacteristic.rawValue)
    let SecurityStateCharacteristicUUID = CBUUID(string: FitpayPaymentCharacteristicUUID.SecurityStateCharacteristic.rawValue)

    let PaymentServiceUUID = CBUUID(string: FitpayServiceUUID.PaymentServiceUUID.rawValue)
    let DeviceInfoServiceUUID = CBUUID(string: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue)

    // Note: currently does not support a characteristic being provided by two or more services
    var paymentServiceCharacteristicArray : [CharacteristicInfo] = [
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "APDU Control", withUUID: FitpayPaymentCharacteristicUUID.APDUControlCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "APDU Result", withUUID: FitpayPaymentCharacteristicUUID.APDUResultCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "Continuation Control", withUUID: FitpayPaymentCharacteristicUUID.ContinuationControlCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "Contnuation Packet", withUUID: FitpayPaymentCharacteristicUUID.ContinuationPacketCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue , withName: "Secure Element ID", withUUID: FitpayPaymentCharacteristicUUID.SecureElementIdCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "Notification", withUUID: FitpayPaymentCharacteristicUUID.NotificationCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "Security Write", withUUID: FitpayPaymentCharacteristicUUID.SecurityWriteCharacteristic.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.PaymentServiceUUID.rawValue, withName: "Security State", withUUID: FitpayPaymentCharacteristicUUID.SecurityStateCharacteristic.rawValue)
        ]
    
    var deviceInfoServiceCharacteristicArray: [CharacteristicInfo] = [
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "Manufacturer Name", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_MANUFACTURER_NAME_STRING.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "Model Number", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_MODEL_NUMBER_STRING.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "Serial Number", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_SERIAL_NUMBER_STRING.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "Firmware Revision", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_FIRMWARE_REVISION_STRING.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "Hardware Revision", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_HARDWARE_REVISION_STRING.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "Software Revision", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_SOFTWARE_REVISION_STRING.rawValue),
        CharacteristicInfo(withServiceUUID: FitpayServiceUUID.DeviceInfoServiceUUID.rawValue, withName: "System ID", withUUID: FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_SYSTEM_ID.rawValue)
    ]

    var characteristicArray  = [CharacteristicInfo]()

    
    @IBOutlet weak var sequenceIdTextField: NSTextField!
    @IBOutlet weak var statusLabel: NSTextFieldCell!
    @IBOutlet weak var paymentAmount: NSTextField!
    @IBOutlet weak var continuationLabel: NSTextField!
    @IBOutlet weak var txProgress: NSLevelIndicator!
    @IBOutlet weak var apduRequest: NSTextField!
    @IBOutlet weak var apduResult: NSTextField!
    @IBOutlet weak var apduButton: NSButton!
    @IBOutlet weak var testButton: NSButton!
    @IBOutlet weak var continuationStepper: NSStepper!
    
    @IBOutlet weak var sendNotification: NSButton!
    @IBOutlet weak var notificationData: NSTextField!
    @IBOutlet weak var receivedNotificationData: NSTextField!
    
    @IBOutlet weak var securityWriteData: NSTextField!
    @IBOutlet weak var securityWriteButton: NSButton!
    @IBOutlet weak var securityState: NSTextField!
    
    @IBOutlet weak var pairingDeviceName: NSTextField!
    
    @IBOutlet weak var characteristicTableView: NSTableView!

    @IBOutlet weak var viewPaymentServiceButton: NSButton!
    @IBOutlet weak var viewDeviceInfoServiceButton: NSButton!
    
    //MARK: Actions
    
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
            sendApduContinuation(apduPacket)
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
        sendApduContinuation(NSData(bytes: randomBytes, length: bytesCount))
        self.testButton.enabled = true
    }

    @IBAction func sendNotification(sender: NSButton) {
        self.continuationLabel.stringValue = "sending notification to device"
        debugPrint("sendNotification is not implemented")
    }

    
    @IBAction func sendSecurityWrite(sender: NSButton) {
        if (securityWriteCharacteristic == nil) {
            self.continuationLabel.stringValue = "security write characteristic is not available on this service"
            return
        }

        self.continuationLabel.stringValue = "sending security update to toggle nfc device"
        debugPrint("current security state: \(hexString(securityStateCharacteristic.value))")
        var isNfcEnabled: Bool = false;
        if (securityStateCharacteristic.value != nil) {
            let currentState = SecurityStateMessage(withMessage: securityStateCharacteristic.value!)
            isNfcEnabled = currentState.isNfcEnabled
        }
        let msg = SecurityWriteMessage.init(withEnabled: !isNfcEnabled).msg
        debugPrint("... write security write update: \(msg) to characteristic: \(securityWriteCharacteristic.UUID), length: \(msg.length)")
        if ((securityWriteCharacteristic) != nil) {
            wearablePeripheral.writeValue(msg, forCharacteristic: securityWriteCharacteristic, type: CBCharacteristicWriteType.WithResponse)
        } else {
            self.continuationLabel.stringValue = "security write characteristic is not available on this service"
        }
    }
    
    
    @IBAction func serviceViewSelected(sender: NSButton) {
        debugPrint("service view selected: \(sender.title)")
        if (sender == viewPaymentServiceButton) {
            debugPrint("view payment service")
            displayServiceUUID = FitpayServiceUUID.PaymentServiceUUID.rawValue;
        }
        if (sender == viewDeviceInfoServiceButton) {
            debugPrint("view device info service")
            displayServiceUUID = FitpayServiceUUID.DeviceInfoServiceUUID.rawValue;
        }
        doCharacteristicRead()
        //characteristicTableView.reloadData();
    }
    
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
    var securityWriteCharacteristic: CBCharacteristic!
    var securityStateCharacteristic: CBCharacteristic!
    var notificationCharacteristic: CBCharacteristic!
    
    var startTime: NSTimeInterval = 0
    
    var displayServiceUUID = ""
   
    
    func getDataRange(withData data: NSData, withBob start: Int, withEnd end: Int) -> NSData {
        let range : NSRange = NSMakeRange(start, end)
        var buffer = [UInt8](count: end - start, repeatedValue: 0x00)
        data.getBytes(&buffer, range: range)
        
        return NSData(bytes: buffer, length: end - start)
    }

    var continuation: Continuation = Continuation()
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        self.apduRequest.stringValue = "FF"
        self.statusLabel.stringValue = ""
        self.continuationLabel.stringValue = ""
        self.pairingDeviceName.stringValue = "FitPay Wearable"
        self.disableUi()
        
        self.txProgress.doubleValue = 0.0
        self.txProgress.displayIfNeeded()
        
        characteristicArray = paymentServiceCharacteristicArray + deviceInfoServiceCharacteristicArray
        
        characteristicTableView.setDataSource(self)
        characteristicTableView.setDelegate(self)

    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        debugPrint("ViewController view did appear")
        characteristicTableView.reloadData();
    }


    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        debugPrint("centralManagerDidUpdateState invoked.  \(central.state)")
        if central.state == CBCentralManagerState.PoweredOn {
            self.statusLabel.stringValue = "Searching for \(self.pairingDeviceName.stringValue)"
            central.scanForPeripheralsWithServices(nil, options: nil)
        } else {
            self.statusLabel.stringValue = "Bluetooth not available"
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        //debugPrint("discovered peripheral: + \(peripheral)")
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        
        if (nameOfDeviceFound == self.pairingDeviceName.stringValue) {
            debugPrint("found device: \(self.pairingDeviceName.stringValue), peripheral: \(peripheral)")
            self.statusLabel.stringValue = "Found \(self.pairingDeviceName.stringValue), Connecting..."
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
        self.statusLabel.stringValue = "Searching for \(self.pairingDeviceName.stringValue)"
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        debugPrint("discovered services from peripheral: \(peripheral), error: \(error)")
        for service in peripheral.services! {
            let thisService = service as CBService
            if thisService.UUID == PaymentServiceUUID {
                debugPrint("peripheral has PaymentService: \(PaymentServiceUUID)");
                self.statusLabel.stringValue = "FitPay Payment Service Found"
                viewPaymentServiceButton.enabled = true
                displayServiceUUID = thisService.UUID.UUIDString
                viewPaymentServiceButton.state = NSOnState;
                peripheral.discoverCharacteristics(nil, forService: thisService)
                self.enableUi()
            } else if thisService.UUID == DeviceInfoServiceUUID {
                debugPrint("peripheral has DeviceInfoService: \(thisService.UUID)");
                self.statusLabel.stringValue = "Device Info Service Found"
                viewDeviceInfoServiceButton.enabled = true;
                displayServiceUUID = thisService.UUID.UUIDString
                if (viewPaymentServiceButton.state != NSOnState) {
                    viewDeviceInfoServiceButton.state = NSOnState;
                }
                peripheral.discoverCharacteristics(nil, forService: thisService)
            }

        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        debugPrint("discovered characateristics for service: \(service.UUID), error: \(error)")
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            let thisUUID = coerceUUIDStringNameToRealUUID(thisCharacteristic.UUID.UUIDString)
            debugPrint("found characteristic: \(thisCharacteristic), UUID: \(thisUUID)")
            let characterisiticInfo = getCharacteristicInfo(thisUUID)
            if (characterisiticInfo != nil) {
                let permissions = getPermissionsString(thisCharacteristic)
                debugPrint(" .. permissions: \(permissions)")
                characterisiticInfo?.permissions = permissions
                characterisiticInfo?.characteristic = thisCharacteristic
            } else {
                debugPrint("could not find characteristicInfo for: \(thisUUID)")
            }
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
            } else if (thisCharacteristic.UUID == SecureElementIdCharacteristicUUID) {
                print(" ... found secure element id characteristic")
            } else if (thisCharacteristic.UUID == NotificationCharacteristicUUID) {
                print(" ... found transaction notification characteristic")
                self.notificationCharacteristic = thisCharacteristic
                print(" ... subscribing to transaction notifications")
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            } else if (thisCharacteristic.UUID == SecurityWriteCharacteristicUUID) {
                print(" ... found security write characteristic")
                self.securityWriteCharacteristic = thisCharacteristic
            } else if (thisCharacteristic.UUID == SecurityStateCharacteristicUUID) {
                print(" ... found security state characteristic")
                self.securityStateCharacteristic = thisCharacteristic
                print(" ... subscribing to security state notifications")
                wearablePeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            }
        }
        doCharacteristicRead()
        characteristicTableView.reloadData();
    }
    
    func coerceUUIDStringNameToRealUUID(uuid : String) -> String {
        if (uuid == "Manufacturer Name String") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_MANUFACTURER_NAME_STRING.rawValue
        }
        if (uuid == "Model Number String") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_MODEL_NUMBER_STRING.rawValue
        }
        if (uuid == "Serial Number String") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_SERIAL_NUMBER_STRING.rawValue
        }
        if (uuid == "Firmware Revision String") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_FIRMWARE_REVISION_STRING.rawValue
        }
        if (uuid == "Hardware Revision String") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_HARDWARE_REVISION_STRING.rawValue
        }
        if (uuid == "Software Revision String") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_SOFTWARE_REVISION_STRING.rawValue
        }
        if (uuid == "System ID") {
            return FitpayDeviceInfoCharacteristicUUID.CHARACTERISTIC_SYSTEM_ID.rawValue
        }
        return uuid
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("didUpdateValueForCharacteristic: \(characteristic.UUID), error: \(error)")
        
        // update display
        updateViewForCharacteristicUpdate(characteristic)
        
        if characteristic.UUID == APDUResultCharacteristic {
            debugPrint("APDU Result characteristic update.   \(APDUResultCharacteristic)")
            let elapsedTime: Double = Double(NSDate.timeIntervalSinceReferenceDate() - startTime) * 1000
            let elapsedTimeStr: String = String(format: "%0.2f", elapsedTime)
            
            print("raw apdu result [\(hexString(characteristic.value))]")
            
            var val = characteristic.value
            if (val == nil || val?.length == 0) {
                val = NSData()
            }
            
            let apduResultMessage = ApduResultMessage(withMessage: val!)
            
            postResult(apduResultMessage, elapsedTimeStr: elapsedTimeStr)
            
        } else if characteristic.UUID == ContinuationControlCharacteristic {
            debugPrint("Continuation control characteristic update.   \(characteristic.UUID) with value: \(hexString(characteristic.value))")
            
            var val = characteristic.value
            if (val == nil || val?.length == 0) {
                val = NSData()
            }
            
            let continuationControlMessage = ContinuationControlMessage(msg: val!)
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
            var val = characteristic.value
            if (val == nil || val?.length == 0) {
                val = NSData()
            }
            let msg : ContinuationPacketMessage = ContinuationPacketMessage(msg: val!)
            debugPrint("continuation packet.  sortOrder: \(msg.sortOrder), data: \(hexString(msg.data))")
            let pos = Int(msg.sortOrder);
            continuation.data.insert(msg.data, atIndex: pos)
        } else if characteristic.UUID == NotificationCharacteristicUUID {
            debugPrint("Transaction notification characteristic update.   \(characteristic.UUID) with value: \(hexString(characteristic.value))")
            self.continuationLabel.stringValue = "Received transaction notification:  \(hexString(characteristic.value))"
            self.receivedNotificationData.stringValue = "\(hexString(characteristic.value))"
        } else if characteristic.UUID == SecurityStateCharacteristicUUID {
            debugPrint("Security state characteristic update.   \(characteristic.UUID) with value: \(hexString(characteristic.value))")
            self.continuationLabel.stringValue = "Received security state update:  \(hexString(characteristic.value))"
            self.securityState.stringValue = "\(hexString(characteristic.value))"
        }

    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("didUpdateNotificationStateForCharacteristic: \(characteristic.UUID), error: \(error)")
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
    
    func sendApduContinuation(dataToSend: NSData) {
        debugPrint("sendContinuation: \(dataToSend)")
        let CONTINUATION_MTU: Int = MTU - 2
        let startMsg = continutationControlMessage(APDUControlCharacteristic)
        debugPrint("writing continuation control start to charactacteristic: \(continuationCharacteristicControl.UUID), value: \(hexString(startMsg))")
        wearablePeripheral.writeValue(startMsg, forCharacteristic: continuationCharacteristicControl, type: CBCharacteristicWriteType.WithResponse)

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
    
    func continutationControlMessage(withUuid: CBUUID) -> NSData {
        let msg = NSMutableData()
        msg.appendData(START_CONTROL)
        // UUID is little endian
        msg.appendData(reverseData(withUuid.data))

        return msg
    }
    
    
    func disableUi() {
        self.testButton.enabled = false
        self.apduRequest.enabled = false
        self.apduButton.enabled = false
        self.sequenceIdTextField.enabled = false
        self.securityWriteButton.enabled = false
        self.sendNotification.enabled = false

    }
    
    func enableUi() {
        self.testButton.enabled = true
        self.apduRequest.enabled = true
        self.apduButton.enabled = true
        self.sequenceIdTextField.enabled = true
        self.securityWriteButton.enabled = true
        self.sendNotification.enabled = true
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
    
    func getPermissionsString(characteristic : CBCharacteristic) -> String {
        var value = ""
        let permissions : [CBCharacteristicProperties] = [
            CBCharacteristicProperties.Read,
            CBCharacteristicProperties.Write,
            CBCharacteristicProperties.WriteWithoutResponse,
            CBCharacteristicProperties.Indicate,
            CBCharacteristicProperties.IndicateEncryptionRequired,
            CBCharacteristicProperties.Notify,
            CBCharacteristicProperties.NotifyEncryptionRequired
        ]
        let values : [String] = ["R", "W", "WN", "I", "IE", "N", "NE"]
        var i = 0
        for permission in permissions {
            if ((characteristic.properties.rawValue & permission.rawValue) > 0) {
                if (value.characters.count > 0) {
                    value += "|"
                }
                value += values[i]
            }
            i++
        }
        return value
    }
    
    func getCharacteristicInfo(uuid: String) -> CharacteristicInfo? {
        for characteristicInfo in characteristicArray {
            if (characteristicInfo.uuid.lowercaseString == uuid.lowercaseString) {
                return characteristicInfo
            }
        }
        return nil
    }
    
    func doCharacteristicRead() {
        for characteristicInfo in characteristicArray {
            if (characteristicInfo.characteristic != nil) {
                if (isCharacteristicReadable(characteristicInfo.characteristic!)) {
                    debugPrint("Reading value for characteristic: \(characteristicInfo.characteristic!.UUID)")
                    wearablePeripheral.readValueForCharacteristic(characteristicInfo.characteristic!)
                }
            }
        }
    }
    
    func isCharacteristicReadable(characteristic: CBCharacteristic) -> Bool {
        if ((characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue) > 0) {
            return true
        }
        return false
    }
    
    func updateViewForCharacteristicUpdate(characteristic: CBCharacteristic) {
        let info = getCharacteristicInfo(characteristic.UUID.UUIDString)
        if (info != nil) {
            info!.characteristic = characteristic
        }
        characteristicTableView.reloadData();
    }

    
    // NSTableViewDataSource, NSTableViewDelegate Impl
    
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        debugPrint("numberOfRowsInTableView called for displayServiceUUID: \(displayServiceUUID)")
        var numberRows = 0
        if (displayServiceUUID.lowercaseString == FitpayServiceUUID.PaymentServiceUUID.rawValue.lowercaseString) {
            numberRows = paymentServiceCharacteristicArray.count
        } else if (displayServiceUUID.lowercaseString == FitpayServiceUUID.DeviceInfoServiceUUID.rawValue.lowercaseString) {
            numberRows = deviceInfoServiceCharacteristicArray.count
        }
        debugPrint("Number of rows in displayServiceUUID: \(numberRows)")
        return numberRows
    }
    
    func tableView(tableView: NSTableView,
        viewForTableColumn tableColumn: NSTableColumn?,
        row: Int) -> NSView? {
            var charArray = [CharacteristicInfo]()
            if (displayServiceUUID.lowercaseString == FitpayServiceUUID.PaymentServiceUUID.rawValue.lowercaseString) {
                charArray = paymentServiceCharacteristicArray
            } else if (displayServiceUUID.lowercaseString == FitpayServiceUUID.DeviceInfoServiceUUID.rawValue.lowercaseString) {
                charArray = deviceInfoServiceCharacteristicArray
            }

            //debugPrint("view for table column: \(tableColumn?.identifier), row: \(row)")
            
            var text:String = ""
            var cellIdentifier: String = ""
            
            if (row > (charArray.count - 1)) {
                debugPrint("index out of range for row \(row), displayServiceUUID: \(displayServiceUUID)")
                return nil
            }
            
            let item = charArray[row]
            
            if tableColumn == tableView.tableColumns[0] {
                text = item.name
                cellIdentifier = "characteristicNameID"
            } else if tableColumn == tableView.tableColumns[1] {
                text = item.uuid
                cellIdentifier = "uuidID"
            } else if tableColumn == tableView.tableColumns[2] {
                text = item.permissions
                cellIdentifier = "permissionsID"
            } else if tableColumn == tableView.tableColumns[3] {
                if (item.characteristic != nil) {
                    let bytes = item.characteristic!.value
                    text = hexString(bytes)
                } else {
                    text = "not available"
                }
                cellIdentifier = "valueID"
            }
            //debugPrint("populating value for row: \(row), text: \(text), cellIdentifier: \(cellIdentifier)")
            
            if let cell = tableView.makeViewWithIdentifier(cellIdentifier, owner: self) as! NSTableCellView? {
                cell.textField?.stringValue = text
                return cell
            }
            debugPrint("return nil (unexpected)")
            return nil
    }


}

