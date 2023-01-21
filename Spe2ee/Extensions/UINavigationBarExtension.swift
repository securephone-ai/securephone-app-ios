import Foundation
import UIKit

extension UINavigationBar {
  func hideBottomLine() {
    setBackgroundImage(UIImage(), for:.default)
    shadowImage = UIImage()
    layoutIfNeeded()
  }
  
  func showBottomLine() {
    setBackgroundImage(nil, for:.default)
    shadowImage = nil
    layoutIfNeeded()
  }
}
