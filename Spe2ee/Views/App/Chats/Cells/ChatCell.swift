import UIKit
import PinLayout
import Combine
import SwipeCellKit

class ChatCell: SwipeTableViewCell {
  static let ID = "ChatCell"
  
  private enum AnimationState {
    case edit
    case normal
  }
  
  // Layout Values
  private let displayNameBottomSpace: CGFloat = 3.0
  private let HorizontalSpace = CGFloat(integerLiteral: 4)
  
  private lazy var unreadMessageBadge: BadgeSwift = {
    let badge = BadgeSwift()
    badge.font = UIFont.appFont(ofSize: 14)
    badge.textColor = .white
    badge.badgeColor = .link
    badge.isHidden = true
    return badge
  }()
  
  private var userImage: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: "avatar_profile.png")) // Default image
    imageView.frame = CGRect(origin: .zero, size: CGSize(width: 55, height: 55))
    imageView.layer.cornerRadius = 28
    imageView.contentMode = .scaleAspectFill
    imageView.layer.masksToBounds = true;
    return imageView
  }()
  
  var displayNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 17, textStyle: .headline)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 1
    return label
  }()
  
  lazy var lastMessageLabel: UILabel = {
    let label = UILabel()
    label.textColor = .systemGray
    label.font = UIFont.appFontSemiBold(ofSize: 17, textStyle: .headline)
    label.numberOfLines = 1
    label.lineBreakMode = .byTruncatingTail
    return label
  }()
  
  private lazy var typingLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontItalic(ofSize: 15)
    label.textColor = UIColor.systemGray
    label.text = "Typing..."
    label.sizeToFit()
    label.alpha = 0
    return label
  }()
  
  private lazy var lastMessageDateLabel: UILabel = {
    let label = UILabel()
    label.textColor = UIColor.systemGray
    return label
  }()
  
  private lazy var receiptImage: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.isHidden = true
    return imageView
  }()
  
  private lazy var selectedCheckmark: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: " "))
    imageView.pin.sizeToFit()
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private lazy var fileTypeImage: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.isHidden = true
    imageView.tintColor = .systemGray
    return imageView
  }()
  
  lazy var lastMessageUsernameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15)
    label.textColor = UIColor.systemGray
    return label
  }()
  
  private var animationState = AnimationState.normal {
    didSet {
      if oldValue != animationState {
        UIView.animate(withDuration: 0.3, animations: {
          self.isAnimating = true
          self.layoutViews()
        }, completion: { (_) in
          self.isAnimating = false
        })
      }
    }
  }
  var isAnimating = false
  
  private var cancellableBag = Set<AnyCancellable>()
  
  var viewModel: ChatCellViewModel! {
    didSet {
      displayNameLabel.text = viewModel.name
      
      viewModel.group?.$description.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (groupDescription) in
        guard let strongSelf = self else { return }
        strongSelf.displayNameLabel.text = strongSelf.viewModel.name
      }).store(in: &cancellableBag)
      
      viewModel.$isSelected.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] value in
        guard let strongSelf = self else { return }
        strongSelf.selectedCheckmark.image = value ? UIImage(named: "full_check") : UIImage(named: "empty_check")
      }).store(in: &cancellableBag)
      
      viewModel.isEditing.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] value in
        guard let strongSelf = self else { return }
        if value {
          strongSelf.animationState = .edit
          let bgColorView = UIView()
          bgColorView.backgroundColor = Constants.ChatsListSelectedBackgroundColor
          strongSelf.selectedBackgroundView = bgColorView
        } else {
          strongSelf.animationState = .normal
          strongSelf.selectedBackgroundView = nil
          strongSelf.selectedCheckmark.image = UIImage(named: "empty_check")
        }
      }).store(in: &cancellableBag)
      
      viewModel.$isLastMessageDeleted.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self](value) in
        guard let strongSelf = self else { return }
        if value, let msg = strongSelf.viewModel.lastMessage {
          strongSelf.lastMessageLabel.attributedText = msg.body.getAttributedText(fontSize: 17)
        }
      }).store(in: &cancellableBag)
      
      // Group Scope
      do {

        viewModel.group?.backgroundFetchMessages()
        viewModel.group?.$profileImagePath.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (imagePath) in
          guard let strongSelf = self else { return }
          if let imagePath = imagePath, let image = UIImage.fromPath(imagePath) {
            strongSelf.userImage.image = image
          } else {
            strongSelf.userImage.image = UIImage(named: "avatar_profile_group")
          }
        }).store(in: &cancellableBag)
        viewModel.group?.$unreadMessagesCount.throttle(for: .milliseconds(400), scheduler: DispatchQueue.main, latest: true).sink(receiveValue: { [weak self] (count) in
          guard let strongSelf = self else { return }
          strongSelf.updateUnreadMessageCount(count: count)
        }).store(in: &cancellableBag)
        
        if let members = viewModel.group?.members, let accountNumber = Blackbox.shared.account.registeredNumber {
          for member in members where member.registeredNumber != accountNumber {
            member.isTyping
            .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: {  [weak self] isTypingTuple in
              guard let strongSelf = self, let group = strongSelf.viewModel.group, let typingGroup = isTypingTuple.group, typingGroup.ID == group.ID else { return }
              
              if isTypingTuple.isTyping {
                
                if let _ = strongSelf.viewModel.contact {
                  strongSelf.typingLabel.text = "typing...".localized()
                }
                else if let _ = strongSelf.viewModel.group {
                  // Handle group typing
                  strongSelf.typingLabel.attributedText = NSAttributedString(string: "\(member.getName()) \("is typing...".localized())").adjustDirectionBasedOnSystemLanguage()
                }
                strongSelf.typingLabel.sizeToFit()
                
                // show the animation only if needed
                if strongSelf.typingLabel.alpha == 0 {
                  UIView.animate(withDuration: 0.1) {
                    strongSelf.typingLabel.alpha = 1
                    strongSelf.lastMessageLabel.alpha = 0
                    strongSelf.receiptImage.alpha = 0
                    strongSelf.selectedCheckmark.alpha = 0
                    strongSelf.fileTypeImage.alpha = 0
                    strongSelf.lastMessageUsernameLabel.alpha = 0
                  }
                }
                
                // Reset typing after 2.6 seconds
                DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 2.6) {
                  member.isTyping.send((false, group))
                }
                
              } else {
                strongSelf.typingLabel.alpha = 0
                strongSelf.lastMessageLabel.alpha = 1
                strongSelf.receiptImage.alpha = 1
                strongSelf.selectedCheckmark.alpha = 1
                strongSelf.fileTypeImage.alpha = 1
                strongSelf.lastMessageUsernameLabel.alpha = 1
              }
            }).store(in: &cancellableBag)
          }
        }
      }

      // Contact Scope
      do {
        viewModel.contact?.backgroundFetchMessages()
        viewModel.contact?.$profilePhotoPath.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (imagePath) in
            guard let strongSelf = self else { return }
            if let imagePath = imagePath, let image = UIImage.fromPath(imagePath) {
              strongSelf.userImage.image = image
            } else {
              strongSelf.userImage.image = UIImage(named: "avatar_profile")
            }
          }).store(in: &cancellableBag)
        viewModel.contact?.$unreadMessagesCount.throttle(for: .milliseconds(400), scheduler: DispatchQueue.main, latest: true).sink(receiveValue: { [weak self] (count) in
          guard let strongSelf = self else { return }
          strongSelf.updateUnreadMessageCount(count: count)
        }).store(in: &cancellableBag)
        viewModel.contact?.isTyping
          .filter {
            $0.group == nil
          }
          .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
          .sink(receiveValue: {  [weak self] isTypingTuple in
            guard let strongSelf = self, let contact = strongSelf.viewModel.contact else { return }
            
            if isTypingTuple.isTyping {
              
              if let _ = strongSelf.viewModel.contact {
                strongSelf.typingLabel.text = "typing...".localized()
              }
              else if let _ = strongSelf.viewModel.group {
                // Handle group typing
                strongSelf.typingLabel.attributedText = NSAttributedString(string: "\(contact.getName()) \("is typing...".localized())").adjustDirectionBasedOnSystemLanguage()
              }
              strongSelf.typingLabel.sizeToFit()
              
              // show the animation only if needed
              if strongSelf.typingLabel.alpha == 0 {
                UIView.animate(withDuration: 0.1) {
                  strongSelf.typingLabel.alpha = 1
                  strongSelf.lastMessageLabel.alpha = 0
                  strongSelf.receiptImage.alpha = 0
                  strongSelf.selectedCheckmark.alpha = 0
                  strongSelf.fileTypeImage.alpha = 0
                  strongSelf.lastMessageUsernameLabel.alpha = 0
                }
              }
              
              // Reset typing after 2.6 seconds
              DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 2.6) {
                contact.isTyping.send((false, nil))
              }
              
            } else {
              strongSelf.typingLabel.alpha = 0
              strongSelf.lastMessageLabel.alpha = 1
              strongSelf.receiptImage.alpha = 1
              strongSelf.selectedCheckmark.alpha = 1
              strongSelf.fileTypeImage.alpha = 1
              strongSelf.lastMessageUsernameLabel.alpha = 1
            }
          }).store(in: &cancellableBag)
      }
      
      if let message = viewModel.lastMessage {
        if message.status == .outgoing {
          receiptImage.isHidden = message.type == .deleted
        } else {
          receiptImage.isHidden = true
        }
        
        message.$checkmarkType
          .receive(on: DispatchQueue.main)
          .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
          .sink(receiveValue: { [weak self] (type) in
            guard let strongSelf = self else { return }
            
            switch type {
            case .sent:
              strongSelf.receiptImage.image = UIImage(named: "receipt_sent")
            case .received:
              strongSelf.receiptImage.image = UIImage(named: "receipt_received")
            case .read:
              strongSelf.receiptImage.image = UIImage(named: "receipt_read")
            case .unSent:
              strongSelf.receiptImage.image = UIImage(named: "unsent")
            default:
              break
            }
          }).store(in: &cancellableBag)
        
        if let date = message.status == MessageStatus.incoming ? message.dateReceived : message.dateSent {
          if date.isInToday {
            lastMessageDateLabel.text = date.timeString12Hour()
          }
          else if date.isInYesterday{
            lastMessageDateLabel.text = "Yesterday".localized()
          }
          else if date.isInCurrentWeek {
            lastMessageDateLabel.text = date.dayName()
          }
          else if date.isInCurrentYear {
            lastMessageDateLabel.text = Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM d") : date.dateStringIslamic(withFormat: "E, MMM d")
          }
          else {
            lastMessageDateLabel.text = Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM yyyy") : date.dateStringIslamic(withFormat: "E, MMM yyyy")
          }
          lastMessageDateLabel.font = UIFont.appFont(ofSize: 15, textStyle: .body)
          lastMessageDateLabel.sizeToFit()
        }
        
        if let group = viewModel.group {
          contentView.addSubview(lastMessageUsernameLabel)
          if let accountNumber = Blackbox.shared.account.registeredNumber, message.sender == accountNumber {
            lastMessageUsernameLabel.text = "You".localized()
          }
          else {
            var name = group.getGroupMember(message: message).getName()
            if name == "0000001" {
              name = ""
            }
            
            lastMessageUsernameLabel.text = name
          }
          lastMessageUsernameLabel.sizeToFit()
        }
        
        if message.containAttachment {
          contentView.addSubview(fileTypeImage)
          fileTypeImage.isHidden = false
        }
        else {
          fileTypeImage.isHidden = true
        }
        
        switch message.type {
        case .audio:
          lastMessageLabel.text = "Audio".localized()
          fileTypeImage.image = UIImage(systemName: "mic.fill")
        case .contact:
          lastMessageLabel.text = "Contact".localized()
          fileTypeImage.image = UIImage(systemName: "person.fill")
        case .document:
          lastMessageLabel.text = "Document".localized()
          fileTypeImage.image = UIImage(systemName: "doc.fill")
        case .location:
          lastMessageLabel.text = "Location".localized()
          fileTypeImage.image = UIImage(systemName: "mappin.and.ellipse")
        case .photo:
          lastMessageLabel.text = "Photo".localized()
          fileTypeImage.image = UIImage(systemName: "camera.fill")
        case .video:
          lastMessageLabel.text = "Video".localized()
          fileTypeImage.image = UIImage(systemName: "video.fill")
        default:
          if message.isAlertMessage {
            lastMessageLabel.attributedText = message.alertMsg?.getAttributedText(fontSize: 17)?.adjustDirectionBasedOnSystemLanguage()
          } else {
            lastMessageLabel.attributedText = message.body.getAttributedText(fontSize: 17)
          }
        }
      }
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
  private func setupCell() {
    separatorInset = UIEdgeInsets(top: 0, left: 78, bottom: 0, right: 0)
    
    // Add UI Elements to cell
    contentView.addSubview(selectedCheckmark)
    contentView.addSubview(userImage)
    contentView.addSubview(typingLabel)
    contentView.addSubview(lastMessageDateLabel)
    contentView.addSubview(displayNameLabel)
    contentView.addSubview(lastMessageLabel)
    contentView.addSubview(unreadMessageBadge)
    contentView.addSubview(lastMessageUsernameLabel)
    contentView.addSubview(receiptImage)
  }
  
}

