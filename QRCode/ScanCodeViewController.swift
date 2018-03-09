//
//  ScanCodeViewController.swift
//  PublicAssemblyDemo
//
//  Created by 张涛 on 2018/3/7.
//  Copyright © 2018年 张涛. All rights reserved.
//

import UIKit
import AVFoundation

let screenWidth = UIScreen.main.bounds.size.width
let screenHeight = UIScreen.main.bounds.size.height

private let scanAnimationDuration = 3.0 //扫描动画单次时长
private let scanPaneWidth: CGFloat = screenWidth * 0.7 //扫描框宽度

class ScanCodeViewController: UIViewController {
    
    var activityIndicatorView = UIActivityIndicatorView()
    
    lazy var scanPane : UIImageView = { ///扫描框
        let scanPane = UIImageView()
        scanPane.frame = CGRect(x: (screenWidth - scanPaneWidth)/2, y: (screenHeight - scanPaneWidth)/2, width: scanPaneWidth, height: scanPaneWidth)
        scanPane.image = UIImage(named: "QRCode_ScanBox")
        
        return scanPane
    }()
    
    lazy var scanLine : UIImageView = { ///扫描线
        let scanLine = UIImageView()
        scanLine.frame = CGRect(x: 0, y: 0, width: self.scanPane.bounds.width, height: 3)
        scanLine.image = UIImage(named: "QRCode_ScanLine")
        
        return scanLine
    }()
    
