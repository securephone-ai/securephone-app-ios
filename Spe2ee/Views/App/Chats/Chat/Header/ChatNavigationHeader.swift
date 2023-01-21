import AVFoundation
import UIKit
import PinLayout
import Combine
import NextLevel

class ChatNavigationHeader: UIView {
  
  private var cancellableBag = Set<AnyCancellable>()
  
  private var titleViewContainer = UIView()

  private lazy var chatImage: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
    imageView.layer.cornerRadius = 18
    imageView.contentMode = .scaleAspectFill
    imageView.layer.masksToBounds = true
    return imageView
  }()

  private lazy var chatTitle: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBoldNoDynamic(ofSize: 15)
    
    if self.chatViewModel.isGroupChat {
      label.text = self.chatViewModel.group!.description
    } else {
      if Blackbox.shared.account.settings.supportInAppChatNumber == self.chatViewModel.contact!.registeredNumber {
         label.text = "Calc support".localized()
      } else {
        label.text = "\(self.chatViewModel.contact!.getName()) \(self.chatViewModel.contact!.surname)"
      }
    }
    
    label.sizeToFit()
    label.lineBreakMode = .byTruncatingTail
    return label
  }()
  
  private lazy var subtitleLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontNoDynamic(ofSize: 12.5)
    label.text = "A"
    label.frame = CGRect(x: 0, y: 0, width: 100, height: label.requiredHeight)
    label.text = ""
    label.textColor = .lightGray
    label.alpha = 0
    return label
  }()
  
  private lazy var callButton: UIButton = {
    let button = UIButton(type: .system)
    button.setImage(UIImage.thinSystemImage(name: "phone"), for: .normal)
    button.addTarget(self, action: #selector(startCall), for: .touchUpInside)
    button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
    button.isEnabled = true
    return button
  }()
  
  private lazy var videoButton: UIButton = {
    let button = UIButton(type: .system)
    button.setImage(UIImage.thinSystemImage(name: "video"), for: .normal)
    button.addTarget(self, action: #selector(startVideoCall), for: .touchUpInside)
    button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
    button.isEnabled = true
    return button
  }()
  
  private lazy var cancellButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel".localized(), for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    button.addTarget(self, action: #selector(cancelEdit), for: .touchUpInside)
    button.sizeToFit()
    button.alpha = 0
    return button
  }()
  
  private let activityIndicatorView: UIActivityIndicatorView = {
    let view = UIActivityIndicatorView(style: .medium)
    view.color = .black
    view.hidesWhenStopped = true
    return view
  }()
  
  private let connectingLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontNoDynamic(ofSize: 14)
    label.text = "Connecting".localized()
    label.sizeToFit()
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .black
    label.isHidden = true
    return label
  }()
  
  
  private var chatViewModel: ChatViewModel!
  
  private var typingTimer: DispatchTimer?
  
  init(viewModel: ChatViewModel, frame: CGRect) {
    self.chatViewModel = viewModel
    super.init(frame: frame)
    clipsToBounds = true
    
    addSubview(cancellButton)
    addSubview(titleViewContainer)
    titleViewContainer.addSubview(chatImage)
    titleViewContainer.addSubview(chatTitle)
    titleViewContainer.addSubview(subtitleLabel)
    addSubview(callButton)
    
    addSubview(activityIndicatorView)
    addSubview(connectingLabel)
    
    
    self.chatViewModel.group?.$description
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] (groupDesc) in
        guard let strongSelf = self else { return }
        strongSelf.chatTitle.text = groupDesc
        strongSelf.layoutAnimatedView()
      }).store(in: &cancellableBag)
    
    self.chatViewModel.$isForwardEditing
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self](value) in
        guard let strongSelf = self else { return }
        UIView.animate(withDuration: 0.2) {
          if value {
            strongSelf.cancellButton.alpha = 1
            strongSelf.callButton.alpha = 0
            strongSelf.videoButton.alpha = 0
          } else {
            strongSelf.cancellButton.alpha = 0
            strongSelf.callButton.alpha = 1
            strongSelf.videoButton.alpha = 1
          }
        }
      }).store(in: &cancellableBag)
    
    self.chatViewModel.$isDeleteEditing
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self](value) in
        guard let strongSelf = self else { return }
        UIView.animate(withDuration: 0.2) {
          if value {
            strongSelf.cancellButton.alpha = 1
            strongSelf.callButton.alpha = 0
            strongSelf.videoButton.alpha = 0
          } else {
            strongSelf.cancellButton.alpha = 0
            strongSelf.callButton.alpha = 1
            strongSelf.videoButton.alpha = 1
          }
        }
      }).store(in: &cancellableBag)
    

    //
    if let contact = self.chatViewModel.contact {
      
      contact.isTyping
        .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] isTypingTuple in
          guard let strongSelf = self else { return }
          
          strongSelf.typingTimer?.disarm()
          strongSelf.typingTimer = nil
          
          if isTypingTuple.isTyping {
            strongSelf.typingTimer = DispatchTimer(countdown: .seconds(4), payload: {
              // reset the typing value after 4 seconds
              contact.isTyping.send((false, nil))
              strongSelf.typingTimer?.disarm()
              strongSelf.typingTimer = nil
            })
            strongSelf.typingTimer?.arm()
            strongSelf.subtitleLabel.text = "typing...".localized()
            strongSelf.subtitleLabel.font = UIFont.appFontItalicNoDynamic(ofSize: 13)
            strongSelf.subtitleLabel.pin.sizeToFit(.content)
          } else {
            if contact.onlineStatus == .online {
              strongSelf.subtitleLabel.font = UIFont.appFontNoDynamic(ofSize: 13)
              strongSelf.subtitleLabel.text = "Online".localized()
              strongSelf.subtitleLabel.pin.sizeToFit(.content)
            } else {
              strongSelf.subtitleLabel.text = nil
            }
          }
          
        }).store(in: &cancellableBag)
      
      contact.$profilePhotoPath
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] (path) in
          guard let strongSelf = self else { return }
          if let path = path, !path.isEmpty, let image = UIImage.fromPath(path) {
            strongSelf.chatImage.image = image
          } else {
            strongSelf.chatImage.image = UIImage(named: "avatar_profile")
          }
        }).store(in: &cancellableBag)
      
      contact.$onlineStatus
        .receive(on: DispatchQueue.main)
        .debounce(for: .milliseconds(1000), scheduler: DispatchQueue.main)
        .throttle(for: .milliseconds(1000), scheduler: DispatchQueue.main, latest: true)
        .sink(receiveValue: { [weak self] (status) in
          guard let strongSelf = self else { return }
          
          if Blackbox.shared.isNetworkReachable == false {
            strongSelf.subtitleLabel.text = nil
          } else {
            switch status {
            case .online:
              strongSelf.subtitleLabel.text = "Online".localized()
              strongSelf.subtitleLabel.font = UIFont.appFontNoDynamic(ofSize: 13)
              strongSelf.subtitleLabel.sizeToFit()
            case .lastSeen(let str):
              strongSelf.subtitleLabel.text = str
              strongSelf.subtitleLabel.font = UIFont.appFontNoDynamic(ofSize: 13)
              strongSelf.subtitleLabel.sizeToFit()
            case .offline:
              strongSelf.subtitleLabel.text = nil
            }
          }
          
          UIView.animate(withDuration: 0.2) {
            strongSelf.layoutAnimatedView()
          }
        }).store(in: &cancellableBag)
      
      Blackbox.shared.$isNetworkReachable
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (isNetworkReachable) in
        guard let strongSelf = self else { return }
        if isNetworkReachable == false {
          strongSelf.subtitleLabel.text = nil
          UIView.animate(withDuration: 0.2) {
            strongSelf.layoutAnimatedView()
          }
        } else {
          contact.updateProfileStatusAsync()
        }
      }.store(in: &cancellableBag)
      
      addSubview(videoButton)
      if contact.registeredNumber == Blackbox.shared.account.settings.supportInAppCallNumber {
        videoButton.isHidden = true
      }
    }
    else if let group = self.chatViewModel.group {
      
      for member in group.members {
        member.isTyping
          .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
          .receive(on: DispatchQueue.main)
          .sink(receiveValue: { [weak self] isTypingTuple in
            guard let strongSelf = self, let typingGroup = isTypingTuple.group, typingGroup.ID == group.ID else { return }
            
            strongSelf.typingTimer?.disarm()
            strongSelf.typingTimer = nil
            
            if isTypingTuple.isTyping {
              strongSelf.typingTimer = DispatchTimer(countdown: .seconds(4), payload: {
                // reset the typing value after 4 seconds
                member.isTyping.send((false, group))
                strongSelf.typingTimer?.disarm()
                strongSelf.typingTimer = nil
              })
              strongSelf.typingTimer?.arm()
              strongSelf.subtitleLabel.attributedText = NSAttributedString(string: "\(member.getName()) \("is typing...".localized())").adjustDirectionBasedOnSystemLanguage()
              strongSelf.subtitleLabel.font = UIFont.appFontItalicNoDynamic(ofSize: 13)
              strongSelf.subtitleLabel.sizeToFit()
            } else {
              strongSelf.subtitleLabel.text = group.getMembersName()
              strongSelf.subtitleLabel.font = UIFont.appFontNoDynamic(ofSize: 13)
              strongSelf.subtitleLabel.sizeToFit()
            }
          }).store(in: &cancellableBag)
      }
      
      subtitleLabel.text = group.getMembersName()
      subtitleLabel.alpha = 1

      group.$profileImagePath
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] (path) in
          guard let strongSelf = self else { return }
          if let path = path, !path.isEmpty, let image = UIImage.fromPath(path) {
            strongSelf.chatImage.image = image
          } else {
            strongSelf.chatImage.image = UIImage(named: "avatar_profile_group")
          }
        }).store(in: &cancellableBag)
      
      group.$members
        .receive(on: DispatchQueue.main)
        .filter({ [weak self] (_) -> Bool in
          guard let strongSelf = self else { return false }
          return strongSelf.chatViewModel.isGroupChat
        })
        .sink(receiveValue: { [weak self] (_) in
          guard let strongSelf = self else { return }
          if let group = strongSelf.chatViewModel.group, group.members.count > 0 {
            strongSelf.subtitleLabel.text = group.getMembersName()
          }
          strongSelf.subtitleLabel.sizeToFit()
        }).store(in: &cancellableBag)
    }
    
    if chatViewModel.getMessagesCount() == 0 {
      activityIndicatorView.startAnimating()
      connectingLabel.isHidden = false
      titleViewContainer.isHidden = true
      
      self.chatViewModel.initialMessagesFetched.receive(on: DispatchQueue.main).sink { [weak self](_) in
        guard let strongSelf = self else { return }
        strongSelf.activityIndicatorView.stopAnimating()
        strongSelf.connectingLabel.isHidden = !strongSelf.activityIndicatorView.isAnimating
        strongSelf.titleViewContainer.isHidden = false
      }.store(in: &cancellableBag)
    }
  
    let gesture = UILongPressGestureRecognizer(target: self, action: #selector(headerTapped(_:)))
    gesture.minimumPressDuration = 0
    titleViewContainer.addGestureRecognizer(gesture)
    
    titleViewContainer.layer.masksToBounds = true
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    pin.all()
    
    if AppUtility.isArabic {
      callButton.pin.vCenter().left(4)
      titleViewContainer.pin.top().bottom().right().right(of: callButton)
      
      if self.chatViewModel.isGroupChat {
        chatImage.pin.right(12).height(titleViewContainer.height-4).vCenter().width(titleViewContainer.height-4)
      } else {
        videoButton.pin.centerLeft(to: callButton.anchor.centerRight).marginLeft(16)
        chatImage.pin.right(50).height(titleViewContainer.height-4).vCenter().width(titleViewContainer.height-4)
        titleViewContainer.pin.centerLeft(to: videoButton.anchor.centerRight).marginLeft(2)
      }
      cancellButton.pin.vCenter().left(4)
    }
    else {
      callButton.pin.vCenter().right()
      titleViewContainer.pin.top().bottom().left().left(of: callButton)
      
      if self.chatViewModel.isGroupChat {
        chatImage.pin.left(12).height(titleViewContainer.height-4).vCenter().width(titleViewContainer.height-4)
      } else {
        chatImage.pin.left(50).height(titleViewContainer.height-4).vCenter().width(titleViewContainer.height-4)
        videoButton.pin.centerRight(to: callButton.anchor.centerLeft).marginRight(16)
        titleViewContainer.pin.centerRight(to: videoButton.anchor.centerLeft)
      }
      cancellButton.pin.vCenter().right()
    }
    
    layoutAnimatedView()
    chatImage.cornerRadius = chatImage.height / 2
  }
  
  private func layoutAnimatedView() {
    guard let orientation = screenOrientation else { return }
    
    if orientation == .portrait {
      chatTitle.font = UIFont.appFontSemiBoldNoDynamic(ofSize: 15)
      subtitleLabel.font = UIFont.appFontNoDynamic(ofSize: 12.5)
    } else {
      chatTitle.font = UIFont.appFontSemiBoldNoDynamic(ofSize: 13)
      subtitleLabel.font = UIFont.appFontNoDynamic(ofSize: 11.5)
    }

    if let text = subtitleLabel.text, text.isEmpty == false {
     
      if AppUtility.isArabic {
        if orientation == .portrait {
          
          subtitleLabel.alpha = 1
          chatTitle.pin.topRight(to: chatImage.anchor.topLeft).marginRight(6).marginTop(1)
          subtitleLabel.pin.topRight(to: chatTitle.anchor.bottomRight).left(8).marginTop(1)
          chatTitle.sizeToFit()
          
        } else {
          
          subtitleLabel.alpha = 1
          chatTitle.pin.topRight(to: chatImage.anchor.topLeft).marginRight(6).marginTop(UIAccessibility.isBoldTextEnabled ? -2 : 0)
          subtitleLabel.pin.topRight(to: chatTitle.anchor.bottomRight).left(8)
          chatTitle.sizeToFit()
          
        }
      }
      else {
        if orientation == .portrait {
          
          subtitleLabel.alpha = 1
          chatTitle.pin.topLeft(to: chatImage.anchor.topRight).marginLeft(6).marginTop(1)
          subtitleLabel.pin.topLeft(to: chatTitle.anchor.bottomLeft).right(10).marginTop(1)
          subtitleLabel.sizeToFit()
          chatTitle.sizeToFit()
          
        } else {
          
          subtitleLabel.alpha = 1
          chatTitle.pin.topLeft(to: chatImage.anchor.topRight).marginLeft(6).marginTop(UIAccessibility.isBoldTextEnabled ? -2 : 0)
          subtitleLabel.pin.topLeft(to: chatTitle.anchor.bottomLeft).right(10)
          chatTitle.sizeToFit()
          subtitleLabel.sizeToFit()
          
        }
      }
      
    }
    else {
      
      if AppUtility.isArabic {
        subtitleLabel.alpha = 0
        chatTitle.pin.centerRight(to: chatImage.anchor.centerLeft).marginRight(6)
        subtitleLabel.pin.topRight(to: chatTitle.anchor.bottomRight)
        chatTitle.sizeToFit()
      }
      else {
        subtitleLabel.alpha = 0
        chatTitle.pin.centerLeft(to: chatImage.anchor.centerRight).marginLeft(6)
        subtitleLabel.pin.topLeft(to: chatTitle.anchor.bottomLeft)
        chatTitle.sizeToFit()
      }
    }
    
    connectingLabel.pin.vCenter().hCenter(AppUtility.isArabic ? 10 : -10)
    if AppUtility.isArabic {
      activityIndicatorView.pin.centerLeft(to: connectingLabel.anchor.centerRight).marginLeft(5)
    } else {
      activityIndicatorView.pin.centerRight(to: connectingLabel.anchor.centerLeft).marginRight(5)
    }
    
  }
  
  @objc func headerTapped(_ gesture: UITapGestureRecognizer) {
    switch gesture.state {
    case .began:
      UIView.animate(withDuration: 0.1) {
        self.titleViewContainer.alpha = 0.5
      }
    case .ended:
      let point = gesture.location(in: self)
      if point.x > 0 || point.y > 0 {
        if let vc = findViewController() as? UINavigationController {
          if let group = chatViewModel.group {
            let groupInfoVC = ChatGroupInfoTableViewController(group: group)
            groupInfoVC.delegate = self
            vc.pushViewController(groupInfoVC)
          } else if let contact = chatViewModel.contact {
            let contactInfoVC = ContactInfoViewController(contact: contact)
            contactInfoVC.delegate = self
            vc.pushViewController(contactInfoVC)
          }
        }
      }
      UIView.animate(withDuration: 0.1) {
        self.titleViewContainer.alpha = 1
      }
    default:
      break
    }
  }
  
  @objc func cancelEdit() {
    chatViewModel.isForwardEditing = false
    chatViewModel.isDeleteEditing = false
    chatViewModel.removeSelectedMessages()
  }
  
  @objc func startCall() {
    chatViewModel.isForwardEditing = false
    
    if let group = chatViewModel.group {
      let vc = ConferenceCallContactsSelectionViewController(contacts: group.members.filter { $0.registeredNumber != Blackbox.shared.account.registeredNumber })
      vc.delegate = self
      findViewController()?.present(vc, animated: true, completion: nil)
    } else {
      Blackbox.shared.callManager.startCall(contact: chatViewModel.contact!)
    }
  }
  
  @objc func startVideoCall() {
    chatViewModel.isForwardEditing = false
    if let chatVC = Blackbox.shared.chatViewController {
      if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
        if !chatViewModel.isGroupChat {
          Blackbox.shared.callManager.startCall(contact: chatViewModel.contact!, video: true)
        }
      } else {
        NextLevel.requestAuthorization(forMediaType: AVMediaType.video) { (mediaType, status) in
          if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
            if !self.chatViewModel.isGroupChat {
              DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
                guard let strongSelf = self else { return }
                Blackbox.shared.callManager.startCall(contact: strongSelf.chatViewModel.contact!, video: true)
              }
              
            }
          } else if status == .notAuthorized {
            // gracefully handle when audio/video is not authorized
            AppUtility.camDenied(viewController: chatVC)
          }
        }
      }
    }
  }
  
}

extension ChatNavigationHeader: ConferenceCallContactsSelectionViewControllerDelegate {
  func didSelectContacts(contacts: [BBContact]) {
    if contacts.isEmpty == false {
      Blackbox.shared.callManager.startConferenceCall(contacts: contacts)
    }
  }
}
 

extension ChatNavigationHeader: ContactInfoViewControllerDelegate {
  func didSelectSearch() {
    chatViewModel.isSearching = true
  }
}
