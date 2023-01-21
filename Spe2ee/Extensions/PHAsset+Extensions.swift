import Foundation
import Photos
import UIKit


extension PHAsset {
  
  func getURL(completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
    if mediaType == .image {
      let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
      options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
        return true
      }
      requestContentEditingInput(with: options, completionHandler: { (contentEditingInput, info) -> Void in
        completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
      })
    } else if mediaType == .video {
      let options: PHVideoRequestOptions = PHVideoRequestOptions()
      options.version = .original
      
      PHImageManager.default().requestAVAsset(forVideo: self, options: options, resultHandler: { (asset, audioMix, info) -> Void in
        if let urlAsset = asset as? AVURLAsset {
          let localVideoUrl: URL = urlAsset.url as URL
          completionHandler(localVideoUrl)
        } else {
          completionHandler(nil)
        }
      })
    }
  }
}
