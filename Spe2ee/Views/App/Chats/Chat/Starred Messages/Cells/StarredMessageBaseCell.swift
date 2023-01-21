import UIKit
import PinLayout
import AudioToolbox
import Combine


class StarredMessageBaseCell: MessageDefaultCell {
  
  // MARK: - Vars and UI Elements Declarations
  private enum AnimationState {
    case edit
    case normal
  }
  private var animationState = AnimationState.normal
  private var isAnimating = false
  
  // Content right margin from Superview
  public static let bubbleContentMargin: CGFloat = 18
  public static let bodyToDateMargin: CGFloat = 30
  private let replyViewHeight: CGFloat = 60.0
  
  open weak var delegate: MessageCellDelegate?
  
  //  private var swipedX: CGFloat = .zero
  
  private var hasVibratedOnReplySwipe = false
  private var reply = false
  private var lastSwipeXPosition: CGFloat = .zero
  
  
  // MARK: - View Model
  override var viewModel: MessageViewModel! {
    didSet {
      
      if AppUtility.isArabic {
        bubbleView.bubbleType = .incomingLastArabic
      } else {
        bubbleView.bubbleType = .incomingLast
      }
      
      if viewModel.isSent {
        bubbleView.setColor(color: Constants.OutgoingBubbleColor)
        receiptImage.isHidden = viewModel.message.type == .deleted
        
        switch viewModel.message.checkmarkType {
        case .read:
          receiptImage.image = UIImage(named: "receipt_read")
        case .received:
          receiptImage.image = UIImage(named: "receipt_received")
        case .sent:
          receiptImage.image = UIImage(named: "receipt_sent")
        case .unSent:
          receiptImage.image = UIImage(named: "unsent")
        case .none:
          break
        }
        
        if let imagePath = Blackbox.shared.account.profilePhotoPath, let image = UIImage.fromPath(imagePath) {
          contactProfileImage.image = image
        } else {
          contactProfileImage.image = UIImage(named: "avatar_profile")
        }
        
        if let group = viewModel.group {
          senderNameLabel.text = "\("You".localized()) @ \(group.description)"
        } else {
          senderNameLabel.text = "You".localized()
        }
        
      } else {
        bubbleView.setColor(color: Constants.IncomingBubbleColor)
        receiptImage.isHidden = true
        
        if let imagePath = viewModel.contact.profilePhotoPath, let image = UIImage.fromPath(imagePath) {
          contactProfileImage.image = image
        } else {
          contactProfileImage.image = UIImage(named: "avatar_profile")
        }
        
        if let group = viewModel.group {
          senderNameLabel.text = "\(viewModel.contact.getName()) @ \(group.description)"
        } else {
          senderNameLabel.text = viewModel.contact.getName()
        }
      }
      
      if self.viewModel.message.isForwarded {
        messageRootContainer.addSubview(forwardedView)
      }
      
      if viewModel.isReply {
        var contactName = "You".localized()
        if !self.viewModel.isSent {
          contactName = !self.viewModel.contact.name.isEmpty ? self.viewModel.contact.name : self.viewModel.contact.registeredNumber
        }
        replyView = MessageCellReplyView(msgID: self.viewModel.repliedMessageID,
                                         contactName: contactName,
                                         body: self.viewModel.repliedMessageBody,
                                         type: self.viewModel.repliedMessageType,
                                         contactColor: self.viewModel.contactColor)
        replyView!.delegate = self
        messageRootContainer.addSubview(replyView!)
      }
      
      if viewModel.message.isAlertMessage {
        if viewModel.message.type == .alertCopy {
          bubbleView.alertType = .copy
        } else if viewModel.message.type == .alertForward {
          bubbleView.alertType = .forward
        }
        
        var contactName = "You".localized()
        if let alertMsgSenderRef = self.viewModel.message.alertMsgSenderRef, alertMsgSenderRef != Blackbox.shared.account.registeredNumber {
          contactName = self.viewModel.contact.name.isEmpty == false ? self.viewModel.contact.name : self.viewModel.contact.registeredNumber
        }
        
        replyView = MessageCellReplyView(msgID: self.viewModel.message.alertMsgIdRef ?? "",
                                         contactName: contactName,
                                         body: self.viewModel.message.alertMsgContentRef ?? "",
                                         type: self.viewModel.message.alertMsgTypeRef ?? .text,
                                         contactColor: self.viewModel.contactColor,
                                         isEventAlert: true)
        replyView!.delegate = self
        messageRootContainer.addSubview(replyView!)
      }
      
      dateLabel.font = UIFont.appFont(ofSize: 13, textStyle: .footnote)
      dateLabel.text = viewModel.messageSentTime
      dateLabel.textColor = viewModel.message.containAttachment ? .white : .systemGray2
      dateLabel.sizeToFit()
      
      secondDateLabel.text = viewModel.message.dateSent.dateString(ofStyle: .short)
      secondDateLabel.sizeToFit()
      
      
      switch viewModel.message.type {
      case .deleted, .alertCopy, .alertForward:
        return animationState = .normal
      default:
        break
      }
      
      viewModel.$alpha
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] (value) in
          guard let strongSelf = self else { return }
          strongSelf.contentView.alpha = value
        }).store(in: &cancellableBag)
      
      viewModel.$isEditing
        .receive(on: DispatchQueue.main)
        .filter({ [weak self] (value) -> Bool in
          guard let strongSelf = self else { return false }
          
          if value.forward == false && value.delete == false {
            // If the user stopped editing, we proceed to reset the cells.
            return true
          }
          // If the user is editing, we allow him to delete only a specific Type of messages.
          switch strongSelf.viewModel.message.type {
          case .deleted, .alertCopy, .alertForward:
            return false
          default:
            return true
          }
        })
        .sink(receiveValue: { [weak self] (value) in
          guard let strongSelf = self else { return }
          
          if value.forward || value.delete && strongSelf.animationState == .edit {
            strongSelf.setNeedsLayout()
            strongSelf.layoutIfNeeded()
            return
          }
          
          if value.forward == false && value.delete == false && strongSelf.animationState == .normal {
            strongSelf.setNeedsLayout()
            strongSelf.layoutIfNeeded()
            return
          }
          
          UIView.animate(withDuration: 0.3, animations: {
            if value.forward || value.delete {
              strongSelf.animationState = .edit
            }  else {
              strongSelf.animationState = .normal
              strongSelf.selectedCheckmark.image = UIImage(named: "empty_check")
            }
            strongSelf.isAnimating = true
            strongSelf.setNeedsLayout()
            strongSelf.layoutIfNeeded()
          }, completion: { (_) in
            strongSelf.isAnimating = false
          })
        }).store(in: &cancellableBag)
      
      viewModel.$isSelected
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] (value) in
          guard let strongSelf = self else { return }
          strongSelf.selectedCheckmark.image = value ? UIImage(named: "full_check") : UIImage(named: "empty_check")
        }).store(in: &cancellableBag)
      
      viewModel.message.$checkmarkType
        .receive(on: DispatchQueue.main)
        .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
        .filter({ [weak self] (_) -> Bool in
          guard let strongSelf = self else { return false }
          return strongSelf.viewModel.isSent
        })
        .sink(receiveValue: { [weak self] (type) in
          guard let strongSelf = self else { return }
          switch type {
          case .read:
            strongSelf.receiptImage.image = UIImage(named: "receipt_read")
          case .received:
            strongSelf.receiptImage.image = UIImage(named: "receipt_received")
          case .sent:
            strongSelf.receiptImage.image = UIImage(named: "receipt_sent")
          case .unSent:
            strongSelf.receiptImage.image = UIImage(named: "unsent")
          case .none:
            break
          }
        }).store(in: &cancellableBag)
    }
  }
  
  // MARK: - UI Elements present in every cell
  /// Bubble View
  internal var messageRootContainer: UIView = {
    let view = UIView()
//    view.backgroundColor = .blue
    view.layer.masksToBounds = true
    view.clipsToBounds = false
    return view
  }()
  
  /// Content parent view
  var messageContentView: UIView = {
    let view = UIView()
    view.layer.masksToBounds = true
    view.clipsToBounds = false
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
    view.addGestureRecognizer(tapGestureRecognizer)
    
    return view
  }()
  
  /// Message Date
  var dateLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 13)
    label.textColor = .systemGray2
    return label
  }()
  
  /// Receipt image
  lazy var receiptImage: UIImageView = {
    let image = UIImageView(image: UIImage(named: "receipt_sent"))
    image.contentMode = .scaleAspectFit
    image.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
    image.isHidden = true
    return image
  }()
  
  /// Sender profile icon
  var contactProfileImage: UIImageView = {
    let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
    image.contentMode = .scaleAspectFill
    image.cornerRadius = 14
    return image
  }()
  
  /// Sender Name label used in group chats
  var senderNameLabel: PaddingLabel = {
    let label = PaddingLabel()
    label.font = UIFont.appFontSemiBold(ofSize: 14)
    label.text = "A"
    label.sizeToFit()
    label.text = ""
    label.leftInset = 4
    return label
  }()
  
  /// Message Date
  var secondDateLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 15)
    label.text = "A"
    label.sizeToFit()
    label.text = ""
    label.textColor = .systemGray
    return label
  }()
  
  private lazy var forwardedView: ForwardedView = {
    let view = ForwardedView()
    return view
  }()
  
  lazy var bubbleView: BubbleView = {
    let bubbleView = BubbleView()
    return bubbleView
  }()
  
  /// Selected Chckmark
  private lazy var selectedCheckmark: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: "empty_check"))
    imageView.pin.sizeToFit()
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private var disclosureIndicatorImageView: UIImageView = {
    var image = UIImage(systemName: "chevron.right")
    if AppUtility.isArabic {
      image = image?.imageFlippedForRightToLeftLayoutDirection()
    }
    let imageView = UIImageView(image: image)
    imageView.frame = CGRect(x: 0, y: 0, width: 15, height: 15)
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .systemGray
    return imageView
  }()
  
  /// Reply view
  private var replyView: MessageCellReplyView?
  
  // MARK: - Initializers
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
}

