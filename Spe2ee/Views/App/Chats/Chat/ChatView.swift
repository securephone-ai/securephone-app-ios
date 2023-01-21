import UIKit
import PinLayout
import MapKit
import Combine
import AudioToolbox
import DifferenceKit
import JGProgressHUD
import SCLAlertView
import SwifterSwift
import MobileCoreServices
import AssetsPickerViewController
import Photos
import DifferenceKit


struct AssetObject {
    var url: URL
    var isVideo: Bool
    
    mutating func setVideoUrl(url: URL) {
        self.url = url
    }
}

class ChatView: UIView {
    
    private var cancellableBag = Set<AnyCancellable>()
    
    // MARK: - Vars and UI Elements Declarations
    private var isTableAtBottom: Bool {
        guard let lastMessageIndexPath = viewModel.getLastMessageIndexPath() else { return false }
        
        let cells = messagesTable.visibleCells
        if let lastCell = cells.last, let lastCellIndexPath = lastCell.indexPath, lastMessageIndexPath == lastCellIndexPath {
            return true
        }
        return false
    }
    private var firstNewMesagesFetched: Bool = true
    
    
    var keyboardHeight = CGFloat()
    private var viewModel: ChatViewModel!
    private var currentCellIndexPathSwiped: IndexPath?
    private lazy var imageManager = {
        return PHCachingImageManager()
    }()
    
