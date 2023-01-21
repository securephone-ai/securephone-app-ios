import UIKit
import Combine

extension UITextField {
  
  func addBottomBorder(color: UIColor = UIColor.systemGray4, borderTickness: CGFloat = 0.5) {
    if self.layer.sublayers != nil {
      for layer in self.layer.sublayers! {
        if let name = layer.name, name == "bottomLine" {
          layer.removeFromSuperlayer()
        }
      }
    }
    let bottomLine = CALayer()
    bottomLine.name = "bottomLine"
    bottomLine.frame = CGRect(x: 0, y: self.frame.size.height - 1, width: self.frame.size.width, height: borderTickness)
    bottomLine.backgroundColor = color.cgColor
    borderStyle = .none
    layer.addSublayer(bottomLine)
  }
  
  func addTopBorder(color: UIColor = UIColor.systemGray4, borderTickness: CGFloat = 0.5) {
    if self.layer.sublayers != nil {
      for layer in self.layer.sublayers! {
        if let name = layer.name, name == "topLine" {
          layer.removeFromSuperlayer()
        }
      }
    }
    let topLine = CALayer()
    topLine.name = "topLine"
    topLine.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: borderTickness)
    topLine.backgroundColor = color.cgColor
    borderStyle = .none
    layer.addSublayer(topLine)
  }
  
  var textPublisher: AnyPublisher<String, Never> {
    NotificationCenter.default
      .publisher(for: UITextField.textDidChangeNotification, object: self)
      .compactMap { $0.object as? UITextField } // receiving notifications with objects which are instances of UITextFields
      .map { $0.text ?? "" } // mapping UITextField to extract text
      .eraseToAnyPublisher()
  }
  
  func setLeftPaddingPoints(_ amount:CGFloat){
    let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: height))
    self.leftView = paddingView
    self.leftViewMode = .always
  }
  func setRightPaddingPoints(_ amount:CGFloat) {
    let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: height))
    self.rightView = paddingView
    self.rightViewMode = .always
  }
}
