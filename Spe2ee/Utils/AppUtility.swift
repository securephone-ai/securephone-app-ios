import Foundation
import AVFoundation
import UIKit
import CryptoKit
import BlackboxCore

final class AppUtility {
    
    static let isArabic = NSLocale.preferredLanguages[0].range(of:"ar") != nil
    
    static func isAppInForeground(completion block: @escaping((Bool) -> Void)) {
        DispatchQueue.main.async {
            //      if UIApplication.shared.applicationState == .active {
            if UIApplication.shared.applicationState != .background {
                block(true)
            } else {
                block(false)
            }
        }
    }
    
    static func isAppInForeground() -> Bool {
        if UIApplication.shared.applicationState == .active {
            return true
        } else {
            return false
        }
    }
    
    static func generateVideoThumbnail(fileName: String, filekey: String, at time: Int64 = 0) -> UIImage? {
        do {
            let path = URL(fileURLWithPath: fileName, isDirectory: false, relativeTo: nil )
            let newUrl = path.appendingPathExtension("MOV")
            
            if !filekey.isEmpty,
               let data = AppUtility.decryptFile(fileName, key: filekey.base64Decoded ?? "") {
                try data.write(to: newUrl)
            } else {
                try FileManager.default.copyItem(at: path, to: newUrl)
            }
            
            let asset = AVURLAsset(url: newUrl, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: time, timescale: 1), actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            try FileManager.default.removeItem(at: newUrl)
            return thumbnail.scaled(toHeight: 360)
        } catch let error {
            loge("*** Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func decryptFile(_ filepath: String, key: String) -> Data? {
        var url = URL(fileURLWithPath: filepath)
        
        if url.pathExtension.isEmpty {
            url.appendPathExtension(".enc")
        }
        
        let path = url.path.replacingOccurrences(of: "\0enc", with: ".enc") 
        return BlackboxCore.decryptFile(path, key: key)
    }
    
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        var path = paths[0].appendingPathComponent("test/")
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try path.setResourceValues(resourceValues)
            
        } catch {
            print("failed to set resource value")
        }
        
        return path
    }
    
    static func getTemporaryDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    
    static func getFileSize(_ path: String) -> UInt64 {
        guard FileManager.default.fileExists(atPath: path) else { return .zero }
        
        var fileSize: UInt64 = .zero
        do {
            //return [FileAttributeKey : Any]
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            fileSize = attr[FileAttributeKey.size] as! UInt64
            
            //if you convert to NSDictionary, you can get file size old way as well.
            let dict = attr as NSDictionary
            fileSize = dict.fileSize()
        } catch {
            loge(error)
        }
        return fileSize
    }
    
    static func copyFile(_ path: String, fileName: String) -> String? {
        do {
            let originPath = URL(fileURLWithPath: path)
            var destinationPath = getDocumentsDirectory().appendingPathComponent(fileName)
            let pathExtension = destinationPath.pathExtension
            destinationPath.deleteLastPathComponent()
            destinationPath = destinationPath.appendingPathComponent(UUID().uuidString)
            destinationPath.appendPathExtension(pathExtension)
            try FileManager.default.copyItem(at: originPath, to: destinationPath)
            return destinationPath.path
        } catch {
            loge(error)
        }
        return nil
    }
    