    lazy var topSearchBar = SearchBar()
    
    
    // MARK: - Views
    private lazy var opaqueView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        let dismissOnTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissOpaqueBackground))
        dismissOnTapGesture.delegate = self
        blurEffectView.addGestureRecognizer(dismissOnTapGesture)
        return blurEffectView
    }()
    
    private lazy var autoDeleteDialog: MessageAutoDeleteDialog = {
        let view = MessageAutoDeleteDialog()
        view.delegate = self
        return view
    }()
    
    private lazy var imagePickerController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = self
        return picker
    }()
    
    private let backgroundImage: UIImageView = {
        //    let image = UIImageView(image: UIImage(named: self.isDarkMode ? "dark_chat_background" : "light_chat_background"))
        var image: UIImage?
        if let imgName = UserDefaults.standard.string(forKey: "chat_wallpaper") {
            image = UIImage(named: imgName)
        } else {
            image = UIImage(named: "Wallpaper_4")
        }
        let imageView = UIImageView(image: image)
        //    let imageView = UIImageView(image: UIImage(named: "chat_background"))
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    lazy var blurEffectView: UIVisualEffectView = {
        let blurEffectView = UIVisualEffectView(effect: nil)
        return blurEffectView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.masksToBounds = false
        return view
    }()
    
    lazy var messagesTable: UITableView = {
        let table = UITableView()
        table.delaysContentTouches = true
        table.dataSource = self
        table.delegate = self
        // Register cells
        table.register(MessageCellText.self, forCellReuseIdentifier: Constants.MessageCellText_ID)
        table.register(MessageCell.self, forCellReuseIdentifier: Constants.MessageCell_ID)
        table.register(MessageCellDocument.self, forCellReuseIdentifier: Constants.MessageCellDocument_ID)
        table.register(MessageCellLocation.self, forCellReuseIdentifier: Constants.MessageCellLocation_ID)
        table.register(MessageCellAudio.self, forCellReuseIdentifier: Constants.MessageCellAudio_ID)
        table.register(MessageCellSystem.self, forCellReuseIdentifier: Constants.MessageCellSystem_ID)
        table.register(MessageCellSystemAutoDelete.self, forCellReuseIdentifier: Constants.MessageCellSystemAutoDelete_ID)
        table.register(MessageCellSystemTemporaryChat.self, forCellReuseIdentifier: Constants.MessageCellSystemTemporaryChat_ID)
        table.register(MessageCellAlertCopyForward.self, forCellReuseIdentifier: Constants.MessageCellAlertCopyForward_ID)
        table.register(UnreadMessagesBannerCell.self, forCellReuseIdentifier: Constants.UnreadMessagesBannerCell_ID)
        table.register(MessageCellDeleted.self, forCellReuseIdentifier: Constants.MessageCellDeleted_ID)
        // Register Header / Footer view
        table.register(MessagesSectionHeader.self, forHeaderFooterViewReuseIdentifier: Constants.MessagesSectionHeader_ID)
        
        table.separatorStyle = .none
        table.backgroundColor = .clear
        table.contentInset.bottom = 10
        
        // Hide keyboard on single tap gesture
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        gestureRecognizer.cancelsTouchesInView = false
        table.addGestureRecognizer(gestureRecognizer)
        
        // How context menu on long press gesture
        let longPressCell = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        longPressCell.minimumPressDuration = 0.6
        longPressCell.delegate = self
        longPressCell.cancelsTouchesInView = false
        table.addGestureRecognizer(longPressCell)
        
        return table
    }()
    
    private lazy var tableBottomBorder: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.3))
        view.backgroundColor = .systemGray2
        return view
    }()
    
    lazy var footerView: ChatFooterView = {
        let footer = ChatFooterView(chatViewModel: self.viewModel)
        footer.backgroundColor = .systemGray6
        footer.delegate = self
        footer.cameraBtn.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        return footer
    }()
    
    private lazy var forwardFooterView: MessagesSelectionFooterView = {
        let footer = MessagesSelectionFooterView(chatViewModel: self.viewModel)
        return footer
    }()
    
    private lazy var searchBarFooterView: SearchBarFooterView = {
        let footer = SearchBarFooterView()
        return footer
    }()
    
    private lazy var scrollToBottomView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 68, height: 44))
        view.backgroundColor = .white
        view.borderWidth = 0.5
        view.borderColor = .lightGray
        view.cornerRadius = 6
        
        view.dropShadow(color: UIColor.black, opacity: 0.2, offSet: CGSize(width: 0, height: 1), radius: 1, scale: true)
        
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: UIImage.SymbolWeight.light)
        button.setImage(UIImage(systemName: "chevron.down.circle", withConfiguration: config), for: .normal)
        button.tintColor = .link
        button.addTarget(self, action: #selector(scrollToBottomViewPressed), for: .touchUpInside)
        
        view.addSubview(button)
        button.pin.vCenter().left(8)
        
        view.alpha = 0
        
        return view
    }()
    
    @objc private func scrollToBottomViewPressed() {
        logi()
        scrollToLastMesssage()
    }
    
    
    // MARK: - Setup
    init(viewModel: ChatViewModel) {
        super.init(frame: .zero)
        self.viewModel = viewModel
        
        backgroundColor = .systemGray6
        
        // As of iOS 9 and later, no need to remove the observer
        // https://developer.apple.com/documentation/foundation/notificationcenter/1407263-removeobserver
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        self.addSubview(backgroundImage)
        self.addSubview(blurEffectView)
        self.addSubview(contentView)
        contentView.addSubview(messagesTable)
        contentView.addSubview(tableBottomBorder)
        contentView.addSubview(footerView)
        contentView.insertSubview(forwardFooterView, belowSubview: footerView)
        contentView.insertSubview(searchBarFooterView, belowSubview: footerView)
        contentView.addSubview(scrollToBottomView)
        
        viewModel.initialMessagesFetched
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (messagesSections) in
                guard let strongSelf = self else { return }
                
                if let contact = strongSelf.viewModel.contact {
                    contact.messagesSections = messagesSections
                }
                else if let group = strongSelf.viewModel.group {
                    group.messagesSections = messagesSections
                }
                
                strongSelf.viewModel.refreshDataSourceUnreadMessagesBannerPosition()
                
                strongSelf.messagesTable.reloadData {
                    if strongSelf.viewModel.unreadMessagesCount > 0 {
                        strongSelf.scrollToLastReadMessage {
                            strongSelf.viewModel.sendAllReadReceipt()
                        }
                    }
                    else {
                        strongSelf.scrollToLastMesssage()
                        strongSelf.viewModel.sendAllReadReceipt()
                    }
                }
                
            }).store(in: &cancellableBag)
        
        viewModel.oldMessagesFetched
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (messagesSections) in
                guard let strongSelf = self else { return }
                
                UIView.performWithoutAnimation {
                    
                    // 1) Get the topmost visible indexpath
                    
                    let firstIndexPath = strongSelf.getTopVisibleIndexPath()
                    
                    if let contact = strongSelf.viewModel.contact {
                        contact.messagesSections = messagesSections
                    }
                    else if let group = strongSelf.viewModel.group {
                        group.messagesSections = messagesSections
                    }
                    
                    // keep the scroll offset to the previous message position
                    if let cell = strongSelf.messagesTable.cellForRow(at: firstIndexPath) as? MessageBaseCell,
                       let newCellIndexPath = strongSelf.viewModel.getIndexPathMessage(msgID: cell.viewModel.message.ID) {
                        strongSelf.messagesTable.reloadData {
                            // Restore Scrolling
                            strongSelf.messagesTable.scrollToRow(at: newCellIndexPath, at: .top, animated: false)
                        }
                    }
                    else if let cell = strongSelf.messagesTable.cellForRow(at: firstIndexPath) as? MessageDefaultCell {
                        if cell is UnreadMessagesBannerCell {
                            strongSelf.messagesTable.reloadData()
                        } else if  let newCellIndexPath = strongSelf.viewModel.getIndexPathMessage(msgID: cell.viewModel.message.ID) {
                            strongSelf.messagesTable.reloadData {
                                // Restore Scrolling
                                strongSelf.messagesTable.scrollToRow(at: newCellIndexPath, at: .top, animated: false)
                            }
                        }
                    }
                    
                }
                
            }).store(in: &cancellableBag)
        
        viewModel.newMessagesFetched
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (messagesSections) in
                guard let strongSelf = self else { return }
                
                // Update the messages sections
                if let contact = strongSelf.viewModel.contact {
                    contact.messagesSections = messagesSections
                    contact.unreadMessages = contact.getRealUnreadMessagesViewModels().map({ (msgViewModel) -> String in
                        return msgViewModel.message.ID
                    })
                }
                else if let group = strongSelf.viewModel.group {
                    group.messagesSections = messagesSections
                    group.unreadMessages = group.getRealUnreadMessagesViewModels().map({ (msgViewModel) -> String in
                        return msgViewModel.message.ID
                    })
                }
                
                if strongSelf.viewModel.canUpdateUnreadMessageBanner {
                    strongSelf.viewModel.refreshDataSourceUnreadMessagesBannerPosition()
                }
                
                strongSelf.viewModel.updateReceiptsAsync()
                
                strongSelf.messagesTable.reloadData {
                    strongSelf.scrollToLastReadMessage(delay: 0.2) {
                        strongSelf.viewModel.sendAllReadReceipt()
                    }
                }
            }).store(in: &cancellableBag)
        
        viewModel.showAlertError.receive(on: DispatchQueue.main).sink { [weak self] (tuple) in
            guard let strongSelf = self, let viewController = strongSelf.findViewController() else { return }
            let alertController = UIAlertController(title: tuple.title, message: tuple.message, preferredStyle: .alert)
            let action1 = UIAlertAction(title: "OK".localized(), style: .default, handler: nil)
            alertController.addAction(action1)
            viewController.present(alertController, animated: true, completion: nil)
        }.store(in: &cancellableBag)
        
        
        viewModel.$isForwardEditing
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self](value) in
                guard let strongSelf = self else { return }
                strongSelf.animateSelectMessagesBottomBar(show: value)
            }).store(in: &cancellableBag)
        
        viewModel.$isDeleteEditing
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (value) in
                guard let strongSelf = self else { return }
                strongSelf.animateSelectMessagesBottomBar(show: value)
            }).store(in: &cancellableBag)
        
        viewModel.screenshotTaken
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (screenshot) in
                guard let strongSelf = self else { return }
                if let data = screenshot.jpegData(compressionQuality: 0.5) {
                    let fileUrl = AppUtility.getTemporaryDirectory().appendingPathComponent("\(UUID().uuidString).jpeg")
                    do {
                        try data.write(to: fileUrl)
                        //          "alert:#screenshot"
                        strongSelf.viewModel.sendFile(filePath: fileUrl.path, body: "alert:#screenshot")
                    } catch {
                        logi(error)
                    }
                }
                //        strongSelf.viewModel.sendChatAlertAsync(alert: .screenshot)
            }).store(in: &cancellableBag)
        
        
        viewModel.$isSearching
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (value) in
                guard let strongSelf = self else { return }
                if value {
                    strongSelf.topSearchBar.show()
                } else {
                    DispatchQueue.global(qos: .background).async {
                        let sections = strongSelf.viewModel.getMessagesSection()
                        for section in sections {
                            for messageViewModel in section.messages where messageViewModel.searchedStringsRange.isEmpty == false {
                                messageViewModel.searchedStringsRange = []
                            }
                        }
                    }
                }
            }).store(in: &cancellableBag)
        
        topSearchBar.isActive.sink { [weak self] (value) in
            guard let strongSelf = self else { return }
            if value == false {
                strongSelf.searchBarFooterView.indexPaths = []
                strongSelf.viewModel.isSearching = false
                if strongSelf.keyboardHeight == 0 {
                    // if the keyboard height is bigger than 0 the layout will be updated from the keyboard event
                    strongSelf.setNeedsLayout()
                    strongSelf.layoutIfNeeded()
                }
            }
        }.store(in: &cancellableBag)
        
        topSearchBar.searchString
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .background))
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .sink { [weak self] (pattern) in
                guard let strongSelf = self else { return }
                
                logi(pattern)
                
                let lowercasePattern = pattern.lowercased()
                
                let sections = strongSelf.viewModel.getMessagesSection()
                if lowercasePattern.count < 2 {
                    strongSelf.searchBarFooterView.indexPaths = []
                    for section in sections {
                        for messageViewModel in section.messages where messageViewModel.searchedStringsRange.isEmpty == false {
                            messageViewModel.searchedStringsRange = []
                        }
                    }
                }
                else {
                    var matchedIndexPath: [IndexPath] = []
                    for (sectionIndex, section) in sections.enumerated() {
                        for (messageIndex, messageViewModel) in section.messages.enumerated() where messageViewModel.message.body.isEmpty == false && (messageViewModel.message.type == .text || messageViewModel.message.type == .photo || messageViewModel.message.type == .video) {
                            
                            // all the patterns we have to search in a the string
                            var patterns = lowercasePattern.words().filter { $0.count >= 2 }
                            // remove any dupliated strings
                            patterns = patterns.removeDuplicates()
                            
                            var realPatterns: [String] = []
                            if patterns.count > 1 {
                                for p1 in patterns {
                                    var added = false
                                    for p2 in patterns where p2 != p1 && realPatterns.contains(p1) == false {
                                        if p2.starts(with: p1) {
                                            realPatterns.removeAll { (str) -> Bool in
                                                str.starts(with: p1) || p1.starts(with: str)
                                            }
                                            added = true
                                            realPatterns.append(p1)
                                        }
                                        
                                        if added == false {
                                            realPatterns.append(p1)
                                        }
                                    }
                                }
                            } else {
                                realPatterns = patterns
                            }
                            
                            // Every real pattern must have a match, otherwise no workds will be highlited
                            var rpMatched: [String] = []
                            let sourceString = messageViewModel.message.body.lowercased()
                            var selectedRanges: [NSRange] = []
                            
                            // the following table will be used to keep trak of the starting index of a word.
                            // In cases where there are multiple identical words we will use the last index as a starting point for the match.
                            var wordsStartIndexeTable: [String : [String.Index]] = [:]
                            let words = sourceString.words()
                            for word in words {
                                for rp in realPatterns where word.starts(with: rp) {
                                    if let wordIndexes = wordsStartIndexeTable[word], let lastSavedIndex = wordIndexes.last {
                                        if let index = sourceString.index(of: word, startIndex: sourceString.index(lastSavedIndex, offsetBy: word.count)) {
                                            wordsStartIndexeTable[word]?.append(index)
                                            let endIndex = sourceString.index(index, offsetBy: word.count)
                                            selectedRanges.append(NSRange(index..<endIndex, in: sourceString))
                                        }
                                    } else {
                                        if let index = sourceString.index(of: word) {
                                            wordsStartIndexeTable[word] = [index]
                                            let endIndex = sourceString.index(index, offsetBy: word.count)
                                            selectedRanges.append(NSRange(index..<endIndex, in: sourceString))
                                        }
                                    }
                                    
                                    if rpMatched.contains(rp) == false {
                                        rpMatched.append(rp)
                                    }
                                    // we have found a match, so we can continue to the next word
                                    continue
                                }
                            }
                            // Save he member into the chatlist group item.
                            let changeset = StagedChangeset(source: realPatterns, target: rpMatched)
                            
                            if changeset.isEmpty {
                                // Every pattern has been matched
                                messageViewModel.searchedStringsRange = selectedRanges
                                matchedIndexPath.append(IndexPath(row: messageIndex, section: sectionIndex))
                            } else {
                                messageViewModel.searchedStringsRange = []
                            }
                            
                        }
                    }
                    
                    strongSelf.searchBarFooterView.indexPaths = matchedIndexPath
                }
                
            }.store(in: &cancellableBag)
        
        searchBarFooterView.selectedIndexChanged.sink { [weak self] (selectedIndexPath) in
            guard let strongSelf = self else { return }
            strongSelf.messagesTable.scrollToRow(at: selectedIndexPath, at: .middle, animated: true)
            if let cell = strongSelf.messagesTable.cellForRow(at: selectedIndexPath) as? MessageBaseCell {
                cell.bubbleBlinkAnimation()
            } else {
                //retry when the scroll is completed
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
                    if let cell = strongSelf.messagesTable.cellForRow(at: selectedIndexPath) as? MessageBaseCell {
                        cell.bubbleBlinkAnimation()
                    }
                }
            }
        }.store(in: &cancellableBag)
        
        // GROUP Scope
        do {
            // reset the message added fleag
            viewModel.group?.messageAdded
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] (arg) in
                    guard let strongSelf = self, let group = strongSelf.viewModel.group else { return }
                    
                    let contact = group.getGroupMember(message: arg.message)
                    
                    if strongSelf.addMessage(message: arg.message, contact: contact, group: group) {
                        guard strongSelf.window != nil else { return }
                        AppUtility.isAppInForeground { (success) in
                            if success {
                                //                  let scrollDelay = arg.message.type == .photo || arg.message.type == .video ? 0.1 : 0.0
                                strongSelf.appendMessageToTable(addSection: arg.addNewSection, message: arg.message, scrollToBottom: true)
                                if arg.message.status == .incoming {
                                    strongSelf.viewModel.sendAllReadReceipt()
                                }
                            } else {
                                // Message Received when the app was in background.
                                // Refresh the unread banner position
                                strongSelf.viewModel.refreshDataSourceUnreadMessagesBannerPosition()
                            }
                        }
                    }
                }).store(in: &cancellableBag)
            
            viewModel.group?.deletedIndexPathsPublisher
                .receive(on: DispatchQueue.main)
                .filter({ (indexPaths) -> Bool in
                    if indexPaths.isEmpty == false {
                        if let messageViewModel = viewModel.getMessageViewModel(at: indexPaths[0]), messageViewModel.message.type == .deleted {
                            return true
                        }
                    }
                    return false
                })
                .sink(receiveValue: { [weak self](deletedIndexPaths) in
                    guard let strongSelf = self else { return }
                    strongSelf.messagesTable.beginUpdates()
                    strongSelf.messagesTable.reloadRows(at: deletedIndexPaths, with: .automatic)
                    strongSelf.messagesTable.endUpdates()
                }).store(in: &cancellableBag)
        }
        
        // Contact Scope
        do {
            // reset the message added fleag
            viewModel.contact?.messageAdded
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] (arg) in
                    guard let strongSelf = self, let contact = strongSelf.viewModel.contact else { return }
                    
                    if strongSelf.addMessage(message: arg.message, contact: contact) {
                        guard strongSelf.window != nil else { return }
                        AppUtility.isAppInForeground { (success) in
                            if success {
                                //                  let scrollDelay = arg.message.type == .photo || arg.message.type == .video ? 0.1 : 0.0
                                strongSelf.appendMessageToTable(addSection: arg.addNewSection, message: arg.message, scrollToBottom: true)
                                
                                if arg.message.status == .incoming {
                                    strongSelf.viewModel.sendAllReadReceipt()
                                }
                            } else {
                                // Message Received when the app was in background.
                                // Refresh the unread banner position
                                strongSelf.viewModel.refreshDataSourceUnreadMessagesBannerPosition()
                            }
                        }
                    }
                }).store(in: &cancellableBag)
            
            viewModel.contact?.deletedIndexPathsPublisher
                .receive(on: DispatchQueue.main)
                .filter({ (indexPaths) -> Bool in
                    if indexPaths.isEmpty == false {
                        if let messageViewModel = viewModel.getMessageViewModel(at: indexPaths[0]), messageViewModel.message.type == .deleted {
                            return true
                        }
                    }
                    return false
                })
                .sink(receiveValue: { [weak self](deletedIndexPaths) in
                    guard let strongSelf = self else { return }
                    strongSelf.messagesTable.beginUpdates()
                    strongSelf.messagesTable.reloadRows(at: deletedIndexPaths, with: .automatic)
                    strongSelf.messagesTable.endUpdates()
                }).store(in: &cancellableBag)
        }
        
    }
    
    deinit {
        logi("ChatView deinitialized")
    }
    
    
    /// Add message to the Messages Sections
    /// - Parameters:
    ///   - message: the message to add
    ///   - contact: the contact who sent the message
    ///   - group: the group in which the message was sent
    func addMessage(message: Message, contact: BBContact, group: BBGroup? = nil) -> Bool {
        
        // remove Unread Banner if a new message is sent
        if self.window != nil, message.status == .outgoing, viewModel.hasUnreadMessagesBanner, let indexPath = viewModel.getUnreadMessagesBannerIndexPath() {
            
            viewModel.group?.messagesSections[indexPath.section].messages.remove(at: indexPath.row)
            viewModel.contact?.messagesSections[indexPath.section].messages.remove(at: indexPath.row)
            
            if viewModel.getMessagesCount(at: indexPath.section) == messagesTable.numberOfRows(inSection: indexPath.section) - 1 {
                messagesTable.safeDeleteRow(at: indexPath, with: .fade)
            } else {
                messagesTable.reloadData()
            }
            
            viewModel.hasUnreadMessagesBanner = false
        }
        
        if let group = group {
            if group.isMessagePresent(message: message) {
                return false
            }
            
            // Get the lat section
            if group.messagesSections.count == 0 {
                group.messagesSections = [MessagesSection(date: Date(), messages: [MessageViewModel(message: message,
                                                                                                    contact: contact,
                                                                                                    group: group)])]
            }
            else {
                if let lastSection = group.messagesSections.last, lastSection.date.isInToday {
                    
                    let sectionIndex = group.messagesSections.count-1
                    
                    // update the previous message "next message Sender"
                    group.messagesSections[sectionIndex].messages.last?.nextMessageSender = message.sender
                    
                    // Create the message view model and update the previous message sender
                    let messageViewModel = MessageViewModel(message: message, contact: contact, group: group)
                    messageViewModel.previousMessageSender = group.messagesSections[sectionIndex].messages.last?.message.sender
                    
                    // Append the message if is the same day
                    group.messagesSections[sectionIndex].messages.append(messageViewModel)
                    
                    // Be sure that everything is sorted correctly
                    group.messagesSections[sectionIndex].messages.sort {
                        if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 < id2 {
                            return true
                        }
                        return false
                    }
                    
                }
                else {
                    // Create a new Section
                    group.messagesSections.append(
                        MessagesSection(date: Date(), messages: [MessageViewModel(message: message,
                                                                                  contact: contact,
                                                                                  group: group)]))
                }
            }
        }
        else {
            if viewModel.contact!.isMessagePresent(message: message) {
                return false
            }
            
            // Get the lat section
            if viewModel.contact!.messagesSections.count == 0 {
                viewModel.contact!.messagesSections = [MessagesSection(date: Date(), messages: [MessageViewModel(message: message, contact: contact, group: group)])]
            }
            else {
                if let lastSection = contact.messagesSections.last, lastSection.date.isInToday {
                    
                    let sectionIndex = contact.messagesSections.count-1
                    
                    // update the previous message "next message Sender"
                    contact.messagesSections[sectionIndex].messages.last?.nextMessageSender = message.sender
                    
                    // Create the message view model and update the previous message sender
                    let messageViewModel = MessageViewModel(message: message, contact: contact, group: group)
                    messageViewModel.previousMessageSender = contact.messagesSections[sectionIndex].messages.last?.message.sender
                    
                    // Append the message if is the same day
                    contact.messagesSections[contact.messagesSections.count-1].messages.append(messageViewModel)
                    
                    // Be sure that everything is sorted correctly
                    contact.messagesSections[sectionIndex].messages.sort {
                        if let id1 = Int($0.message.ID), let id2 = Int($1.message.ID), id1 < id2 {
                            return true
                        }
                        return false
                    }
                    
                }
                else {
                    // Create a new Section
                    viewModel.contact!.messagesSections.append(
                        MessagesSection(date: Date(), messages: [MessageViewModel(message: message,
                                                                                  contact: contact,
                                                                                  group: group)]))
                }
            }
        }
        return true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        dismissOpaqueBackground()
        backgroundImage.pin.all()
        blurEffectView.pin.all()
        layoutAnimatedView()
    }
    
    private func layoutAnimatedView() {
        if let orientation = screenOrientation {
            if orientation == .portrait {
                contentView.pin.top(pin.safeArea.top).left(pin.safeArea.left).right(pin.safeArea.right).bottom()
            } else {
                contentView.pin.top(pin.safeArea.top).left().right().bottom()
            }
        }
        else {
            contentView.pin.top(pin.safeArea.top).left(pin.safeArea.left).right(pin.safeArea.right).bottom()
        }
        
        if viewModel.isForwardEditing {
            footerView.pin
                .bottom(-footerView.height)
                .left()
                .right()
            searchBarFooterView.pin
                .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                .bottom(-(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom))
                .left()
                .right()
            forwardFooterView.pin
                .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                .bottom()
                .left()
                .right()
            tableBottomBorder.pin.width(100%).bottomCenter(to: forwardFooterView.anchor.topCenter)
            messagesTable.pin.above(of: forwardFooterView).top().left().right()
            
            scrollToBottomView.pin.right(-10).above(of: forwardFooterView).marginBottom(30)
        }
        else if viewModel.isSearching {
            footerView.pin
                .bottom(-footerView.height)
                .left()
                .right()
            forwardFooterView.pin
                .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                .bottom(-(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom))
                .left()
                .right()
            searchBarFooterView.pin
                .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                .bottom()
                .left()
                .right()
            tableBottomBorder.pin.width(100%).bottomCenter(to: searchBarFooterView.anchor.topCenter)
            messagesTable.pin.above(of: searchBarFooterView).top().left().right()
            
            scrollToBottomView.pin.right(-10).above(of: searchBarFooterView).marginBottom(30)
        }
        else {
            let footerHeight = Blackbox.shared.defaultFooterHeight + pin.safeArea.bottom
            
            footerView.pin
                .bottom(keyboardHeight)
                .left()
                .right()
                .height(footerHeight)
            
            forwardFooterView.pin
                .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                .bottom(-(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom))
                .left()
                .right()
            
            searchBarFooterView.pin
                .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                .bottom(-(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom))
                .left()
                .right()
            
            
            tableBottomBorder.pin.width(100%).bottomCenter(to: footerView.anchor.topCenter)
            messagesTable.pin.top().width(100%).bottomCenter(to: tableBottomBorder.anchor.topCenter)
            
            scrollToBottomView.pin.right(-10).above(of: footerView).marginBottom(30)
        }
        
    }
    
    private func getTopVisibleRow() -> Int {
        //We need this to accounts for the translucency below the nav bar
        if let chatVC = Blackbox.shared.chatViewController, let navigation = chatVC.navigationController {
            let navBar = navigation.navigationBar
            let whereIsNavBarInTableView = messagesTable.convert(navBar.bounds, from: navBar)
            let pointWhereNavBarEnds = CGPoint(x: 0, y: whereIsNavBarInTableView.origin.y + whereIsNavBarInTableView.size.height + 1)
            let accurateIndexPath = messagesTable.indexPathForRow(at: pointWhereNavBarEnds)
            return accurateIndexPath?.row ?? 0
        }
        return 0
    }
    
    private func getTopVisibleIndexPath() -> IndexPath {
        //We need this to accounts for the translucency below the nav bar
        if let chatVC = Blackbox.shared.chatViewController, let navigation = chatVC.navigationController {
            let navBar = navigation.navigationBar
            let whereIsNavBarInTableView = messagesTable.convert(navBar.bounds, from: navBar)
            let pointWhereNavBarEnds = CGPoint(x: 0, y: whereIsNavBarInTableView.origin.y + whereIsNavBarInTableView.size.height + 1)
            if let accurateIndexPath = messagesTable.indexPathForRow(at: pointWhereNavBarEnds) {
                return accurateIndexPath
            }
        }
        return IndexPath(row: 0, section: 0)
    }
    
    private func heightDifferenceBetweenTopRowAndNavBar() -> CGFloat {
        if let chatVC = Blackbox.shared.chatViewController, let navigation = chatVC.navigationController {
            let rectForTopRow = messagesTable.rectForRow(at:IndexPath(row:  getTopVisibleRow(), section: 0))
            let navBar = navigation.navigationBar
            let whereIsNavBarInTableView = messagesTable.convert(navBar.bounds, from: navBar)
            let pointWhereNavBarEnds = CGPoint(x: 0, y: whereIsNavBarInTableView.origin.y + whereIsNavBarInTableView.size.height)
            let differenceBetweenTopRowAndNavBar = rectForTopRow.origin.y - pointWhereNavBarEnds.y
            return differenceBetweenTopRowAndNavBar
        }
        return 0.0
    }
    
    private func animateSelectMessagesBottomBar(show: Bool) {
        guard viewModel.isSearching == false else { return }
        
        UIView.animate(withDuration: 0.2) {
            self.blurEffectView.effect = show ? UIBlurEffect(style: .light) : nil
        }
        
        //    self.blurEffectView.isHidden = !show
        
        if show {
            UIView.animate(withDuration: 0.12, animations: {
                self.footerView.pin.bottom(-self.footerView.frame.height)
            }) { (result) in
                UIView.animate(withDuration: 0.12) {
                    self.forwardFooterView.pin
                        .bottom()
                        .height(Blackbox.shared.defaultFooterHeight+self.pin.safeArea.bottom)
                        .left()
                        .right()
                }
            }
        }
        else {
            viewModel.removeSelectedMessages()
            
            UIView.animate(withDuration: 0.12, animations: {
                self.forwardFooterView.pin
                    .bottom(-self.forwardFooterView.frame.height)
                    .left()
                    .right()
            }) { (result) in
                UIView.animate(withDuration: 0.12) {
                    self.footerView.pin.bottom(self.keyboardHeight)
                }
            }
        }
    }
    
}

