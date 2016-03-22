//
//  CharacteristicInfo.swift
//  Wearable Test Harness
//
//  Created by Tim Shanahan on 3/16/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Foundation
import CoreBluetooth

class CharacteristicInfo {

    var serviceUUID: String
    var name : String
    var uuid : String
    var permissions : String
    var characteristic : CBCharacteristic?
    
    init(withServiceUUID: String, withName: String, withUUID: String, withPermissions: String, withCharacteristic: CBCharacteristic) {
        self.serviceUUID = withServiceUUID
        self.name = withName
        self.uuid = withUUID
        self.permissions = withPermissions
        self.characteristic = withCharacteristic
    }
    
    init(withServiceUUID: String, withName: String, withUUID: String) {
        self.serviceUUID = withServiceUUID
        self.name = withName
        self.uuid = withUUID
        self.permissions = "not avail"
    }
    
}
