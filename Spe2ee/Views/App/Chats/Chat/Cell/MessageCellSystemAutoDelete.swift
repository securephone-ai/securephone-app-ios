import UIKit
import PinLayout


class MessageCellSystemAutoDelete: MessageDefaultCell {
  
  override var viewModel: MessageViewModel! {
    didSet {
      self.messageLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 15.5)
      self.messageLabel.textAlignment = .center
    }
  }
  
  private var rootView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 8
    view.backgroundColor = UIColor.init(hexString: "FDF3BE")
    return view
  }()
  
  private var messageLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  private var autoDeleteTimerImageView: UIImageView = {
    let image = UIImageView(image: UIImage(named: "quick_timer"))
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
    rootView.addSubview(autoDeleteTimerImageView)
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
    autoDeleteTimerImageView.pin.vCenter().left(15).width(size).height(size)
  }
  
}