extension ChatCell {
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard !isAnimating else { return }
    layoutViews()
  }
  
  /// Set the UI Elements Contraints.
  private func layoutViews() {
    
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
      let size = displayNameLabel.height*1.2
      if AppUtility.isArabic {
        selectedCheckmark.pin.vCenter().right(20).height(size).width(size)
      } else {
        selectedCheckmark.pin.vCenter().left(20).height(size).width(size)
      }
      break
    }
    
    if AppUtility.isArabic {
      userImage.pin
        .centerRight(to: selectedCheckmark.anchor.centerLeft)
        .marginHorizontal(20)
      
      displayNameLabel.pin
        .top(8)
        .left(of: userImage)
        .marginRight(10)
        .marginHorizontal(10)
        .sizeToFit()
      
      typingLabel.pin
        .below(of: displayNameLabel, aligned: .right)
        .marginTop(displayNameBottomSpace)
      
      lastMessageDateLabel.pin
        .vCenter(to: displayNameLabel.edge.vCenter)
        .left(14)
    } else {
      userImage.pin
        .centerLeft(to: selectedCheckmark.anchor.centerRight)
        .marginHorizontal(20)
      
      displayNameLabel.pin
        .top(8)
        .right(of: userImage)
        .marginLeft(10)
        .marginHorizontal(10)
        .sizeToFit()
      
      typingLabel.pin
        .below(of: displayNameLabel, aligned: .left)
        .marginTop(displayNameBottomSpace)
      
      lastMessageDateLabel.pin
        .vCenter(to: displayNameLabel.edge.vCenter)
        .right(10)
    }
    
    if viewModel.isGroup {
      groupChatContraints()
    } else {
      singleChatContraints()
    }
    
    lastMessageLabel.lineBreakMode = .byTruncatingTail
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    
    cancellableBag.cancellAndRemoveAll()
    
    displayNameLabel.text = ""
    lastMessageLabel.text = ""
    typingLabel.text = ""
    lastMessageLabel.textColor = .systemGray
    
    fileTypeImage.image = nil
    fileTypeImage.removeFromSuperview()
    lastMessageUsernameLabel.text = ""
    lastMessageUsernameLabel.removeFromSuperview()
    receiptImage.isHidden = true
    lastMessageDateLabel.text = ""
    
    typingLabel.alpha = 0
    lastMessageLabel.alpha = 1
    receiptImage.alpha = 1
    selectedCheckmark.alpha = 1
    fileTypeImage.alpha = 1
    lastMessageUsernameLabel.alpha = 1
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    
    // update UI
    //    accessoryType = selected ? .checkmark : .disclosureIndicator
  }
  
  private func updateUnreadMessageCount(count: Int) {
    if count > 0 {
      unreadMessageBadge.isHidden = false
      unreadMessageBadge.text = String(count)
      unreadMessageBadge.pin
        .sizeToFit()
        .topRight(to: lastMessageDateLabel.anchor.bottomRight)
        .marginTop(8)
      if let contact = viewModel.contact {
        contact.isTyping.send((false, nil))
      } else if let group = viewModel.group {
        group.members.forEach {
          $0.isTyping.send((false, group))
        }
      }
    } else {
      // Safe check for zero unread message.
      unreadMessageBadge.isHidden = true
    }
  }
  
}