// MARK: - Cell Setup and Lifecyle
extension StarredMessageBaseCell {
  
  private func setupCell() {
    selectionStyle = .none
    separatorInset.left = 60
    
    contentView.addSubview(messageRootContainer)
    contentView.addSubview(selectedCheckmark)
    contentView.addSubview(senderNameLabel)
    contentView.addSubview(contactProfileImage)
    contentView.addSubview(secondDateLabel)
    contentView.addSubview(disclosureIndicatorImageView)
    
    messageRootContainer.addSubview(bubbleView)
    messageRootContainer.addSubview(messageContentView)
    messageContentView.addSubview(dateLabel)
    messageContentView.addSubview(receiptImage)
    
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellableBag.cancellAndRemoveAll()
    
    dateLabel.text = ""
    bubbleView.alertType = .none
    receiptImage.image = nil

    if replyView != nil {
      replyView!.removeFromSuperview()
    }
    
    forwardedView.removeFromSuperview()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    layer.backgroundColor = UIColor.clear.cgColor
    backgroundColor = .clear
    
    guard let orientation = screenOrientation else { return }
    
    // Default Cell layout
    if viewModel.alpha != 1 {
      viewModel.alpha = 1
    }
    
    switch animationState {
    case .normal:
      selectedCheckmark.alpha = 0
      if AppUtility.isArabic {
        selectedCheckmark.pin.vCenter().right(-selectedCheckmark.frame.size.width)
      } else {
        selectedCheckmark.pin.vCenter().left(-selectedCheckmark.frame.size.width)
      }
      break
    case .edit:
      selectedCheckmark.alpha = 1
      if AppUtility.isArabic {
        selectedCheckmark.pin.vCenter().right(selectedCheckmark.frame.size.width)
      } else {
        selectedCheckmark.pin.vCenter().left(selectedCheckmark.frame.size.width)
      }
      break
    }
    
    secondDateLabel.sizeToFit()
    
    if AppUtility.isArabic {
      contactProfileImage.pin.top(10).left(of: selectedCheckmark).marginRight(10)
      secondDateLabel.pin.vCenter(to: contactProfileImage.edge.vCenter).left(15)
      senderNameLabel.pin.centerRight(to: contactProfileImage.anchor.centerLeft).marginRight(6).centerLeft(to: secondDateLabel.anchor.centerRight).marginRight(6)
      messageRootContainer.pin.below(of: senderNameLabel, aligned: .right).marginRight(-9).marginTop(12).height(height-60)
    } else {
      contactProfileImage.pin.top(10).right(of: selectedCheckmark).marginLeft(10)
      secondDateLabel.pin.vCenter(to: contactProfileImage.edge.vCenter).right(15)
      senderNameLabel.pin.centerLeft(to: contactProfileImage.anchor.centerRight).marginLeft(6).centerRight(to: secondDateLabel.anchor.centerLeft).marginRight(6)
      messageRootContainer.pin.below(of: senderNameLabel, aligned: .left).marginLeft(-9).marginTop(12).height(height-60)
    }
    
    if viewModel.message.containAttachment {
      // Fixed width and Height
      // Width is equale to 75% of Portrait screen
      messageRootContainer.pin
        .maxWidth(70%)
        .width(viewModel.bubbleSizePortrait.width)
    } else {
      messageRootContainer.pin
        .maxWidth(70%)
        .width(orientation.isPortrait ? viewModel.bubbleSizePortrait.width : viewModel.bubbleSizeLandscape.width)
    }
    
    bubbleView.pin.top(1).left(2).right(2).bottom(1.5)
    bubbleView.setNeedsDisplay()
    
    if AppUtility.isArabic {
      layoutMessageArabic()
    } else {
      layoutMessage()
    }
    
    dateLabel.bringSubviewToFront(messageContentView)
  }
  
