import UIKit
import Combine
import DifferenceKit



class StarredMessagesViewController: UIViewController {

  private var contact: BBContact?
  private var group: BBGroup?
  private var cancellableBag = Set<AnyCancellable>()
  
  private lazy var starredMessages: [MessageViewModel] = {
    if contact != nil {
      return contact!.starredMessages
    } else if group != nil {
      return group!.starredMessages
    } else {
      var messages = [MessageViewModel]()
      for chat in Blackbox.shared.chatItems {
        if let chatCellViewModel = chat.getChatItemViewModel() {
          if let contact = chatCellViewModel.contact, contact.starredMessages.count > 0 {
            messages.append(contentsOf: contact.starredMessages)
          } else if let group = chatCellViewModel.group, group.starredMessages.count > 0 {
            messages.append(contentsOf: group.starredMessages)
          }
        }
      }
      let starredMessages = messages.filter {
        return $0.message.type != .alertCopy &&
          $0.message.type != .alertForward &&
          $0.message.type != .alertScreenshot &&
          $0.message.type != .alertScreenRecording &&
          $0.message.type != .deleted &&
          $0.message.type.isSystemMessage() == false
      }.sorted {
        if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 > id2 {
          return true
        }
        return false
      }
      
      return starredMessages
    }
  }()
  
  init(contact: BBContact) {
    self.contact = contact
    super.init(nibName: nil, bundle: nil)
  }
  
  init(group: BBGroup) {
    self.group = group
    super.init(nibName: nil, bundle: nil)
  }
  
  init() {
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  private lazy var messagesTable: UITableView = {
    let tableView = UITableView()
    tableView.register(StarredMessageCell.self, forCellReuseIdentifier: Constants.StarredMessageCell_ID)
    tableView.register(StarredMessageCellText.self, forCellReuseIdentifier: Constants.StarredMessageCellText_ID)
    tableView.register(StarredMessageCellAudio.self, forCellReuseIdentifier: Constants.StarredMessageCellAudio_ID)
    tableView.register(StarredMessageCellDocuments.self, forCellReuseIdentifier: Constants.StarredMessageCellDocument_ID)
    tableView.register(StarredMessageCellLocation.self, forCellReuseIdentifier: Constants.StarredMessageCellLocation_ID)
    tableView.backgroundColor = .clear
    tableView.contentInset.bottom = 10
    tableView.delegate = self
    tableView.dataSource = self
    
    let longPressCell = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
    longPressCell.minimumPressDuration = 0.6
    longPressCell.delegate = self
    longPressCell.cancelsTouchesInView = false
    tableView.addGestureRecognizer(longPressCell)
    
    tableView.tableFooterView = UIView()
    
    return tableView
  }()
  
  private lazy var noStarredMessagesLabel: UILabel = {
    let label = UILabel(text: "\("No Starred Messages".localized())\n\n \("Tap and hold on any message to start it, so you can easily find it later.".localized())", style: .body)
    label.font = UIFont.appFont(ofSize: 15)
    label.adjustsFontForContentSizeCategory = true
    label.isHidden = true
    label.numberOfLines = 0
    label.textAlignment = .center
    return label
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Starred Messages".localized()
    
    // Do any additional setup after loading the view.
    view.backgroundColor = .systemGray5
    view.addSubview(messagesTable)
    view.addSubview(noStarredMessagesLabel)
    
    contact?.$starredMessages
      .receive(on: DispatchQueue.main)
      .filter({ (messages) -> Bool in
        return messages.count > 0
      })
      .sink(receiveValue: { [weak self] (messages) in
        guard let strongSelf = self else { return }
        let changeset = StagedChangeset(source: strongSelf.starredMessages, target: messages)
        if changeset.isEmpty == false {
          strongSelf.starredMessages = messages
          strongSelf.messagesTable.reloadData()
        }
      }).store(in: &cancellableBag)
    
    group?.$starredMessages
      .receive(on: DispatchQueue.main)
      .filter({ (messages) -> Bool in
        return messages.count > 0
      })
      .sink(receiveValue: { [weak self] (messages) in
        guard let strongSelf = self else { return }
        let changeset = StagedChangeset(source: strongSelf.starredMessages, target: messages)
        if changeset.isEmpty == false {
          strongSelf.starredMessages = messages
          strongSelf.messagesTable.reloadData()
        }
      }).store(in: &cancellableBag)
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Blackbox.shared.currentViewController = self
    
    noStarredMessagesLabel.isHidden = starredMessages.count > 0
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    messagesTable.pin.all()
    noStarredMessagesLabel.pin.vCenter().left(30).right(30).sizeToFit(.width)
  }
  
}

extension StarredMessagesViewController: UITableViewDataSource, UITableViewDelegate {
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return starredMessages.count
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard let orientation = self.view.screenOrientation else { return 0 }
    