// MARK: - Single Chat
extension ChatCell {
  /// This Image is always the first in line
  private func singleChatAddMessageReceiptImage() {
    receiptImage.pin
      .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
      .vCenter()
      .right(of: userImage)
      .marginLeft(10)
  }
  
  /// Add File Type Icon to the cell.
  private func singleChatAddFileTypeImage(message: Message) {
    // TODO: Add correct file type. FOr testing purpose we just add the photo type
    if message.status == .outgoing && message.type != .deleted {
      // Last Message is sent. The fileType image goes after the checkmark
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .centerLeft(to: receiptImage.anchor.centerRight)
        .marginHorizontal(HorizontalSpace)
    } else {
      // Last Message is received. The fileType image goes at the start
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .vCenter()
        .right(of: userImage)
        .marginLeft(10)
    }
    fileTypeImage.isHidden = false
  }
  
  /// This is the last element to be added, after the message status Icon, the fileTypeImage or
  /// just at the beginning if the message is received and its a just a text
  private func singleChatAddLastMessageLabel(after view: UIView?) {
    if view != nil {
      lastMessageLabel.pin
        .centerLeft(to: view!.anchor.centerRight)
        .marginHorizontal(HorizontalSpace)
        .right(40)
        .height(lastMessageLabel.requiredHeight)
    } else {
      lastMessageLabel.pin
        .vCenter()
        .right(of: userImage)
        .marginLeft(10)
        .right(40)
        .height(lastMessageLabel.requiredHeight)
    }
  }
  
