//
//  QRCodeManager.swift
//  PublicAssemblyDemo
//
//  Created by 张涛 on 2018/3/7.
//  Copyright © 2018年 张涛. All rights reserved.
//

import UIKit
import CoreImage
import AudioToolbox

struct PhotoSource:OptionSet {
    let rawValue:Int
    
    static let camera = PhotoSource(rawValue: 1)
    static let photoLibrary = PhotoSource(rawValue: 1<<1)
    
}


func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs)
    {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs)
    {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

typealias finishedImage = (_ image:UIImage) -> ()

class QRCodeManager: NSObject {
    ///1.单例
    
    static let shareManager = QRCodeManager()
    private override init() {}
    
    var finishedImg : finishedImage?
    var isEditor = false
    
    
    
    ///2.选择图片
    
    func choosePicture(_ controller : UIViewController,  editor : Bool,options : PhotoSource = [.camera,.photoLibrary], finished : @escaping finishedImage) {
        
        finishedImg = finished
        isEditor = editor
        
        if options.contains(.camera) && options.contains(.photoLibrary) {
            let alertController = UIAlertController(title: "请选择图片", message: nil, preferredStyle: .actionSheet)
            
            let photographAction = UIAlertAction(title: "拍照", style: .default) { (_) in
                
                self.openCamera(controller: controller, editor: editor)
                
            }
            let photoAction = UIAlertAction(title: "从相册选取", style: .default) { (_) in
                
                self.openPhotoLibrary(controller: controller, editor: editor)
                
            }
            
            let cannelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            
            alertController.addAction(photographAction)
            alertController.addAction(photoAction)
            alertController.addAction(cannelAction)
            
            controller.present(alertController, animated: true, completion: nil)
            
            
        }else  if options.contains(.photoLibrary) {
            
            self.openPhotoLibrary(controller: controller, editor: editor)
            
        }else if options.contains(.camera) {
            
            self.openCamera(controller: controller, editor: editor)
            
        }
        
        
    }
    
    ///打开相册
    
    func openPhotoLibrary(controller : UIViewController,  editor : Bool) {
        
        let photo = UIImagePickerController()
        photo.delegate = self
        photo.sourceType = .photoLibrary
        photo.allowsEditing = editor
        controller.present(photo, animated: true, completion: nil)
        
    }
    
    ///打开相机
    
    func openCamera(controller : UIViewController,  editor : Bool) {
        
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        
        let photo = UIImagePickerController()
        photo.delegate = self
        photo.sourceType = .camera
        photo.allowsEditing = editor
        controller.present(photo, animated: true, completion: nil)
        
        
    }
    
    ///3.确认弹出框
    
    class func confirm(title:String?,message:String?,controller:UIViewController,handler: ( (UIAlertAction) -> Swift.Void)? = nil) {
        
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let entureAction = UIAlertAction(title: "确定", style: .destructive, handler: handler)
        alertVC.addAction(entureAction)
        controller.present(alertVC, animated: true, completion: nil)
        
    }
    
    
    ///4.播放声音
    class func playAlertSound(sound:String) {
        
        guard let soundPath = Bundle.main.path(forResource: sound, ofType: nil)  else { return }
        guard let soundUrl = NSURL(string: soundPath) else { return }
        
        var soundID:SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundUrl, &soundID)
        AudioServicesPlaySystemSound(soundID)
        
    }
    
    /**
     识别图片二维码
     
     - returns: 二维码内容
     */
    class func recognizeQRCode(sourceImage: UIImage) -> String? {
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
        var ciImage = sourceImage.ciImage
        if ciImage == nil {
            let cgImage = sourceImage.cgImage
            if cgImage == nil { return nil }
            ciImage = CIImage(cgImage: cgImage!)
        }
        if ciImage == nil { return nil }
        let features = detector?.features(in: ciImage!)
        guard (features?.count)! > 0 else { return nil }
        let feature = features?.first as? CIQRCodeFeature
        return feature?.messageString
    }
    
    //2.获取圆角图片
    func getRoundRectImage(sourceImage: UIImage,size:CGFloat,radius:CGFloat) -> UIImage {
        
        return getRoundRectImage(sourceImage: sourceImage,size: size, radius: radius, borderWidth: nil, borderColor: nil)
        
    }
    
    
    //3.获取圆角图片(带边框)
    func getRoundRectImage(sourceImage: UIImage,size:CGFloat,radius:CGFloat,borderWidth:CGFloat?,borderColor:UIColor?) -> UIImage {
        let scale = sourceImage.size.width / size ;
        
        //初始值
        var defaultBorderWidth : CGFloat = 0
        var defaultBorderColor = UIColor.clear
        
        if let borderWidth = borderWidth { defaultBorderWidth = borderWidth * scale }
        if let borderColor = borderColor { defaultBorderColor = borderColor }
        
        let radius = radius * scale
        let react = CGRect(x: defaultBorderWidth, y: defaultBorderWidth, width: sourceImage.size.width - 2 * defaultBorderWidth, height: sourceImage.size.height - 2 * defaultBorderWidth)
        
        //绘制图片设置
        UIGraphicsBeginImageContextWithOptions(sourceImage.size, false, UIScreen.main.scale)
        
        let path = UIBezierPath(roundedRect:react , cornerRadius: radius)
        
        //绘制边框
        path.lineWidth = defaultBorderWidth
        defaultBorderColor.setStroke()
        path.stroke()
        
        path.addClip()
        
        //画图片
        sourceImage.draw(in: react)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!;
        
    }
   

}
/// Delegate
extension QRCodeManager: UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        guard let image = info[isEditor ? UIImagePickerControllerEditedImage : UIImagePickerControllerOriginalImage] as? UIImage else { return }
        picker.dismiss(animated: true) { [weak self] in
            guard let tmpFinishedImg = self?.finishedImg else { return }
            tmpFinishedImg(image)
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
}

