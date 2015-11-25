//
//  ViewController.swift
//  BluetoothBarcodeScanning
//
//  Created by Developer on 24/11/2015.
//  Copyright © 2015 Plumhead Software. All rights reserved.
//

import UIKit
import AVFoundation
import CoreBluetooth
import QuartzCore

@objc class BTPeripheralController : UIViewController {
    // Barcode scanning stuff
    @IBOutlet weak var scanLabel: UIView!
    @IBOutlet weak var scanStopStart: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var publishButton: UIButton!
    @IBOutlet weak var barcodeLabel: UILabel!

    var avSession : AVCaptureSession?
    var avPreview : AVCaptureVideoPreviewLayer?
    var scanning = false
    var latestBarcode : String?
    
    // Bluetooth related stuff
    let TransferServiceUUID = "E20A39F4-73F5-4BC4-A12F-17D1AD666661"
    let TransferCharacteristicUUID = "08590F7E-DB05-467E-8757-72F6F66666D4"
    var peripheralManager : CBPeripheralManager!
    var btCharacteristic : CBMutableCharacteristic!
    var btData : NSMutableData?

    override func viewDidLoad() {
        super.viewDidLoad()

        btData = NSMutableData()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        print("View Disappearing")
        peripheralManager.stopAdvertising()
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func sendBarcode() {
        guard let bc = self.latestBarcode else {return}
        
        let msg = NSString(string: "\(bc)").dataUsingEncoding(NSUTF8StringEncoding)
        _ = peripheralManager.updateValue(msg!, forCharacteristic: self.btCharacteristic, onSubscribedCentrals: nil)
        self.latestBarcode = nil
        
        peripheralManager.stopAdvertising()
    }
    
    @IBAction func publishBarcode(sender: AnyObject) {
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[CBUUID(string: TransferServiceUUID)]])
        publishButton.enabled = false
    }
}


//MARK: CBPeripheralManagerDelegate
extension BTPeripheralController : CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        print("Peripheral Manager: update state : \(peripheral.state.rawValue)")
        guard peripheral.state == .PoweredOn else {return}
        print("Peripheral powered on")
        
        btCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TransferCharacteristicUUID), properties: CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Readable)
        
        let svc = CBMutableService(type: CBUUID(string: TransferServiceUUID), primary: true)
        svc.characteristics = [btCharacteristic]
        
        print("Starting peripheral service")
        peripheralManager.addService(svc)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        print("Peripheral: subscribed")
        sendBarcode()
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        print("Peripheral: unsubscribed")
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        print("Ready To Update Subscribers")
        sendBarcode()
    }
}



//MARK: Barcode Scanning Stuff
extension BTPeripheralController {
    
    @IBAction func toggleStopStartScan(sender: UIButton) {
        if scanning {
            stopScanning()
        }
        else {
            startScanning()
        }
    }
    
    
    func startScanning() {
        defer {
            publishButton.enabled = false
            peripheralManager.stopAdvertising()
        }
        
        do {
            let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
            let input = try AVCaptureDeviceInput(device: device)
            
            avSession = AVCaptureSession()
            avSession!.addInput(input)
            
            let mOutput = AVCaptureMetadataOutput()
            avSession!.addOutput(mOutput)
            
            let batchQueue = dispatch_queue_create("com.barcode-scanning", nil)
            mOutput.setMetadataObjectsDelegate(self, queue: batchQueue)
            
            // configure metadata types we want to recognise
            mOutput.metadataObjectTypes = [AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeEAN8Code]
            
            avPreview = AVCaptureVideoPreviewLayer(session: avSession!)
            avPreview!.videoGravity = AVLayerVideoGravityResizeAspectFill
            avPreview!.frame = scanLabel.layer.bounds
            
            scanLabel.layer.addSublayer(avPreview!)
            
            avSession!.startRunning()
            statusLabel.text = "Scanning"
            barcodeLabel.text = ""
            scanning = true
            scanStopStart.titleLabel?.text = "Stop"
            
        }
        catch let e {
            statusLabel.text = "ERROR: \(e)"
            stopScanning()
        }
    }
    
    func stopScanning() {
        
        avSession?.stopRunning()
        avSession = nil
        avPreview?.removeFromSuperlayer()
        avPreview = nil
        
        statusLabel.text = "not scanning"
        scanning = false
        
        scanStopStart.titleLabel?.text = "Start"
        publishButton.enabled = self.latestBarcode != nil
    }
    
}






//MARK: AVCaptureMetadataOutputObjectsDelegate
extension BTPeripheralController : AVCaptureMetadataOutputObjectsDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        guard metadataObjects.count > 0,
            let meta = metadataObjects[0] as? AVMetadataMachineReadableCodeObject else {return}
        
        // Do some action depending on what metadata type returned.
        dispatch_async(dispatch_get_main_queue()) {
            switch meta.type {
            case AVMetadataObjectTypeCode128Code:
                self.statusLabel.text = "Type 128 (\(meta.stringValue))"
                self.latestBarcode = meta.stringValue
                self.barcodeLabel.text = meta.stringValue
                
            case AVMetadataObjectTypeCode39Code:
                self.statusLabel.text = "Type 39 (\(meta.stringValue)"
                self.latestBarcode = meta.stringValue
                self.barcodeLabel.text = meta.stringValue

            case AVMetadataObjectTypeCode93Code:
                self.statusLabel.text = "Type 93 (\(meta.stringValue)"
                self.latestBarcode = meta.stringValue
                self.barcodeLabel.text = meta.stringValue

            case AVMetadataObjectTypeEAN13Code:
                self.statusLabel.text = "EAN 13 (\(meta.stringValue)"
                self.latestBarcode = meta.stringValue
                self.barcodeLabel.text = meta.stringValue
                
            case AVMetadataObjectTypeEAN8Code:
                self.statusLabel.text = "EAN 8 (\(meta.stringValue)"
                self.latestBarcode = meta.stringValue
                self.barcodeLabel.text = meta.stringValue
                
            case _ :
                self.statusLabel.text = "Other type"
                self.latestBarcode = nil
                self.barcodeLabel.text = "Not Known"

            }
            
            self.stopScanning()
        }
        
    }
    
    
}
