    static func moveFile(_ path: String, fileName: String) -> String? {
        do {
            let originPath = URL(fileURLWithPath: path)
            let destinationPath = getDocumentsDirectory().appendingPathComponent(fileName)
            try FileManager.default.moveItem(at: originPath, to: destinationPath)
            return destinationPath.path
        } catch {
            loge(error)
        }
        return nil
    }
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }
    
    /// OPTIONAL Added method to adjust lock and rotate to the desired orientation
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
        
        self.lockOrientation(orientation)
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    
    static func camDenied(viewController: UIViewController) {
        DispatchQueue.main.async
        {
            var alertTitle = "\("To use video calls, this app needs access to your iPhone's camera. You can fix this by doing the following".localized()):\n\n1. \("Close this app.".localized())\n\n2. \("Open the Settings app.".localized())\n\n3. \("Scroll to the bottom and select this app in the list.".localized())\n\n4. \("Turn the Camera on.".localized())\n\n5. \("Open this app and try again.".localized())"
            
            let alertButton = "Settings".localized()
            var settingsAction = UIAlertAction(title: alertButton, style: .default, handler: nil)
            let cancelAction = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
            
            if UIApplication.shared.canOpenURL(URL(string: UIApplication.openSettingsURLString)!)
            {
                alertTitle = "To use video calls, this app needs access to your iPhone's camera. Tap Settings and turn on Camera.".localized()
                settingsAction = UIAlertAction(title: alertButton, style: .default, handler: {(alert: UIAlertAction!) -> Void in
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                })
            }
            
            let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .alert)
            alert.addAction(cancelAction)
            alert.addAction(settingsAction)
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    static func notificationDenied(viewController: UIViewController) {
        DispatchQueue.main.async
        {
            var alertTitle = "\("To work properly this app needs Notification Authorization. You can fix this by doing the following".localized()):\n\n1. \("Close this app".localized()).\n\n2. \("Open the Settings app.".localized())\n\n3. \("Scroll to the bottom and select this app in the list.".localized())\n\n4. \("Allow Notifications.".localized())\n\n5. \("Open this app and try again.".localized())"
            
            let alertButton = "Settings".localized()
            var settingsAction = UIAlertAction(title: alertButton, style: .default, handler: nil)
            let cancelAction = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
            
            if UIApplication.shared.canOpenURL(URL(string: UIApplication.openSettingsURLString)!)
            {
                alertTitle = "To work properly this app needs Notificationa authorizations. Tap Settings and turn the authorization ON.".localized()
                settingsAction = UIAlertAction(title: alertButton, style: .default, handler: {(alert: UIAlertAction!) -> Void in
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                })
            }
            
            let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .alert)
            alert.addAction(cancelAction)
            alert.addAction(settingsAction)
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    static func getLastVisibleWindow() -> UIWindow {
        let windows = UIApplication.shared.windows
        if let window = windows.reversed().first(where: { (window) -> Bool in
            // WE check for window.subviews[0].subviews[0].frame.origin. because sometimes the keyboard windows remain open but Out of screen the screen.
            return window.isHidden == false && window.subviews.count > 0 && window.subviews[0].subviews.count > 0 && window.subviews[0].subviews[0].frame.origin.y < UIScreen.main.bounds.size.height
        }) {
            return window
        } else {
            return windows[0]
        }
    }
    
    static func getFirstWindow() -> UIWindow {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
        //    return UIApplication.shared.windows[0]
    }
    
}

// MARK: - Watermark Views on KeyWindow Window
extension AppUtility {
    fileprivate static let waterMarkLabel: UILabel = {
        let sideSize = UIScreen.main.bounds.size.height > UIScreen.main.bounds.size.width ? UIScreen.main.bounds.size.height * 1.5 : UIScreen.main.bounds.size.width * 1.5
        let label = UILabel(frame: CGRect(x: -sideSize/2, y: -sideSize/2, width: sideSize, height: sideSize*2))
        label.isUserInteractionEnabled = false
        label.textColor = .gray
        label.alpha = 0.30
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 18)
        label.adjustsFontForContentSizeCategory = true
        
        let inputString = "\(Blackbox.shared.account.registeredNumber ?? "")51e3eb37471db46a4c4f9472deb594d4a56ceae0a163728aa45b6a06ed1d43cb"
        let inputData = Data(inputString.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        if let hash = hashString.slicing(from: 0, length: 16) {
            var finalStr = "Top Secret \(hash) "
            for _ in 1..<120 {
                finalStr = "\(finalStr) # Top Secret \(hash) "
            }
            label.text = "\(finalStr)"
        }
        label.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 5)
        return label
    }()
    
    fileprivate static let logoImageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        imageView.image = UIImage(named: "logo_no_background")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.alpha = 0.15
        return imageView
    }()
    
    static func addWatermarkToWindow() {
        if let window = UIApplication.shared.windows.first(where: { (window) -> Bool in
            return window.isKeyWindow
        }) {
            window.addSubview(AppUtility.waterMarkLabel)
            window.addSubview(AppUtility.logoImageView)
            AppUtility.logoImageView.pin.vCenter().hCenter()
            AppUtility.waterMarkLabel.pin.vCenter().hCenter()
        }
    }
    
    static func removeWatermarkFromWindow() {
        AppUtility.waterMarkLabel.removeFromSuperview()
        AppUtility.logoImageView.removeFromSuperview()
    }
    
    static func setAppBadgeNumber(_ number: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = number
        }
    }
    
    static func convertVideoToLowQuality(inputURL: URL, compressionProgressBlock: ((Float)->Void)? = nil, completion block: ((URL) -> Void)?) {
        
        //    logi("compressFile -file size before compression: \(getFileSize(inputURL.path) / 1_048_576) mb")
        logi("file size before compression: \(getFileSize(inputURL.path)) bytes")
        
        // add these properties
        var assetWriter: AVAssetWriter!
        var assetReader: AVAssetReader?
        //    let bitRate: NSNumber = NSNumber(value: 1_250_000) // *** you can change this number
        let bitRate: NSNumber = NSNumber(value: 2_000_000) // *** you can change this number
        
        
        var audioFinished = false
        var videoFinished = false
        
        let asset = AVAsset(url: inputURL)
        
        //create asset reader
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assetReader = nil
        }
        
        guard let reader = assetReader else {
            loge("Could not iniitalize asset reader probably failed its try catch")
            // show user error message/alert
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else { return }
        let videoReaderSettings: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB]
        //    logi(videoTrack.estimatedDataRate)
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        
        var assetReaderAudioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
            
            let audioReaderSettings: [String : Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]
            
            assetReaderAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioReaderSettings)
            
            if reader.canAdd(assetReaderAudioOutput!) {
                reader.add(assetReaderAudioOutput!)
            } else {
                logi("Couldn't add audio output reader")
                // show user error message/alert
                return
            }
        }
        
        guard reader.canAdd(assetReaderVideoOutput) else {
            logi("Couldn't add video output reader")
            // show user error message/alert
            return
        }
        reader.add(assetReaderVideoOutput)
        
        let videoSettings: [String : Any] = [
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitRate],
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
        ]
        
        let audioSettings: [String:Any] = [AVFormatIDKey : kAudioFormatMPEG4AAC,
                                   AVNumberOfChannelsKey : 2,
                                         AVSampleRateKey : 44100.0,
                                      AVEncoderBitRateKey: 128000
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform
        
        let videoInputQueue = DispatchQueue(label: "videoQueue")
        let audioInputQueue = DispatchQueue(label: "audioQueue")
        
        do {
            let outputURL = getTemporaryDirectory().appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4)
        } catch {
            assetWriter = nil
        }
        guard let writer = assetWriter else {
            print("assetWriter was nil")
            // show user error message/alert
            return
        }
        
        writer.shouldOptimizeForNetworkUse = true
        writer.add(videoInput)
        writer.add(audioInput)
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        
        let closeWriter: ()->Void = {
            if (audioFinished && videoFinished) {
                assetWriter?.finishWriting(completionHandler: {
                    if let assetWriter = assetWriter {
                        //            logi("compressFile -file size after compression: \(getFileSize(assetWriter.outputURL.path) / 1_048_576) mb")
                        logi("file size after compression: \(getFileSize(assetWriter.outputURL.path)) bytes")
                    }
                    
                    block?((assetWriter?.outputURL)!)
                })
                
                reader.cancelReading()
            }
        }
        
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) {
            while(audioInput.isReadyForMoreMediaData) {
                if let cmSampleBuffer = assetReaderAudioOutput?.copyNextSampleBuffer() {
                    
                    audioInput.append(cmSampleBuffer)
                    
                } else {
                    audioInput.markAsFinished()
                    DispatchQueue.main.async {
                        audioFinished = true
                        closeWriter()
                    }
                    break;
                }
            }
        }
        
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) {
            // request data here
            let totalDuration = CMTimeGetSeconds(videoTrack.timeRange.duration)
            var progress: Float = 0
            while(videoInput.isReadyForMoreMediaData) {
                if let cmSampleBuffer = assetReaderVideoOutput.copyNextSampleBuffer() {
                    let sampleBufferAtSecond = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer)).rounded(toPlaces: 1)
                    videoInput.append(cmSampleBuffer)
                    
                    let newProgress = (Float(sampleBufferAtSecond / totalDuration) * 100).rounded()
                    if newProgress > progress {
                        progress = newProgress
                        DispatchQueue.main.async {
                            compressionProgressBlock?(progress)
                        }
                    }
                } else {
                    videoInput.markAsFinished()
                    DispatchQueue.main.async {
                        videoFinished = true
                        closeWriter()
                    }
                    break;
                }
            }
        }
    }
    
    static var isDeviceJailbroken: Bool {
        
        guard TARGET_IPHONE_SIMULATOR != 1 else { return false }
        
        // Check 1 : existence of files that are common for jailbroken devices
        if FileManager.default.fileExists(atPath: "/Applications/Cydia.app")
            || FileManager.default.fileExists(atPath: "/Library/MobileSubstrate/MobileSubstrate.dylib")
            || FileManager.default.fileExists(atPath: "/bin/bash")
            || FileManager.default.fileExists(atPath: "/usr/sbin/sshd")
            || FileManager.default.fileExists(atPath: "/etc/apt")
            || FileManager.default.fileExists(atPath: "/private/var/lib/apt/")
            || UIApplication.shared.canOpenURL(URL(string:"cydia://package/com.example.package")!) {
            
            return true
        }
        
        // Check 2 : Reading and writing in system directories (sandbox violation)
        let stringToWrite = "Jailbreak Test"
        do {
            try stringToWrite.write(toFile:"/private/JailbreakTest.txt", atomically:true, encoding:String.Encoding.utf8)
            // Device is jailbroken
            return true
        } catch {
            return false
        }
    }
    
}


extension AppUtility {
    static func benchmark(_ title: String, block: (@escaping () -> ()) -> ()) {
        let startTime = CFAbsoluteTimeGetCurrent()
        block {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("\(title):: Time: \(timeElapsed)")
        }
    }
    
    private static func testLogURL() -> URL {
        return getDocumentsDirectory().appendingPathComponent("testLog.txt")
    }
    
    static func printLog() {
        try? logi(String(contentsOf: testLogURL()))
    }
    
    static func removeLogFile() {
        try? FileManager.default.removeItem(at: testLogURL())
    }
    
    static func writeToLog(content: String) {
        
        let contentToAppend = content+"\n"
        let url = testLogURL()
        
        //Check if file exists
        if let fileHandle = FileHandle(forWritingAtPath: url.path) {
            //Append to file
            fileHandle.seekToEndOfFile()
            fileHandle.write(contentToAppend.data(using: .utf8)!)
        }
        else {
            //Create new file
            do {
                try contentToAppend.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Error creating \(url.path)")
            }
        }
    }
}
