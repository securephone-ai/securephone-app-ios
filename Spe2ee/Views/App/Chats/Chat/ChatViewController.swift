import UIKit
import Combine

struct MsgViewMargins {
  static let top: CGFloat = 5.0
  static let bottom: CGFloat = MsgViewMargins.top
  static let top_plus_bottom: CGFloat = top*2
  static let left: CGFloat = 30.0
}

class ChatViewController: BBViewController {
  
  var viewModel: ChatViewModel?
  var chatView: ChatView?
  
  private var chatHeader: ChatNavigationHeader?
  private var firstAppear = true
  private var contantStatusTimer: DispatchTimer?
  private var cancellableBag = Set<AnyCancellable>()
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .darkContent
  }
  
  init(viewModel: ChatViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
    
    self.hidesBottomBarWhenPushed = true
    self.chatView = ChatView(viewModel: self.viewModel!)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  deinit {
    logi("ChatViewController deinitialized")
    chatView = nil
    viewModel = nil
    NotificationCenter.default.removeObserver(self)
    navigationController?.popViewController(animated: true)
  }

}

// MARK: - View Lifecycle
extension ChatViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()    
    
    // As of iOS 9 and later, no need to remove the observer
    // https://developer.apple.com/documentation/foundation/notificationcenter/1407263-removeobserver
    NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)

    chatHeader = ChatNavigationHeader(viewModel: viewModel!, frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: topbarHeight))
    navigationItem.titleView = chatHeader!
    
    navigationItem.hidesBackButton = true
    let config = UIImage.SymbolConfiguration(pointSize: 18.5, weight: UIImage.SymbolWeight.semibold)
    let image = UIImage(systemName: "chevron.left", withConfiguration: config)
    let newBackButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(goBack))
    navigationItem.leftBarButtonItem = newBackButton
    
  }
  
  @objc func goBack() {
    if let chatView = chatView {
      chatView.footerView.msgTextView.resignFirstResponder()
    }
    if let viewModel = viewModel {
      viewModel.isForwardEditing = false
      viewModel.isDeleteEditing = false
      viewModel.removeOldMessages()
    }
  
    chatView = nil
    
    NotificationCenter.default.removeObserver(self)
    navigationController?.popViewController(animated: true)
    Blackbox.shared.chatViewController = nil
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    navigationController?.navigationBar.prefersLargeTitles = false
    AppUtility.removeWatermarkFromWindow()
    guard let viewModel = viewModel, let chatView = chatView else { return }
    
    viewModel.refreshDataSourceUnreadMessagesBannerPosition()
    chatView.messagesTable.reloadData()
    
    if let contact = viewModel.contact {
      chatView.footerView.msgTextView.text = contact.unsentMessage
      chatView.footerView.updateFooterHeight()
      
      if contact.getRealUnreadMessagesViewModels().count > 0 {
        //          chatView.scrollToLastReadMessage(animated: false)
        chatView.scrollToLastReadMessage(animated: false) {
          viewModel.sendAllReadReceipt()
        }
      }
      else if firstAppear {
        chatView.scrollToLastMesssage(animated: false)
      }
      
    }
    else if let group = viewModel.group {
      chatView.footerView.msgTextView.text = group.unsentMessage
      chatView.footerView.updateFooterHeight()
      
      if group.getRealUnreadMessagesViewModels().count > 0 {
        chatView.scrollToLastReadMessage(animated: false) {
          viewModel.sendAllReadReceipt()
        }
      } else if firstAppear {
        chatView.scrollToLastMesssage(animated: false)
      }
    }
    
    if let contact = viewModel.contact {
      contantStatusTimer = DispatchTimer(countdown: .milliseconds(10), repeating: .seconds(60), payload: {
        contact.updateProfileStatusAsync()
      })
      contantStatusTimer?.arm()
    }
    
    firstAppear = false
    
    chatHeader?.setNeedsLayout()
    chatHeader?.layoutIfNeeded()
    
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let viewModel = viewModel else { return }
    
    Blackbox.shared.chatViewController = self
    
    if UIScreen.main.isCaptured {
      viewModel.sendChatAlertAsync(alert: .screenRecorded)
    }
    
    if viewModel.isSearching {
      chatView?.topSearchBar.setFirstResponder()
    }
    
//    DispatchQueue.global(qos: .background).async { [weak self] in
//      guard let strongSelf = self else { return }
//      for i in 0..<40 {
//        usleep(450000)
//        strongSelf.viewModel?.sendTextMessage(text: String(i))
//      }
//    }
  
  }
  
  override func loadView() {
    super.loadView()
    view = chatView
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    chatView?.topSearchBar.dismiss()
    
    if let chatView = chatView {
      chatView.footerView.msgTextView.resignFirstResponder()
    }
    
    contantStatusTimer?.disarm()
    contantStatusTimer = nil
  
    if let viewModel = viewModel {
      viewModel.isForwardEditing = false
      viewModel.isDeleteEditing = false
    }
    
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let strongSelf = self, let viewModel = strongSelf.viewModel else { return }
      let sections = viewModel.getMessagesSection()
      for section in sections {
        section.messages.forEach {
          $0.stopRefreshFileTransferState()
        }
      }
    }
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    if let chatHeader = self.chatHeader {
      chatHeader.frame = CGRect(x: 0, y: 0, width: size.width, height: 100)
    }
  }
  
  @objc func willEnterForeground() {
    if let chatView = chatView {
      chatView.messagesTable.reloadData {
        chatView.scrollToLastReadMessage()
      }
      chatView.updateTableSectionHeadersVisibility()
      
      guard let viewModel = self.viewModel else { return }
      viewModel.canUpdateUnreadMessageBanner = true
      viewModel.fetchNewMessagesAsync()
      
      guard let contact = viewModel.contact else { return }
      contact.updateProfileStatusAsync()
    }
  }
  
  @objc func didEnterBackground() {
    guard let chatView = chatView, let viewModel = viewModel else { return }
    
    // remove Unread Banner when app goes to background
    if let indexPath = viewModel.getUnreadMessagesBannerIndexPath() {
      viewModel.group?.messagesSections[indexPath.section].messages.remove(at: indexPath.row)
      viewModel.contact?.messagesSections[indexPath.section].messages.remove(at: indexPath.row)
      chatView.messagesTable.safeDeleteRows(at: [indexPath], with: .fade)
      viewModel.hasUnreadMessagesBanner = false
    }
    
  }
  
}
