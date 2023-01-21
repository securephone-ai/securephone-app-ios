import UIKit
import PinLayout

class ContactCell: UITableViewCell {
  static let ID = "ContactCell"
  
  let avatar: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    imageView.contentMode = .scaleAspectFill
    imageView.image = UIImage(named: "avatar_profile")
    imageView.layer.cornerRadius = CGFloat(20)
    imageView.layer.masksToBounds = true
    imageView.backgroundColor = .systemGray6
    return imageView
  }()
  
  let contactName: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.adjustsFontForContentSizeCategory = true
    label.height = "".size(usingFont: label.font).height
    return label
  }()
  
  let contactNumber: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.tintColor = .systemGray4
    label.adjustsFontForContentSizeCategory = true
    label.height = "".size(usingFont: label.font).height
    return label
  }()
  
  let status: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    label.tintColor = .systemGray4
    return label
  }()
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
//    separatorInset.left = 70
    contentView.addSubview(avatar)
    contentView.addSubview(contactName)
    contentView.addSubview(contactNumber)
    contentView.addSubview(status)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    avatar.image = UIImage(named: "avatar_profile")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    contactNumber.sizeToFit()
    status.sizeToFit()
    
    avatar.pin.top(6).bottom(6).width(avatar.height)
    if AppUtility.isArabic {
      avatar.pin.right(14)
      if let text = contactNumber.text, !text.isEmpty {
        contactName.pin.left(of: avatar).marginRight(10).top(7).left(14)
        contactNumber.pin.topRight(to: contactName.anchor.bottomRight).marginTop(2)
        status.pin.centerRight(to: contactNumber.anchor.centerLeft).marginRight(8).left(14)
      } else {
        contactName.pin.vCenter().left(of: avatar).marginRight(10).left(14)
      }
      separatorInset.left = width - (contactName.frame.origin.x + contactName.width)
    }
    else {
      avatar.pin.left(14)
      
      if let text = contactNumber.text, !text.isEmpty {
        contactName.pin.right(of: avatar).marginLeft(10).top(7).right(14)
        contactNumber.pin.topLeft(to: contactName.anchor.bottomLeft).marginTop(2)
        status.pin.centerLeft(to: contactNumber.anchor.centerRight).marginLeft(8).right(14)
      } else {
        contactName.pin.vCenter().right(of: avatar).marginLeft(10).right(14)
      }
      separatorInset.left = contactName.frame.origin.x
    }
    
    avatar.cornerRadius = avatar.height / 2
  }
}


extension ContactCell {
  static func getCellRequiredHeight() -> CGFloat {
    return "".size(usingFont: UIFont.appFont(ofSize: 16)).height + "".size(usingFont: UIFont.appFont(ofSize: 13)).height + 20
  }
}
