
import Foundation
import UIKit


class MemberCellView: UIView {
  
  var memberImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 56, height: 56))
    imageView.layer.cornerRadius = 30
    //imageView.image = UIImage(named: "avatar_profile")
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  var removeButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
    button.tintColor = .white
    button.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    button.contentMode = .scaleAspectFit
    button.backgroundColor = .systemGray3
    button.isCircle = true
    button.layer.borderColor = UIColor.white.cgColor
    button.layer.borderWidth = 2.0
    return button
  }()
  
  var memberNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontLight(ofSize: 12)
    return label
  }()

  var memberNameInitialsLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 18)
    label.textColor = .white
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
      
    addSubview(memberImageView)
    addSubview(removeButton)
    addSubview(memberNameLabel)
    addSubview(memberNameInitialsLabel)
    
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    memberNameLabel.sizeToFit()
    memberNameInitialsLabel.sizeToFit()
    
    memberImageView.pin.hCenter().top(8)
    removeButton.pin.topRight(to: memberImageView.anchor.topRight).marginRight(-1).marginTop(-1)
    memberNameLabel.pin.below(of: memberImageView, aligned: .center).marginTop(1)
    memberNameInitialsLabel.pin.vCenter(to: memberImageView.edge.vCenter).hCenter()
  
  }
}
