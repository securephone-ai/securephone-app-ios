import Foundation
import UIKit
import Combine


extension UIImageView {
  var imagePubliher: AnyPublisher<UIImage, Never> {
    NotificationCenter.default
      .publisher(for: .imageDidChangeNotification, object: self)
      .compactMap { $0.object as? UIImageView } // receiving notifications with objects which are instances of UITextFields
      .map { $0.image ?? UIImage() } // mapping UIImageView to extract the image
      .eraseToAnyPublisher()
  }
  
  func setImageColor(color: UIColor) {
    let templateImage = self.image?.withRenderingMode(.alwaysTemplate)
    self.image = templateImage
    self.tintColor = color
  }
}
