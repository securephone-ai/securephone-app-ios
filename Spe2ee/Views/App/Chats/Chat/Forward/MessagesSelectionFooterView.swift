import UIKit
import Combine

protocol MessagesSelectionFooterViewDelegate: class {
  func didForwardMessages();
}

class MessagesSelectionFooterView: UIView {
  weak var delegate: MessagesSelectionFooterViewDelegate?

  private var cancellableBag = Set<AnyCancellable>()
  private let chatViewModel: ChatViewModel!
  
  private var selectedMessagesCountLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 18)
    return label
  }()
  
  private var forwardButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
    let conf = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "arrowshape.turn.up.right", withConfiguration: conf), for: .normal)
    button.isEnabled = false
    button.addTarget(self, action: #selector(forwardMessages), for: .touchUpInside)
    return button
  }()
  
  private var deleteButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
    let conf = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "trash", withConfiguration: conf), for: .normal)
    button.isEnabled = false
    button.addTarget(self, action: #selector(deleteMessages), for: .touchUpInside)
    return button
  }()
  
  init(chatViewModel: ChatViewModel) {
    self.chatViewModel = chatViewModel
    super.init(frame: CGRect(x: 0, y: 0, width: 0, height: Blackbox.shared.defaultFooterHeight))
    backgroundColor = .systemGray6
    
    addSubview(forwardButton)
    addSubview(deleteButton)
    addSubview(selectedMessagesCountLabel)
    
    
    self.chatViewModel.$selectedMessages.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (messages) in
      guard let strongSelf = self else { return }
      strongSelf.selectedMessagesCountLabel.text = "\(messages.count) selected"
      strongSelf.selectedMessagesCountLabel.sizeToFit()
      strongSelf.forwardButton.isEnabled = messages.count > 0
      strongSelf.deleteButton.isEnabled = messages.count > 0
      strongSelf.setNeedsLayout()
      strongSelf.layoutIfNeeded()
    }).store(in: &cancellableBag)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    forwardButton.isHidden = !chatViewModel.isForwardEditing
    deleteButton.isHidden = !chatViewModel.isDeleteEditing
    forwardButton.pin.left(10).top(4)
    deleteButton.pin.left(10).top(4)
    selectedMessagesCountLabel.pin.vCenter(to: forwardButton.edge.vCenter).hCenter()
  }
  
  @objc func forwardMessages() {
    let viewController = ForwardChatsListViewController(doneButtonTitle: "Forward".localized())
    viewController.delegate = self
    let navigation = UINavigationController(rootViewController: viewController)
    Blackbox.shared.chatViewController?.present(navigation, animated: true, completion: nil)
  }
  
  @objc func deleteMessages() {
    chatViewModel.deleteMessagesAsync(messages: chatViewModel.selectedMessages)
    chatViewModel.isDeleteEditing = false
  }
}

extension MessagesSelectionFooterView: ForwardChatsListViewControllerDelegate {
  func didFinishSelection(chats: [ChatItems]) {
    for chat in chats {
      if let chatItemViewModel = chat.getChatItemViewModel() {
        for selectedMessageViewModel in chatViewModel.selectedMessages.sorted(by: { $0.message.dateSent < $1.message.dateSent }) {
          
          let message = selectedMessageViewModel.message
          // Copy the message and change the sender and recipient
          let newMessage = message.copy() as! Message
          
          // Send chat alert
          if message.status == .incoming {
            chatViewModel.sendChatAlertAsync(alert: .messagesForwarded, message: message)
            newMessage.isForwarded = true
          }
          
          newMessage.sender = Blackbox.shared.account.registeredNumber!
          if chatItemViewModel.isGroup, let group = chatItemViewModel.group {
            newMessage.recipient = group.ID
            switch message.type {
            case .audio, .photo, .video, .document:
              newMessage.resetFileForward()
              group.sendFileAsync(newMessage) { (errorMessage) in
                if errorMessage == nil, message.status == .incoming {
                  newMessage.setForwardedAsync(completion: nil)
                }
              }
            case .text:
              group.sendMessageAsync(newMessage) { (errorMessage) in
                if errorMessage == nil, message.status == .incoming {
                  newMessage.setForwardedAsync(completion: nil)
                }
              }
            default:
              break
            }
          } else if let contact = chatItemViewModel.contact {
            newMessage.recipient = contact.registeredNumber
            switch message.type {
            case .audio, .photo, .video, .document:
              newMessage.resetFileForward()
              contact.sendFileAsync(newMessage) { (errorMessage) in
                if errorMessage == nil, message.status == .incoming {
                  newMessage.setForwardedAsync(completion: nil)
                }
              }
            case .text:
              contact.sendMessageAsync(newMessage) { errorMessage in
                if errorMessage == nil, message.status == .incoming {
                  newMessage.setForwardedAsync(completion: nil)
                }
              }
            default:
              break
            }
          }
          
        }
      }
    }
    chatViewModel.isForwardEditing = false
    if chats.count == 1 {
      // open the new chat only if we forwarde to a single chat and it's not the same chat from which the forward message is generated.
      let chat = chats[0]
      if let chatItemViewModel = chat.getChatItemViewModel() {
        
        if chatItemViewModel.isGroup {
          if let group = chatViewModel.group, group.ID == chatItemViewModel.group!.ID {
            return
          }
          Blackbox.shared.chatListViewController?.openChat(group: chatItemViewModel.group!)
        } else {
          if let contact = chatViewModel.contact, contact.ID == chatItemViewModel.contact!.ID {
            return
          }
          Blackbox.shared.chatListViewController?.openChat(contact: chatItemViewModel.contact!)
        }
      }
    }
  }
  
  func didCancelSelection() {
    chatViewModel.isForwardEditing = false
    chatViewModel.removeSelectedMessages()
  }
}
