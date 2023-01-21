import UIKit
import PinLayout
import AudioToolbox
import Combine


protocol MessageCellDelegate: class {
    func didSwipeToShowMessageInfo(otherCellsAlpha: CGFloat, indexPath: IndexPath)
    func didEndSwipeToShowMessageInfo(messageViewModel: MessageViewModel, indexPath: IndexPath)
    func swipeStarted(indexPath: IndexPath)
    func swipeEnded(indexPath: IndexPath)
    func shouldSwipe(indexPath: IndexPath) -> Bool
    func didSwipeToReply(at indexPath: IndexPath)
    func didTapReply(messageID: String)
}

extension MessageCellDelegate {
    func swipeStarted(indexPath: IndexPath) {}
    func swipeEnded(indexPath: IndexPath) {}
    func didSwipeToReply(at indexPath: IndexPath) {}
}

/// Base UITableView cell
class MessageBaseCell: MessageDefaultCell {
    
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
//    private let replyViewHeight: CGFloat = 60.0
    private var replyViewSize: CGSize {
        guard let tableView = tableView else {
            return .zero
        }
        return MessageCellReplyView.getSize(
            with: tableView.width * 0.75,
            body: viewModel.isReply ?
                viewModel.repliedMessageBody : viewModel.message.alertMsgContentRef ?? "",
            messageType: viewModel.isReply ? viewModel.repliedMessageType : viewModel.message.alertMsgTypeRef ?? .text
        )
    }
    
    open weak var delegate: MessageCellDelegate?
    open var pan: UIPanGestureRecognizer!
    //  private var swipedX: CGFloat = .zero
    
    private var hasVibratedOnReplySwipe = false
    private var reply = false
    private var lastSwipeXPosition: CGFloat = .zero
    