  private func singleChatContraints() {
    if AppUtility.isArabic {
      singleChatContraintsArabic()
    } else {
      guard let message = viewModel.lastMessage else { return }
      
      if message.status == .outgoing && message.type != .deleted {
        singleChatAddMessageReceiptImage()
      }
      
      if message.containAttachment {
        singleChatAddFileTypeImage(message: message)
        singleChatAddLastMessageLabel(after: fileTypeImage)
      } else {
        singleChatAddLastMessageLabel(after: message.status == .outgoing && message.type != .deleted ? receiptImage : nil)
      }
    }
  }
  
  // MARK: - Arabic
  /// This Image is always the first in line
  private func singleChatAddMessageReceiptImageArabic() {
    receiptImage.pin
      .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
      .vCenter()
      .left(of: userImage)
      .marginRight(10)
  }
  
  /// Add File Type Icon to the cell.
  private func singleChatAddFileTypeImageArabic(message: Message) {
    // TODO: Add correct file type. FOr testing purpose we just add the photo type
    if message.status == .outgoing && message.type != .deleted {
      // Last Message is sent. The fileType image goes after the checkmark
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .centerRight(to: receiptImage.anchor.centerLeft)
        .marginHorizontal(HorizontalSpace)
    } else {
      // Last Message is received. The fileType image goes at the start
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .vCenter()
        .left(of: userImage)
        .marginRight(10)
    }
    fileTypeImage.isHidden = false
  }
  
