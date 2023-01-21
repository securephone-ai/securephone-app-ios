import Foundation
import PinLayout
import UIKit

open class WatermarkedImageView: UIView {
  
  open var image: UIImage? = nil {
    didSet {
      imageView.image = image
    }
  }
  
  open var watermarkText: String? = nil {
    didSet {
      guard let watermarkText = watermarkText else { return }
      var finalStr = watermarkText
      for _ in 1..<60 {
        finalStr.append(" # \(watermarkText)")
      }
      watermarkLabel.text = finalStr
    }
  }
  
  open var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  private var watermarkLabel: UILabel = {
    let sideSize = UIScreen.main.bounds.size.height > UIScreen.main.bounds.size.width ? UIScreen.main.bounds.size.height * 1.5 : UIScreen.main.bounds.size.width * 1.5
    let label = UILabel(frame: CGRect(x: -sideSize/2, y: -sideSize/2, width: sideSize, height: sideSize*2))
    label.isUserInteractionEnabled = false
    label.textColor = .gray
    label.alpha = 0.30
    label.numberOfLines = 0
    label.font = UIFont.systemFont(ofSize: 18)
    label.adjustsFontForContentSizeCategory = true
    label.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 5)
    return label
  }()
  
  public init(image: UIImage? = nil, watermarkText: String? = nil) {
    super.init(frame: .zero)
    
    layer.cornerRadius = 6
    layer.masksToBounds = true
    
    self.image = image
    self.watermarkText = watermarkText
    
    self.addSubview(imageView)
    self.addSubview(watermarkLabel)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.pin.all()
    watermarkLabel.pin.vCenter().hCenter()
    
  }
  
}
