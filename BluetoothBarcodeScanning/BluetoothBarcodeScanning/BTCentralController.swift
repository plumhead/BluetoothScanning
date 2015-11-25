//
//  BarcodeListController.swift
//  BluetoothBarcodeScanning
//
//  Created by Developer on 24/11/2015.
//  Copyright © 2015 Plumhead Software. All rights reserved.
//

import UIKit
import CoreBluetooth

@objc class BTCentralController : UITableViewController {

    var model : [String] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    var statusLabel : String = ""
    
    // Bluetooth related stuff
    let TransferServiceUUID = "E20A39F4-73F5-4BC4-A12F-17D1AD666661"
    let TransferCharacteristicUUID = "08590F7E-DB05-467E-8757-72F6F66666D4"
    var centralManager : CBCentralManager!
    var btPeripheral : CBPeripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureBluetooth()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        cleanup()
        centralManager.stopScan()
    }
    
    // MARK: - Table view data source
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("barcodeCell", forIndexPath: indexPath)
        cell.textLabel?.text = model[indexPath.row]
        return cell
    }
}


//MARK: Bluetooth Stuff
extension BTCentralController {
    
    func configureBluetooth() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func bluetoothScan() {
//        print( "Scanning" )
        
        centralManager.scanForPeripheralsWithServices([CBUUID(string: TransferServiceUUID)], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])

//        print("Scanning Started")
    }
    
    func cleanup() {
        guard let dp = btPeripheral where dp.state == .Connected else {return}
        
        let _ =
            (dp.services ?? [])
            .flatMap {$0.characteristics}
            .flatMap {$0}
            .filter {$0.isNotifying && $0.UUID == CBUUID(string: TransferCharacteristicUUID)}
            .map {dp.setNotifyValue(false, forCharacteristic: $0)}  // don't need result of map
        
    }
    
}

//MARK: CBCentralManagerDelegate
extension BTCentralController : CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
//        print("Central Manager: did update state \(central.state)")
        guard central.state == .PoweredOn else {
//            print("[BT-STATE] \(central.state)")
            return
        }
        
        bluetoothScan()
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if RSSI.integerValue > -15 || RSSI.integerValue < -35 {
            // signal strength too low or above reasonable range
            return
        }
        
        guard btPeripheral == nil else {return}

        print("BT: Name(\(peripheral.name)) strength(\(RSSI.integerValue))")
        
        btPeripheral = peripheral
        centralManager.connectPeripheral(peripheral, options: nil)
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Failed to connect \(error)")
        cleanup()
    }
    
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Peripheral Connected")
        centralManager.stopScan()
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: TransferServiceUUID)])
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Peripheral Disconnected")
        bluetoothScan()
    }
}

//MARK: CBPeripheralDelegate
extension BTCentralController : CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("Peripheral: did discover services")
        guard error == nil else {
            print("Error: Peripheral discover services: \(error!.localizedDescription)")
            cleanup()
            return
        }
        
        guard let svcs = peripheral.services else {
            print("Info: Peripheral has no services")
            return
        }
        
        for svc in svcs {
            peripheral.discoverCharacteristics([CBUUID(string: TransferCharacteristicUUID)], forService: svc)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        print("Peripheral: did discover characteristics for service")
        guard error == nil else {
            print("Error: Peripheral discovering characteristics: \(error!.localizedDescription)")
            cleanup()
            return
        }
        
        guard let ch = service.characteristics else {
            print("Info: service has no characteristics")
            return
        }
        
        let _ = ch.filter {$0.UUID == CBUUID(string: TransferCharacteristicUUID)}.map {peripheral.setNotifyValue(true, forCharacteristic: $0)}
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard error == nil else {
            print("Error: Peripheral updating value: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {return}
        
        if let sd = NSString(data: data, encoding: NSUTF8StringEncoding) {
            peripheral.setNotifyValue(false, forCharacteristic: characteristic)
            centralManager.cancelPeripheralConnection(peripheral)
            
            model.append(sd as String)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("Peripheral: did update notification state")
        guard error == nil else {
            print("Error: changing notification state: \(error!.localizedDescription)")
            return
        }
        
        guard characteristic.UUID == CBUUID(string: TransferCharacteristicUUID) else {return}
        
        if characteristic.isNotifying {
            print("Notifying")
        }
        else {
            print("Notifying stopped")
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
    
}
