
import UIKit
import PinLayout

class MessageCellContacts: MessageBaseCell {

  /// Contact Image Preview
  lazy var firstContactImage: UIImageView = {
    let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    image.contentMode = .scaleToFill
    return image
  }()
  
  /// Contact Image Preview
  lazy var secondContactImage: UIImageView = {
    let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    image.contentMode = .scaleToFill
    return image
  }()
  
  /// Contact Image Preview
  lazy var thirdContactImage: UIImageView = {
    let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    image.contentMode = .scaleToFill
    return image
  }()
  
  /// Contact Image Preview
  lazy var chevronRightImage: UIImageView = {
    let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
    image.image = UIImage(named: "disclosure_indicator")
    image.contentMode = .scaleAspectFit
    return image
  }()
  
  /// Info button placed at the view's bottom
  lazy var infoButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("View All".localized(), for: .normal)
    return button
  }()
  
  lazy var title: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    return label
  }()
  
  override var viewModel: MessageViewModel! {
    didSet {
      logi(viewModel.alpha)
    }
  }
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
  func setupCell() {
    messageRootContainer.addSubview(title)
    messageRootContainer.addSubview(chevronRightImage)
    messageRootContainer.addSubview(infoButton)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    
  }
}

