

import UIKit

@IBDesignable
public class RoundedButton: UIButton {
  
  var isInterfaceBuilder = false
  
  @IBInspectable var isCircle: Bool = false {
    didSet {
      let biggerSide = layer.frame.width > layer.frame.height ? layer.frame.width : layer.frame.height
      layer.frame = CGRect(origin: layer.frame.origin, size: CGSize(width: biggerSide, height: biggerSide))
      cornerRadius = biggerSide/2
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configure()
  }
  
  func configure() {
    self.titleLabel?.numberOfLines = 0
    self.titleLabel?.textAlignment = .center
  }

  
  /*
   // Only override draw() if you perform custom drawing.
   // An empty implementation adversely affects performance during animation.
   override func draw(_ rect: CGRect) {
   // Drawing code
   }
   */
  
}