extension ChatView {
    /**
     Scroll the message table if is already scrolled to the bottom
     */
    func scrollToLastMesssage(animated: Bool = true, delay: Double = 0.0, completion block: (() -> Void)? = nil) {
        // we need a delay otherwise the table is not scrolled correctly
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: {
            let numSections = self.messagesTable.numberOfSections
            if numSections > 0 {
                let numRows = self.messagesTable.numberOfRows(inSection: numSections-1)
                if numRows > 0 {
                    self.messagesTable.safeScrollToRow(at: IndexPath(row: numRows-1, section: numSections-1), at: .top, animated: animated)
                }
            }
            block?()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.updateTableSectionHeadersVisibility()
            })
        })
    }
    
    func scrollToLastReadMessage(animated: Bool = true, delay: Double = 0.0, completion block: (() -> Void)? = nil) {
        // we need a delay otherwise the table is not scrolled correctly
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: {
            
            if let unreadBannerIndexPath = self.viewModel.getUnreadMessagesBannerIndexPath() {
                self.messagesTable.safeScrollToRow(at: unreadBannerIndexPath, at: .middle, animated: animated)
                self.updateTableSectionHeadersVisibility()
            }
            
            block?()
        })
    }
    
    /**
     Scroll the message table if is already scrolled to the bottom
     */
    func scrollTo(indexPath: IndexPath, animated: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.messagesTable.safeScrollToRow(at: indexPath, at: .bottom, animated: animated)
            strongSelf.updateTableSectionHeadersVisibility()
        }
    }
    
}

