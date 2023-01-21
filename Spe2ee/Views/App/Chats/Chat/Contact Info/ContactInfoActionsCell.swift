import Foundation

class ContactInfoActionCell: UITableViewCell {
  
  var contactNameLabel: UILabel = {
    let label = UILabel()
    label.frame = CGRect(x: 0, y: 0, width: 0, height: UILabel(text: "A").requiredHeight)
    label.font = UIFont.appFontSemiBold(ofSize: 17)
    label.textColor = .black
    label.numberOfLines = 1
    return label
  }()
  
  var contactNumberLabel: UILabel = {
    let label = UILabel()
    label.frame = CGRect(x: 0, y: 0, width: 0, height: UILabel(text: "A").requiredHeight)
    label.font = UIFont.appFont(ofSize: 13)
    label.textColor = .gray
    return label
  }()
  
  var chatButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    button.tintColor = .link
    button.setImage(UIImage(systemName: "bubble.left.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.backgroundColor = .systemGray5
    button.isCircle = true
    return button
  }()
  
  var videoCallButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    button.tintColor = .link
    button.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium)), for: .normal)
    button.backgroundColor = .systemGray5
    button.isCircle = true
    button.isEnabled = true
    return button
  }()
  
  var callButton: RoundedButton = {
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
    contentView.addSubview(contactNameLabel)
    contentView.addSubview(contactNumberLabel)
    contentView.addSubview(chatButton)
    contentView.addSubview(videoCallButton)
    contentView.addSubview(callButton)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if AppUtility.isArabic {
      callButton.pin.vCenter().left(20)
      videoCallButton.pin.vCenter().right(of: callButton).marginLeft(10)
      chatButton.pin.vCenter().right(of: videoCallButton).marginLeft(10)
      contactNameLabel.pin.right(of: chatButton).top(12).right(16)
      contactNumberLabel.pin.right(of: chatButton).below(of: contactNameLabel).marginTop(4).right(16)
    } else {
      callButton.pin.vCenter().right(20)
      videoCallButton.pin.vCenter().left(of: callButton).marginRight(10)
      chatButton.pin.vCenter().left(of: videoCallButton).marginRight(10)
      contactNameLabel.pin.left(of: chatButton).top(12).left(16)
      contactNumberLabel.pin.left(of: chatButton).below(of: contactNameLabel).marginTop(4).left(16)
    }
  }
}
