import Foundation
import UIKit

public class AsyncImageView: UIImageView {
  private class ImageLoadOperation {
    private(set) var isCancelled: Bool = false
    
    func cancel() {
      isCancelled = true
    }
  }
  private var imageLoadOperation: ImageLoadOperation?
  
  private func cancel() {
    if let imageLoadOperation = imageLoadOperation {
      imageLoadOperation.cancel()
      self.imageLoadOperation = nil
    }
  }
  
  override public var image: UIImage? {
    willSet {
      cancel()
    }
  }
  
  public func loadImage(from path: String) {
    let imageLoadOperation = ImageLoadOperation()
    self.imageLoadOperation = imageLoadOperation
    
    DispatchQueue.global(qos: .background).async {
      let imageOrNil = UIImage(contentsOfFile: path)
      guard let image = imageOrNil else {
        return
      }
      
      let decodedImage = AsyncImageView.decodeImage(image: image)
      
      DispatchQueue.main.async {
        guard !imageLoadOperation.isCancelled else {
          return
        }
        
        super.image = decodedImage
      }
    }
  }
  
  public func loadImageNamed(name: String) {
    cancel()
    
    let pathToImageOrNil = AsyncImageView.pathToImageNamed(name: name)
    guard let pathToImage = pathToImageOrNil else {
      super.image = nil
      return
    }
    
    let imageLoadOperation = ImageLoadOperation()
    self.imageLoadOperation = imageLoadOperation
    
    DispatchQueue.global(qos: .background).async {
      let imageOrNil = UIImage(contentsOfFile: pathToImage)
      guard let image = imageOrNil else {
        return
      }
      
      let decodedImage = AsyncImageView.decodeImage(image: image)
      
      DispatchQueue.main.async {
        guard !imageLoadOperation.isCancelled else {
          return
        }
        
        super.image = decodedImage
      }
    }
  }
  
  private static func pathToImageNamed(name: String) -> String? {
    let screenScale = UIScreen.main.scale
    
    var resourceNames = [String]()
    switch screenScale {
    case 3:
      resourceNames.append(name + "@3x")
      fallthrough
      
    case 2:
      resourceNames.append(name + "@2x")
      fallthrough
      
    case 1:
      resourceNames.append(name)
      
    default:
      break
    }
    
    for resourceName in resourceNames {
      if let pathToImage = Bundle.main.path(forResource: resourceName, ofType: "png") {
        return pathToImage
      }
    }
    
    return nil
  }
  
  private static func decodeImage(image: UIImage) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    defer {
      UIGraphicsEndImageContext()
    }
    
    image.draw(at: CGPoint.zero)
    
    return UIGraphicsGetImageFromCurrentImageContext()
  }
}
