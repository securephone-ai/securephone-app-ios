

import Foundation

import UIKit
import Toast_Swift

private struct ViewConstants {
  static let marginBottom: CGFloat = 80
}

extension UIView {
  
  func showBottomToast(_ text: String, duration: TimeInterval = ToastManager.shared.duration) {
    let x = bounds.size.width / 2.0
    let y = bounds.size.height - ViewConstants.marginBottom
    makeToast(text, point: CGPoint(x: x, y: y), title: nil, image: nil, completion: nil)
  }
  
}
