

import Foundation
import UIKit
import CoreGraphics

extension UISegmentedControl {
  /// Tint color doesn't have any effect on iOS 13.
  func ensureiOS12Style() {
    if #available(iOS 13, *) {
      let tintColorImage = UIImage(color: tintColor)
      // Must set the background image for normal to something (even clear) else the rest won't work
      setBackgroundImage(UIImage(color: backgroundColor ?? .clear), for: .normal, barMetrics: .default)
      setBackgroundImage(tintColorImage, for: .selected, barMetrics: .default)
      setBackgroundImage(UIImage(color: tintColor.withAlphaComponent(0.2)), for: .highlighted, barMetrics: .default)
      setBackgroundImage(tintColorImage, for: [.highlighted, .selected], barMetrics: .default)
      setTitleTextAttributes([.foregroundColor: tintColor!, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .regular)], for: .normal)
      setTitleTextAttributes([.foregroundColor: UIColor.white, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .regular)], for: .selected)
      setDividerImage(tintColorImage, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
      layer.borderWidth = 1
      layer.borderColor = tintColor.cgColor
    }
  }
}

extension UIImage {
  public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
    let rect = CGRect(origin: .zero, size: size)
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    color.setFill()
    UIRectFill(rect)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    guard let cgImage = image?.cgImage else { return nil }
    self.init(cgImage: cgImage)
  }
}

extension UITextView {
  func numberOfLines() -> Int {
    let layoutManager = self.layoutManager
    let numberOfGlyphs = layoutManager.numberOfGlyphs
    var lineRange: NSRange = NSMakeRange(0, 1)
    var index = 0
    var numberOfLines = 0
    
    while index < numberOfGlyphs {
      layoutManager.lineFragmentRect(
        forGlyphAt: index, effectiveRange: &lineRange
      )
      index = NSMaxRange(lineRange)
      numberOfLines += 1
    }
    return numberOfLines
  }
}


extension UIView {
  
  // OUTPUT 1
  func dropShadow(scale: Bool = true) {
    layer.masksToBounds = false
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.5
    layer.shadowOffset = CGSize(width: -1, height: 1)
    layer.shadowRadius = 1
    
    layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    layer.shouldRasterize = true
    layer.rasterizationScale = scale ? UIScreen.main.scale : 1
  }
  
  // OUTPUT 2
  func dropShadow(color: UIColor, opacity: Float = 0.5, offSet: CGSize, radius: CGFloat = 1, scale: Bool = true) {
    layer.masksToBounds = false
    layer.shadowColor = color.cgColor
    layer.shadowOpacity = opacity
    layer.shadowOffset = offSet
    layer.shadowRadius = radius
    
    if layer.cornerRadius > 0 {
      layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath
    } else {
      layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
    }
    
    layer.shouldRasterize = true
    layer.rasterizationScale = scale ? UIScreen.main.scale : 1
  }
  
  var screenOrientation: UIInterfaceOrientation? {
    if let interfaceOrientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation {
      // Use interfaceOrientation
      return interfaceOrientation
    }
    return nil
  }
  
  func copyView<T: UIView>() -> T {
    do {
      return try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)) as! T
    }
  }
}

extension UIImage {
  
  func addShadow(blurSize: CGFloat = 0.6) -> UIImage {
    
    let shadowColor = UIColor(white:0.0, alpha:1).cgColor
    
    let context = CGContext(data: nil,
                            width: Int(self.size.width + blurSize),
                            height: Int(self.size.height + blurSize),
                            bitsPerComponent: self.cgImage!.bitsPerComponent,
                            bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    context.setShadow(offset: CGSize(width: 0,height: -blurSize),
                      blur: blurSize,
                      color: shadowColor)
    context.draw(self.cgImage!,
                 in: CGRect(x: 0, y: blurSize, width: self.size.width, height: self.size.height),
                 byTiling:false)
    
    return UIImage(cgImage: context.makeImage()!)
  }
  
  func colorized(color : UIColor) -> UIImage {
    
    let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
    
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    if let context = UIGraphicsGetCurrentContext() {
      context.setBlendMode(.multiply)
      context.translateBy(x: 0, y: self.size.height)
      context.scaleBy(x: 1.0, y: -1.0)
      context.draw(self.cgImage!, in: rect)
      context.clip(to: rect, mask: self.cgImage!)
      context.setFillColor(color.cgColor)
      context.fill(rect)
    }
    
    let colorizedImage = UIGraphicsGetImageFromCurrentImageContext()
    
    UIGraphicsEndImageContext()
    return colorizedImage!
  }
}





extension UIResponder {
  /**
   * Returns the next responder in the responder chain cast to the given type, or
   * if nil, recurses the chain until the next responder is nil or castable.
   */
  func next<U: UIResponder>(of type: U.Type = U.self) -> U? {
    return self.next.flatMap({ $0 as? U ?? $0.next() })
  }
}

extension UITableViewCell {
  var tableView: UITableView? {
    return self.next(of: UITableView.self)
  }
  
  var indexPath: IndexPath? {
    return self.tableView?.indexPath(for: self)
  }
}

extension UICollectionViewCell {
  var collectionView: UICollectionView? {
    return self.next(of: UICollectionView.self)
  }
  
  var indexPath: IndexPath? {
    return self.collectionView?.indexPath(for: self)
  }
}


extension UIApplication {

    var visibleViewController: UIViewController? {

        guard let rootViewController = keyWindow?.rootViewController else {
            return nil
        }

        return getVisibleViewController(rootViewController)
    }

    private func getVisibleViewController(_ rootViewController: UIViewController) -> UIViewController? {

        if let presentedViewController = rootViewController.presentedViewController {
            return getVisibleViewController(presentedViewController)
        }

        if let navigationController = rootViewController as? UINavigationController {
            return navigationController.visibleViewController
        }

        if let tabBarController = rootViewController as? UITabBarController {
            return tabBarController.selectedViewController
        }

        return rootViewController
    }
}

extension String {
    func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }

    func base64Decoded() -> String {
        guard let data = Data(base64Encoded: self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