// MARK: - Actions / Selectors
extension ChatView {
    @objc fileprivate func hideKeyboard() {
        footerView.msgTextView.resignFirstResponder()
        topSearchBar.hideKeyboard()
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        if let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let newHeight = UIScreen.main.bounds.height - endFrame.origin.y - safeAreaInsets.bottom
            if keyboardHeight != newHeight {
                keyboardHeight = newHeight < 0 ? 0 : newHeight
                
                if viewModel.isSearching == false {
                    searchBarFooterView.pin
                        .height(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom)
                        .bottom(-(Blackbox.shared.defaultFooterHeight+pin.safeArea.bottom))
                        .left()
                        .right()
                    
                    footerView.pin.bottom(keyboardHeight)
                    tableBottomBorder.pin.bottomCenter(to: footerView.anchor.topCenter)
                    if keyboardHeight == 0 {
                        messagesTable.pin.above(of: tableBottomBorder).top()
                    }
                    else {
                        messagesTable.pin.above(of: tableBottomBorder)
                    }
                    messagesTable.contentInset.top = keyboardHeight + (footerView.frame.size.height - Blackbox.shared.defaultFooterHeight - footerView.bottomSafeAreaHeight)
                    
                    scrollToBottomView.pin.right(-10).above(of: footerView).marginBottom(30)
                }
                else {
                    // Hide the normal footer
                    footerView.pin.bottom(-footerView.height)
                    // Show the search bar footer
                    searchBarFooterView.pin.bottom(keyboardHeight)
                    tableBottomBorder.pin.bottomCenter(to: searchBarFooterView.anchor.topCenter)
                    messagesTable.pin.above(of: tableBottomBorder)
                    messagesTable.contentInset.top = keyboardHeight + (searchBarFooterView.frame.size.height - Blackbox.shared.defaultFooterHeight - footerView.bottomSafeAreaHeight)
                    
                    scrollToBottomView.pin.right(-10).above(of: searchBarFooterView).marginBottom(30)
                }
            }
        }
    }
    
    @objc func longPress(longPressGesture: UILongPressGestureRecognizer) {
        if viewModel.isForwardEditing {
            return
        }
        if longPressGesture.state == .began {
            let point = longPressGesture.location(in: messagesTable)
            
            // Create a copy of the cell at the selected point, add it to an opaque black background
            // and add this backlground to the Windows last view to make it appear on top of everything.
            // Gaining the effect of Highliting the selected Cell.
            // Dismiss the background on tap.
            if point != .zero {
                
                // Cast the cell to the MessageBaseCell because at this point we just need the take screenshot of it.
                guard let indexPath = messagesTable.indexPathForRow(at: point), let cell = messagesTable.cellForRow(at: indexPath) as? MessageBaseCell else {
                    // Auto Delete dialog
                    showAutoDeleteTimer()
                    return
                }
                
                switch cell.viewModel.message.type {
                case .alertCopy, .alertForward, .alertScreenshot, .alertScreenRecording, .deleted, .systemMessage:
                    // Auto Delete dialog
                    showAutoDeleteTimer()
                    return
                default:
                    break
                }
                
                // Get the cell frame relative to coordinateSpace
                let frame = messagesTable.convert(cell.frame, to: coordinateSpace)
                let cellFrame = CGRect(
                    x: cell.messageRootContainer.frame.origin.x,
                    y: frame.origin.y,
                    width: cell.messageRootContainer.frame.size.width,
                    height: cell.messageRootContainer.frame.size.height
                )
                
                let pointInCell = CGPoint(x: point.x, y: cellFrame.origin.y + (cellFrame.size.height / 2))
                if cellFrame.contains(pointInCell) == true {
                    // Point is over the cell bubble
                    // Add the cell screenshot to the  opaque View
                    opaqueView.contentView.removeSubviews()
                    opaqueView.frame = UIScreen.main.bounds
                    let cellView = UIView(frame: cellFrame)
                    opaqueView.contentView.addSubview(cellView)
                    let imageView = UIImageView(image: cell.messageRootContainer.takeScreenshot())
                    cellView.addSubview(imageView)
                    imageView.pin.all()
                    
                    // Add the opaque view as the Window top view
                    AppUtility.getLastVisibleWindow().addSubview(opaqueView)
                    
                    // Show the correct popup items based on the cell type, message content and chat type
                    var items = [Menu]()
                    if cell.viewModel.message.isStarred {
                        items.append(Menu(icon: UIImage(systemName: "star.fill"), title: "Unstar".localized(), action: { [weak self] in
                            guard let strongSelf = self else { return }
                            strongSelf.viewModel.contact?.unsetStarredMessage(messageViewModel: cell.viewModel, completion: { (success) in
                                DispatchQueue.main.async {
                                    if success == false {
                                        SCLAlertView().showError("Error", subTitle: "Something went wrong while connecting to the server.")
                                    }
                                }
                            })
                            strongSelf.viewModel.group?.unsetStarredMessage(messageViewModel: cell.viewModel, completion: { (success) in
                                DispatchQueue.main.async {
                                    if success == false {
                                        SCLAlertView().showError("Error", subTitle: "Something went wrong while connecting to the server.")
                                    }
                                }
                            })
                        }))
                    } else {
                        items.append(Menu(icon: UIImage(systemName: "star.fill"), title: "Star".localized(), action: { [weak self] in
                            guard let strongSelf = self else { return }
                            strongSelf.viewModel.contact?.setStarredMessage(messageViewModel: cell.viewModel, completion: { (success) in
                                DispatchQueue.main.async {
                                    if success == false {
                                        SCLAlertView().showError("Error", subTitle: "Something went wrong while connecting to the server.")
                                    }
                                }
                            })
                            strongSelf.viewModel.group?.setStarredMessage(messageViewModel: cell.viewModel, completion: { (success) in
                                DispatchQueue.main.async {
                                    if success == false {
                                        SCLAlertView().showError("Error", subTitle: "Something went wrong while connecting to the server.")
                                    }
                                }
                            })
                        }))
                    }
                    
                    items.append(contentsOf: [
                        Menu(icon: UIImage(systemName: "arrowshape.turn.up.left.fill"), title: "Reply".localized(), action: { [weak self] in
                            guard let strongSelf = self else { return }
                            strongSelf.footerView.addChatFooterReplyView(message: cell.viewModel.message, contact: cell.viewModel.contact)
                        }),
                        Menu(icon: UIImage(systemName: "arrowshape.turn.up.right.fill"), title: "Forward".localized(), action: { [weak self] in
                            guard let strongSelf = self else { return }
                            strongSelf.hideKeyboard()
                            strongSelf.viewModel.isForwardEditing = true
                            cell.viewModel.isSelected = true
                            strongSelf.viewModel.addSelectedMessage(cellViewModel: cell.viewModel)
                        })]
                    )
                    
                    // add the Copy item only if the message has text
                    if cell.viewModel.message.body.isEmpty == false && (cell is MessageCell || cell is MessageCellText) {
                        items.append(Menu(icon: UIImage(systemName: "doc.on.clipboard.fill"), title: "Copy".localized(), action: { [weak self] in
                            guard let strongSelf = self else { return }
                            UIPasteboard.general.string = cell.viewModel.message.body
                            if cell.viewModel.isSent == false {
                                strongSelf.viewModel.sendChatAlertAsync(alert: .messageCopied, message: cell.viewModel.message)
                            }
                        }))
                    }
                    
                    // Add info item if it is a sent message
                    if cell.viewModel.isSent {
                        items.append(
                            Menu(icon: UIImage(systemName: "info.circle.fill"), title: "Info".localized(), action: {
                                let infoVc = MessageInfoViewController(messageViewModel: cell.viewModel)
                                if let chatVC = Blackbox.shared.chatViewController {
                                    chatVC.navigationController?.pushViewController(infoVc, animated: true)
                                }
                            })
                        )
                        
                        items.append(
                            Menu(icon: UIImage(systemName: "trash.fill"), title: "Delete".localized(), action: { [weak self] in
                                guard let strongSelf = self else { return }
                                strongSelf.hideKeyboard()
                                strongSelf.viewModel.isDeleteEditing = true
                                cell.viewModel.isSelected = true
                                strongSelf.viewModel.addSelectedMessage(cellViewModel: cell.viewModel)
                            })
                        )
                    }
                    
                    
                    
                    // Add these items it it is a message received from a group
                    if viewModel.isGroupChat, !cell.viewModel.isSent {
                        items.append(Menu(
                            icon: UIImage(systemName: "arrowshape.turn.up.left.fill"),
                            title: "Reply Privately".localized(),
                            action: {
                                logi("Reply Privately")
                            }))
                        items.append(Menu(
                            icon: UIImage(systemName: "bubble.left.fill"),
                            title: "\("Message".localized()) \(cell.viewModel.contact.getName())",
                            action: {
                                Blackbox.shared.chatListViewController?.openChat(contact: cell.viewModel.contact)
                            }))
                    }
                    
                    let pointInParent = convert(point, from: messagesTable)
                    let popupMenu = PopupMenu(menuItems: items, tapPoint: pointInParent, superview: opaqueView)
                    popupMenu.popUp()
                    
                    Vibration.light.vibrate()
                } else {
                    showAutoDeleteTimer()
                }
            }
        }
    }
    
    /// Gest remove the opaque view from the superview and remove every subviews
    @objc func dismissOpaqueBackground() {
        opaqueView.removeFromSuperview()
        opaqueView.contentView.removeSubviews()
    }
    
    func showAutoDeleteTimer() {
        if let group = viewModel.group, group.role == .normal {
            return
        }
        // Auto Delete dialog
        let timer = self.viewModel.contact != nil ? self.viewModel.contact!.chatAutoDeleteTimer : self.viewModel.group!.chatAutoDeleteTimer
        autoDeleteDialog.show(initialValue: timer)
    }
    
}