  /// This is the last element to be added, after the message status Icon, the fileTypeImage or
  /// just at the beginning if the message is received and its a just a text
  private func singleChatAddLastMessageLabelArabic(after view: UIView?) {
    if view != nil {
      lastMessageLabel.pin
        .centerRight(to: view!.anchor.centerLeft)
        .marginHorizontal(HorizontalSpace)
        .left(40)
        .height(lastMessageLabel.requiredHeight)
    } else {
      lastMessageUsernameLabel.pin
        .vCenter()
        .left(of: userImage)
        .marginRight(10)
      
      lastMessageLabel.pin
        .vCenter()
        .left(of: userImage)
        .marginRight(10)
        .left(40)
        .height(lastMessageLabel.requiredHeight)
    }
  }
  
  private func singleChatContraintsArabic() {
    guard let message = viewModel.lastMessage else { return }
    
    if message.status == .outgoing && message.type != .deleted {
      singleChatAddMessageReceiptImageArabic()
    }
    
    if message.containAttachment {
      singleChatAddFileTypeImageArabic(message: message)
      singleChatAddLastMessageLabelArabic(after: fileTypeImage)
    } else {
      singleChatAddLastMessageLabelArabic(after: message.status == .outgoing && message.type != .deleted ? receiptImage : nil)
    }
  }
}

// MARK: - Group Chat
extension ChatCell {
  /// :nodoc:
  private func groupChatAddLastMessageUsernameLabel() {
    lastMessageUsernameLabel.pin
      .minHeight(16.33)
      .vCenter()
      .right(of: userImage)
      .marginLeft(10)
  }
  
  /// :nodoc:
  private func groupChatAddMessageStatusImage() {
    receiptImage.pin
      .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
      .below(of: lastMessageUsernameLabel, aligned: .left)
      .marginTop(displayNameBottomSpace)
  }
  