    // MARK: - View Model
    override var viewModel: MessageViewModel! {
        didSet {
            
            if viewModel.showDownloadButton {
                viewModel.message.fileTransferState = 0
            }
            
            if viewModel.isSent {
                receiptImage.isHidden = viewModel.message.type == .deleted
                if viewModel.nextMessageSender != viewModel.message.sender {
                    bubbleView.bubbleType = AppUtility.isArabic ? .outgoingLastArabic : .outgoingLast
                }
                else {
                    bubbleView.bubbleType = AppUtility.isArabic ? .outgoingArabic : .outgoing
                }
                
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
                
            }
            else {
                receiptImage.isHidden = true
                if viewModel.nextMessageSender != viewModel.message.sender {
                    bubbleView.bubbleType = AppUtility.isArabic ? .incomingLastArabic : .incomingLast
                } else {
                    bubbleView.bubbleType = AppUtility.isArabic ? .incomingArabic : .incoming
                }
                
                if viewModel.isRead == false {
                    if let group = viewModel.group {
                        group.sendAllReadReceiptAsync()
                    } else {
                        viewModel.contact.sendAllReadReceiptAsync()
                    }
                }
                
            }
            
            if self.viewModel.message.isForwarded {
                messageRootContainer.addSubview(forwardedView)
            }
            
            if viewModel.isReply {
                var contactName = "You".localized()
                if self.viewModel.isSent == false {
                    contactName = !self.viewModel.contact.name.isEmpty ? self.viewModel.contact.name : self.viewModel.contact.registeredNumber
                }
                contactName = self.viewModel.repliedMessageContactName
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
            if viewModel.message.isAlertMessage {
                dateLabel.textColor = .white
            } else {
                dateLabel.textColor = viewModel.message.containAttachment ? .white : .systemGray2
            }
            dateLabel.sizeToFit()
            
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
                    
                    var image: UIImage?
                    switch type {
                    case .read:
                        image = UIImage(named: "receipt_read")
                    case .received:
                        image = UIImage(named: "receipt_received")
                    case .sent:
                        image = UIImage(named: "receipt_sent")
                    case .unSent:
                        image = UIImage(named: "unsent")
                    case .none:
                        break
                    }
                    
                    if strongSelf.viewModel.isRead == false {
                        strongSelf.receiptImage.image = image?.withRenderingMode(.alwaysTemplate)
                        strongSelf.receiptImage.tintColor = strongSelf.dateLabel.textColor
                    } else {
                        strongSelf.receiptImage.image = image?.withRenderingMode(.alwaysOriginal)
                    }
                    
                }).store(in: &cancellableBag)
            
            viewModel.$nextMessageSender
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] (nextSender) in
                    guard let strongSelf = self else { return }
                    if strongSelf.viewModel.isSent {
                        if nextSender != strongSelf.viewModel.message.sender {
                            strongSelf.bubbleView.bubbleType = AppUtility.isArabic ? .outgoingLastArabic : .outgoingLast
                        } else if strongSelf.bubbleView.bubbleType != .outgoing  {
                            strongSelf.bubbleView.bubbleType = AppUtility.isArabic ? .outgoingArabic : .outgoing
                        }
                    } else {
                        if nextSender != strongSelf.viewModel.message.sender {
                            strongSelf.bubbleView.bubbleType = AppUtility.isArabic ? .incomingLastArabic : .incomingLast
                        } else if strongSelf.bubbleView.bubbleType != .incoming {
                            strongSelf.bubbleView.bubbleType = AppUtility.isArabic ? .incomingArabic : .incoming
                        }
                    }
                    strongSelf.bubbleView.setNeedsDisplay()
                }).store(in: &cancellableBag)
            
            viewModel.message.$isStarred
                .receive(on: DispatchQueue.main)
                .sink { [weak self] (isStarred) in
                    guard let strongSelf = self else { return }
                    strongSelf.starredImageView.isHidden = !isStarred
                }.store(in: &cancellableBag)
            
            
            viewModel.message.$autoDelete.receive(on: DispatchQueue.main).sink { [weak self] (value) in
                guard let strongSelf = self else { return }
                strongSelf.autoDeleteTimerImageView.isHidden = !value
            }.store(in: &cancellableBag)
            
        }
    }
    
    // MARK: - UI Elements present in every cell
    /// Bubble View
    internal var messageRootContainer: UIView = {
        let view = UIView()
        //view.backgroundColor = .clear
        view.layer.masksToBounds = true
        view.clipsToBounds = false
        return view
    }()
    private var messageTopSpace: CGFloat {
        return viewModel.previousMessageSender == viewModel.message.sender ? 4.0 : 14
    }
    
    /// Content parent view
    internal var messageContentView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.clipsToBounds = false
        return view
    }()
    
    private var starredImageView: UIImageView = {
        let image = UIImageView(image: UIImage(systemName: "star.fill"))
        image.contentMode = .scaleAspectFit
        image.frame = CGRect(x: 0, y: 0, width: 13, height: 13)
        image.tintColor = .systemGray2
        image.isHidden = true
        return image
    }()
    
    private var autoDeleteTimerImageView: UIImageView = {
        let image = UIImageView(image: UIImage(named: "quick_timer"))
        image.contentMode = .scaleAspectFit
        image.frame = CGRect(x: 0, y: 0, width: 13, height: 13)
        image.tintColor = .systemGray2
        image.isHidden = true
        return image
    }()
    
    /// Message Date
    internal var dateLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.font = UIFont.appFont(ofSize: 13)
        label.textColor = .systemGray2
        label.topInset = 0
        label.bottomInset = 0
        label.rightInset = 0
        label.leftInset = 0
        return label
    }()
    
    /// Receipt image
    internal lazy var receiptImage: UIImageView = {
        let image = UIImageView(image: UIImage(named: "receipt_sent"))
        image.contentMode = .scaleAspectFit
        image.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        image.isHidden = true
        return image
    }()
    
    /// Reply Button
    internal lazy var replyButton: RoundedButton = {
        let btn = RoundedButton(type: .system)
        btn.setImage(UIImage(systemName: "arrowshape.turn.up.left.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .small)), for: .normal)
        //btn.imageEdgeInsets = UIEdgeInsets(top: 6, left: 9, bottom: 6, right: 6)
        btn.tintColor = .white
        btn.backgroundColor = .brown
        btn.alpha = 1
        btn.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        btn.isCircle = true
        return btn
    }()
    
    /// Sender Name label used in group chats
    internal lazy var senderNameTextView: PaddingLabel = {
        let label = PaddingLabel()
        label.font = UIFont.appFontSemiBold(ofSize: 14)
        label.leftInset = 4
        return label
    }()
    
    private lazy var forwardedView: ForwardedView = {
        let view = ForwardedView()
        return view
    }()
    
    var bubbleView: BubbleView = {
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
extension MessageBaseCell {
    
    private func setupCell() {
        selectionStyle = .none
        
        contentView.addSubview(messageRootContainer)
        contentView.addSubview(replyButton)
        contentView.addSubview(selectedCheckmark)
        messageRootContainer.addSubview(bubbleView)
        messageRootContainer.addSubview(messageContentView)
        messageContentView.addSubview(dateLabel)
        messageContentView.addSubview(receiptImage)
        messageContentView.addSubview(starredImageView)
        messageContentView.addSubview(autoDeleteTimerImageView)
        
        pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        cancellableBag.cancellAndRemoveAll()
        
        dateLabel.text = ""
        bubbleView.alertType = .none
        receiptImage.image = nil
        
        senderNameTextView.removeFromSuperview()
        if replyView != nil {
            replyView!.removeFromSuperview()
        }
        
        forwardedView.removeFromSuperview()
        
        //    viewModel.stopRefreshFileTransferState()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.backgroundColor = UIColor.clear.cgColor
        backgroundColor = .clear
        
        guard let orientation = screenOrientation else { return }
        
        if pan.state == .ended || pan.state == .possible {
            // Default Cell layout
            if viewModel.alpha != 1 {
                viewModel.alpha = 1
            }
            
            switch animationState {
            case .normal:
                selectedCheckmark.alpha = 0
                selectedCheckmark.pin.vCenter().left(-selectedCheckmark.frame.size.width)
                break
            case .edit:
                selectedCheckmark.alpha = 1
                selectedCheckmark.pin.vCenter().left(selectedCheckmark.frame.size.width)
                break
            }
            
            if AppUtility.isArabic {
                replyButton.pin.vCenter().right()
            } else {
                replyButton.pin.vCenter().left()
            }
            replyButton.alpha = 0
            
            messageRootContainer.pin.top().bottom()
            
            if viewModel.message.containAttachment {
                // Fixed width and Height
                // Width is equale to 75% of Portrait screen
                messageRootContainer.pin
                    .maxWidth(80%)
                    .width(viewModel.bubbleSizePortrait.width)
            } else {
                messageRootContainer.pin
                    .maxWidth(75%)
                    .width(orientation.isPortrait ? viewModel.bubbleSizePortrait.width : viewModel.bubbleSizeLandscape.width)
            }
            
            if viewModel.previousMessageSender != viewModel.message.sender {
                bubbleView.pin.top(10).left(2).right(2).bottom(1.5)
            } else {
                bubbleView.pin.top(1).left(2).right(2).bottom(1.5)
            }
            
            bubbleView.setNeedsDisplay()
            
            if viewModel.isSent {
                if AppUtility.isArabic {
                    layoutOutgoingMessageArabic()
                } else {
                    layoutOutgoingMessage()
                }
            } else {
                if AppUtility.isArabic {
                    layoutIncomingMessageArabic()
                } else {
                    layoutIncomingMessage()
                }
            }
            
        }
        else if pan.state == .changed {
            let p: CGPoint = pan.translation(in: self)
            let x = p.x
            
            if AppUtility.isArabic {
                // Swipe right ?
                if x > 0 {
                    // Swipe left (Show message Info: Allowed only for sent messages)
                    if x >= 55 {
                        messageRootContainer.pin.left(55)
                    } else {
                        hasVibratedOnReplySwipe = false
                        replyButton.alpha = x / 70
                        replyButton.pin.right(-x)
                        messageRootContainer.pin.left(x)
                    }
                    
                }
                else {
                    if x <= -70 {
                        
                        if !hasVibratedOnReplySwipe {
                            reply = true
                            hasVibratedOnReplySwipe = true
                            Vibration.light.vibrate()
                        }
                        
                        replyButton.alpha = 1
                        // This value will create an elastic effect when overswiping the cell
                        let horizontalLimit = 70 * (1 + log(-x/70))
                        
                        if viewModel.isSent {
                            messageRootContainer.pin.left(-horizontalLimit+15)
                        } else {
                            messageRootContainer.pin.right(horizontalLimit)
                        }
                    }
                    else {
                        hasVibratedOnReplySwipe = false
                        
                        if viewModel.isSent {
                            replyButton.alpha = -x / 70
                            replyButton.pin.right(-x)
                            messageRootContainer.pin.left(x+15)
                        } else {
                            // Show the reply button after 35 pixel translation
                            if x <= -35 {
                                replyButton.alpha = (-x-35) / 35
                                replyButton.pin.right(-x-35)
                            }
                            messageRootContainer.pin.right(-x)
                        }
                    }
                }
            }
            else {
                // Swipe right ?
                if x > 0 {
                    if x >= 70 {
                        
                        if !hasVibratedOnReplySwipe {
                            reply = true
                            hasVibratedOnReplySwipe = true
                            Vibration.light.vibrate()
                        }
                        
                        replyButton.alpha = 1
                        // This value will create an elastic effect when overswiping the cell
                        let horizontalLimit = 70 * (1 + log(x/70))
                        
                        if viewModel.isSent {
                            messageRootContainer.pin.right(-horizontalLimit+16)
                        } else {
                            messageRootContainer.pin.left(horizontalLimit)
                        }
                    }
                    else {
                        hasVibratedOnReplySwipe = false
                        
                        if viewModel.isSent {
                            replyButton.alpha = x / 70
                            replyButton.pin.left(x)
                            messageRootContainer.pin.right(-x+16)
                        } else {
                            // Show the reply button after 35 pixel translation
                            if x >= 35 {
                                replyButton.alpha = (x-35) / 35
                                replyButton.pin.left(x-35)
                            }
                            messageRootContainer.pin.left(x)
                        }
                    }
                    
                }
                else {
                    // Swipe left (Show message Info: Allowed only for sent messages)
                    if x <= -55 {
                        messageRootContainer.pin.right(55)
                    } else {
                        hasVibratedOnReplySwipe = false
                        replyButton.alpha = x / 70
                        replyButton.pin.left(x)
                        messageRootContainer.pin.right(-x)
                    }
                }
            }
            
            
            
            lastSwipeXPosition = x
        }
        
        dateLabel.bringSubviewToFront(messageContentView)
        starredImageView.bringSubviewToFront(messageContentView)
        starredImageView.tintColor = dateLabel.textColor
    }
    
    @objc func onPan(_ pan: UIPanGestureRecognizer) {
        
        guard let table = tableView, !table.isDragging else { return }
        guard let delegate = self.delegate else { return }
        guard let indexPath = self.indexPath else { return }
        
        table.isScrollEnabled = true
        switch pan.state {
        case .began:
            delegate.swipeStarted(indexPath: indexPath)
        case .changed:
            if !delegate.shouldSwipe(indexPath: indexPath) {
                return
            }
            let p: CGPoint = pan.translation(in: self)
            
            // Wait for 8 pixel movement beofre updating the swipe movement
            if -8 ... 8 ~= p.x {
                return
            }
            
            if AppUtility.isArabic {
                // Right Swipe allowed only for sent messages
                if p.x > 0, !viewModel.isSent {
                    return
                }
            } else {
                // Left Swipe allowed only for sent messages
                if p.x < 0, !viewModel.isSent {
                    return
                }
            }
            
            table.isScrollEnabled = false
            
            self.setNeedsLayout()
            
            if viewModel.isSent {
                if AppUtility.isArabic {
                    // fire on right swipe
                    if p.x > 0, p.x <= 55 {
                        delegate.didSwipeToShowMessageInfo(otherCellsAlpha: 1 - (-p.x/80), indexPath: indexPath)
                    }
                } else {
                    // fire on left swipe
                    if p.x < 0, p.x >= -55 {
                        delegate.didSwipeToShowMessageInfo(otherCellsAlpha: 1 - (-p.x/80), indexPath: indexPath)
                    }
                }
            }
            
        case .ended:
            let p: CGPoint = pan.translation(in: self)
            
            if viewModel.isSent {
                if AppUtility.isArabic {
                    if p.x >= 55 {
                        delegate.didEndSwipeToShowMessageInfo(messageViewModel: viewModel, indexPath: indexPath)
                    }
                } else {
                    if p.x <= -55 {
                        delegate.didEndSwipeToShowMessageInfo(messageViewModel: viewModel, indexPath: indexPath)
                    }
                }
            }
            
            if AppUtility.isArabic {
                if p.x < -70 {
                    delegate.didSwipeToReply(at: indexPath)
                }
            } else {
                if p.x > 70 {
                    delegate.didSwipeToReply(at: indexPath)
                }
            }
            
            // restore the cells to initial state
            UIView.animate(withDuration: 0.4, animations: {
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }) { (Bool) in
                delegate.swipeEnded(indexPath: indexPath)
                table.isScrollEnabled = true
            }
            
        default:
            break
        }
    }
    
}

// MARK: - Layout Functions
private extension MessageBaseCell {
    
    func layoutOutgoingMessage() {
        messageRootContainer.pin.right(8)
        
        if viewModel.message.isForwarded {
            forwardedView.pin.top(messageTopSpace).left(4.5).right(15) // This will add 18 height in total
            messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
        } else if viewModel.isReply || viewModel.message.isAlertMessage {
            replyView!.pin.top(messageTopSpace).left(4.5).right(15).height(replyViewSize.height) // This will add 74 height in total
            messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
        } else {
            messageContentView.pin.top(messageTopSpace).left(5).bottom(6).right(16)
        }
        
        if viewModel.message.isAlertMessage || viewModel.message.type == .deleted {
            receiptImage.isHidden = true
            dateLabel.pin.right(3).bottom()
        } else {
            receiptImage.pin.right(3).bottom().height(dateLabel.height).width(dateLabel.height)
            dateLabel.pin.centerRight(to: receiptImage.anchor.centerLeft).marginHorizontal(4)
        }
        
        let whSize = dateLabel.height - 4
        let starredIconSize = CGSize(width: whSize, height: whSize)
        starredImageView.pin.size(starredIconSize).centerRight(to: dateLabel.anchor.centerLeft).marginRight(3)
        
        autoDeleteTimerImageView.pin.height(dateLabel.height-3).width(dateLabel.height-3).vCenter(to: dateLabel.edge.vCenter).left(4)
    }
    
    func layoutIncomingMessage() {
        messageRootContainer.pin.centerLeft(to: selectedCheckmark.anchor.centerRight).marginLeft(4)
        
        if viewModel.message.isGroupChat {
            senderNameTextView.text = viewModel.contactName
            senderNameTextView.sizeToFit()
            messageRootContainer.addSubview(senderNameTextView)
            senderNameTextView.pin.top(messageTopSpace).left(15).right(5)
            senderNameTextView.textColor = self.viewModel.message.isAlertMessage ? .black : self.viewModel.contactColor
            
            if viewModel.message.isForwarded {
                forwardedView.pin.topLeft(to: senderNameTextView.anchor.bottomLeft).marginTop(4).right(5) // This will add 18 height in total
                messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
            } else if viewModel.isReply || viewModel.message.isAlertMessage {
                replyView!.pin.topLeft(to: senderNameTextView.anchor.bottomLeft).marginTop(4).right(5).height(replyViewSize.height) // This will add 74 height in total
                messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
            } else {
                messageContentView.pin.topLeft(to: senderNameTextView.anchor.bottomLeft).marginTop(2).bottom(6).right(5)
            }
        }
        else {
            if viewModel.message.isForwarded {
                forwardedView.pin.top(messageTopSpace).left(15).right(5) // This will add 18 height in total
                messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
            }
            else if viewModel.isReply || viewModel.message.isAlertMessage {
                replyView!.pin.top(messageTopSpace).left(15).right(5).height(replyViewSize.height) // This will add 74 height in total
                messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
            }
            else {
                messageContentView.pin.top(messageTopSpace).left(15).bottom(6).right(6)
            }
        }
        
        dateLabel.pin.right(5).bottom()
        let whSize = dateLabel.height - 4
        let starredIconSize = CGSize(width: whSize, height: whSize)
        starredImageView.pin.centerRight(to: dateLabel.anchor.centerLeft).marginRight(3).size(starredIconSize)
        
        autoDeleteTimerImageView.pin.height(dateLabel.height-3).width(dateLabel.height-3).vCenter(to: dateLabel.edge.vCenter).left(4)
    }
    
    func layoutOutgoingMessageArabic() {
        messageRootContainer.pin.centerLeft(to: selectedCheckmark.anchor.centerRight).marginLeft(4)
        
        if viewModel.message.isForwarded {
            forwardedView.pin.top(messageTopSpace).left(15).right(5) // This will add 18 height in total
            messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
        }
        else if viewModel.isReply || viewModel.message.isAlertMessage {
            replyView!.pin.top(messageTopSpace).left(15).right(5).height(replyViewSize.height) // This will add 74 height in total
            messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(5)
        }
        else {
            messageContentView.pin.top(messageTopSpace).left(15).bottom(6).right(6)
        }
        
        // In this case, this layout is used for Outgoing messages, so we must add the receipt image
        if viewModel.message.type == .deleted {
            dateLabel.pin.left(5).bottom()
        } else {
            receiptImage.pin.left(5).bottom().height(dateLabel.height).width(dateLabel.height)
            dateLabel.pin.centerLeft(to: receiptImage.anchor.centerRight).marginLeft(4)
        }
        
        let whSize = dateLabel.height - 4
        let starredIconSize = CGSize(width: whSize, height: whSize)
        starredImageView.pin.centerLeft(to: dateLabel.anchor.centerRight).marginLeft(3).size(starredIconSize)
        
        autoDeleteTimerImageView.pin.height(dateLabel.height-3).width(dateLabel.height-3).vCenter(to: dateLabel.edge.vCenter).right(4)
    }
    
    func layoutIncomingMessageArabic() {
        messageRootContainer.pin.right(8)
        
        if viewModel.message.isGroupChat {
            senderNameTextView.text = viewModel.contact.getName()
            senderNameTextView.sizeToFit()
            messageRootContainer.addSubview(senderNameTextView)
            senderNameTextView.pin.top(messageTopSpace).left(5).right(15)
            senderNameTextView.textColor = self.viewModel.message.isAlertMessage ? .black : self.viewModel.contactColor
            
            if viewModel.message.isForwarded {
                forwardedView.pin.topLeft(to: senderNameTextView.anchor.bottomLeft).marginTop(4).right(5) // This will add 18 height in total
                messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
            } else if viewModel.isReply || viewModel.message.isAlertMessage {
                replyView!.pin.topLeft(to: senderNameTextView.anchor.bottomLeft).marginTop(4).right(15).height(replyViewSize.height) // This will add 74 height in total
                messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
            } else {
                messageContentView.pin.topLeft(to: senderNameTextView.anchor.bottomLeft).marginTop(2).bottom(6).right(15)
            }
        }
        else {
            if viewModel.message.isForwarded {
                forwardedView.pin.top(messageTopSpace).left(5).right(15) // This will add 18 height in total
                messageContentView.pin.topLeft(to: forwardedView.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
            }
            else if viewModel.isReply || viewModel.message.isAlertMessage {
                replyView!.pin.top(messageTopSpace).left(5).right(15).height(replyViewSize.height) // This will add 74 height in total
                messageContentView.pin.topLeft(to: replyView!.anchor.bottomLeft).marginTop(4).bottom(6).right(15)
            }
            else {
                messageContentView.pin.top(messageTopSpace).left(5).bottom(6).right(15)
            }
        }
        
        receiptImage.isHidden = true
        if viewModel.message.isAlertMessage {
            dateLabel.pin.left(3).bottom()
        }
        else {
            dateLabel.pin.left(5).bottom()
        }
        
        let whSize = dateLabel.height - 4
        let starredIconSize = CGSize(width: whSize, height: whSize)
        starredImageView.pin.centerRight(to: dateLabel.anchor.centerLeft).marginRight(3).size(starredIconSize)
        
        autoDeleteTimerImageView.pin.height(dateLabel.height-3).width(dateLabel.height-3).vCenter(to: dateLabel.edge.vCenter).right(4)
    }
    
}

// MARK: - Public Functions
extension MessageBaseCell {
    
    internal func bubbleBlinkAnimation() {
        bubbleView.blinkCalc()
    }
    
}


// MARK: - UIGestureRecognizerDelegate
extension MessageBaseCell {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if viewModel.message.isAlertMessage || viewModel.message.type == .deleted || viewModel.isEditing.delete || viewModel.isEditing.forward {
            return false
        }
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            //let translation = panGestureRecognizer.translation(in: superview!)
            let translation = panGestureRecognizer.translation(in: superview)
            if abs(translation.x) > abs(translation.y) {
                return true
            }
            return false
        }
        return false
    }
}

// MARK: - Reply View Delegate
extension MessageBaseCell: MessageCellReplyViewDelegate {
    func didTapReplyView(messageID: String) {
        guard let delegate = self.delegate else { return }
        delegate.didTapReply(messageID: messageID)
    }
}

// MARK: - Static functions
extension MessageBaseCell {
    
    /// Calculate the required bubble size for the specific type
    /// - Parameters:
    ///   - viewModel: message view model
    ///   - maxWidth: the parent view width
    /// - Returns: the bubble size
    static func calculateBubbleSize(viewModel: MessageViewModel, maxWidth: CGFloat, isPortrait: Bool = true) -> CGSize {
        
        var cellHeight: CGFloat = .zero
        var cellWidth: CGFloat = .zero
        
        /// Simulate the real cell and return the size
        var maxBubbleWidth = maxWidth
        if viewModel.message.containAttachment {
            maxBubbleWidth = maxWidth * 0.80
        }
        else {
            maxBubbleWidth = maxWidth * 0.75
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
        
        // Add space to the TOP of the cell if the previous message was from a different user
        if viewModel.previousMessageSender != viewModel.message.sender && viewModel.message.type.isSystemMessage() == false {
            cellHeight += 10
        }
        
        // Add the "Forwarded" label height
        if viewModel.message.isForwarded {
            let forwardSize = "Forwarded".size(usingFont: UIFont.appFontItalic(ofSize: 13, textStyle: .footnote))
            cellHeight += forwardSize.height
        }
        
        // Add the "Reply" View height, that is used for Reply messages and for system alert of type copy and forward
//        if viewModel.isReply || viewModel.message.type == .alertCopy || viewModel.message.type == .alertForward {
//            cellHeight += 64
//        }
        
        let replyViewSize = getReplyViewSize(maxWidth: maxBubbleWidth, viewModel: viewModel)
        cellHeight += replyViewSize.height
        
        switch viewModel.message.type {
        case .photo, .video:
            cellWidth = maxBubbleWidth
            // Get the file
            cellHeight += isPortrait ? 320 : 170
            
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
            cellHeight += getBodyLabelSize(text: "A", maxWidth: maxBubbleWidth).height + 76
        //      cellHeight += 90
        case .audio:
            cellWidth = maxBubbleWidth
            cellHeight += 68
        case .alertScreenshot, .alertScreenRecording:
            // Messsage Body
            let bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth + 40, fontSize: 15)
            cellHeight += bodySize.height + 22
            cellWidth += bodySize.width + 40
        case .systemMessage(let type):
            switch type {
            case .autoDelete, .temporaryChat:
                let bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: (maxWidth * 0.80)-80, fontSize: 15.5, textAlignement: .center)
                cellHeight += bodySize.height + 20
                cellWidth += bodySize.width
            case .missedVideoCall, .missedCall:
                // Messsage Body
                var bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth + 40, fontSize: 15)
                cellHeight += bodySize.height + 22
                cellWidth += bodySize.width + 40
                
                bodySize = getBodyLabelSize(text: "A", maxWidth: maxContentWidth + 40, fontSize: 15)
                cellWidth += bodySize.width + 22
                
            default:
                // Messsage Body
                let bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth + 40, fontSize: 15)
                cellHeight += bodySize.height + 22
                cellWidth += bodySize.width + 40
            }
        default:
            if viewModel.message.type == .text || viewModel.message.isAlertMessage || viewModel.message.type == .deleted {
                
                // Messsage Body
                var bodySize: CGSize = .zero
                if viewModel.message.isAlertMessage {
                    let fontSize: CGFloat = viewModel.message.type == .alertScreenshot || viewModel.message.type == .alertScreenRecording ? 15.0 : 17.0
                    bodySize = getBodyLabelSize(text: viewModel.message.alertMsg ?? "", maxWidth: maxContentWidth, fontSize: fontSize)
                }
                else {
                    // specific format for deleted message
                    if viewModel.message.type == .deleted {
                        // remove the extra width added by the "Stop" icon
                        let dateSize = viewModel.messageSentTime.size(usingFont: UIFont.appFont(ofSize: 13, textStyle: .footnote))
                        let extraWidth = (dateSize.height * 1.1) + 12
                        cellWidth += extraWidth
                        bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth - extraWidth)
                    }
                    else {
                        bodySize = getBodyLabelSize(text: viewModel.message.body, maxWidth: maxContentWidth)
                    }
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
                        let size = (viewModel.contactName as NSString).size(withAttributes: fontAttributes as [NSAttributedString.Key : Any])
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
        
        cellWidth = cellWidth < replyViewSize.width ? replyViewSize.width : cellWidth
        
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    private static func getBodyLabelSize(text: String, maxWidth: CGFloat, fontSize: CGFloat = 17, textAlignement: NSTextAlignment = .left) -> CGSize {
        let label = UILabel()
        label.backgroundColor = .clear
        label.numberOfLines = 0
        label.attributedText = text.getAttributedText(fontSize: text.isSingleEmoji ? 55 : fontSize)
        label.textAlignment = textAlignement
        var size = label.sizeThatFits(CGSize(width: maxWidth-1, height: .infinity))
        size.width -= text.isSingleEmoji ? 15 : 0
        return size
    }
    
    private static func getReplyViewSize(maxWidth: CGFloat, viewModel: MessageViewModel) -> CGSize {
        return viewModel.isReply
            || viewModel.message.type == .alertCopy
            || viewModel.message.type == .alertForward ?
            MessageCellReplyView.getSize(
                with: maxWidth,
                body:
                    viewModel.isReply ? viewModel.repliedMessageBody : viewModel.message.alertMsgContentRef ?? "",
                messageType: viewModel.isReply ? viewModel.repliedMessageType : viewModel.message.alertMsgTypeRef ?? .text
            ) :
            .zero
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