extension ChatView: MessageAutoDeleteDialogDelegate {
    func didSelectTime(time: MessageAutoDeleteTimer) {
        
        func autoDeleteFaield() {
            DispatchQueue.main.async {
                SCLAlertView().showError("Error".localized(), subTitle: "Something went wrong while connecting to the server.".localized())
            }
        }
        
        viewModel.contact?.setAutoDeleteMessagesAsync(seconds: time.getSeconds(), completion: { success in
            if success == false {
                autoDeleteFaield()
            }
        })
        viewModel.group?.setAutoDeleteMessagesAsync(seconds: time.getSeconds(), completion: { success in
            if success == false {
                autoDeleteFaield()
            }
        })
    }
}

extension ChatView: ChatFooterViewDelegate {
    func didSendText(body: String, replyTo message: Message?) {
        viewModel.sendTextMessage(text: body, replyTo: message)
    }
    
    func didSendAudio(filePath: String, replyTo message: Message?) {
        if FileManager.default.fileExists(atPath: filePath) {
            viewModel.sendFile(filePath: filePath, replyTo: message)
        }
    }
    
    func appendMessageToTable(addSection: Bool, message: Message, scrollToBottom: Bool = true, scrollDelay: Double = 0.0) {
        guard let messageIndexPath = viewModel.getIndexPathMessage(msgID: message.ID) else { return }
        
        // Check if the number of sections are the same after the update to prevent crashes
        if addSection {
            if messagesTable.numberOfSections == 0 {
                // if the Table is empty, just add the new section
                messagesTable.insertSections(IndexSet(integer: 0), with: .none)
            } else {
                // else we check if the total number of messages i
                let newNumOfSections = viewModel.getMessagesSection().count
                if messagesTable.numberOfSections+1 == newNumOfSections {
                    messagesTable.insertSections(IndexSet(integer: newNumOfSections-1), with: .none)
                } else {
                    messagesTable.reloadData()
                }
            }
        }
        else {
            if messagesTable.numberOfSections > messageIndexPath.section, messagesTable.numberOfRows(inSection: messageIndexPath.section) + 1 == viewModel.getMessagesCount(at: messageIndexPath.section) {
                // Insert the new message
                messagesTable.insertRows(at: [messageIndexPath], with: .bottom)
            } else {
                messagesTable.reloadData()
            }
        }
        
        if message.status == .incoming, let unreadIndexPath = viewModel.getUnreadMessagesBannerIndexPath() {
            if let cell = messagesTable.cellForRow(at: unreadIndexPath) as? UnreadMessagesBannerCell {
                let count = messagesTable.numberOfRows(inSection: unreadIndexPath.section) - (unreadIndexPath.row + 1) // indexPath.row index start from zero, so we add 1
                if viewModel.unreadMessagesCount > 1 {
                    cell.unreadMessagesLabel.text = "\(count) \("Unread messages".localized().uppercased())"
                } else {
                    cell.unreadMessagesLabel.text = "\(count) \("Unread message".localized().uppercased())"
                }
            }
        }
        
        if scrollToBottom && messageIndexPath == viewModel.getLastMessageIndexPath()  {
            scrollToLastMesssage(animated: true, delay: scrollDelay)
        }
    }
    
    func heightDidChange(height: CGFloat) {
        guard viewModel.isSearching == false else { return }
        UIView.animate(withDuration: 0.2) {
            self.footerView.pin.bottom(self.keyboardHeight)
            self.tableBottomBorder.pin.bottomCenter(to: self.footerView.anchor.topCenter)
            self.messagesTable.pin.above(of: self.tableBottomBorder)
            self.messagesTable.contentInset.top += height
            self.scrollToBottomView.pin.above(of: self.footerView).marginBottom(30)
        }
    }
    
    func configureAction(action: UIAlertAction, imageName: String) {
        let image = UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(scale: .large))
        action.setValue(image, forKey: "image")
        action.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
    }
    
    func multiChoiceAttachmentClick() {
        guard let viewController = findViewController() else { return }
        //    guard let viewController = Blackbox.shared.chatViewController else { return }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.permittedArrowDirections = .down
        
        let cameraAction = UIAlertAction(title: "Camera".localized(), style: .default) { _ in
            self.openCamera()
        }
        let libraryAction = UIAlertAction(title: "Photo & Video Library".localized(), style: .default) { _ in
            self.openLibrary()
        }
        let documentsAction = UIAlertAction(title: "Document".localized(), style: .default) { _ in
            self.attachDocument()
        }
        let locationAction = UIAlertAction(title: "Location".localized(), style: .default) { _ in
            self.attachLocation()
        }
        let _ = UIAlertAction(title: "Contact".localized(), style: .default) { _ in
            self.attachContact()
        }
        
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        
        configureAction(action: cameraAction, imageName: "camera")
        configureAction(action: libraryAction, imageName: "photo")
        configureAction(action: documentsAction, imageName: "doc")
        configureAction(action: locationAction, imageName: "mappin.and.ellipse")
        //    configureAction(action: contactAction, imageName: "person.circle")
        
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(documentsAction)
        alertController.addAction(locationAction)
        //    alertController.addAction(contactAction)
        alertController.addAction(cancel)
        
        // force actions background color to white
        if let view = alertController.view.subviews.first, let view2 = view.subviews.first {
            view2.subviews.forEach {
                $0.backgroundColor = .white
            }
        }
        
        // iOS Bug: https://stackoverflow.com/a/58666480/1232289
        for subView in alertController.view.subviews {
            for constraint in subView.constraints where constraint.debugDescription.contains("width == - 16") {
                subView.removeConstraint(constraint)
            }
        }
        
        viewController.present(alertController, animated: true, completion: nil)
    }
    
    @objc private func openCamera() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let viewController = Blackbox.shared.chatViewController else { return }
            strongSelf.imagePickerController.sourceType = .camera
            strongSelf.imagePickerController.modalPresentationStyle = .fullScreen
            /*
             videoQuality resolution width/height:
             - typeHigh             = 1080x1920
             - typeMedium           = 360x480
             - typeIFrame1280x720   = 1280x720
             */
            strongSelf.imagePickerController.videoQuality = .type640x480
            viewController.present(strongSelf.imagePickerController, animated: true, completion: nil)
        }
    }
    
    private func openLibrary() {
        //    guard let viewController = Blackbox.shared.chatViewController else { return }
        //    imagePickerController.sourceType = .photoLibrary
        //    imagePickerController.mediaTypes = ["public.image", "public.movie"]
        //    imagePickerController.modalPresentationStyle = .fullScreen
        //    viewController.present(imagePickerController, animated: true, completion: nil)
        
        guard let vc = findViewController() else { return }
        let pickerConfig = AssetsPickerConfig()
        pickerConfig.albumIsShowEmptyAlbum = false
        pickerConfig.assetsMaximumSelectionCount = 15;
        
        let picker = AssetsPickerViewController()
        picker.pickerConfig = pickerConfig
        picker.isShowLog = false
        picker.pickerDelegate = self
        picker.modalPresentationStyle = .fullScreen
        vc.present(picker, animated: true, completion: nil)
    }
    
    private func attachDocument() {
        guard let viewController = Blackbox.shared.chatViewController else { return }
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(
            documentTypes: ["com.apple.iwork.pages.pages",
                            "com.apple.iwork.pages.sffpages",
                            "com.apple.iwork.numbers.numbers",
                            "com.apple.iwork.keynote.key",
                            "com.microsoft.excel.xls",
                            "com.microsoft.word.doc",
                            "com.adobe.pdf",
                            "public.composite-content",
                            "public.image",
                            "public.movie",
                            "public.audio",
                            "com.microsoft.powerpoint.​ppt"],
            in: UIDocumentPickerMode.import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .fullScreen
        viewController.present(documentPicker, animated: true, completion: nil)
    }
    
    private func attachLocation() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let viewController = Blackbox.shared.chatViewController else { return }
            let locationPicker = LocationPicker(delegate: strongSelf)
            locationPicker.Show(to: viewController)
        }
    }
    
    private func attachContact() {
        ContactsHelper.requestForAccess { [weak self] (access) in
            guard let strongSelf = self, let viewController = strongSelf.findViewController() else { return }
            
            ContactsPickerConfig.doneString = "OK".localized()
            let contactsPiker = ContactsPicker(sourceType: .phone)
            contactsPiker.delegate = self
            contactsPiker.isDataGrouped = true
            contactsPiker.Show(to: viewController)
        }
    }
}