  @objc func tapped(sender: UITapGestureRecognizer)
  {
    logi()
  }
  
}

// MARK: - Layout Functions
private extension StarredMessageBaseCell {
  
  func layoutMessage() {
    disclosureIndicatorImageView.pin.right(15).vCenter(to: bubbleView.edge.vCenter)
    
    if viewModel.message.isForwarded {
      forwardedView.pin.top(4.0).left(15).right(5) // This will add 18 height in total
      messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
    } else if viewModel.isReply || viewModel.message.isAlertMessage {
      replyView!.pin.top(4.0).left(15).right(5).height(replyViewHeight) // This will add 74 height in total
      messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
    } else {
      messageContentView.pin.top(4.0).left(15).bottom(6).right(5)
    }
    
    if viewModel.isSent {
      receiptImage.isHidden = false
      receiptImage.pin.right(3).bottom()
      dateLabel.pin.centerRight(to: receiptImage.anchor.centerLeft).marginHorizontal(4)
    } else {
      receiptImage.isHidden = true
      dateLabel.pin.right(3).bottom()
    }
  }
  
  func layoutMessageArabic() {
    disclosureIndicatorImageView.pin.left(15).vCenter(to: bubbleView.edge.vCenter)
    
    if viewModel.message.isForwarded {
      forwardedView.pin.top(4.0).left(4.5).right(15) // This will add 18 height in total
      messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
    } else if viewModel.isReply || viewModel.message.isAlertMessage {
      replyView!.pin.top(4.0).left(4.5).right(15).height(replyViewHeight) // This will add 74 height in total
      messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
    } else {
      messageContentView.pin.top(4.0).left(5).bottom(6).right(16)
    }
    
    if viewModel.isSent {
      receiptImage.isHidden = false
      receiptImage.pin.left(5).bottom()
      dateLabel.pin.centerLeft(to: receiptImage.anchor.centerRight).marginLeft(4)
    } else {
      receiptImage.isHidden = true
      dateLabel.pin.left(5).bottom()
    }
  }
  
}