  /// :nodoc:
  private func groupChatAddFileTypeImage(message: Message) {
    if message.status == .outgoing && message.type != .deleted {
      // Last Message is sent. The fileType image goes after the checkmark
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .centerLeft(to: receiptImage.anchor.centerRight)
        .marginHorizontal(HorizontalSpace)
    } else {
      // Last Message is received. The fileType image goes at the start
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .below(of: lastMessageUsernameLabel, aligned: .left)
        .marginTop(displayNameBottomSpace)
    }
    fileTypeImage.isHidden = false
  }
  
  /// :nodoc:
  private func groupChatAddLastMessageLabel(after view: UIView?) {
    lastMessageLabel.sizeToFit()
    if view != nil {
      lastMessageLabel.pin
        .centerLeft(to: view!.anchor.centerRight)
        .marginHorizontal(HorizontalSpace)
        .right(40)
        .height(lastMessageLabel.requiredHeight)
    } else {
      lastMessageLabel.pin
        .below(of: lastMessageUsernameLabel, aligned: .left)
        .marginTop(displayNameBottomSpace)
        .right(40)
    }
    
  }
  
  /// :nodoc:
  private func groupChatContraints() {
    if AppUtility.isArabic {
      groupChatContraintsArabic()
    } else {
      guard let message = viewModel.lastMessage else { return }
      
      groupChatAddLastMessageUsernameLabel()
      
      if message.status == .outgoing {
        groupChatAddMessageStatusImage()
      }
      
      if message.containAttachment {
        groupChatAddFileTypeImage(message: message)
        groupChatAddLastMessageLabel(after: fileTypeImage)
      } else {
        groupChatAddLastMessageLabel(after: message.status == .outgoing && message.type != .deleted ? receiptImage : nil)
      }
    }
  }
  
  // MARK: - Arabic
  /// :nodoc:
  private func groupChatAddLastMessageUsernameLabelArabic() {
    lastMessageUsernameLabel.pin
      .minHeight(16.33)
      .vCenter()
      .left(of: userImage)
      .marginRight(10)
  }
  
  /// :nodoc:
  private func groupChatAddMessageStatusImageArabic() {
    receiptImage.pin
      .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
      .below(of: lastMessageUsernameLabel, aligned: .right)
      .marginTop(displayNameBottomSpace)
  }
  
  /// :nodoc:
  private func groupChatAddFileTypeImageArabic(message: Message) {
    if message.status == .outgoing && message.type != .deleted {
      // Last Message is sent. The fileType image goes after the checkmark
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .centerRight(to: receiptImage.anchor.centerLeft)
        .marginHorizontal(HorizontalSpace)
    } else {
      // Last Message is received. The fileType image goes at the start
      fileTypeImage.pin
        .size(CGSize(width: displayNameLabel.height * 0.8, height: displayNameLabel.height * 0.8))
        .below(of: lastMessageUsernameLabel, aligned: .right)
        .marginTop(displayNameBottomSpace)
    }
    fileTypeImage.isHidden = false
  }
  
  /// :nodoc:
  private func groupChatAddLastMessageLabelArabic(after view: UIView?) {
    lastMessageLabel.sizeToFit()
    if view != nil {
      lastMessageLabel.pin
        .centerRight(to: view!.anchor.centerLeft)
        .marginHorizontal(HorizontalSpace)
        .left(40)
        .height(lastMessageLabel.requiredHeight)
    } else {
      lastMessageLabel.pin
        .below(of: lastMessageUsernameLabel, aligned: .right)
        .marginTop(displayNameBottomSpace)
        .left(40)
    }
    
  }
  
  /// :nodoc:
  private func groupChatContraintsArabic() {
    guard let message = viewModel.lastMessage else { return }
    
    groupChatAddLastMessageUsernameLabelArabic()
    
    if message.status == .outgoing {
      groupChatAddMessageStatusImageArabic()
    }
    
    if message.containAttachment {
      groupChatAddFileTypeImageArabic(message: message)
      groupChatAddLastMessageLabelArabic(after: fileTypeImage)
    } else {
      groupChatAddLastMessageLabelArabic(after: message.status == .outgoing && message.type != .deleted ? receiptImage : nil)
    }
    
  }
  
}

