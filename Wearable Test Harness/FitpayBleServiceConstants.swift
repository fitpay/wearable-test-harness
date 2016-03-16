//
//  FitpayBleServiceConstants.swift
//  Wearable Test Harness
//
//  Created by Tim Shanahan on 3/16/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Foundation
import CoreBluetooth


enum FitpayCharacteristicUUID: String {
    
    case ContinuationControlCharacteristic = "cacc2825-0a2b-4cf2-a1a4-b9db27691382"
    case ContinuationPacketCharacteristic = "52d26993-6d10-4080-8166-35d11cf23c8c"
    case APDUControlCharacteristic = "0761f49b-5f56-4008-b203-fd2406db8c20"
    case APDUResultCharacteristic = "840f2622-ff4a-4a56-91ab-b1e6dd977db4"
    case NotificationCharacteristic = "37051cf0-d70e-4b3c-9e90-0f8e9278b4d3"
    case SecurityWriteCharacteristic = "e4bbb38f-5aaa-4056-8cf0-57461082d598"
    case SecurityStateCharacteristic = "ab1fe5e7-4e9d-4b8c-963f-5265dc7de466"

}

enum FitpayServiceUUID: String {
    
    case PaymentServiceUUID = "d7cc1dc2-3603-4e71-bce6-e3b1551633e0"
    case DeviceInfoServiceUUID = "0000180a-0000-1000-8000-00805f9b34fb"
    
}
