//
//  BluetoothDiscovery.swift
//  EmoBot
//
//  Created by Lea Marolt on 6/17/17.
//  Copyright © 2017 elemes. All rights reserved.
//

import Foundation
import CoreBluetooth

let Elemes_BLE_Service_UUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
let Elemes_Face_Char_UUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
let Elemes_Sound_Char_UUID = CBUUID(string: "52f2baf1-2eda-4e08-a075-6bb05a4e90dc")
let Elemes_BLE_Service_Changed_Notification = "elemesBleServiceChangedNotification"

class BluetoothService: NSObject, CBPeripheralDelegate {
    
    var peripheral: CBPeripheral?
    var faceCharacteristic: CBCharacteristic?
    var soundCharacteristic: CBCharacteristic?
    var emoFace: botFace?
    
    init(with peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral!.delegate = self
    }
    
    func reset() {
        peripheral = nil
        sendBluetoothServiceNotification(for: false)
    }
    
    func startDiscoveringServices() {
        guard let _peripheral = peripheral else { return }
        _peripheral.discoverServices([Elemes_BLE_Service_UUID])
    }
    
    //MARK: CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        var services: [CBService]? = nil
        let uuidsForBTService: [CBUUID] = [Elemes_Face_Char_UUID]
        
        if (peripheral != self.peripheral || error != nil)  {
            return
        }
        
        services = peripheral.services
        
        if let _services = services {
            for service in _services {
                if service.uuid == Elemes_BLE_Service_UUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        } else {
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if (peripheral != self.peripheral || error != nil)  {
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == Elemes_Face_Char_UUID {
                faceCharacteristic = characteristic
                sendBluetoothServiceNotification(for: true)
            }
            if characteristic.uuid == Elemes_Sound_Char_UUID {
                soundCharacteristic = characteristic
                sendBluetoothServiceNotification(for: true)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        //print("Update value for: \(descriptor.value ?? "nothing")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("Update value for: \(characteristic)")
        
        guard let data = characteristic.value else { return }
        if characteristic.uuid == Elemes_Face_Char_UUID {
            let face = botFace(rawValue: Int(UInt32(data:data)))
            emoFace = face
        } else {
            //print("MY DAtA ISSSSS: \(UInt32(data:data))")
        }
        
        print("MY DATA IS: \(UInt32(data:data))")
    }
    
    //MARK: Services
    
    func sendBluetoothServiceNotification(for bluetoothConnected: Bool) {
        let connectionDetails = ["isConnected" : bluetoothConnected.description]
        
        NotificationCenter.default.post(name: Notification.Name.init(Elemes_BLE_Service_Changed_Notification), object: self, userInfo: connectionDetails)
    }
    
    func write(position: UInt32) {
        var _position = position
        guard faceCharacteristic != nil else { return }
        
        let data: Data = Data(bytes: &_position, count: MemoryLayout<UInt32>.size)
        guard let _peripheral = peripheral,
        let _faceCharacteristic = faceCharacteristic else { return }
        _peripheral.writeValue(data, for: _faceCharacteristic, type: .withResponse)
    }
}

// https://stackoverflow.com/questions/32894363/reading-a-ble-peripheral-characteristic-and-checking-its-value
// Data Extensions:
protocol DataConvertible {
    init(data:Data)
    var data:Data { get }
}

extension DataConvertible {
    init(data:Data) {
        guard data.count == MemoryLayout<Self>.size else {
            fatalError("data size (\(data.count)) != type size (\(MemoryLayout<Self>.size))")
        }
        self = data.withUnsafeBytes { $0.pointee }
    }
    
    var data:Data {
        var value = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}

extension UInt8:DataConvertible {}
extension UInt16:DataConvertible {}
extension UInt32:DataConvertible {}
extension Int32:DataConvertible {}
extension Int64:DataConvertible {}
extension Double:DataConvertible {}
extension Float:DataConvertible {}