// MARK: - Public Functions
extension StarredMessageBaseCell {
  
  internal func bubbleBlinkAnimation() {
    bubbleView.blink()
  }
  
}

// MARK: - Reply View Delegate
extension StarredMessageBaseCell: MessageCellReplyViewDelegate {
  func didTapReplyView(messageID: String) {
    guard let delegate = self.delegate else { return }
    delegate.didTapReply(messageID: messageID)
  }
}

// MARK: - Static functions
extension StarredMessageBaseCell {
  static func calculateBubbleSize(viewModel: MessageViewModel, maxWidth: CGFloat) -> CGSize {
    
    // default for starred message
    var cellHeight: CGFloat = 60.0
    var cellWidth: CGFloat = .zero
    
    /// Simulate the real cell and return the size
    var maxBubbleWidth = maxWidth
    if viewModel.message.containAttachment {
      maxBubbleWidth = maxWidth * 0.70
    } else {
      maxBubbleWidth = maxWidth * 0.70
    }
    let maxContentWidth = maxBubbleWidth - bubbleContentMargin - 8 // 8 = left margin from superview
    
    // Message date + Message receipt icon + star icon
    var bottomInfosSize = viewModel.messageSentTime.size(usingFont: UIFont.appFont(ofSize: 13, textStyle: .footnote))
    if viewModel.isSent {
      // Add the Receipt Image width of 16 plus 4 margin
      bottomInfosSize.width += 20 // add the Receipt Image width of 16 plus 4 margin
    }
    // Add space for the star icon used for starred messages
    bottomInfosSize.width += bottomInfosSize.height / 1.5
    
    // Add the space required for the Sender Name Label
    if viewModel.message.isGroupChat, viewModel.isSent == false {
      cellHeight += 20
    }
    
    // Add the "Forwarded" label height
    if viewModel.message.isForwarded {
      let forwardSize = "Forwarded".size(usingFont: UIFont.appFontItalic(ofSize: 13, textStyle: .footnote))
      cellHeight += forwardSize.height
    }
    // Add the "Reply" View height, that is used for Reply messages and for system alert of type copy and forward
    if viewModel.isReply || viewModel.message.type == .alertCopy || viewModel.message.type == .alertForward {
      cellHeight += 64
    }
    
    switch viewModel.message.type {
    case .photo, .video:
      cellWidth = maxBubbleWidth
      // Get the file
      // TODO: Check image size form real file
      if let image = UIImage(named: "portrait_photo") {
        cellHeight += image.size.width > image.size.height ? 170  : 320
      }
      if viewModel.message.body.isEmpty == false {
        cellHeight += 20
        cellHeight += getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth).height
        cellHeight += bottomInfosSize.height
        
        viewModel.isBodyAboveDate = true
      }
    case .location:
      cellWidth = maxBubbleWidth
      cellHeight += 180
    case .document(_):
      cellWidth = maxBubbleWidth
      cellHeight += 90
    case .audio:
      cellWidth = maxBubbleWidth
      cellHeight += 68
    default:
      if viewModel.message.type == .text || viewModel.message.isAlertMessage || viewModel.message.type == .deleted {
        
        // Messsage Body
        var bodySize: CGSize = .zero
        if viewModel.message.isAlertMessage {
          let fontSize: CGFloat = viewModel.message.type == .alertScreenshot || viewModel.message.type == .alertScreenRecording ? 15.0 : 17.0
          bodySize = getBodyLabelSize(text: viewModel.message.alertMsg ?? "", maxWidth: maxContentWidth, fontSize: fontSize)
        }
        else {
          bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth)
        }
        
        cellHeight += 14 // Some margins
        cellHeight += bodySize.height
        cellHeight += viewModel.message.isAlertMessage ? 4 : 0
        cellHeight += bottomInfosSize.height
        viewModel.isBodyAboveDate = true
        
        if bodySize.width > maxContentWidth || viewModel.message.containAttachment {
          cellWidth = maxBubbleWidth
        }
        else {
          let width = bottomInfosSize.width + bubbleContentMargin + bodyToDateMargin
          cellWidth += bodySize.width + bubbleContentMargin < width ? width : bodySize.width + bubbleContentMargin
          cellWidth += 16
          
          // Check if the width is less then the sender name width for group chat and in that case use the sender name width+25
          if viewModel.message.isGroupChat, viewModel.isSent == false {
            let font = UIFont.appFontSemiBold(ofSize: 14)
            let fontAttributes = [NSAttributedString.Key.font: font]
            let size = (viewModel.contact.getName() as NSString).size(withAttributes: fontAttributes as [NSAttributedString.Key : Any])
            let senderNameWidth = size.width + bubbleContentMargin
            
            cellWidth = cellWidth < senderNameWidth ? senderNameWidth + 25 : cellWidth
          }
          
          // check if the width is less then the "Forwarded" width and in that case use the "Forwarded" word width+60
          if viewModel.message.isForwarded {
            let forwardSize = "Forwarded".size(usingFont: UIFont.appFontItalic(ofSize: 13, textStyle: .footnote))
            if cellWidth < forwardSize.width + 60 {
              cellWidth = forwardSize.width + 60
            }
          }
        }
      }
    }
    
    return CGSize(width: cellWidth, height: cellHeight)
  }
  
  fileprivate static func getBodyLabelSize(text: String, maxWidth: CGFloat, fontSize: CGFloat = 17) -> CGSize {
    let label = UILabel()
    label.backgroundColor = .clear
    label.numberOfLines = 0
    label.attributedText = text.getAttributedText(fontSize: text.isSingleEmoji ? 55 : fontSize)
    var size = label.sizeThatFits(CGSize(width: maxWidth-1, height: .infinity))
    size.width -= text.isSingleEmoji ? 16 : 0
    return size
  }
}


private class ForwardedView: UIView {
  
  private let arrowImage: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 5, y: 0, width: 10, height: 10))
    imageView.contentMode = .scaleAspectFill
    imageView.tintColor = .systemGray3
    imageView.image = UIImage(systemName: "arrowshape.turn.up.right.fill", withConfiguration: UIImage.SymbolConfiguration(weight: UIImage.SymbolWeight.light))
    return imageView
  }()
  
  private let label: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontItalic(ofSize: 13, textStyle: .footnote)
    label.text = "Forwarded".localized()
    label.textColor = .systemGray
    label.sizeToFit()
    return label
  }()
  
  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 17))
    addSubview(arrowImage)
    addSubview(label)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    arrowImage.pin.vCenter()
    label.pin.centerLeft(to: arrowImage.anchor.centerRight).marginLeft(4)
  }
}
