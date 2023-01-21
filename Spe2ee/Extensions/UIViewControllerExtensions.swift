
import Foundation
import UIKit

extension UIViewController {
  var className: String {
    String(describing: type(of: self))
  }
  
  var isModal: Bool {
    if let index = navigationController?.viewControllers.firstIndex(of: self), index > 0 {
      return false
    } else if presentingViewController != nil {
      return true
    } else if navigationController?.presentingViewController?.presentedViewController == navigationController {
      return true
    } else if tabBarController?.presentingViewController is UITabBarController {
      return true
    } else {
      return false
    }
  }
  
  /// Calculate the nav bar height if present
  var topbarHeight: CGFloat {
    return (view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0) +
      (self.navigationController?.navigationBar.frame.height ?? 0.0)
  }
}
