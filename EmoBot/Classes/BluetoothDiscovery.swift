//
//  BluetoothService.swift
//  EmoBot
//
//  Created by Lea Marolt on 6/17/17.
//  Copyright © 2017 elemes. All rights reserved.
//

import Foundation
import CoreBluetooth

final class BluetoothDiscovery: NSObject, CBCentralManagerDelegate {
    
    static var shared: BluetoothDiscovery = BluetoothDiscovery()
    var bluetoothService: BluetoothService? {
        didSet {
            bluetoothService?.startDiscoveringServices()
            BluetoothDiscovery.shared.bluetoothService = bluetoothService
        }
    }
    
    var centralManager: CBCentralManager? {
        didSet {
            BluetoothDiscovery.shared.centralManager = centralManager
        }
    }
    var peripheralBLE: CBPeripheral? {
        didSet {
            BluetoothDiscovery.shared.peripheralBLE = peripheralBLE
        }
    }
    
    override init() {
        let serialQueue = DispatchQueue(label: "com.elemes")
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: serialQueue)
    }
    
    func startScanning() {
        guard let _centralManager = centralManager else { return }
        _centralManager.scanForPeripherals(withServices: nil, options: [:])
    }
    
    //MARK: CBCentralManagerDelegate
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Be sure to retain the peripheral or it will fail during connection.
        
        // Validate peripheral information
        // print(peripheral.name)
        
        guard let name = peripheral.name, name == "EmoBot-Local" || name == "EmoBot" else { return }
        
        if let _peripheralBLE = peripheralBLE, _peripheralBLE.state != CBPeripheralState.disconnected {
            return
        }
        
        peripheralBLE = peripheral // Retain the peripheral before trying to connect
        bluetoothService = nil // Reset service
        guard let _centralManager = centralManager else { return }
        _centralManager.connect(peripheralBLE!, options: nil) // Connect to peripheral
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        guard let _peripheralBLE = peripheralBLE, peripheral == _peripheralBLE else {
            return
        }
        
        bluetoothService = BluetoothService.init(with: peripheral)
        guard let _centralManager = centralManager else { return }
        _centralManager.stopScan() // stop scanning for new devices
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        guard let _peripheralBLE = peripheralBLE else {
            return
        }
        
        // See if it was our peripheral that disconnected
        if peripheral == _peripheralBLE {
            bluetoothService = nil
            peripheralBLE = nil
        }
        
        // Start scanning for new devices
        startScanning()
    }
    
    @available(iOS 5.0, *)
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let _centralManager = centralManager else { return }
        
        switch _centralManager.state {
        case .poweredOff:
            clearDevices()
        case .poweredOn:
            startScanning()
        case .resetting:
            clearDevices()
        default:
            break
        }
    }
    
    //MARK: Private
    func clearDevices() {
        bluetoothService = nil
        peripheralBLE = nil
    }
}
