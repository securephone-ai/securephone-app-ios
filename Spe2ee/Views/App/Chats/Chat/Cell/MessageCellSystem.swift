import UIKit
import PinLayout


class MessageCellSystem: MessageDefaultCell {
  
  override var viewModel: MessageViewModel! {
    didSet {
      
      missedCallImageView.isHidden = true
      
      switch viewModel.message.type {
      case .alertScreenshot:
        rootView.backgroundColor = Constants.AlertColorScreenshot
        messageLabel.attributedText = viewModel.message.alertMsg?.attributedForChat
        messageLabel.textColor = .white
        sendReadReceipt()
        
        dateLabel.isHidden = false
        
      case .alertScreenRecording:
        rootView.backgroundColor = Constants.AlertColorScreenshot
        messageLabel.attributedText = viewModel.message.alertMsg?.attributedForChat
        messageLabel.textColor = .white
        sendReadReceipt()
        
        dateLabel.isHidden = false
      case .systemMessage(let type):
        
        if type == .missedCall {
          missedCallImageView.image = UIImage(systemName: "phone.fill.arrow.down.left")
          missedCallImageView.isHidden = false
        } else if type == .missedVideoCall {
          missedCallImageView.image = UIImage(systemName: "arrow.down.left.video.fill")
          missedCallImageView.isHidden = false
        }
        fallthrough
      default:
        rootView.backgroundColor = Constants.SystemMessageBackgroundColor
        messageLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 15)?.adjustDirectionBasedOnSystemLanguage()
        messageLabel.textAlignment = .center
        messageLabel.textColor = .black
      }
    }
  }
  
  private var rootView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 8
    return view
  }()
  
  private var messageLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15)
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()
  
  private var dateLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.isHidden = true
    return label
  }()
  
  private var missedCallImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .red
    return imageView
  }()
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    backgroundColor = .clear
    selectionStyle = .none
    
    contentView.addSubview(rootView)
    rootView.addSubview(messageLabel)
    rootView.addSubview(dateLabel)
    rootView.addSubview(missedCallImageView)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard let orientation = screenOrientation else { return }
    
    rootView.pin
      .top(4)
      .bottom(4)
      .width(orientation.isPortrait ? viewModel.bubbleSizePortrait.width : viewModel.bubbleSizeLandscape.width)
      .hCenter()
    rootView.dropShadow(color: .black, opacity: 0.2, offSet: CGSize(width: 0, height: 0.6), radius: 1, scale: true)
    
    messageLabel.pin.top().bottom().left(8).right(8)
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 0))
    label.font = UIFont.appFont(ofSize: 15)
    label.text = "A"
    label.frame = CGRect(x: 0, y: 0, width: 100, height: label.requiredHeight)
    
    missedCallImageView.pin.left(8).vCenter().width(label.height).height(label.height)
  }
  
  func sendReadReceipt() {
    if viewModel.isRead == false , viewModel.isSent == false {
      if let group = self.viewModel.group {
        group.sendReadReceiptAsync(of: self.viewModel.message)
      } else {
        self.viewModel.contact.sendReadReceiptAsync(of: self.viewModel.message)
      }
    }
  }
  

}

