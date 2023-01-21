import UIKit
import PinLayout

class GroupInfoMemberCell: UITableViewCell {
  
  var avatarImageView: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    imageView.contentMode = .scaleAspectFill
    imageView.image = UIImage(named: "avatar_profile")
    imageView.cornerRadius = 20
    imageView.backgroundColor = .systemGray6
    return imageView
  }()
  
  var contactNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    return label
  }()
  
  var contactNumberLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 13)
    label.tintColor = .systemGray4
    return label
  }()
  
  var statusLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 13)
    label.tintColor = .systemGray4
    return label
  }()
  
  var roleLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 13)
    label.tintColor = .systemGray2
    return label
  }()
  
  var activityIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(style: .medium)
    indicator.color = .black
    indicator.startAnimating()
    indicator.isHidden = true
    return indicator
  }()
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    separatorInset.left = 70
    
    contentView.addSubview(avatarImageView)
    contentView.addSubview(contactNameLabel)
    contentView.addSubview(contactNumberLabel)
    contentView.addSubview(statusLabel)
    contentView.addSubview(roleLabel)
    contentView.addSubview(activityIndicator)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    avatarImageView.image = UIImage(named: "avatar_profile")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    contactNameLabel.sizeToFit()
    contactNumberLabel.sizeToFit()
    statusLabel.sizeToFit()
    roleLabel.sizeToFit()
    
    if AppUtility.isArabic {
      avatarImageView.pin.vCenter().right(18)
      
      if let text = contactNumberLabel.text, !text.isEmpty {
        contactNameLabel.pin.left(of: avatarImageView).marginRight(10).top(7)
        contactNumberLabel.pin.topRight(to: contactNameLabel.anchor.bottomRight).marginTop(2)
        statusLabel.pin.bottom(to: contactNumberLabel.edge.bottom).left(of: contactNumberLabel).marginRight(3).left()
      } else {
        contactNameLabel.pin.vCenter().left(of: avatarImageView).marginRight(10)
      }
      
      roleLabel.pin.vCenter().left(20)
      activityIndicator.pin.vCenter().left(20)
    } else {
      avatarImageView.pin.vCenter().left(18)
      
      if let text = contactNumberLabel.text, !text.isEmpty {
        contactNameLabel.pin.right(of: avatarImageView).marginLeft(10).top(7)
        contactNumberLabel.pin.topLeft(to: contactNameLabel.anchor.bottomLeft).marginTop(2)
        statusLabel.pin.bottom(to: contactNumberLabel.edge.bottom).right(of: contactNumberLabel).marginLeft(3).right()
      } else {
        contactNameLabel.pin.vCenter().right(of: avatarImageView).marginLeft(10)
      }
      
      roleLabel.pin.vCenter().right(20)
      activityIndicator.pin.vCenter().right(20)
    }
  }
  
  func startActivity() {
    activityIndicator.startAnimating()
    activityIndicator.isHidden = false
    roleLabel.isHidden = true
  }
  
  func stopActivity() {
    roleLabel.isHidden = false
    activityIndicator.stopAnimating()
    activityIndicator.isHidden = true
  }
}