    if starredMessages.count > indexPath.row {
      let messageViewModel = starredMessages[indexPath.row]
      
      if orientation.isPortrait {
        if messageViewModel.bubbleSizePortrait == .zero || messageViewModel.recalculateSize {
          messageViewModel.bubbleSizePortrait = StarredMessageBaseCell.calculateBubbleSize(viewModel: messageViewModel, maxWidth: tableView.width)
        }
        //        messageViewModel.bubbleSizePortrait = MessageCell.calculateBubbleSize(viewModel: messageViewModel, maxWidth: frame.width)
        messageViewModel.recalculateSize = true
        return messageViewModel.bubbleSizePortrait.height
        
      } else if orientation.isLandscape {
        if messageViewModel.message.containAttachment {
          if messageViewModel.bubbleSizeLandscape == .zero || messageViewModel.recalculateSize {
            // For attachment the Width is always based on the portrait width, so we just use the height when in landscape.
            messageViewModel.bubbleSizeLandscape = StarredMessageBaseCell.calculateBubbleSize(viewModel: messageViewModel, maxWidth: tableView.height)
          }
          //          messageViewModel.bubbleSizeLandscape = MessageCell.calculateBubbleSize(viewModel: messageViewModel, maxWidth: frame.height)
        } else {
          if messageViewModel.bubbleSizeLandscape == .zero || messageViewModel.recalculateSize {
            messageViewModel.bubbleSizeLandscape = StarredMessageBaseCell.calculateBubbleSize(viewModel: messageViewModel, maxWidth: tableView.width)
          }
          //          messageViewModel.bubbleSizeLandscape = MessageCell.calculateBubbleSize(viewModel: messageViewModel, maxWidth: frame.width)
        }
        messageViewModel.recalculateSize = true
        return messageViewModel.bubbleSizeLandscape.height
      }
      
    }
    return 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if starredMessages.count > indexPath.row {
      let messageViewModel = starredMessages[indexPath.row]
      switch messageViewModel.message.type {
      case .text:
        if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.StarredMessageCellText_ID, for: indexPath) as? StarredMessageCellText {
          cell.viewModel = messageViewModel
          return cell
        }
      case .photo, .video:
        if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.StarredMessageCell_ID, for: indexPath) as? StarredMessageCell {
          cell.viewModel = messageViewModel
          return cell
        }
      case .document(_):
        if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.StarredMessageCellDocument_ID, for: indexPath) as? StarredMessageCellDocuments {
          cell.viewModel = messageViewModel
          return cell
        }
      case .location:
        if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.StarredMessageCellLocation_ID, for: indexPath) as? StarredMessageCellLocation {
          cell.viewModel = messageViewModel
          return cell
        }
      case .audio:
        if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.StarredMessageCellAudio_ID, for: indexPath) as? StarredMessageCellAudio {
          cell.viewModel = messageViewModel
          return cell
        }
      default:
        break
      }
    }
    return UITableViewCell()
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    
    let messageViewModel = self.starredMessages[indexPath.row]
    
    guard let navController = self.navigationController else {
      return
    }

    for vc in navController.viewControllers {
      if let chatViewController = vc as? ChatViewController {
        if let group = messageViewModel.group {
          if let chatVM = chatViewController.viewModel, let chatGroup = chatVM.group, chatGroup.ID == group.ID {
            navController.popToViewController(chatViewController) {
              chatViewController.chatView?.didTapReply(messageID: messageViewModel.message.ID)
            }
            return
          }
        } else {
          if let chatVM = chatViewController.viewModel, let chatContact = chatVM.contact, chatContact.registeredNumber == messageViewModel.contact.registeredNumber {
            navController.popToViewController(chatViewController) {
              chatViewController.chatView?.didTapReply(messageID: messageViewModel.message.ID)
            }
            return
          }
        }
      }
    }
    
    if let group = messageViewModel.group {
      let chatVC = ChatViewController(viewModel: ChatViewModel(group: group))
      navController.pushViewController(chatVC, completion: {
        chatVC.chatView?.didTapReply(messageID: messageViewModel.message.ID)
      })
    } else {
      let chatVC = ChatViewController(viewModel: ChatViewModel(contact: messageViewModel.contact))
      navController.pushViewController(chatVC, completion: {
        chatVC.chatView?.didTapReply(messageID: messageViewModel.message.ID)
      })
    }
  
  }
  
}

extension StarredMessagesViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    // prevent opaque background to be dismissed if tap in on popup cell.
    guard let view = touch.view, let cell = view.superview else { return true }
    if cell.isKind(of: PopupMenuCell.self) {
      return false
    }
    return true
  }
}

extension StarredMessagesViewController {
  @objc func longPress(longPressGesture: UILongPressGestureRecognizer) {
    
  }
}