extension ChatView: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.getMessagesSection().count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Constants.MessagesSectionHeader_ID) as? MessagesSectionHeader else { return UIView()}
        header.labelBackgroundView.alpha = 1
        let date = viewModel.getMessagesSectionDate(at: section)
        
        if date.isInToday {
            header.titleLabel.text = "Today".localized()
        } else if date.isInYesterday {
            header.titleLabel.text = "Yesterday".localized()
        } else if date.isInCurrentWeek {
            header.titleLabel.text = date.dayName()
        } else if date.isInCurrentYear {
            header.titleLabel.text = Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM d") : date.dateStringIslamic(withFormat: "E, MMM d")
        } else {
            header.titleLabel.text = Blackbox.shared.account.settings.calendar == .gregorian ? date.string(withFormat: "E, MMM yyyy") : date.dateStringIslamic(withFormat: "E, MMM yyyy")
        }
        
        return header
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.getMessagesCount(at: section)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let messageViewModel = viewModel.getMessageViewModel(at: indexPath) {
            
            if messageViewModel.message.type == .alertScreenshot || messageViewModel.message.type == .alertScreenRecording {
                let label = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: 0))
                label.font = UIFont.appFont(ofSize: 16)
                label.textAlignment = .center
                label.numberOfLines = 0
                label.adjustsFontForContentSizeCategory = true
                label.text = "A"
                
                // 4x or 3x label height based on message type
                var height = messageViewModel.message.type == .alertScreenshot ? label.requiredHeight * 4 : label.requiredHeight * 3
                // top margin 4 + bottom margin 4 = 8
                height += 8
                // space between each label
                // 2 space from alertTypeLabel to contentLabel
                // 2 space from contentLabel to dateLabel
                // 2 space from dateLabel to previewLabel
                height += 6
                // 8 space from alertTypeLabel to top
                // 8 space from previewLabel to bottom
                height += 16
                
                return height
            }
            
            if messageViewModel.message.type == .unreadMessages {
                let label = UILabel(text: "1000 UNREAD MESSAGES", style: .body)
                label.frame = CGRect(x: 0, y: 0, width: tableView.width - 40, height: 20)
                label.adjustsFontForContentSizeCategory = true
                return label.requiredHeight + 20
            }
            
            if messageViewModel.message.type == .deleted {
                messageViewModel.recalculateSize = true
            }
            
            guard let orientation = screenOrientation else { return 0 }
            
            if orientation.isPortrait {
                if messageViewModel.bubbleSizePortrait == .zero || messageViewModel.recalculateSize {
                    messageViewModel.bubbleSizePortrait = MessageCell.calculateBubbleSize(viewModel: messageViewModel,
                                                                                          maxWidth: tableView.width)
                }
                messageViewModel.recalculateSize = false
                return messageViewModel.bubbleSizePortrait.height
                
            } else {
                if messageViewModel.message.containAttachment {
                    if messageViewModel.bubbleSizeLandscape == .zero || messageViewModel.recalculateSize {
                        // For attachment the Width is always based on the portrait width, so we just use the height when in landscape.
                        messageViewModel.bubbleSizeLandscape = MessageCell.calculateBubbleSize(viewModel: messageViewModel,
                                                                                               maxWidth: tableView.height,
                                                                                               isPortrait: false)
                    }
                }
                else {
                    if messageViewModel.bubbleSizeLandscape == .zero || messageViewModel.recalculateSize {
                        messageViewModel.bubbleSizeLandscape = MessageCell.calculateBubbleSize(viewModel: messageViewModel,
                                                                                               maxWidth: tableView.width,
                                                                                               isPortrait: false)
                    }
                }
                messageViewModel.recalculateSize = false
                return messageViewModel.bubbleSizeLandscape.height
            }
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let messageViewModel = viewModel.getMessageViewModel(at: indexPath) {
            switch messageViewModel.message.type {
            case .deleted:
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellDeleted_ID, for: indexPath) as? MessageCellDeleted {
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .text, .alertCopy, .alertForward, .alertDelete:
                if messageViewModel.message.isAlertMessage {
                    let cell = MessageCellText()
                    cell.delegate = self
                    cell.viewModel = messageViewModel
                    return cell
                }
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellText_ID, for: indexPath) as? MessageCellText {
                    cell.delegate = self
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .photo, .video:
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCell_ID, for: indexPath) as? MessageCell {
                    cell.delegate = self
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .document(_):
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellDocument_ID, for: indexPath) as? MessageCellDocument {
                    cell.delegate = self
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .location:
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellLocation_ID, for: indexPath) as? MessageCellLocation {
                    cell.delegate = self
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .audio:
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellAudio_ID, for: indexPath) as? MessageCellAudio {
                    cell.delegate = self
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .systemMessage(let type):
                switch type {
                case .temporaryChat:
                    if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellSystemTemporaryChat_ID, for: indexPath) as? MessageCellSystemTemporaryChat {
                        cell.viewModel = messageViewModel
                        return cell
                    }
                case .autoDelete :
                    if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellSystemAutoDelete_ID, for: indexPath) as? MessageCellSystemAutoDelete {
                        cell.viewModel = messageViewModel
                        return cell
                    }
                default:
                    if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellSystem_ID, for: indexPath) as? MessageCellSystem {
                        cell.viewModel = messageViewModel
                        return cell
                    }
                }
            case .alertScreenRecording, .alertScreenshot:
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.MessageCellAlertCopyForward_ID, for: indexPath) as? MessageCellAlertCopyForward {
                    cell.viewModel = messageViewModel
                    return cell
                }
            case .unreadMessages:
                if let cell = messagesTable.dequeueReusableCell(withIdentifier: Constants.UnreadMessagesBannerCell_ID, for: indexPath) as? UnreadMessagesBannerCell {
                    if viewModel.canUpdateUnreadMessageBanner {
                        viewModel.canUpdateUnreadMessageBanner = false
                    }
                    let count = tableView.numberOfRows(inSection: indexPath.section) - (indexPath.row + 1) // indexPath.row index start from zero, so we add 1
                    if viewModel.unreadMessagesCount > 1 {
                        cell.unreadMessagesLabel.text = "\(count) \("Unread messages".localized().uppercased())"
                    } else {
                        cell.unreadMessagesLabel.text = "\(count) \("Unread message".localized().uppercased())"
                    }
                    cell.viewModel = messageViewModel
                    return cell
                }
            default:
                break
            }
        }
        let cell = UITableViewCell()
        cell.backgroundColor = .clear
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let messageViewModel = viewModel.getMessageViewModel(at: indexPath) {
            switch messageViewModel.message.type {
            case .deleted:
                if let cell = cell as? MessageCellDeleted {
                    cell.viewModel = messageViewModel
                }
            case .text, .alertCopy, .alertForward, .alertDelete:
                if let cell = cell as? MessageCellText {
                    cell.viewModel = messageViewModel
                }
            case .photo, .video:
                if let cell = cell as? MessageCell {
                    cell.viewModel = messageViewModel
                }
            case .document(_):
                if let cell = cell as? MessageCellDocument {
                    cell.viewModel = messageViewModel
                }
            case .location:
                if let cell = cell as? MessageCellLocation {
                    cell.viewModel = messageViewModel
                }
            case .audio:
                if let cell = cell as? MessageCellAudio {
                    cell.viewModel = messageViewModel
                }
            case .systemMessage(let type):
                switch type {
                case .temporaryChat:
                    if let cell = cell as? MessageCellSystemTemporaryChat {
                        cell.viewModel = messageViewModel
                    }
                case .autoDelete :
                    if let cell = cell as? MessageCellSystemAutoDelete {
                        cell.viewModel = messageViewModel
                    }
                default:
                    if let cell = cell as? MessageCellSystem {
                        cell.viewModel = messageViewModel
                    }
                }
            case .alertScreenRecording, .alertScreenshot:
                if let cell = cell as? MessageCellAlertCopyForward {
                    cell.viewModel = messageViewModel
                }
            case .unreadMessages:
                if let cell = cell as? UnreadMessagesBannerCell {
                    if cell.unreadMessagesLabel.text == nil {
                        cell.unreadMessagesLabel.text = "\(viewModel.unreadMessagesCount) \("Unread messages".localized().uppercased())"
                    }
                }
            default:
                break
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            if !scrollView.isDecelerating {
                self.updateTableSectionHeadersVisibility()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            self.updateTableSectionHeadersVisibility()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let indexPaths = messagesTable.indexPathsForVisibleRows, let indexPath = indexPaths.first else { return }
        guard let header = messagesTable.headerView(forSection: indexPath.section) as? MessagesSectionHeader else { return }
        header.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) {
            header.labelBackgroundView.alpha = 1
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.messagesTable.isDragging, !strongSelf.viewModel.isFetching, let paths = strongSelf.messagesTable.indexPathsForVisibleRows, paths.count > 0 {
                let path = paths[0]
                if path.section == 0, path.row <= 15 {
                    // tro to fetch old messages
                    strongSelf.viewModel.isFetching = true
                    strongSelf.viewModel.fetchOldMessagesAsync {
                        strongSelf.viewModel.isFetching = false
                    }
                }
            }
        }
        
        if messagesTable.isTableAtBottom(bottomInsetDistance: 300) {
            self.scrollToBottomView.alpha = 0
        } else {
            self.scrollToBottomView.alpha = 1
        }
    }
    
    func updateTableSectionHeadersVisibility() {
        guard let indexPaths = messagesTable.indexPathsForVisibleRows, let indexPath = indexPaths.first else { return }
        guard let header = messagesTable.headerView(forSection: indexPath.section) as? MessagesSectionHeader else { return }
        
        if indexPath.row == 0 {
            if let cell = messagesTable.cellForRow(at: indexPath){
                let cellAbsoluteFrame = messagesTable.convert(cell.frame, to: self.coordinateSpace)
                let point = messagesTable.convert(header.center, to: self.coordinateSpace)
                if !cellAbsoluteFrame.contains(point) {
                    return
                }
            }
        }
        
        if !messagesTable.isDragging {
            UIView.animate(withDuration: 0.5) {
                header.labelBackgroundView.alpha = 0
            }
        }
        
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
    }
}

