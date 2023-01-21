import UIKit
import Combine
import Network
import Alamofire
import BlackboxCore

class AppRootViewController: UITabBarController {
    
    private let notReachable = false
    private let resendMessagesQueue = DispatchQueue(label: "send_undelivered_message_queue")
    
    private var didEnterBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var didEnterBackgroundTaskTimer: DispatchTimer?
    private var cancellableBag = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGray6
        
        let blackbox = Blackbox.shared
        blackbox.appRootViewController = self
        
        selectedIndex = 0
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didTakeScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        
        UIScreen.main.addObserver(self, forKeyPath: "captured", options: .new, context: nil)
        
        blackbox.$isNetworkReachable.receive(on: DispatchQueue.main).sink { [weak self] (value) in
            guard let strongSelf = self else { return }
            if value {
                strongSelf.sendUndeliveredMessages()
                strongSelf.appRefresh()
            } else {
                // blackbox.account.isInternalPushregistered = false
            }
        }.store(in: &cancellableBag)
        
        let contactsSelectionVC = ContactsSelectionViewController()
        let item2 = UINavigationController(rootViewController: contactsSelectionVC)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: UIImage.SymbolWeight.light)
        let icon2 = UITabBarItem(title: "Contacts".localized(), image: UIImage(systemName: "person.circle", withConfiguration: config), selectedImage: UIImage(systemName: "person.circle.fill", withConfiguration: config))
        item2.tabBarItem = icon2
        
        
        var controllers = self.viewControllers!  //array of the root view controllers displayed by the tab bar interface
        controllers.insert(item2, at: 1)
        self.viewControllers = controllers
        didEnterBackgroundTaskTimer = DispatchTimer(countdown: .seconds(25), payload: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.endBackgroundTask()
        })
        
        //    Blackbox.shared.$callHistoryCellsViewModels.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] cellViewModels in
        //      guard let strongSelf = self else { return }
        //
        //    }).store(in: &cancellableBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //    // Maybe there was an inoming call
        //    if let callInfo = UserDefaults.standard.object(BBCallInfo.self, with: "callinc") {
        //      let blackbox = Blackbox.shared
        //      if let call = blackbox.callManager.callWithUUID(uuid: callInfo.uuid) {
        //        // The UIKit is still open
        //        call.getInfo { (success) in
        ////          if success {
        ////            // Update the call informations
        ////            blackbox.providerDelegate?.provider.reportCall(with: call.uuid, updated: blackbox.providerDelegate?.getUpdatedCallInfo(call))
        ////          }
        //        }
        //      } else {
        //        blackbox.providerDelegate?.reportIncomingCallInternalPush(uuid: callInfo.uuid)
        //      }
        //    }
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "captured") {
            if let chatVC = Blackbox.shared.chatViewController {
                if UIScreen.main.isCaptured {
                    if let chatViewModel = chatVC.viewModel {
                        chatViewModel.sendChatAlertAsync(alert: .screenRecorded)
                    }
                }
            }
        }
    }
    
    @objc func willEnterForeground() {
        self.appRefresh()
    }
    
    @objc func didEnterBackground() {
        // end any previous background task, if any.
        endBackgroundTask()
        
        // Stat a new background task
        didEnterBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AppRootViewController - didEnterBackgroundTask") {
            self.endBackgroundTask()
        }
        
        // Start the timer that will end the background task after 25 seconds
        didEnterBackgroundTaskTimer?.disarm()
        didEnterBackgroundTaskTimer?.arm()
        
        let blackbox = Blackbox.shared
        
        // Send offline status
        blackbox.account.updateOnlineStatus(status: .offline) { (success) in
            self.endBackgroundTask()
        }
        
        // close the Internal push connection
        blackbox.account.isInternalPushregistered = false
        
        // Stop periodic check incoming messages
        blackbox.account.periodicallyCheckForNewMessages = false
        
        // Stop the background thread that is refreshing the download % value
        for chat in blackbox.chatItems {
            if let chatItemViewModel = chat.getChatItemViewModel() {
                if let contact = chatItemViewModel.contact {
                    for messagesSection in contact.messagesSections {
                        for messageViewModel in messagesSection.messages where messageViewModel.message.containAttachment && messageViewModel.message.fileTransferState != 100 {
                            messageViewModel.stopRefreshFileTransferState()
                        }
                    }
                }
                else if let group = chatItemViewModel.group {
                    for messagesSection in group.messagesSections {
                        for messageViewModel in messagesSection.messages where messageViewModel.message.containAttachment && messageViewModel.message.fileTransferState != 100 {
                            messageViewModel.stopRefreshFileTransferState()
                        }
                    }
                }
            }
        }
        
        BlackboxCore.removeTemporaryFiles()
        
        do {
            // Remove every .MOV files created for thumbnails, "record.m4a -> Audio Recorded, image used for upload
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: AppUtility.getDocumentsDirectory().path)
            for filePath in files where
                filePath.contains("thumbnail.png") ||
                filePath.pathExtension == "MOV" ||
                filePath == "record.m4a" ||
                (filePath.pathExtension == "jpeg" && filePath.count < 64)
            {
                try fileManager.removeItem(atPath: AppUtility.getDocumentsDirectory().appendingPathComponent(filePath).path)
            }
        } catch {
            loge(error)
        }
    }
    
    private func endBackgroundTask() {
        if didEnterBackgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(didEnterBackgroundTask)
            didEnterBackgroundTask = .invalid
        }
    }
    
    @objc func preferredContentSizeChanged(_ notification: Notification) {
        if let chatVC = Blackbox.shared.chatViewController, let chatViewModel = chatVC.viewModel {
            let sections = chatViewModel.getMessagesSection()
            sections.forEach {
                $0.messages.forEach {
                    $0.recalculateSize = true
                }
            }
            if let chatView = chatVC.chatView {
                chatView.messagesTable.reloadData()
                chatView.footerView.msgTextView.font = UIFont.appFont(ofSize: 18, textStyle: .body)
                chatView.footerView.calculateFooterHeight()
                chatView.footerView.updateFooterHeight()
                chatView.footerView.setNeedsLayout()
                chatView.footerView.layoutIfNeeded()
            }
            
        }
        
        
        // Recalculate every message height on the background
        DispatchQueue.global(qos: .background).async {
            let blackbox = Blackbox.shared
            let chatVC = Blackbox.shared.chatViewController
            for item in blackbox.chatItems {
                if let chatItemViewModel = item.getChatItemViewModel() {
                    
                    if let contact = chatItemViewModel.contact {
                        if chatVC != nil, let chatViewModel = chatVC!.viewModel, let activeChatContact = chatViewModel.contact, activeChatContact.registeredNumber == contact.registeredNumber {
                            continue
                        }
                        
                        contact.messagesSections.forEach {
                            $0.messages.forEach {
                                $0.recalculateSize = true
                            }
                        }
                    } else if let  group = chatItemViewModel.group {
                        if chatVC != nil,  let chatViewModel = chatVC!.viewModel, let activeChatGroup = chatViewModel.group, activeChatGroup.ID == group.ID {
                            continue
                        }
                        group.messagesSections.forEach {
                            $0.messages.forEach {
                                $0.recalculateSize = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func didTakeScreenshot() {
        if let chatVC = Blackbox.shared.chatViewController, let chatViewModel = chatVC.viewModel {
            if let screenshot = UIApplication.shared.screenshot {
                chatViewModel.screenshotTaken.send(screenshot)
            }
        }
    }
    
    
    /// The following method will perform the fllowing actions:
    /// - Refresh the Account info
    /// - Check if the App needs to be updated
    /// - Register with internal push
    /// - Update the contacts list
    /// - Update the chat list
    /// - Update the calls history
    private func appRefresh() {
        let blackbox = Blackbox.shared
        let account = blackbox.account
        
        blackbox.account.fetchAccountInfoAsync { (success) in
            if success {
                if blackbox.account.needUpdate {
                    DispatchQueue.main.async {
                        self.viewControllers?.removeAll()
                        
                        blackbox.networkManager?.stopListening()
                        blackbox.networkManager = nil
                        blackbox.appRootViewController = nil
                        blackbox.callViewController = nil
                        blackbox.chatViewController = nil
                        blackbox.currentViewController = nil
                        blackbox.chatListViewController = nil
                        blackbox.contactsSections.removeAll()
                        blackbox.temporaryContacts.removeAll()
                        blackbox.archivedChatItems.removeAll()
                        blackbox.callHistoryCellsViewModels.removeAll()
                        blackbox.chatItems.removeAll()
                        
                        UIApplication.shared.windows[0].rootViewController = NewUpdateViewController()
                    }
                }
                else {
                    account.isInternalPushregistered = true
                    blackbox.account.updateOnlineStatus(status: .online)
                    blackbox.account.periodicallyCheckForNewMessages = true
                    
                    if let _ = blackbox.currentViewController as? ChatsListViewController {
                        blackbox.fetchContactsAsync(limitsearch: 10000) { (success) in
                            if success {
                                // Fetch chats and messages
                                blackbox.fetchChatListAsync()
                                
                                // Fetch calls history
                                blackbox.fetchCallsHistoryAsync(completion: nil)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    
    /// Loop through all the messages and Send the ones that have not been delivered.
    private func sendUndeliveredMessages() {
        self.resendMessagesQueue.asyncAfter(deadline: DispatchTime.now() + 3) {
            let blackbox = Blackbox.shared
            for chatItem in blackbox.chatItems {
                if let chatItemViewModel = chatItem.getChatItemViewModel() {
                    let messagesSections = chatItemViewModel.isGroup ? chatItemViewModel.group!.messagesSections : chatItemViewModel.contact!.messagesSections
                    for section in messagesSections {
                        for messageViewModel in section.messages where messageViewModel.message.status == .outgoing {
                            if messageViewModel.message.deliveredToServer == false {
                                switch messageViewModel.message.type {
                                case .text:
                                    chatItemViewModel.contact?.sendMessageAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                    chatItemViewModel.group?.sendMessageAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                case .location:
                                    chatItemViewModel.contact?.sendLocationAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                    chatItemViewModel.group?.sendLocationAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                case .photo, .video, .audio:
                                    chatItemViewModel.contact?.sendFileAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                    chatItemViewModel.group?.sendFileAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                case .alertCopy, .alertDelete, .alertForward, .alertScreenRecording, .alertScreenshot:
                                    chatItemViewModel.contact?.sendMessageAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                    chatItemViewModel.group?.sendMessageAsync(messageViewModel.message, appendMessageToTable: false, completion: nil)
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
}


