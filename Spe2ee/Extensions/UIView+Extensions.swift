

import Foundation
import UIKit

extension UIView {
  func findViewController() -> UIViewController? {
    if let nextResponder = self.next as? UIViewController {
      return nextResponder
    } else if let nextResponder = self.next as? UIView {
      return nextResponder.findViewController()
    } else {
      return nil
    }
  }
  
  func asImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(bounds: bounds)
    return renderer.image { rendererContext in
      layer.render(in: rendererContext.cgContext)
    }
  }
  
  func takeScreenshot() -> UIImage {
    // Begin context
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
    
    // Draw view in that context
    drawHierarchy(in: self.bounds, afterScreenUpdates: true)
    
    // And finally, get image
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    if (image != nil)
    {
      return image!
    }
    return UIImage()
  }
  
  var isDarkMode: Bool {
    return traitCollection.userInterfaceStyle == .dark
  }
  
  func mask(withRect rect: CGRect, inverse: Bool = false) {
    let path = UIBezierPath(rect: rect)
    let maskLayer = CAShapeLayer()
    
    if inverse {
      path.append(UIBezierPath(rect: self.bounds))
      maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
    }
    
    maskLayer.path = path.cgPath
    
    self.layer.mask = maskLayer
  }
  
  func mask(withPath path: UIBezierPath, inverse: Bool = false) {
    let path = path
    let maskLayer = CAShapeLayer()
    
    if inverse {
      path.append(UIBezierPath(rect: self.bounds))
      maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
    }
    
    maskLayer.path = path.cgPath
    
    self.layer.mask = maskLayer
  }
}

