import UIKit
import Combine
import AVFoundation
import DeviceKit

protocol ChatFooterViewDelegate: class {
  
  /// Called every time the height change
  /// - Parameter height: the new height
  func heightDidChange(height: CGFloat)

  func didSendText(body: String, replyTo message: Message?)
  
  func didSendAudio(filePath: String, replyTo message: Message?)
  
  func multiChoiceAttachmentClick()
}

extension ChatFooterViewDelegate {
  func multiChoiceAttachmentClick() {}
}

class ChatFooterView: UIView {
  
  enum RecordinState {
    case recording
    case locked
    case none
  }
  
  let buttonSize = CGSize(width: 34, height: 34)
  private var leftRightMargin: CGFloat {
    if Device.current.hasSensorHousing, let orientation = screenOrientation, orientation != .portrait  {
      return 50.0
    }
    return 12.0
  }
  
  lazy var bottomSafeAreaHeight: CGFloat = {
    return pin.safeArea.bottom
  }()
  
  weak var delegate: ChatFooterViewDelegate?
  
  var recordinAnimationInitiated = true
  var recordingState: RecordinState = .none {
    didSet {
      if recordingState == .none {
        animatedMicImage.layer.removeAllAnimations()
        recordinAnimationInitiated = false
        
        recordingLabel.alpha = 0
        animatedMicImage.alpha = 0
        chevronLeftImage.alpha = 0
        timerLabel.alpha = 0
        
        // layout elements to
        // Default elements
        let marginLR = leftRightMargin
        let marginTop = self.chatFooterReplyView == nil ? MsgViewMargins.top : (MsgViewMargins.top + ChatFooterReplyView.height)
        self.multiChoiceAttachmentBtn.pin
          .left(marginLR)
          .top(marginTop)
        
        micButton.pin
          .right(marginLR)
          .top(marginTop)
        
        cameraBtn.pin
          .centerRight(to: micButton.anchor.centerLeft)
          .marginRight(10)
        
        msgTextView.pin
          .horizontallyBetween(multiChoiceAttachmentBtn, and: cameraBtn)
          .marginLeft(10)
          .marginRight(20)
          .top(marginTop)
          .height(msgTextViewHeight)
        
        sendButton.pin
          .right(marginLR)
          .top(marginTop)
        
        sendButton.isCircle = true
        
        // Recordin elements
        layoutRecordingElements()
        
        UIView.animate(withDuration: 0.4) {
          self.cameraBtn.alpha = 1
          self.multiChoiceAttachmentBtn.alpha = 1
          self.msgTextView.alpha = 1
        }
        
        timerCount = 0
        recordingTimer?.invalidate()
        timerLabel.text = "00:00"
        
      } else if recordingState == .recording {
        recordinAnimationInitiated = true
        let marginLR = leftRightMargin
        UIView.animate(withDuration: 0.4, animations: {
          self.cameraBtn.alpha = 0
          self.multiChoiceAttachmentBtn.alpha = 0
          self.msgTextView.alpha = 0
          self.recordingLabel.alpha = 1
          self.animatedMicImage.alpha = 1
          self.chevronLeftImage.alpha = 1
          
          self.multiChoiceAttachmentBtn.pin.left(-100)
          self.msgTextView.pin.centerLeft(to: self.multiChoiceAttachmentBtn.anchor.centerRight)
          
          
          var marginTop = MsgViewMargins.top
          if self.chatFooterReplyView != nil {
            marginTop += ChatFooterReplyView.height
          }
          
          self.animatedMicImage.pin.left(marginLR).vCenter(to: self.micButton.edge.vCenter)
          self.timerLabel.pin.centerLeft(to: self.animatedMicImage.anchor.centerRight).marginLeft(10)
          self.recordingLabel.pin.hCenter().vCenter(to: self.micButton.edge.vCenter)
          self.chevronLeftImage.pin.centerLeft(to: self.recordingLabel.anchor.centerRight).marginLeft(4)
          
        }) { (result) in
          if self.recordinAnimationInitiated {
            self.timerLabel.alpha = 1
            self.animatedMicImage.tintColor = .red
            
            // Animate the mic button
            UIView.animate(withDuration: 0.6, delay: 0.0, options: [.curveLinear, .autoreverse, .repeat], animations: {
              self.animatedMicImage.alpha = 0
            }, completion: nil)
            
            // Start recording!
            self.audioRecorder.record(to: nil)
            
            self.recordingTimer = Timer.scheduledTimer(timeInterval: 0.99,
                                                       target: self,
                                                       selector: #selector(self.updateRecordingTimer),
                                                       userInfo: nil,
                                                       repeats: true)
          }
        }
      }
    }
  }
  var recordingStartingPoint = CGPoint.zero
  var recordingLabelStartingX = CGFloat.zero
  
