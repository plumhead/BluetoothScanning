//
//  ViewController.swift
//  BluetoothBarcodeScanning
//
//  Created by Developer on 24/11/2015.
//  Copyright © 2015 Plumhead Software. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController {
    @IBOutlet weak var scanLabel: UIView!
    @IBOutlet weak var scanStopStart: UIButton!
    @IBOutlet weak var statusLabel: UILabel!

    
    var avSession : AVCaptureSession?
    var avPreview : AVCaptureVideoPreviewLayer?
    var scanning = false

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }


}



//MARK: Barcode Scanning Stuff
extension ViewController {
    
    @IBAction func toggleStopStartScan(sender: UIButton) {
        if scanning {
            stopScanning()
        }
        else {
            startScanning()
        }
    }
    
    
    func startScanning() {
        
        do {
            let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
            let input = try AVCaptureDeviceInput(device: device)
            
            avSession = AVCaptureSession()
            avSession!.addInput(input)
            
            let mOutput = AVCaptureMetadataOutput()
            avSession!.addOutput(mOutput)
            
            let batchQueue = dispatch_queue_create("com.barcode-scanning", nil)
            mOutput.setMetadataObjectsDelegate(self, queue: batchQueue)
            mOutput.metadataObjectTypes = [AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeEAN8Code]
            
            avPreview = AVCaptureVideoPreviewLayer(session: avSession!)
            avPreview!.videoGravity = AVLayerVideoGravityResizeAspectFill
            avPreview!.frame = scanLabel.layer.bounds
            
            scanLabel.layer.addSublayer(avPreview!)
            
            avSession!.startRunning()
            statusLabel.text = "Scanning"
            scanning = true
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
    }
    
}



//MARK: Bluetooth Stuff
extension ViewController {
    
    
    
}


//MARK: AVCaptureMetadataOutputObjectsDelegate
extension ViewController : AVCaptureMetadataOutputObjectsDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        guard metadataObjects.count > 0,
            let meta = metadataObjects[0] as? AVMetadataMachineReadableCodeObject else {return}
        
        dispatch_async(dispatch_get_main_queue()) {[unowned self] in
            switch meta.type {
            case AVMetadataObjectTypeCode128Code: self.statusLabel.text = "Type 128 (\(meta.stringValue))"
            case AVMetadataObjectTypeCode39Code: self.statusLabel.text = "Type 39 (\(meta.stringValue)"
            case AVMetadataObjectTypeCode93Code: self.statusLabel.text = "Type 93 (\(meta.stringValue)"
            case AVMetadataObjectTypeEAN13Code: self.statusLabel.text = "EAN 13 (\(meta.stringValue)"
            case AVMetadataObjectTypeEAN8Code: self.statusLabel.text = "EAN 8 (\(meta.stringValue)"
            case _ : self.statusLabel.text = "Other type"
            }
        }
        
    }
    
    
}