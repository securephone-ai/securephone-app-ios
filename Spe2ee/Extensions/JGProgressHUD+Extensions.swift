import Foundation
import JGProgressHUD

extension JGProgressHUD {
  
  /// Dismiss the hud on the main thread
  func dismissMT() {
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.dismiss()
    }
  }
}
