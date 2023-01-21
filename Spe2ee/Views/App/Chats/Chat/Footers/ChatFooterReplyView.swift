import Foundation
import UIKit
import PinLayout


/// Reply View on top of ChatFooterView
class ChatFooterReplyView: UIView {
  static let height: CGFloat = 56.0
  
  var contact: BBContact? {
    didSet {
      guard let contact = self.contact else { return }
      guard let message = self.message else { return }
      if let accountNumber = Blackbox.shared.account.registeredNumber, message.sender == accountNumber {
        replayToUserLabel.text = "You".localized()
      } else {
        replayToUserLabel.text = contact.getName()
      }
      replayToUserLabel.sizeToFit()
    }
  }
  
  var message: Message? {
    didSet {
      guard let message = self.message else { return }
      
      if fileTypeImage.isDescendant(of: self) {
        fileTypeImage.removeFromSuperview()
      }
      if fileImage.isDescendant(of: self) {
        fileImage.removeFromSuperview()
      }
      
      switch message.type {
      case .audio:
        fileTypeImage.image = UIImage(systemName: "mic.fill")
        messageBodyLabel.text = "Audio".localized()
        addSubview(fileTypeImage)
      case .contact:
        fileTypeImage.image = UIImage(systemName: "person.fill")
        messageBodyLabel.text = "Contact".localized()
        addSubview(fileTypeImage)
      case .document:
        fileTypeImage.image = UIImage(systemName: "doc.fill")
        messageBodyLabel.text = "Document".localized()
        addSubview(fileTypeImage)
      case .location:
        fileTypeImage.image = UIImage(systemName: "mappin.and.ellipse")
        messageBodyLabel.text = "Location".localized()
        addSubview(fileTypeImage)
      case .photo:
        fileImage.image = UIImage(named: message.localFilename)
        fileTypeImage.image = UIImage(systemName: "camera.fill")
        messageBodyLabel.text = "Photo".localized()
        addSubview(fileTypeImage)
        addSubview(fileImage)
      case .video:
        if let fileUrl = URL(string: message.localFilename) {
            fileImage.image = AppUtility.generateVideoThumbnail(fileName: message.localFilename, filekey: message.fileKey, at: 0)
          fileTypeImage.image = UIImage(systemName: "video.fill")
          messageBodyLabel.text = "Video".localized()
          addSubview(fileTypeImage)
          addSubview(fileImage)
        }
      case .text:
        messageBodyLabel.attributedText = message.body.getAttributedText(fontSize: 15)
      default:
        break
      }
      messageBodyLabel.sizeToFit()
    }
  }
  
  private var verticalColumn: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 3, height: ChatFooterReplyView.height))
    view.backgroundColor = UIColor.random()
    return view
  }()
  
  private var replayToUserLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 15)
    return label
  }()
  
  private lazy var messageBodyLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 14)
    return label
  }()
  
  private lazy var fileImage: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    imageView.layer.cornerRadius = 3
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private lazy var fileTypeImage: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
    imageView.tintColor = .systemGray
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  var closeButton: RoundedButton = {
    let button = RoundedButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
    button.setImage(UIImage(systemName: "xmark.circle", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
    button.isCircle = true
    return button
  }()
  
  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: ChatFooterReplyView.height))
    
    addSubview(verticalColumn)
    addSubview(closeButton)
    addSubview(replayToUserLabel)
    addSubview(messageBodyLabel)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard let message = self.message else { return }
    if contact == nil {
      replayToUserLabel.text = "You".localized()
      replayToUserLabel.sizeToFit()
    }
    
    if AppUtility.isArabic {
      closeButton.pin.vCenter().left(8)
      replayToUserLabel.pin.top(8).right(8)
      
      switch message.type {
      case .photo, .video, .audio, .contact, .document, .location:
        fileTypeImage.pin.topRight(to: replayToUserLabel.anchor.bottomRight).marginTop(4)
        fileImage.pin.centerLeft(to: closeButton.anchor.centerRight).marginRight(6)
        messageBodyLabel.pin.centerRight(to: fileTypeImage.anchor.centerLeft).marginRight(2).left(to: closeButton.edge.right).marginLeft(4)
      default:
        messageBodyLabel.pin.topRight(to:  replayToUserLabel.anchor.bottomRight).marginTop(4).left(to: closeButton.edge.right).marginLeft(6)
      }
    }
    else {
      closeButton.pin.vCenter().right(6)
      replayToUserLabel.pin.top(8).left(8)
      
      switch message.type {
      case .photo, .video:
        fileTypeImage.pin.topLeft(to: replayToUserLabel.anchor.bottomLeft).marginTop(4)
        fileImage.pin.centerRight(to: closeButton.anchor.centerLeft).marginRight(6)
        messageBodyLabel.pin.centerLeft(to: fileTypeImage.anchor.centerRight).marginLeft(2).right(to: fileImage.edge.left).marginRight(4)
      case .audio, .contact, .document, .location:
        fileTypeImage.pin.topLeft(to: replayToUserLabel.anchor.bottomLeft).marginTop(4)
        fileImage.pin.centerRight(to: closeButton.anchor.centerLeft).marginRight(6)
        messageBodyLabel.pin.centerLeft(to: fileTypeImage.anchor.centerRight).marginLeft(2).right()
      default:
        messageBodyLabel.pin.topLeft(to:  replayToUserLabel.anchor.bottomLeft).marginTop(4).right(to: closeButton.edge.left).marginRight(6)
      }
    }
    

  }
  
  func set(message: Message, contact: BBContact?) {
    self.message = message
    self.contact = contact
  }
  
}