extension ChatView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? MessageDefaultCell else { return }
        if cell is UnreadMessagesBannerCell { return }
        
        if cell.viewModel.message.isAlertMessage { return }
        
        if viewModel.isForwardEditing || viewModel.isDeleteEditing {
            cell.viewModel.isSelected = !cell.viewModel.isSelected
            if cell.viewModel.isSelected {
                viewModel.addSelectedMessage(cellViewModel: cell.viewModel)
            } else {
                viewModel.removeFromSelectedMessages(cellViewModel: cell.viewModel)
            }
        }
        
        if cell.viewModel.message.type.isSystemMessageAutoDelete() {
            showAutoDeleteTimer()
        }
        
    }
}

extension ChatView: MessageCellDelegate {
    func didTapReply(messageID: String) {
        if viewModel.isForwardEditing || viewModel.isDeleteEditing {
            return
        }
        
        if let indexPath = viewModel.getIndexPathMessage(msgID: messageID) {
            if let visibleRowsIndexPath = messagesTable.indexPathsForVisibleRows, visibleRowsIndexPath.contains(indexPath) == false {
                messagesTable.scrollToRow(at: indexPath, at: .middle, animated: true)
            }
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
                guard let strongSelf = self else { return }
                if let cell = strongSelf.messagesTable.cellForRow(at: indexPath) as? MessageBaseCell {
                    cell.bubbleBlinkAnimation()
                }
            }
        } else {
            // This is a reply of a old messsage that we don't have in RAM.
            // Fetch old messages and scroll to it
            
            let hud = JGProgressHUD(style: .dark)
            hud.textLabel.text = "Fetching old messages".localized()
            hud.show(in: self)
            
            viewModel.fetchOldMessagesForReplyAsync(replyMsgId: messageID) {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
                    guard let strongSelf = self else { return }
                    hud.dismiss()
                    
                    if let indexPath = strongSelf.viewModel.getIndexPathMessage(msgID: messageID) {
                        strongSelf.messagesTable.scrollToRow(at: indexPath, at: .middle, animated: true)
                        
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
                            guard let strongSelf = self else { return }
                            if let cell = strongSelf.messagesTable.cellForRow(at: indexPath) as? MessageBaseCell {
                                cell.bubbleBlinkAnimation()
                            }
                        }
                    }
                }
            }
        }
        
        //    // TODO: Scroll to replied message
        //    if viewModel.isGroupChat == false {
        //      if let indexPath = viewModel.getIndexPathMessage(msgID: messageID) {
        //        messagesTable.scrollToRow(at: indexPath, at: .middle, animated: true)
        //
        //        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
        //          guard let strongSelf = self else { return }
        //          if let cell = strongSelf.messagesTable.cellForRow(at: indexPath) as? MessageBaseCell {
        //            cell.bubbleBlinkAnimation()
        //          }
        //        }
        //      }
        //    } else {
        //      if let indexPath = viewModel.getIndexPathMessage(msgRef: messageID) {
        //        messagesTable.scrollToRow(at: indexPath, at: .middle, animated: true)
        //
        //        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
        //          guard let strongSelf = self else { return }
        //          if let cell = strongSelf.messagesTable.cellForRow(at: indexPath) as? MessageBaseCell {
        //            cell.bubbleBlinkAnimation()
        //          }
        //        }
        //      }
        //    }
    }
    
    func swipeStarted(indexPath: IndexPath) {
        if currentCellIndexPathSwiped != nil {
            // The previous swipe is still in progress
            return
        }
        currentCellIndexPathSwiped = indexPath
    }
    
    func swipeEnded(indexPath: IndexPath) {
        currentCellIndexPathSwiped = nil
        
        guard let paths = messagesTable.indexPathsForVisibleRows else { return }
        paths.forEach( {
            if let cellViewModel = viewModel.getMessageViewModel(at: $0) {
                cellViewModel.alpha = 1
            }
        })
    }
    
    // Ensure that only 1 cell at the time can swipe
    func shouldSwipe(indexPath: IndexPath) -> Bool {
        if currentCellIndexPathSwiped == nil {
            return false
        }
        if currentCellIndexPathSwiped == indexPath {
            return true
        }
        return false
    }
    
    func didSwipeToShowMessageInfo(otherCellsAlpha: CGFloat, indexPath: IndexPath) {
        guard let paths = messagesTable.indexPathsForVisibleRows else { return }
        
        paths.forEach {
            if let cellViewModel = viewModel.getMessageViewModel(at: $0) {
                cellViewModel.alpha = otherCellsAlpha
            }
        }
    }
    
    func didEndSwipeToShowMessageInfo(messageViewModel: MessageViewModel, indexPath: IndexPath) {
        let infoVc = MessageInfoViewController(messageViewModel: messageViewModel)
        if let chatVC = Blackbox.shared.chatViewController {
            chatVC.navigationController?.pushViewController(infoVc, animated: true)
        }
    }
    
    func didSwipeToReply(at indexPath: IndexPath) {
        if let cellViewModel = viewModel.getMessageViewModel(at: indexPath) {
            if cellViewModel.isSent {
                footerView.addChatFooterReplyView(message: cellViewModel.message)
            } else {
                footerView.addChatFooterReplyView(message: cellViewModel.message, contact: cellViewModel.contact)
            }
        }
    }
}

// MARK: - Attachements
extension ChatView: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        imagePickerController.dismiss(animated: true) {
            if let mediaType = info[.mediaType] as? NSString {
                if mediaType == "public.image" {
                    if let image = info[.originalImage] as? UIImage, let imgRotated = image.fixedOrientation() {
                        // Photo Image original
                        self.openImageEditor(image: imgRotated)
                    } else if let image = info[.editedImage] as? UIImage, let imgRotated = image.fixedOrientation() {
                        // Photo Edited original
                        self.openImageEditor(image: imgRotated)
                    }
                }
                else if mediaType == "public.movie", let fileUrl = info[.mediaURL] as? NSURL {
                    let resSize = self.resolutionSizeForLocalVideo(url: fileUrl)
                    logi(resSize)
                    //          AppUtility.convertVideoToLowQuality(inputURL: fileUrl as URL) { (compressedVideoURL) in
                    //            logi(compressedVideoURL)
                    //          }
                    
                    let newFileUrl = AppUtility.getTemporaryDirectory().appendingPathComponent("\(UUID()).\(fileUrl.pathExtension!)")
                    do {
                        try FileManager.default.copyItem(at: fileUrl.filePathURL!, to: newFileUrl)
                        self.viewModel.sendFile(filePath: newFileUrl.path, replyTo: self.footerView.getReplyMessage())
                    } catch {
                        loge(error)
                    }
                }
            }
        }
        
    }
    
    func resolutionSizeForLocalVideo(url:NSURL) -> CGSize? {
        guard let track = AVAsset(url: url as URL).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
}

extension ChatView: CLImageEditorDelegate {
    