  fileprivate var maxVisibleNumberOfLines = 5
  @Published var isTyping = false
  var typingTimer: DispatchTimer?
  var typingSentTime: DispatchTime?
  
  private lazy var selfMaxHeightPortrait: CGFloat = {
    return msgTextViewMaxHeightPortrait + MsgViewMargins.top_plus_bottom
  }()
  
  private lazy var selfMaxHeightLandscape: CGFloat = {
    return msgTextViewMaxHeightLandscape + MsgViewMargins.top_plus_bottom
  }()
  
  private lazy var msgTextViewMaxHeightPortrait: CGFloat = {
    var newTextView = msgTextView.copyView() as! UITextView
    newTextView.text = "\n\n\n\n"
    return newTextView.sizeThatFits(CGSize(width: newTextView.frame.width, height: .infinity)).height
  }()
  
  private lazy var msgTextViewMaxHeightLandscape: CGFloat = {
    var newTextView = msgTextView.copyView() as! UITextView
    newTextView.text = "\n\n"
    return newTextView.sizeThatFits(CGSize(width: newTextView.frame.width, height: .infinity)).height
  }()
  
  // MARK: - Audio
  private(set) lazy var audioRecorder: AudioRecorderImpl = {
    return AudioRecorderImpl(filename: "record.m4a", recorderOnly: true)
  }()
  
  var recordingTimer: Timer?
  var timerCount = 0
   
  // MARK: - UI Elements
  private var msgTextViewHeight: CGFloat = .zero
  lazy var msgTextView: MessageInputTextView = {
    let textView = MessageInputTextView()
    textView.layer.borderColor = UIColor.systemGray2.cgColor
    textView.layer.borderWidth = 0.3
    textView.verticalScrollIndicatorInsets.right = 6
//    textView.delegate = self
    textView.allowsEditingTextAttributes = false
    textView.font = UIFont.appFont(ofSize: 18, textStyle: .body)
    textView.textContainerInset = UIEdgeInsets(top: 5, left: 7, bottom: 7, right: 8)
    textView.textColor = .black
    return textView
  }()
  