/*
 CIImage
 带便图像的对象
 CIFilter
 表示滤镜，使用key-value coding设置输入值，滤镜强度和输入的CIImage 包含了一个对输入图像的引用以及需要应用于数据的滤镜
 CIContext
 用于渲染CIImage，当一个图片被渲染，作用于图片的滤镜链会被应用到原始的图像数据上。 CIContext可以是基于CPU的，输出为CGImageRef，也可以是基与GPU的，开发者可通过Open ES 2.0 画出来
 CIDetector
 CIDetector用于分析CIImage，以得到CIFeature，每个CIDetector都要用一个探测器类型（NSString）来初始化。这个类型用于告诉探测器要找什么特征
 CIFeatureCIFaceFeature
 当一个CIDetector 分析一个图像，返回值是一个根据探测器类型探测到的CIFeature数组。每一个CIFaceFeature都包含了一个面部的CGRect引用，以及检测到的面孔的左眼、右眼、嘴部对应的CGpoint
 */

/// GenerateQRCode
extension QRCodeManager {
   
    /**
     1.生成二维码
     
     - returns: 黑白普通二维码(大小为300)
     */
    
    func generateQRCode(sourceString: String!) -> UIImage {
        
        return generateQRCodeWithSize(sourceString: sourceString,size: nil)
        
    }
    
    
    /**
     2.生成二维码
     
     - parameter size: 大小
     
     - returns: 生成带大小参数的黑白普通二维码
     */
    func generateQRCodeWithSize(sourceString: String!,size:CGFloat?) -> UIImage {
        
        return generateQRCode(sourceString: sourceString,size: size, logo: nil)
        
    }
    
    
    /**
     3.生成二维码
     
     - parameter logo: 图标
     
     - returns: 生成带Logo二维码(大小:300)
     */
    func generateQRCodeWithLogo(sourceString: String!,logo:UIImage?) -> UIImage {
        
        return generateQRCode(sourceString: sourceString,size: nil, logo: logo)
        
    }
    
    
    /**
     4.生成二维码
     
     - parameter size: 大小
     - parameter logo: 图标
     
     - returns: 生成大小和Logo的二维码
     */
    func generateQRCode(sourceString: String!,size:CGFloat?,logo:UIImage?) -> UIImage {
        
        let color = UIColor.black//二维码颜色
        let bgColor = UIColor.white//二维码背景颜色
        
        return generateQRCode(sourceString: sourceString, size: size, color: color, bgColor: bgColor, logo: logo)
        
    }
    
    
    /**
     5.生成二维码
     
     - parameter size:    大小
     - parameter color:   颜色
     - parameter bgColor: 背景颜色
     - parameter logo:    图标
     
     - returns: 带Logo、颜色二维码
     */
    func generateQRCode(sourceString: String!,size:CGFloat?,color:UIColor?,bgColor:UIColor?,logo:UIImage?) -> UIImage {
        
        let radius : CGFloat = 5//圆角
        let borderLineWidth : CGFloat = 1.5//线宽
        let borderLineColor = UIColor.gray//线颜色
        let boderWidth : CGFloat = 8//白带宽度
        let borderColor = UIColor.white//白带颜色
        
        return generateQRCode(sourceString: sourceString, size: size, color: color, bgColor: bgColor, logo: logo,radius:radius,borderLineWidth: borderLineWidth,borderLineColor: borderLineColor,boderWidth: boderWidth,borderColor: borderColor)
        
    }
    
    
    /**
     6.生成二维码
     
     - parameter size:            大小
     - parameter color:           颜色
     - parameter bgColor:         背景颜色
     - parameter logo:            图标
     - parameter radius:          圆角
     - parameter borderLineWidth: 线宽
     - parameter borderLineColor: 线颜色
     - parameter boderWidth:      带宽
     - parameter borderColor:     带颜色
     
     - returns: 自定义二维码
     */
    func generateQRCode(sourceString: String!, size:CGFloat?,color:UIColor?,bgColor:UIColor?,logo:UIImage?,radius:CGFloat,borderLineWidth:CGFloat?,borderLineColor:UIColor?,boderWidth:CGFloat?,borderColor:UIColor?) -> UIImage {
        
        let ciImage = generateCIImage(sourceString: sourceString, size: size, color: color, bgColor: bgColor)
        let image = UIImage(ciImage: ciImage)
        
        guard let QRCodeLogo = logo else { return image }
        
        
        let logoWidth = image.size.width/4
        let logoFrame = CGRect(x: (image.size.width - logoWidth) /  2, y: (image.size.width - logoWidth) / 2, width: logoWidth, height: logoWidth)
        
        
        // 绘制logo
        UIGraphicsBeginImageContextWithOptions(image.size, false, UIScreen.main.scale)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        //线框
        let logoBorderLineImagae = getRoundRectImage(sourceImage: QRCodeLogo,size: logoWidth, radius: radius, borderWidth: borderLineWidth, borderColor: borderLineColor)
        //边框
        let logoBorderImagae = getRoundRectImage(sourceImage: logoBorderLineImagae,size: logoWidth, radius: radius, borderWidth: boderWidth, borderColor: borderColor)
        
        logoBorderImagae.draw(in: logoFrame)
        
        let QRCodeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        
        
        return QRCodeImage!
        
    }
    
    
    /**
     7.生成CIImage
     
     - parameter size:    大小
     - parameter color:   颜色
     - parameter bgColor: 背景颜色
     
     - returns: CIImage
     */
    func generateCIImage(sourceString: String!,size:CGFloat?,color:UIColor?,bgColor:UIColor?) -> CIImage {
        
        //1.缺省值
        var QRCodeSize : CGFloat = 300//默认300
        var QRCodeColor = UIColor.black//默认黑色二维码
        var QRCodeBgColor = UIColor.white//默认白色背景
        
        if let size = size { QRCodeSize = size }
        if let color = color { QRCodeColor = color }
        if let bgColor = bgColor { QRCodeBgColor = bgColor }
        
        
        //2.二维码滤镜
        let contentData = sourceString.data(using: String.Encoding.utf8)
        let fileter = CIFilter(name: "CIQRCodeGenerator")
        
        fileter?.setValue(contentData, forKey: "inputMessage")
        fileter?.setValue("H", forKey: "inputCorrectionLevel")
        
        let ciImage = fileter?.outputImage
        
        
        //3.颜色滤镜
        let colorFilter = CIFilter(name: "CIFalseColor")
        
        colorFilter?.setValue(ciImage, forKey: "inputImage")
        colorFilter?.setValue(CIColor(cgColor: QRCodeColor.cgColor), forKey: "inputColor0")// 二维码颜色
        colorFilter?.setValue(CIColor(cgColor: QRCodeBgColor.cgColor), forKey: "inputColor1")// 背景色
        
        
        //4.生成处理
        
        let outImage = colorFilter!.outputImage
        let scale = QRCodeSize / outImage!.extent.size.width;
        
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        
        let transformImage = colorFilter!.outputImage!.transformed(by: transform)
        
        return transformImage
        
    }
    
}


