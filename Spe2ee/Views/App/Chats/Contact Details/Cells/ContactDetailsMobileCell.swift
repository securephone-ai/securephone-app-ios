import UIKit

class ContactDetailsMobileCell: ContactDetailsBaseCell {
  static let ID = "ContactDetailsMobileCell"
  
  private var maxWidth: CGFloat {
    return UIScreen.main.bounds.width-30
  }
  
  var phoneNumber: PhoneNumber? {
    didSet {
      guard let phoneNumber = self.phoneNumber else { return }
      
      fieldNameLabel.text = phoneNumber.tag
      fieldNameLabel.sizeToFit()
      
      fieldValueLabel.text = phoneNumber.phone
      fieldValueLabel.sizeToFit()
    }
  }
  
  lazy var chatButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    button.tintColor = .link
    button.setImage(UIImage(systemName: "bubble.left.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.backgroundColor = .systemGray5
    button.isCircle = true
    return button
  }()
  
  lazy var videoCallButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    button.tintColor = .link
    button.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.backgroundColor = .systemGray5
    button.isCircle = true
    button.isEnabled = true
    return button
  }()
  
  lazy var callButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    button.tintColor = .link
    button.setImage(UIImage(systemName: "phone.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.backgroundColor = .systemGray5
    button.isCircle = true
    button.isEnabled = true
    return button
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    contentView.backgroundColor = .white
    contentView.addSubview(chatButton)
    contentView.addSubview(videoCallButton)
    contentView.addSubview(callButton)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    callButton.pin.vCenter().right(20)
    videoCallButton.pin.vCenter().left(of: callButton).marginRight(10)
    chatButton.pin.vCenter().left(of: videoCallButton).marginRight(10)
  }
}