    var lightOn = false///开光灯
    var scanSession: AVCaptureSession?
    var session:AVCaptureSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSubviews()
        setupScanSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScan()
    }
    
    func setupSubviews() {
        view.addSubview(scanPane)
        scanPane.addSubview(scanLine)
        
        let viewTop = UIView()
        viewTop.backgroundColor = UIColor.init(white: 0, alpha: 0.4)
        viewTop.frame = CGRect(x: 0, y: 0, width: screenWidth, height: (screenHeight - scanPaneWidth)/2)
        view.addSubview(viewTop)
        
        let viewBottom = UIView()
        viewBottom.backgroundColor = UIColor.init(white: 0, alpha: 0.4)
        viewBottom.frame = CGRect(x: 0, y: scanPane.bounds.height + viewTop.bounds.height, width: screenWidth, height: (screenHeight - scanPaneWidth)/2)
        view.addSubview(viewBottom)
        
        let viewLeft = UIView()
        viewLeft.backgroundColor = UIColor.init(white: 0, alpha: 0.4)
        viewLeft.frame = CGRect(x: 0, y: viewTop.bounds.height, width: (screenWidth - scanPaneWidth)/2, height: scanPane.bounds.height)
        view.addSubview(viewLeft)
        
        let viewRight = UIView()
        viewRight.backgroundColor = UIColor.init(white: 0, alpha: 0.4)
        viewRight.frame = CGRect(x: (screenWidth - scanPaneWidth)/2 + scanPaneWidth, y: viewTop.bounds.height, width: (screenWidth - scanPaneWidth)/2, height: scanPane.bounds.height)
        view.addSubview(viewRight)
        
        let descLabel = UILabel()
        descLabel.frame = CGRect.init(x: 0, y: viewTop.bounds.size.height - 35, width: screenWidth, height: 20)
        descLabel.text = "将取景框对准二维/条形码，即可自动扫描"
        descLabel.font = UIFont.systemFont(ofSize: 12)
        descLabel.textColor = UIColor.white
        descLabel.textAlignment = .center
        viewTop.addSubview(descLabel)
        
        let lightBtn = UIButton()
        lightBtn.frame = CGRect.init(x: (screenWidth-40)/2, y: viewBottom.bounds.height - 100, width: 70, height: 70)
        lightBtn.setImage(UIImage.init(named: "qrcode_light_normal"), for: .normal)
        lightBtn.setImage(UIImage.init(named: "qrcode_light_pressed"), for: .selected)
        lightBtn.addTarget(self, action: #selector(self.light(_:)), for: .touchUpInside)
        viewBottom.addSubview(lightBtn)

    }
    
    func setupScanSession() {
        //设置捕捉设备
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }

        do {
            //设置设备输入输出
            let input = try AVCaptureDeviceInput(device: device)

            let output = AVCaptureMetadataOutput()

            //设置会话
            let  scanSession = AVCaptureSession()
            scanSession.canSetSessionPreset(.high)

            if scanSession.canAddInput(input) {
                scanSession.addInput(input)
            }

            if scanSession.canAddOutput(output) {
                scanSession.addOutput(output)
                //设置输出流代理，从接收端收到的所有元数据都会被传送到delegate方法，所有delegate方法均在queue中执行
                output.setMetadataObjectsDelegate(self, queue: .main)
                //设置扫描类型(二维码和条形码)
                output.metadataObjectTypes = [
                    AVMetadataObject.ObjectType.qr,
                    .code39,
                    .code128,
                    .code39Mod43,
                    .ean13,
                    .ean8,
                    .code93]
            }
            
            //预览图层
            let scanPreviewLayer = AVCaptureVideoPreviewLayer(session:scanSession)
            scanPreviewLayer.videoGravity = .resizeAspectFill
            scanPreviewLayer.frame = view.layer.bounds
            view.layer.insertSublayer(scanPreviewLayer, at: 0)

            //持续对焦
            if device.isFocusModeSupported(.continuousAutoFocus){
                try  input.device.lockForConfiguration()
                input.device.focusMode = .continuousAutoFocus
                input.device.unlockForConfiguration()
            }

            //设置扫描区域
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureInputPortFormatDescriptionDidChange, object: nil, queue: nil, using: { (noti) in
                output.rectOfInterest = scanPreviewLayer.metadataOutputRectConverted(fromLayerRect: self.scanPane.frame)
            })

            //保存会话
            self.scanSession = scanSession
        }catch {
            //摄像头不可用
            QRCodeManager.confirm(title: "温馨提示", message: "摄像头不可用", controller: self)
            return
        }
    }
    
    //MARK: -
    //MARK: Target Action
    
    //闪光灯
    @objc func light(_ sender: UIButton) {
        lightOn = !lightOn
        sender.isSelected = lightOn
        turnTorchOn()
    }
    
    //开始扫描
    fileprivate func startScan() {
        
        scanLine.layer.add(scanAnimation(), forKey: "scan")
    
        guard let scanSession = scanSession else { return }
        
        if !scanSession.isRunning
        {
            scanSession.startRunning()
        }
    }
    
    //扫描动画
    private func scanAnimation() -> CABasicAnimation {
        
        let startPoint = CGPoint(x: scanLine.center.x  , y: 1)
        let endPoint = CGPoint(x: scanLine.center.x, y: scanPane.bounds.size.height - 2)
        
        let translation = CABasicAnimation(keyPath: "position")
        translation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        translation.fromValue = NSValue(cgPoint: startPoint)
        translation.toValue = NSValue(cgPoint: endPoint)
        translation.duration = scanAnimationDuration
        translation.repeatCount = MAXFLOAT
        translation.autoreverses = true
        
        return translation
    }
    
    ///闪光灯
    private func turnTorchOn() {
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            if lightOn {
                QRCodeManager.confirm(title: "温馨提示", message: "闪光灯不可用", controller: self)
            }
            return
        }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if lightOn && device.torchMode == .off {
                    device.torchMode = .on
                }
                
                if !lightOn && device.torchMode == .on {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            }
            catch{ }
        }
    }
    
    deinit {
        ///移除通知
        NotificationCenter.default.removeObserver(self)
    }
    
    
}

//MARK: -
//MARK: AVCaptureMetadataOutputObjects Delegate
extension ScanCodeViewController : AVCaptureMetadataOutputObjectsDelegate {
    //扫描捕捉完成
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        //停止扫描
        self.scanLine.layer.removeAllAnimations()
        self.scanSession!.stopRunning()
        
        //播放声音
        QRCodeManager.playAlertSound(sound: "noticeMusic.caf")
        
        //扫完完成
        if metadataObjects.count > 0 {
            if let resultObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
                QRCodeManager.confirm(title: "扫描结果", message: resultObj.stringValue, controller: self,handler: { (_) in
                    //继续扫描
                    self.startScan()
                    
                })
            }
        }
    }
}

