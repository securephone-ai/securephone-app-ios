import UIKit
import PinLayout


class MessageCellSystemTemporaryChat: MessageDefaultCell {
  
  override var viewModel: MessageViewModel! {
    didSet {
      self.messageLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 15.5)
      self.messageLabel.textAlignment = .center
    }
  }
  
  private var rootView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 8
    view.backgroundColor = UIColor.init(hexString: "fff5cc")
    return view
  }()
  
  private var messageLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15.5)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0
    return label
  }()
  
  private var iconImageView: UIImageView = {
    let image = UIImageView(image: UIImage(named: "destroy_chat_icon"))
    image.contentMode = .scaleAspectFit
    image.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
    image.tintColor = .black
    return image
  }()
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    backgroundColor = .clear
    selectionStyle = .none
    
    contentView.addSubview(rootView)
    rootView.addSubview(messageLabel)
    rootView.addSubview(iconImageView)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    rootView.pin
      .top(4)
      .bottom(4)
      .width(80%)
      .hCenter()
    rootView.dropShadow(color: .black, opacity: 0.2, offSet: CGSize(width: 0, height: 0.6), radius: 1, scale: true)
    
    messageLabel.pin.top().bottom().left(40).right(40)
    let size = UIFont.appFont(ofSize: 20).pointSize
    iconImageView.pin.vCenter().left(15).width(size).height(size)
  }
  
}