  lazy var multiChoiceAttachmentBtn: UIButton = {
    let button = UIButton(type: .system)
    let large = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "plus"), for: .normal)
    button.tintColor = .link
    button.frame = CGRect(origin: .zero, size: buttonSize)
    return button
  }()
  
  lazy var cameraBtn: UIButton = {
    let button = UIButton(type: .system)
    let large = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "camera", withConfiguration: large), for: .normal)
    button.imageView?.contentMode = .scaleAspectFit
    button.tintColor = .link
    button.backgroundColor = .systemGray6
    button.frame = CGRect(origin: .zero, size: buttonSize)
    return button
  }()

  lazy var sendButton: RoundedButton = {
    let button = RoundedButton(type: .system)
    button.setImage(UIImage(named: "paper_airplane"), for: .normal)
    button.imageEdgeInsets = UIEdgeInsets(top: 6, left: 9, bottom: 6, right: 6)
    button.tintColor = .white
    button.backgroundColor = .link
    button.alpha = 0
    button.addTarget(self, action: #selector(sendButtonPressed), for: .touchUpInside)
    button.frame = CGRect(origin: .zero, size: buttonSize)
    return button
  }()
  
  var chatFooterReplyView: ChatFooterReplyView?
  
  // MARK: Recording UI Elements
  private(set) lazy var micButton: UIButton = {
    let button = UIButton(type: .system)
    let large = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "mic", withConfiguration: large), for: .normal)
    button.imageView?.contentMode = .scaleAspectFit
    button.tintColor = .link
    button.backgroundColor = .systemGray6
    
    let gesture = UILongPressGestureRecognizer(target: self, action: #selector(micButtonLongPress))
    gesture.minimumPressDuration = 0.2
    button.addGestureRecognizer(gesture)
    button.frame = CGRect(origin: .zero, size: buttonSize)
    return button
  }()
  
  private(set) lazy var recordingLabel: UILabel = {
    let label = UILabel()
    label.text = "Slide to cancel".localized()
    label.font = UIFont.appFont(ofSize: 16)
    label.textColor = .systemGray
    label.sizeToFit()
    label.alpha = 0
    return label
  }()
  
  private(set) lazy var chevronLeftImage: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "chevron.left"))
    imageView.contentMode = .scaleAspectFit
    imageView.alpha = 0
    imageView.tintColor = .systemGray
    return imageView
  }()

  private(set) lazy var timerLabel: UILabel = {
    let label = UILabel()
    label.text = "00:00"
    label.textColor = .black
    label.font = UIFont.appFontLight(ofSize: 22)
    label.alpha = 0
    label.sizeToFit()
    return label
  }()
  
  private(set) lazy var animatedMicImage: UIImageView = {
    let large = UIImage.SymbolConfiguration(scale: .large)
    let imageView = UIImageView(image: UIImage(systemName: "mic.fill", withConfiguration: large))
    imageView.tintColor = .systemGray // initial color
    imageView.alpha = 0
    return imageView
  }()
  
  private var cancellableBag = Set<AnyCancellable>()
  
  var chatViewModel: ChatViewModel!
  
  deinit {
    logi("ChatFooterView - deinitialized")
  }
  
  init(chatViewModel: ChatViewModel) {
    super.init(frame: .zero)
    self.chatViewModel = chatViewModel
    
    layer.masksToBounds = false
    backgroundColor = .systemGray5
    
    addSubview(msgTextView)
    addSubview(multiChoiceAttachmentBtn)
    addSubview(cameraBtn)
    addSubview(micButton)
    addSubview(sendButton)
    
    insertSubview(recordingLabel, belowSubview: cameraBtn)
    insertSubview(timerLabel, belowSubview: cameraBtn)
    insertSubview(animatedMicImage, belowSubview: cameraBtn)
    insertSubview(chevronLeftImage, belowSubview: cameraBtn)
    
    multiChoiceAttachmentBtn.addTarget(self, action: #selector(multiChoiceAttachmentClick), for: .touchUpInside)
    
    calculateFooterHeight()

    setupBind()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
 
  override func layoutSubviews() {
    super.layoutSubviews()
      
    if msgTextView.frame.origin.x == 0 {
      layoutInitialState()
    } else {
      let marginLR = leftRightMargin
      micButton.pin.right(marginLR)
      sendButton.pin.right(marginLR)
      multiChoiceAttachmentBtn.pin.left(marginLR)
      
      if isTyping {
        cameraBtn.pin.right(14)
      } else {
        cameraBtn.pin.centerRight(to: micButton.anchor.centerLeft).marginRight(10)
      }
      
      msgTextView.pin
        .horizontallyBetween(multiChoiceAttachmentBtn, and: cameraBtn)
        .marginLeft(10)
        .marginRight(20)
    }
    
  }
  
  func layoutInitialState() {
    // First layout setup call
    
    let marginTop = self.chatFooterReplyView == nil ? MsgViewMargins.top : (MsgViewMargins.top + ChatFooterReplyView.height)
    bottomSafeAreaHeight = pin.safeArea.bottom
    
//    let footerHeight = frame.size.height + bottomSafeAreaHeight
//    pin.height(frame.size.height+bottomSafeAreaHeight)
    
    let footerHeight = frame.size.height
    if msgTextViewHeight == .zero {
      msgTextViewHeight = self.chatFooterReplyView == nil ?
        footerHeight - MsgViewMargins.top_plus_bottom - pin.safeArea.bottom :
        footerHeight - MsgViewMargins.top_plus_bottom - pin.safeArea.bottom - ChatFooterReplyView.height
    }
    
    let marginLR = leftRightMargin
    // Default elements
    multiChoiceAttachmentBtn.pin
      .left(marginLR)
      .top(marginTop)
      
    micButton.pin
      .right(marginLR)
      .top(marginTop)
    
    cameraBtn.pin
      .centerRight(to: micButton.anchor.centerLeft)
      .marginRight(10)
    
    msgTextView.pin
      .horizontallyBetween(multiChoiceAttachmentBtn, and: cameraBtn)
      .marginLeft(10)
      .marginRight(20)
      .top(marginTop)
      .height(msgTextViewHeight)
    
    sendButton.pin
      .right(marginLR)
      .top(marginTop)
    
    sendButton.isCircle = true
    
    // Recordin elements
    layoutRecordingElements()
  }
  
  private func layoutRecordingElements() {
    let marginTop = self.chatFooterReplyView == nil ? MsgViewMargins.top : (MsgViewMargins.top + ChatFooterReplyView.height)
    animatedMicImage.pin.hCenter().top(marginTop)
    timerLabel.pin.centerLeft(to: animatedMicImage.anchor.centerRight).marginLeft(10)
    recordingLabel.pin.centerRight(to: micButton.anchor.centerLeft)
    chevronLeftImage.pin.centerLeft(to: recordingLabel.anchor.centerRight).marginLeft(10)
  }
  
  private func setupBind() {
    $isTyping.receive(on: DispatchQueue.global(qos: .background)).sink(receiveValue: { [weak self] value in
        guard let strongSelf = self else { return }
        
        strongSelf.typingTimer?.disarm()
        strongSelf.typingTimer = nil
        
        if value {
          if let typingSent = strongSelf.typingSentTime {
            let now = DispatchTime.now()
            let nanoTime = now.uptimeNanoseconds - typingSent.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000
            
            if timeInterval > 3 {
              strongSelf.typingTimer = DispatchTimer(countdown: .seconds(3), payload: {
                strongSelf.isTyping = false
              })
              strongSelf.typingTimer?.arm()
              strongSelf.typingSentTime = DispatchTime.now()
              if let contact = strongSelf.chatViewModel.contact {
                contact.sendTypingAsync()
              } else if let group = strongSelf.chatViewModel.group {
                group.sendTypingAsync()
              }
            }
          } else {
            // Started typing
            strongSelf.typingTimer = DispatchTimer(countdown: .seconds(3), payload: {
              strongSelf.isTyping = false
            })
            strongSelf.typingTimer?.arm()
            strongSelf.typingSentTime = DispatchTime.now()
            if let contact = strongSelf.chatViewModel.contact {
              contact.sendTypingAsync()
            } else if let group = strongSelf.chatViewModel.group {
              group.sendTypingAsync()
            }
          }
        } else {
          strongSelf.typingSentTime = nil
        }
      }).store(in: &cancellableBag)
    
    msgTextView.textDidChannge.receive(on: DispatchQueue.main).sink { [weak self](string) in
      guard let strongSelf = self else { return }
      strongSelf.chatViewModel.contact?.unsentMessage = string
      strongSelf.chatViewModel.group?.unsentMessage = string
      strongSelf.updateFooterHeight()
      strongSelf.msgTextView.allowsEditingTextAttributes = !string.isEmpty
    }.store(in: &cancellableBag)
  }
  
  /**
   Calculate the initial Footer Height
   */
  func calculateFooterHeight() {
    
    // calculate footer size based on the UITextView font and padding
    msgTextView.text = "A"
    msgTextView.textContainerInset = UIEdgeInsets(top: 5, left: 7, bottom: 7, right: 8)
    let size = CGSize(width: self.frame.width, height: .infinity)
    let estimatedSize = msgTextView.sizeThatFits(size)
    msgTextView.text = ""
    
    // Set footer height
    Blackbox.shared.defaultFooterHeight = estimatedSize.height + MsgViewMargins.top_plus_bottom
    pin.height(Blackbox.shared.defaultFooterHeight)
    
    // reset the tevieview text
    msgTextView.text = ""
    msgTextView.cornerRadius = estimatedSize.height / 2
  }
  
}

// MARK: Actions & Selectors
extension ChatFooterView {
  /// Trigger delegate function
  @objc private func multiChoiceAttachmentClick() {
    guard let delegate = self.delegate else { return }
    delegate.multiChoiceAttachmentClick()
  }
  
  /// Trigger Delegate function
  @objc fileprivate func sendButtonPressed() {
    guard let delegate = self.delegate else { return }
    let text = msgTextView.getTextToSendInChat().trimmed
    if text.count > 0 {
      delegate.didSendText(body: text, replyTo: chatFooterReplyView?.message)
      msgTextView.clear()
      msgTextView.textColor = .black
      self.chatViewModel.contact?.unsentMessage = ""
      self.chatViewModel.group?.unsentMessage = ""
      closeReplyView()
    }
  }
}

extension ChatFooterView {
  
  func updateFooterHeight() {
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      if strongSelf.msgTextView.text.count > 0 {
        strongSelf.isTyping = true
        
        if strongSelf.sendButton.alpha == 0 {
          UIView.animate(withDuration: 0.2) {
            strongSelf.sendButton.alpha = 1
            strongSelf.micButton.alpha = 0
            strongSelf.cameraBtn.alpha = 0
            strongSelf.cameraBtn.pin.right(14)
            strongSelf.msgTextView.pin
              .horizontallyBetween(strongSelf.multiChoiceAttachmentBtn, and: strongSelf.cameraBtn)
              .marginLeft(10)
              .marginRight(20)
          }
        }
      } else if strongSelf.msgTextView.text.count == 0 {
        strongSelf.isTyping = false
        if strongSelf.sendButton.alpha == 1 {
          UIView.animate(withDuration: 0.2) {
            strongSelf.sendButton.alpha = 0
            strongSelf.micButton.alpha = 1
            strongSelf.cameraBtn.alpha = 1
            strongSelf.cameraBtn.pin.centerRight(to: strongSelf.micButton.anchor.centerLeft).marginRight(10)
            strongSelf.msgTextView.pin
              .horizontallyBetween(strongSelf.multiChoiceAttachmentBtn, and: strongSelf.cameraBtn)
              .marginLeft(10)
              .marginRight(20)
          }
        }
      }
      
      var height = strongSelf.bottomSafeAreaHeight
      height += strongSelf.chatFooterReplyView == nil ? CGFloat.zero : ChatFooterReplyView.height
      var textHeight: CGFloat = .zero
      let size = CGSize(width: strongSelf.msgTextView.frame.width, height: .infinity)
      let estimatedSize = strongSelf.msgTextView.sizeThatFits(size)
      
      if estimatedSize.height > strongSelf.selfMaxHeightPortrait {
        if UIDevice.current.orientation.isLandscape, strongSelf.frame.size.height.rounded() != strongSelf.selfMaxHeightLandscape.rounded() {
          height += strongSelf.selfMaxHeightLandscape
          textHeight = strongSelf.msgTextViewMaxHeightLandscape
        } else if strongSelf.frame.size.height.rounded() != strongSelf.selfMaxHeightPortrait.rounded() {
          height += strongSelf.selfMaxHeightPortrait
          textHeight = strongSelf.msgTextViewMaxHeightPortrait
        } else {
          height += strongSelf.frame.size.height.rounded()
          textHeight = strongSelf.msgTextViewMaxHeightPortrait
        }
      } else {
        height += estimatedSize.height + MsgViewMargins.top_plus_bottom
        textHeight = estimatedSize.height
      }
      strongSelf.msgTextViewHeight = textHeight
      
      let heightDifference = height - strongSelf.frame.size.height
      
      UIView.animate(withDuration: 0.2) {
        strongSelf.pin.height(height)
        var marginTop = MsgViewMargins.top
        if strongSelf.chatFooterReplyView != nil {
          marginTop += ChatFooterReplyView.height
        }
        
        strongSelf.sendButton.pin.top(marginTop)
        strongSelf.micButton.pin.top(marginTop)
        strongSelf.cameraBtn.pin.centerRight(to: strongSelf.micButton.anchor.centerLeft).marginRight(10)
        strongSelf.multiChoiceAttachmentBtn.pin.top(marginTop)
        strongSelf.msgTextView.pin.top(marginTop).height(strongSelf.msgTextViewHeight)
        
        strongSelf.layoutRecordingElements()
      }
      
      if heightDifference != 0 {
        guard let delegate = strongSelf.delegate else { return }
        delegate.heightDidChange(height: heightDifference)
      }
    }
  }
  
  func getReplyMessage() -> Message? {
    return chatFooterReplyView?.message
  }
  
  // MARK: - Recording timer check
  @objc func updateRecordingTimer() {
    timerCount += 1
    
    //(seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    let minutes = (timerCount % 3600) / 60
    let seconds = (timerCount % 3600) % 60
    timerLabel.text = String(format:"%02i:%02i", minutes, seconds)
  }
  
  func addChatFooterReplyView(message: Message, contact: BBContact? = nil) {
    if chatFooterReplyView != nil {
      chatFooterReplyView?.removeFromSuperview()
    }
    
    chatFooterReplyView = ChatFooterReplyView()
    chatFooterReplyView!.set(message: message, contact: contact)
    chatFooterReplyView!.closeButton.addTarget(self, action: #selector(closeReplyView), for: .touchUpInside)
    addSubview(chatFooterReplyView!)
    updateFooterHeight()
  }
  
  @objc func closeReplyView() {
    chatFooterReplyView?.removeFromSuperview()
    chatFooterReplyView = nil
    updateFooterHeight()
  }
  
}

extension ChatFooterView: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {

  }
}