    fileprivate func openImageEditor(image: UIImage) {
        let editor = CLImageEditor(image: image, delegate: self)
        
        editor?.theme.backgroundColor = UIColor.black
        editor?.theme.toolbarColor = UIColor.black.withAlphaComponent(0.8)
        editor?.theme.toolbarTextColor = UIColor.white
        editor?.theme.toolIconColor = "white"
        editor?.theme.statusBarStyle = UIStatusBarStyle.lightContent
        
        let adjustTool = editor?.toolInfo.subToolInfo(withToolName:"CLAdjustmentTool", recursive: false)
        adjustTool?.dockedNumber = 2;
        let blurTool = editor?.toolInfo.subToolInfo(withToolName:"CLBlurTool", recursive:false)
        blurTool?.dockedNumber = 3;
        let rotateTool = editor?.toolInfo.subToolInfo(withToolName: "CLRotateTool", recursive: false)
        rotateTool?.dockedNumber = 0;
        let drawTool = editor?.toolInfo.subToolInfo(withToolName: "CLDrawTool", recursive: false)
        drawTool?.dockedNumber = 1;
        let cropTool = editor?.toolInfo.subToolInfo(withToolName: "CLClippingTool", recursive: false)
        cropTool?.dockedNumber = 5;
        let textTool = editor?.toolInfo.subToolInfo(withToolName: "CLTextTool", recursive: false)
        textTool?.dockedNumber = 4;
        
        //disable tools
        let filterTool = editor?.toolInfo.subToolInfo(withToolName: "CLFilterTool", recursive:false)
        filterTool?.available = false
        let effectTool = editor?.toolInfo.subToolInfo(withToolName: "CLEffectTool", recursive: false)
        effectTool?.available = false
        let resizeTool = editor?.toolInfo.subToolInfo(withToolName: "CLResizeTool", recursive: false)
        resizeTool?.available = false
        let tonecurveTool = editor?.toolInfo.subToolInfo(withToolName: "CLToneCurveTool", recursive: false)
        tonecurveTool?.available = false
        let stickerTool = editor?.toolInfo.subToolInfo(withToolName: "CLStickerTool", recursive:false)
        stickerTool?.available = false
        let splashTool = editor?.toolInfo.subToolInfo(withToolName: "CLSplashTool", recursive: false)
        splashTool?.available = false
        let emoticonTool = editor?.toolInfo.subToolInfo(withToolName: "CLEmoticonTool", recursive: false)
        emoticonTool?.available = false
        
        if let contact = viewModel.contact {
            editor?.replyTo = contact.name as NSString
        } else if let group = viewModel.group {
            editor?.replyTo = group.description as NSString
        }
        
        guard let vc = findViewController() else { return }
        editor?.modalPresentationStyle = .fullScreen
        vc.present(editor!, animated: true, completion: nil)
        //    vc.navigationController?.pushViewController(editor!, animated: true)
    }
    
    
    func imageEditor(_ editor: CLImageEditor!, didSend image: UIImage!, text: String!) {
        if let data = image.jpegData(compressionQuality: 1) {
            let fileUrl = AppUtility.getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).jpeg")
            try? data.write(to: fileUrl)
            
            viewModel.sendFile(filePath: fileUrl.path, body: text, replyTo: footerView.getReplyMessage())
        }
    }
    
}

extension ChatView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // prevent opaque background to be dismissed if tap in on popup cell.
        guard let view = touch.view, let cell = view.superview else { return true }
        if cell.isKind(of: PopupMenuCell.self) {
            return false
        }
        return true
    }
}

extension ChatView: LocationPickerDelegate {
    func didSelectLocation(coordinate: CLLocationCoordinate2D) {
        viewModel.sendLocationMessage(latitude: String(coordinate.latitude), longitude: String(coordinate.longitude))
    }
}

extension ChatView: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == UIDocumentPickerMode.import {
            // This is what it should be
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let fileType = Message.getFileType(fileExtension: url.pathExtension)
                    
                    //
                    if fileType != .text {
                        let fileUrl = AppUtility.getTemporaryDirectory().appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
                        try? data.write(to: fileUrl)
                        self.viewModel.sendFile(filePath: fileUrl.path, replyTo: self.footerView.getReplyMessage())
                    } else {
                        // Unsupported File
                        logw("Unsupported File")
                        SCLAlertView().showWarning("File type not supported".localized(), subTitle: "")
                    }
                    
                } catch {
                    loge(error)
                }
            }
        }
    }
}


extension ChatView: AssetsPickerViewControllerDelegate {
    
    func getImageFromAsset(asset: PHAsset) -> UIImage {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        var thumbnail = UIImage()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight), contentMode: .aspectFill, options: option, resultHandler: {(result, info)->Void in
            thumbnail = result!
        })
        return thumbnail
    }
    
    func assetsPicker(controller: AssetsPickerViewController, selected assets: [PHAsset]) {
        guard assets.count > 0 else { return }
        
        getAssetsObjectsFromPHAssets(assets: assets) { [weak self](assetObjects) in
            guard let strongSelf = self else { return }
            if assetObjects.count == 1 {
                if assetObjects[0].isVideo {
                    strongSelf.compressVideoFiles(objects: assetObjects) { (newObjects) in
                        if newObjects.count(where: {
                            AppUtility.getFileSize($0.url.path) > Blackbox.shared.account.settings.maxDownloadableFileSize
                        }) > 0 {
                            strongSelf.viewModel.showAlertError.send(("File is too big".localized(), ""))
                        }
                        else {
                            strongSelf.viewModel.sendFile(filePath: newObjects[0].url.path, body: "", replyTo: strongSelf.footerView.getReplyMessage())
                        }
                    }
                } else if let image = UIImage.fromPath(assetObjects[0].url.path), let imgRotated = image.fixedOrientation() {
                    strongSelf.openImageEditor(image: imgRotated)
                }
            }
            else {
                strongSelf.compressVideoFiles(objects: assetObjects) { (newObjects) in
                    
                    let validAssetObjects = assetObjects.filter {
                        AppUtility.getFileSize($0.url.path) < Blackbox.shared.account.settings.maxDownloadableFileSize
                    }
                    
                    let diff = newObjects.count - validAssetObjects.count
                    if diff != 0 {
                        let errorTitle = diff == 1 ? "File is too big".localized() : "Some files are too big to send".localized()
                        strongSelf.viewModel.showAlertError.send((errorTitle, ""))
                    }
                    
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        guard let strongSelf = self else { return }
                        for i in 0..<validAssetObjects.count {
                            if i > 0 {
                                usleep(400000)
                            }
                            strongSelf.viewModel.sendFile(filePath: validAssetObjects[i].url.path, body: "", replyTo: strongSelf.footerView.getReplyMessage())
                        }
                    }
                    
                }
            }
        }
    }
    
    /// Get an array on PHAssets and return an array of AssetObject in a callback. The AssetObject contains 2 Porperty, the URL of the file and a a Boolean flag "isVideo"
    /// - Parameters:
    ///   - assets: PHAsset array
    ///   - block: completion block
    private func getAssetsObjectsFromPHAssets(assets: [PHAsset], completion block: (([AssetObject]) -> Void)?) {
        var urls: [AssetObject] = []
        for asset in assets {
            asset.getURL { (url) in
                guard let url = url else { return }
                urls.append(AssetObject(url: url, isVideo: asset.mediaType == .video))
                if urls.count == assets.count {
                    DispatchQueue.main.async {
                        block?(urls)
                    }
                }
            }
        }
    }
    
    
    /// This call is called recursively to compress every Video object witin the AssetObject array. It will return a new AssetObject array with the a new URL to the compressed video.
    /// It will also show a Progress Dialog.
    /// - Parameters:
    ///   - objects: AssetObject array
    ///   - index: the index of the array
    ///   - progressUI: the progress dialog object
    ///   - block: completion block called when e ery file is compressed
    private func compressVideoFiles(objects: [AssetObject], index: Int = 0, progressUI: JGProgressHUD? = nil, completion block: (([AssetObject])->Void)? = nil) {
        if objects[index].isVideo == false {
            if index == objects.count-1 {
                DispatchQueue.main.async {
                    if let hud = progressUI {
                        UIView.animate(withDuration: 0.1, animations: {
                            hud.textLabel.text = "Success!".localized()
                            hud.detailTextLabel.text = nil
                            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                        })
                        hud.dismiss(afterDelay: 1.5)
                    }
                    
                    block?(objects)
                }
            }
            else {
                // recursive call
                compressVideoFiles(objects: objects, index: index+1, progressUI: progressUI, completion: block)
            }
            return
        }
        
        var assetsObjects = objects
        let videosCount = assetsObjects.filter { $0.isVideo }.count
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            
            let hud = progressUI == nil ? JGProgressHUD(style: .dark) : progressUI!
            hud.vibrancyEnabled = true
            hud.indicatorView = JGProgressHUDPieIndicatorView()
            hud.detailTextLabel.text = "0% Complete".localized()
            hud.textLabel.text = "Compressing video \(index+1) of \(videosCount)".localized()
            hud.progress = 0
            
            if progressUI == nil {
                hud.show(in: AppUtility.getLastVisibleWindow())
            }
            
            var resSize = strongSelf.resolutionSizeForLocalVideo(url: assetsObjects[index].url as NSURL)
            logi(resSize)
            
            AppUtility.convertVideoToLowQuality(inputURL: assetsObjects[index].url as URL, compressionProgressBlock: { (progress) in
                // Update the HUS progress
                hud.progress = progress / 100.0
                hud.detailTextLabel.text = "\(Int(progress))% \("Complete".localized())"
            }) { (compressedVideoUrl) in
                // Change the video URL with the compressed one
                assetsObjects[index].setVideoUrl(url: compressedVideoUrl)
                
                resSize = strongSelf.resolutionSizeForLocalVideo(url: compressedVideoUrl as NSURL)
                logi(resSize)
                
                
                if index == assetsObjects.count-1 {
                    // Finish
                    // Show the success Dialog
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.1, animations: {
                            hud.textLabel.text = "Success!".localized()
                            hud.detailTextLabel.text = nil
                            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                        })
                        hud.dismiss(afterDelay: 1.5)
                        
                        // recursive call
                        block?(assetsObjects)
                    }
                } else {
                    // recursive call
                    strongSelf.compressVideoFiles(objects: assetsObjects, index: index+1, progressUI: hud, completion: block)
                }
                
            }
        }
    }
    
    
}
