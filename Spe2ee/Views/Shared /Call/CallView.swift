import Foundation
import UIKit
import Combine
import AVFoundation
import NextLevel
import AVKit
import VideoToolbox
import MarqueeLabel
import BlackboxCore

/// The Call View
class CallView: UIView {
    let captureSession = AVCaptureSession()
    
    private var pause = false
    
    private var call: BBCall?
    private var callTimer = Timer()
    private var callStatusTimer: DispatchTimer?
    
    // Flag used to call confirmVideoCall only once.
    private(set) var videoConfirmed = false
    
    private lazy var fetchIncomingVideoFramesWorker = DispatchWorkItem(qos: .userInteractive) { [weak self] in
        guard let strongSelf = self else { return }
        strongSelf.fetchAndShowCompressedVideoFrames()
    }
    
    private let sendCompressedVideoPacketsQueue = DispatchQueue(label: "sendCompressedVideoPacketsQueue", qos: .userInteractive)
    
    // Video fields
    private var hasStartedReceivingVideoFrames = false
    private var compressedFrameDescription: CMFormatDescription?
    private var incomingFramesNum: UInt64 = 0
    private var isIncomingFirstFrame = true
    
    // Video Compression
    private var compressionSessionOut: VTCompressionSession?
    private let compressionQueue = DispatchQueue(label: "xcurrency.video.frames.compression")
    private var lastSampleBuffer: CMSampleBuffer?
    
    // Combine Framework
    private var cancellableBag = Set<AnyCancellable>()
    
    private final let utilityButtonSizeVoice: CGSize = CGSize(width: 70, height: 70)
    private final let utilityButtonSizeVideo: CGSize = CGSize(width: 56, height: 56)
    private final let utilityImagePointSize: CGFloat = 21.0
    private final let utilityImagePointSizeVideo: CGFloat = 21.0
    private let gradient = CAGradientLayer()
    
    // MARK: UI ELEMENTS
    private var rootView = UIView()
    
    // Video Layer
    private var outgoingVideoPreview: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()
    
    private var incomingVideoPreview: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()
    
    private let incomingVideoProgressIndicator: UIActivityIndicatorView = {
        let loading = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.large)
        loading.color = .white
        loading.startAnimating()
        loading.isHidden = true
        return loading
    }()
    
    private var incomingVideoLayer = AVSampleBufferDisplayLayer()
    
    private(set) var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 12, y: 12, width: 35, height: 35)
        let config = UIImage.SymbolConfiguration(pointSize: 18.5, weight: UIImage.SymbolWeight.semibold)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.isEnabled = false
        return button
    }()
    
    private lazy var infoButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.setImage(UIImage(systemName: "info.circle"), for: .normal)
        button.addTarget(self, action: #selector(infoButtonPressed), for: .touchUpInside)
        button.tintColor = .white
        if let call = self.call {
            button.isHidden = call.members.count > 1 ? false : true
        }
        return button
    }()
    
    private var addContactButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 12, y: 12, width: 35, height: 35)
        let config = UIImage.SymbolConfiguration(pointSize: 21, weight: UIImage.SymbolWeight.light)
        let image = UIImage(systemName: "person.crop.circle.badge.plus", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(addContactPressed), for: .touchUpInside)
        button.isEnabled = true
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 19)
        if let call = self.call {
            label.text = call.hasVideo ? "Video Call".localized() : "Voice Call".localized()
        }
        label.textAlignment = .center
        label.textColor = .white
        label.sizeToFit()
        return label
    }()
    
    private lazy var membersLabel: MarqueeLabel = {
        let label = MarqueeLabel.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width - 80, height: UILabel(text: "A", style: .headline).requiredHeight + 12), rate: 10.0, fadeLength: 10.0)
        label.font = UIFont.appFont(ofSize: 25)
        label.textAlignment = .center
        label.textColor = .white
        label.type = .continuous
        return label
    }()
    
    private lazy var membersProfilesView: CallMembersProfilesView = {
        let view = CallMembersProfilesView(call: self.call!)
        return view
    }()
    
    var callStateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 22)
        label.text = "Connecting...".localized()
        label.textAlignment = .center
        label.textColor = .white
        label.sizeToFit()
        return label
    }()
    
    private lazy var speakerButton: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVoice)
        let config = UIImage.SymbolConfiguration(pointSize: 21, weight: UIImage.SymbolWeight.regular)
        let image = UIImage(systemName: "speaker.3.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGray3
        button.isCircle = true
        button.addTarget(self, action: #selector(self.speakerPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var videoCallButton: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVoice)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSize, weight: UIImage.SymbolWeight.regular)
        let image = UIImage(systemName: "video.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGray3
        button.isCircle = true
        button.addTarget(self, action: #selector(self.videoCallpressed), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private lazy var videoCallButtonVideo: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVideo)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSizeVideo, weight: UIImage.SymbolWeight.regular)
        let image = UIImage(systemName: "video.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGray3
        button.isCircle = true
        button.addTarget(self, action: #selector(self.videoCallpressed), for: .touchUpInside)
        button.isEnabled = true
        return button
    }()
    
    private lazy var muteButton: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVoice)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSize, weight: UIImage.SymbolWeight.regular)
        let image = UIImage(systemName: "mic.slash.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGray3
        button.isCircle = true
        button.addTarget(self, action: #selector(self.mutePressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var muteButtonVideo: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVideo)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSizeVideo, weight: UIImage.SymbolWeight.regular)
        let image = UIImage(systemName: "mic.slash.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGray3
        button.isCircle = true
        button.addTarget(self, action: #selector(self.mutePressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var endCallButton: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVoice)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSize, weight: UIImage.SymbolWeight.light)
        let image = UIImage(systemName: "phone.down.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .red
        button.isCircle = true
        button.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        return button
    }()
    
    private lazy var endCallButtonVideo: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVoice)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSize, weight: UIImage.SymbolWeight.light)
        let image = UIImage(systemName: "phone.down.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .red
        button.isCircle = true
        button.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        return button
    }()
    
    private lazy var videoBottomView: UIView = {
        let view = UIView()
        view.addSubview(videoCallButtonVideo)
        view.addSubview(cameraRotateButton)
        view.addSubview(muteButtonVideo)
        view.addSubview(videoCallButtonVideo)
        view.addSubview(endCallButtonVideo)
        return view
    }()
    
    private lazy var cameraRotateButton: RoundedButton = {
        let button = RoundedButton(type: .system)
        button.frame = CGRect(origin: .zero, size: utilityButtonSizeVideo)
        let config = UIImage.SymbolConfiguration(pointSize: utilityImagePointSizeVideo, weight: UIImage.SymbolWeight.regular)
        let image = UIImage(systemName: "camera.rotate.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGray3
        button.isCircle = true
        button.addTarget(self, action: #selector(self.rotateCameraPressed), for: .touchUpInside)
        return button
    }()
    
    private var speakerButtonLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 13)
        label.textColor = .systemGray3
        label.text = "speaker".localized()
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }()
    
    private var videoCallButtonLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 13)
        label.textColor = .systemGray3
        label.text = "Video Call".localized().lowercased()
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }()
    
    private var muteButtonLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 13)
        label.textColor = .systemGray3
        label.text = "mute".localized()
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }()
    
    private lazy var membersTable: UITableView = {
        let tableView = UITableView()
        tableView.register(CallContactCell.self, forCellReuseIdentifier: CallContactCell.ID)
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.init(white: 1, alpha: 0.3)
        return tableView
    }()
    
    
    init(call: BBCall) {
        self.call = call
        super.init(frame: .zero)
        
        rootView.backgroundColor = .white
        
        addSubview(rootView)
        
        rootView.addSubview(incomingVideoPreview)
        incomingVideoPreview.layer.addSublayer(incomingVideoLayer)
        rootView.addSubview(incomingVideoProgressIndicator)
        rootView.addSubview(outgoingVideoPreview)
        
        rootView.addSubview(backButton)
        rootView.addSubview(infoButton)
        rootView.addSubview(addContactButton)
        rootView.addSubview(titleLabel)
        rootView.addSubview(membersLabel)
        rootView.addSubview(callStateLabel)
        rootView.addSubview(membersProfilesView)
        rootView.addSubview(endCallButton)
        rootView.addSubview(speakerButton)
        rootView.addSubview(speakerButtonLabel)
        rootView.addSubview(videoCallButton)
        rootView.addSubview(videoCallButtonLabel)
        rootView.addSubview(muteButton)
        rootView.addSubview(muteButtonLabel)
        rootView.addSubview(videoBottomView)
        rootView.addSubview(membersTable)
        
        rootView.layer.insertSublayer(gradient, at: 0)
        
        // Update the timer
        periodicallyUpdateStatus()
        
        let nextLevel = NextLevel.shared
        nextLevel.previewLayer = AVCaptureVideoPreviewLayer()
        nextLevel.previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        nextLevel.previewLayer.removeFromSuperlayer()
        nextLevel.automaticallyConfiguresApplicationAudioSession = false
        nextLevel.captureMode = .videoWithoutAudio
        nextLevel.videoDelegate = self
        nextLevel.videoConfiguration.preset = AVCaptureSession.Preset.medium
        nextLevel.devicePosition = .front
        
        outgoingVideoPreview.layer.addSublayer(NextLevel.shared.previewLayer)
        
        setupCombineProps()
    }
    
    deinit {
        call = nil
        if let timer = callStatusTimer {
            timer.disarm()
            callStatusTimer = nil
        }
        logi("CallView Deinitialized")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let call = call else { return }
        
        rootView.pin.all()
        
        //gradient.colors = [Constants.AppMainColorLight.cgColor, Constants.AppMainColorGreen.cgColor]
        gradient.colors = [Constants.AppMainColorGreen.cgColor, Constants.AppMainColorGreen.cgColor]
        gradient.frame = CGRect(x: 0.0, y: 0.0, width: self.frame.size.width, height: self.frame.size.height)
        
        backButton.pin.top(pin.safeArea.top + 8).left(pin.safeArea.left + 5)
        addContactButton.pin.top(pin.safeArea.top + 5).right(pin.safeArea.right + 8)
        addContactButton.isHidden = !(call.isConference && call.isOutgoing)
        titleLabel.pin.horizontallyBetween(backButton, and: addContactButton, aligned: .center)
        
        
        membersLabel.isHidden = call.members.count > 1
        infoButton.isHidden = true
        if call.members.count > 1 {
            callStateLabel.pin.below(of: titleLabel).marginTop(18).left().right()
        }
        else {
            membersLabel.pin.below(of: titleLabel, aligned: .center).marginTop(18)
            infoButton.pin.centerLeft(to: membersLabel.anchor.centerRight).marginLeft(4)
            callStateLabel.pin.below(of: membersLabel).marginTop(6).left().right()
        }
        
        endCallButton.pin.hCenter().bottom(pin.safeArea.bottom+60)
        
        // Hide/Show UI Elements
        membersProfilesView.isHidden = call.hasVideo || call.members.count > 1
        membersTable.isHidden = call.hasVideo || call.members.count <= 1
        //    videoCallButton.isHidden = call.hasVideo || call.isConference
        //    videoCallButtonLabel.isHidden = videoCallButton.isHidden
        videoCallButton.isHidden = true
        videoCallButtonLabel.isHidden = true
        endCallButton.isHidden = call.hasVideo
        speakerButton.isHidden = call.hasVideo
        speakerButtonLabel.isHidden = speakerButton.isHidden
        muteButton.isHidden = call.hasVideo
        muteButtonLabel.isHidden = muteButton.isHidden
        
        
        outgoingVideoPreview.isHidden = !call.hasVideo
        incomingVideoPreview.isHidden = !call.hasVideo
        videoBottomView.isHidden = !call.hasVideo
        incomingVideoProgressIndicator.isHidden = !call.hasVideo
        
        if call.hasVideo {
            videoBottomView.pin.bottom().left().right().height(pin.safeArea.bottom+170)
            
            videoCallButtonVideo.pin
                .hCenter()
                .bottom(pin.safeArea.bottom+20)
            videoCallButton.isCircle = true
            
            muteButtonVideo.pin
                .right(20)
                .bottom(pin.safeArea.bottom+20)
            muteButton.isCircle = true
            
            cameraRotateButton.pin
                .left(20)
                .bottom(pin.safeArea.bottom+20)
            cameraRotateButton.isCircle = true
            
            endCallButtonVideo.pin
                .top()
                .hCenter()
                .marginBottom(pin.safeArea.bottom+20)
            
            incomingVideoPreview.pin.all()
            incomingVideoProgressIndicator.pin.center(to: incomingVideoPreview.anchor.center)
            incomingVideoLayer.videoGravity = .resizeAspectFill
            incomingVideoLayer.frame = incomingVideoPreview.bounds
            incomingVideoLayer.preventsDisplaySleepDuringVideoPlayback = true
            
            if let call = self.call, call.isStarted == false {
                outgoingVideoPreview.pin.all()
            } else {
                //        outgoingVideoPreview.pin.bottom(30).left(30).height(100).aspectRatio(self.frame.size.height/self.frame.size.width)
            }
            
            NextLevel.shared.previewLayer.frame = outgoingVideoPreview.bounds
            
        }
        else {
            endCallButton.pin.hCenter().bottom(pin.safeArea.bottom+60)
            
            videoCallButton.pin
                .size(utilityButtonSizeVoice)
                .above(of: endCallButton, aligned: .center)
                .marginBottom(45)
            videoCallButton.isCircle = true
            videoCallButtonLabel.pin.below(of: videoCallButton, aligned: .center).marginTop(2)
            
            muteButton.pin
                .size(utilityButtonSizeVoice)
                .right(of: videoCallButton, aligned: .center)
            muteButton.isCircle = true
            muteButtonLabel.pin.below(of: muteButton, aligned: .center).marginTop(2)
            
            speakerButton.pin
                .size(utilityButtonSizeVoice)
                .left(of: videoCallButton, aligned: .center)
            speakerButton.isCircle = true
            speakerButtonLabel.pin.below(of: speakerButton, aligned: .center).marginTop(2)
            
            if call.members.count <= 1 {
                membersProfilesView.pin.height(120).left().right().below(of: callStateLabel).marginTop(40)
            }
            else {
                membersTable.pin
                    .verticallyBetween(callStateLabel, and: call.hasVideo ? endCallButtonVideo : videoCallButton)
                    .marginTop(30)
                    .marginBottom(30)
                    .left(30)
                    .right(30)
            }
        }
    }
    
    func setupCombineProps() {
        guard let call = call else { return }
        
        call.$isMuted.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (value) in
            guard let strongSelf = self else { return }
            if value {
                strongSelf.muteButton.backgroundColor = .white
                strongSelf.muteButton.tintColor = .black
                strongSelf.muteButtonVideo.backgroundColor = .white
                strongSelf.muteButtonVideo.tintColor = .black
            } else {
                strongSelf.muteButton.tintColor = .white
                strongSelf.muteButton.backgroundColor = .systemGray3
                strongSelf.muteButtonVideo.backgroundColor = .systemGray3
                strongSelf.muteButtonVideo.tintColor = .white
            }
        }).store(in: &cancellableBag)
        
        call.$isSpeaker.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (value) in
            guard let strongSelf = self else { return }
            if value {
                Blackbox.shared.voipAudioManager.setAudioOutputPort(port: .speaker)
                strongSelf.speakerButton.backgroundColor = .white
                strongSelf.speakerButton.tintColor = .black
            } else {
                Blackbox.shared.voipAudioManager.setAudioOutputPort(port: .none)
                strongSelf.speakerButton.tintColor = .white
                strongSelf.speakerButton.backgroundColor = .systemGray3
            }
        }).store(in: &cancellableBag)
        
        call.$status.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (status) in
            guard let strongSelf = self else { return }
            
            switch status {
            case .setup:
                strongSelf.alpha = 1
                strongSelf.callStateLabel.text = "Connecting...".localized()
            case .ringing:
                strongSelf.alpha = 1
                if call.isOutgoing {
                    strongSelf.callStateLabel.text = "Ringing...".localized()
                }
            case .answeredAudioOnly:
                // Only video calls should have this status, but we check to be safe.
                if call.isOutgoing == false, call.hasVideo {
                    call.answerVideoCall(audioOnly: false) { (success) in
                        if success == false {
                            loge("answerVideoCall - Failed")
                        }
                    }
                }
            case .answered:
                // the call has just been answered
                if call.hasVideo, strongSelf.hasStartedReceivingVideoFrames == false {
                    // the video call has just been answered
                    
                    let blackbox = Blackbox.shared
                    
                    // If this is an incoming video call, we check the camera authorization when the user Answer the call (like whatsapp).
                    // If we are not authorized to use the camera, we close the call and show an alert.
                    if call.isOutgoing == false {
                        if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
                            do {
                                try NextLevel.shared.start()
                                NextLevel.shared.frameRate = 30
                                strongSelf.startFetchingVideoFrames()
                            } catch {
                                loge("NextLevel, failed to start camera session - \(#function)")
                            }
                        } else {
                            NextLevel.requestAuthorization(forMediaType: AVMediaType.video) { (mediaType, status) in
                                logi("NextLevel, authorization updated for media \(mediaType) status \(status)")
                                if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized {
                                    do {
                                        try NextLevel.shared.start()
                                        NextLevel.shared.frameRate = 30
                                        strongSelf.startFetchingVideoFrames()
                                        
                                    } catch {
                                        loge("NextLevel, failed to start camera session")
                                    }
                                } else if status == .notAuthorized {
                                    call.endCall()
                                    
                                    if let parentVC = self?.findViewController() {
                                        if let presentedVC = parentVC.presentedViewController {
                                            presentedVC.dismiss(animated: false) {
                                                parentVC.dismiss(animated: true) {
                                                    if let currentVC = blackbox.currentViewController {
                                                        AppUtility.camDenied(viewController: currentVC)
                                                    }
                                                }
                                            }
                                        } else {
                                            parentVC.dismiss(animated: true) {
                                                if let currentVC = blackbox.currentViewController {
                                                    AppUtility.camDenied(viewController: currentVC)
                                                }
                                            }
                                        }
                                    }
                                    
                                    //                    // Cancel background work item
                                    //                    if let vc = blackbox.callViewController {
                                    //                      vc.dismiss(animated: true) {
                                    //                        blackbox.callViewController = nil
                                    //
                                    //                        if let currentVC = blackbox.currentViewController {
                                    //                          AppUtility.camDenied(viewController: currentVC)
                                    //                        }
                                    //                      }
                                    //                    }
                                }
                            }
                        }
                    } else {
                        strongSelf.startFetchingVideoFrames()
                    }
                }
            case .hangup:
                strongSelf.disableButtons()
            case .ended:
                if let call = strongSelf.call {
                    
                    if call.isEndCallUserInitiated {
                        // The user closed the call succesfully, close the view after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                            logi("Call ended - Closing CallViewController")
                            if let parentVC = self?.findViewController() {
                                if let presentedVC = parentVC.presentedViewController {
                                    presentedVC.dismiss(animated: false) {
                                        parentVC.dismiss(animated: true) {
                                            Blackbox.shared.callViewController = nil
                                        }
                                    }
                                } else {
                                    parentVC.dismiss(animated: true) {
                                        Blackbox.shared.callViewController = nil
                                    }
                                }
                            }
                        }
                    } else {
                        let delay = call.answered ? 1.0 : 2.0
                        // close the view after 2 seconds if it was answered or 3 seconds to let the Call Object play the "No answered tone"
                        strongSelf.endCall()
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
                            logi("Call ended - Closing CallViewController")
                            if let parentVC = self?.findViewController() {
                                if let presentedVC = parentVC.presentedViewController {
                                    presentedVC.dismiss(animated: false) {
                                        parentVC.dismiss(animated: true) {
                                            Blackbox.shared.callViewController = nil
                                        }
                                    }
                                } else {
                                    parentVC.dismiss(animated: true) {
                                        Blackbox.shared.callViewController = nil
                                    }
                                }
                            }
                        }
                    }
                }
            default:
                break
            }
        }).store(in: &cancellableBag)
        
    }
    
    private func updateTimer(call: BBCall) {
        // the call has just been answered
        alpha = 1
        // Update the slider and the counter label
        let totalSeconds = Int(call.duration)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = (totalSeconds % 3600) % 60
        callStateLabel.text = String(format:"%02i:%02i", minutes, seconds)
    }
    
    func periodicallyUpdateStatus() {
        callStatusTimer = DispatchTimer(countdown: .milliseconds(500), repeating: .milliseconds(500), payload: { [weak self] in
            guard let strongSelf = self, let call = strongSelf.call, call.status.rawValue < CallStatus.hangup.rawValue, call.members.count > 0 else { return }
            
            if (call.hasVideo && call.isAudioStarted) || call.isStarted {
                strongSelf.updateTimer(call: call)
            }
            strongSelf.membersLabel.text = call.getMembersName()
            
            strongSelf.setNeedsLayout()
            strongSelf.layoutIfNeeded()
            
            strongSelf.membersTable.reloadData()
            
            if call.members.count == 4 {
                strongSelf.addContactButton.isEnabled = false
            }
            
            if strongSelf.isIncomingFirstFrame == false {
                strongSelf.incomingVideoProgressIndicator.stopAnimating()
            }
        })
        callStatusTimer?.arm()
    }
    
    
    /// Move the outgoing video frame to the bottom right of the screen and start to fetch the incoming video frames in a background thread
    func startFetchingVideoFrames() {
        hasStartedReceivingVideoFrames = true
        UIView.animate(withDuration: 0.2) {
            self.outgoingVideoPreview.pin.bottom(170).right(20).height(160).width(90)
            self.outgoingVideoPreview.layer.cornerRadius = 6
            NextLevel.shared.previewLayer.frame = self.outgoingVideoPreview.bounds
        }
        // Give NextLevel time to load and set the frame description.
        
        DispatchQueue.global(qos: .userInteractive).async(execute: fetchIncomingVideoFramesWorker)
        
    }
    
}

// MARK: - Members Table
extension CallView: UITableViewDataSource, CallContactCellDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let call = call else { return 0 }
        return call.members.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CallContactCell.getCellRequiredHeight()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let call = call else { return UITableViewCell() }
        
        let contact = call.members[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: CallContactCell.ID) as! CallContactCell
        cell.closeButton.isHidden = !call.isOutgoing
        cell.delegate = self
        cell.contactName.textColor = .white
        cell.contactName.text = contact.getName()
        cell.contactNumber.textColor = .white
        
        cell.avatar.borderWidth = 1.5
        cell.avatar.borderColor = .orange
        cell.contactNumber.textColor = .orange
        cell.selectionStyle = .none
        
        switch contact.callInfo.callStatus {
        case .setup:
            cell.contactNumber.text = "calling".localized().lowercased()
        case .ringing:
            cell.contactNumber.text = "ringing".localized().lowercased()
        case .answered, .answeredAudioOnly, .active:
            cell.avatar.borderColor = .white
            cell.contactNumber.textColor = .white
            cell.contactNumber.text = "Outgoing".localized().lowercased()
        default:
            cell.contactNumber.text = "".localized().lowercased()
        }
        
        if let imagePath = contact.profilePhotoPath {
            cell.avatar.contentMode = .scaleAspectFill
            cell.avatar.image = UIImage.fromPath(imagePath)
        }
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear
        return cell
    }
    
    func didTapOnCloseButton(indexPath: IndexPath) {
        guard let call = self.call, indexPath.row < call.members.count else { return }
        call.endCallWith(contact: call.members[indexPath.row]) { (_) in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.membersTable.reloadData()
            }
        }
    }
    
}

// MARK: - Actions
extension CallView {
    @objc func speakerPressed() {
        if let call = self.call {
            call.isSpeaker = !call.isSpeaker
        }
    }
    
    @objc func videoCallpressed() {
        pause = !pause
        videoCallButtonVideo.backgroundColor = pause ? .orange : .systemGray3
    }
    
    @objc func mutePressed() {
        if let call = self.call {
            Blackbox.shared.callManager.setMute(call: call, isMuted: !call.isMuted)
        }
    }
    
    @objc func rotateCameraPressed() {
        NextLevel.shared.flipCaptureDevicePosition()
    }
    
    @objc func endCall() {
        disableButtons()
        
        // Cancel background work item
        rootView.isUserInteractionEnabled = false
        
        if NextLevel.shared.isRunning {
            NextLevel.shared.stop()
        }
        
        if let call = self.call {
            call.endCall(userInitiated: true)
        }
    }
    
    @objc func addContactPressed() {
        guard let vc = findViewController(), let call = self.call else {
            return
        }
        let contacts = Blackbox.shared.contactsSections.reduce(into: [BBContact]()) {
            let contacts = $1.contacts.filter { (c1) -> Bool in
                // Return every contact, except those already present in the call.
                return !call.members.contains(where: { (c2) -> Bool in
                    return c1.registeredNumber == c2.registeredNumber
                })
            }
            $0.append(contentsOf: contacts)
        }
        let selectContactsVC = ConferenceCallContactsSelectionViewController(contacts: contacts, maxSelectedContacts: 4 - call.members.count)
        selectContactsVC.delegate = self
        vc.present(selectContactsVC, animated: true, completion: nil)
    }
    
    @objc func infoButtonPressed() {
        guard let call = self.call, let parentVC = findViewController() else { return }
        let infoVC = CallInfoViewController(call: call)
        infoVC.modalPresentationStyle = .fullScreen
        parentVC.present(infoVC, animated: true, completion: nil)
    }
    
    private func disableButtons() {
        endCallButton.isEnabled = false
        endCallButtonVideo.isEnabled = false
        speakerButton.isEnabled = false
        muteButton.isEnabled = false
        muteButtonVideo.isEnabled = false
        videoCallButton.isEnabled = false
        videoCallButtonVideo.isEnabled = false
        
        UIView.animate(withDuration: 0.2) {
            self.endCallButton.alpha = 0.4
            self.endCallButtonVideo.alpha = 0.4
            self.speakerButton.alpha = 0.4
            self.muteButton.alpha = 0.4
            self.muteButtonVideo.alpha = 0.4
            self.videoCallButton.alpha = 0.4
            self.videoCallButtonVideo.alpha = 0.4
        }
    }
    
    func cleanCallWorkers() {
        if fetchIncomingVideoFramesWorker.isCancelled == false {
            fetchIncomingVideoFramesWorker.cancel()
        }
    }
    
}

extension CallView: ConferenceCallContactsSelectionViewControllerDelegate {
    func didSelectContacts(contacts: [BBContact]) {
        call?.addMembersToConferenceCall(contacts: contacts, completion: { (addedContacts, failedContacts) in
            if let failedContacts = failedContacts, failedContacts.count > 0 {
                loge("Failed to add \(failedContacts.count) contacts to the conference call")
            }
        })
    }
}

// MARK: - Animations
extension CallView {
    fileprivate func hideVideoElementsAnimation() {
        UIView.animate(withDuration: 0.4) {
            if self.videoBottomView.frame.origin.y == self.frame.size.height {
                self.videoBottomView.pin.bottom(self.videoBottomView.frame.size.height)
            } else {
                self.videoBottomView.pin.bottom(-self.videoBottomView.frame.size.height)
            }
        }
    }
}

// MARK: - Video
extension CallView {
    
    
    /// Set the VTCompressionSession used for compressing each frame
    /// - Parameters:
    ///   - width: compress to specific width
    ///   - height: compress to specific height
    func compressAndSendVideoFrames(width: Int, height: Int) {
        let unmanagedSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            //codecType: kCMVideoCodecType_HEVC,  //CHANGED IN H264 CODEC
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: { refCon, _, status, _, sampleBuffer in
                guard status == noErr, let sampleBuffer = sampleBuffer else {
                    return
                }
                
                let scopedSelf = Unmanaged<CallView>.fromOpaque(refCon!).takeUnretainedValue()
                if scopedSelf.pause == false {
                    
                    if scopedSelf.compressedFrameDescription == nil {
                        scopedSelf.compressedFrameDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
                    }
                    
                    if scopedSelf.call == nil {
                        return
                    }
                    
                    if let call = scopedSelf.call, call.status.rawValue >= CallStatus.hangup.rawValue {
                        return
                    }
                    
                    if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                        
                        let blockBufferDataLength = CMBlockBufferGetDataLength(blockBuffer)
                        //                                  var blockBufferData  = [UInt8](repeating: 0, count: blockBufferDataLength)
                        let blockBufferData = UnsafeMutableRawPointer.allocate(byteCount: blockBufferDataLength, alignment: 1)
                        let status = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: blockBufferDataLength, destination: blockBufferData)
                        guard status == noErr else { return }
                        
                        // Send video packet data in differet, serial, thread.
                        scopedSelf.sendCompressedVideoPacketsQueue.async {
                            let result = BlackboxCore.videoCallSendFrame(blockBufferData.assumingMemoryBound(to: UInt8.self), frameSize: blockBufferDataLength)
                            if result == 0 {
                                loge("videoCallSendFrame failed")
                            }
                            blockBufferData.deallocate()
                        }
                    }
                }
                
            },
            refcon: unmanagedSelf,
            compressionSessionOut: &compressionSessionOut)
        
        guard let c = compressionSessionOut else {
            loge("Error creating compression session: \(status)")
            return
        }
        
        // set profile to Main
        //VTSessionSetProperty(c, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_HEVC_Main_AutoLevel) //changed in H264
        VTSessionSetProperty(c, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
        // capture from camera, so it's real time
        VTSessionSetProperty(c, key: kVTCompressionPropertyKey_RealTime, value: true as CFTypeRef)
        VTSessionSetProperty(c, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 30 as CFTypeRef)
        //VTSessionSetProperty(c, key: kVTCompressionPropertyKey_AverageBitRate, value: 500000 as CFTypeRef)
        //VTSessionSetProperty(c, key: kVTCompressionPropertyKey_DataRateLimits, value: [500000, 1] as CFArray)
        
        VTCompressionSessionPrepareToEncodeFrames(c)
    }
    
    /// Confirm the video call and change the status of the Video call to Acive.
    func confirmVideoCall() {
        if let call = self.call, let contact = call.members.first {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.1) {
                logi("Calling BlackboxCore.videoCallConfirm")
                guard let callId = contact.callInfo.callID,
                      let jsonString = BlackboxCore.videoCallConfirm(callId)else {
                    return
                }
                do {
                    let response = try JSONDecoder().decode(BaseResponse.self, from: jsonString.data(using: .utf8)!)
                    if !response.isSuccess() {
                        loge(response.message)
                    }
                } catch {
                    loge(error)
                }
            }
        }
    }
    
    /// Fetch the compressed frames from the server using BlackboxCore.videoCallGetFrame, recreate the CMSampleBuffer, send the frame to AVSampleBufferDisplayLayer object
    func fetchAndShowCompressedVideoFrames() {
        if let call = self.call {
            
            while call.status.rawValue < CallStatus.hangup.rawValue {
                if call.hasVideo && call.isStarted {
                    if let videoFormatDescription = compressedFrameDescription {
                        var blockBufferDataLength: Int32 = 0
                        
                        if call.isOutgoing, videoConfirmed == false {
                            videoConfirmed = true
                            // This will change the status of the Video call to Acive.
                            confirmVideoCall()
                        }
                        
                        guard let blockBufferData = BlackboxCore.videoCallGetFrame(&blockBufferDataLength) else {
                            continue
                        }
                        
                        var blockBuffer2: CMBlockBuffer? = nil
                        var status = CMBlockBufferCreateWithMemoryBlock(
                            allocator: kCFAllocatorDefault,
                            memoryBlock: blockBufferData,
                            blockLength: Int(blockBufferDataLength),
                            blockAllocator: kCFAllocatorDefault,
                            customBlockSource: nil,
                            offsetToData: 0,
                            dataLength: Int(blockBufferDataLength),
                            flags: kCMBlockBufferAssureMemoryNowFlag,
                            blockBufferOut: &blockBuffer2)
                        
                        if status != noErr {
                            loge(status)
                            continue
                        }
                        
                        if let buffer = blockBuffer2 {
                            var sampleBuffer: CMSampleBuffer?
                            
                            if incomingVideoLayer.status == .failed {
                                loge("Incoming VideoLayer status Failed: \(incomingVideoLayer.status.rawValue)")
                                incomingVideoLayer.flush()
                            }
                            
                            if isIncomingFirstFrame {
                                //                  var controlTimebase: CMTimebase? = nil
                                //                  CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault, masterClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase );
                                //
                                //                  incomingVideoLayer.controlTimebase = controlTimebase;
                                //                  CMTimebaseSetTime(incomingVideoLayer.controlTimebase!, time: CMTimeMake(value: CMTime.zero.value, timescale: 1));
                                //                  CMTimebaseSetRate(incomingVideoLayer.controlTimebase!, rate: 1.0);
                            }
                            //                incomingFramesNum += 1
                            
                            //                  let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                            
                            //            let seconds = incomingFrame0time! + Double(1/VideoSettigs.fps) * Double(incomingFramesNum)
                            //            let frameDuration = timeElapsed / Double(incomingFramesNum)
                            //                  let frameDuration: CMTime = CMTimeMake(value: Int64(timeElapsed / Double(incomingFramesNum)), timescale: 600)
                            //                let frameDuration = CMTime.zero
                            //            let presentationTimeStamp = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
                            //                let presentationTimeStamp = CMTime(value: CMTimeValue(incomingFramesNum), timescale: 1_000_000_000)
                            //                var timing = CMSampleTimingInfo(duration: frameDuration,
                            //                                                presentationTimeStamp: presentationTimeStamp,
                            //                                                decodeTimeStamp: CMTime.invalid)
                            
                            status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                                          dataBuffer: buffer,
                                                          dataReady: true,
                                                          makeDataReadyCallback: nil,
                                                          refcon: nil,
                                                          formatDescription: videoFormatDescription,
                                                          sampleCount: 1,
                                                          sampleTimingEntryCount: 0,
                                                          sampleTimingArray: nil,
                                                          sampleSizeEntryCount: 0,
                                                          sampleSizeArray: nil,
                                                          sampleBufferOut: &sampleBuffer)
                            
                            if status != noErr {
                                loge("CMSampleBufferCreate status -> \(status)")
                                continue
                            }
                            
                            if let sampleBuffer = sampleBuffer {
                                CMSampleBufferMakeDataReady(sampleBuffer)
                                
                                setSampleBufferAttachments(sampleBuffer)
                                
                                while incomingVideoLayer.isReadyForMoreMediaData == false {
                                    logi("Incoming VideoLayer Not ready for media data")
                                }
                                if incomingVideoLayer.isReadyForMoreMediaData {
                                    
                                    incomingVideoLayer.enqueue(sampleBuffer)
                                    
                                    if isIncomingFirstFrame {
                                        isIncomingFirstFrame = false
                                    }
                                }
                            }
                            
                        }
                    }
                }
            }
        }
    }
    
    
    /// Set the sample buffer to  display Immediately ignoring the timestamp
    /// - Parameter sampleBuffer: the sample buffer
    func setSampleBufferAttachments(_ sampleBuffer: CMSampleBuffer) {
        //    let attachments: CFArray! = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)! as NSArray
        let dict = attachments[0] as! NSMutableDictionary
        dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
        dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleBufferAttachmentKey_EndsPreviousSampleDuration as NSString as String)
    }
}

extension CallView: NextLevelVideoDelegate {
    func nextLevel(_ nextLevel: NextLevel, didUpdateVideoZoomFactor videoZoomFactor: Float) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, willProcessRawVideoSampleBuffer sampleBuffer: CMSampleBuffer, onQueue queue: DispatchQueue) {
        guard let call = self.call else {
            return
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Initialize the compression object
        if compressionSessionOut == nil {
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            compressAndSendVideoFrames(width: width, height: height)
        }
        
        guard let compressionSession = compressionSessionOut else {
            return
        }
        
        if call.isOutgoing {
            // Exit if the call is not started
            if call.isStarted == false {
                return
            }
        } else {
            // Exit if the call is not active
            if call.status != .active {
                return
            }
        }
        
        lastSampleBuffer = sampleBuffer
        compressionQueue.async {
            imageBuffer.lock(.readwrite) {
                let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let duration = CMSampleBufferGetDuration(sampleBuffer)
                //        var flags = VTEncodeInfoFlags.asynchronous
                let status = VTCompressionSessionEncodeFrame(compressionSession,
                                                             imageBuffer: imageBuffer,
                                                             presentationTimeStamp: presentationTimeStamp,
                                                             duration: duration,
                                                             frameProperties: nil,
                                                             sourceFrameRefcon: nil,
                                                             infoFlagsOut: nil) // &flags
                
                if status == kVTInvalidSessionErr {
                    logw("Invalid Compression session: Invalidate and restart")
                    VTCompressionSessionInvalidate(compressionSession)
                    self.compressionSessionOut = nil
                }
            }
        }
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, renderToCustomContextWithImageBuffer imageBuffer: CVPixelBuffer, onQueue queue: DispatchQueue) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, willProcessFrame frame: AnyObject, timestamp: TimeInterval, onQueue queue: DispatchQueue) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didSetupVideoInSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didSetupAudioInSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didStartClipInSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didCompleteClip clip: NextLevelClip, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didAppendVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didSkipVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didAppendVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didSkipVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didAppendAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didSkipAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didCompleteSession session: NextLevelSession) {
        
    }
    
    func nextLevel(_ nextLevel: NextLevel, didCompletePhotoCaptureFromVideoFrame photoDict: [String : Any]?) {
        
    }
    
}

extension CVPixelBuffer {
    public enum LockFlag {
        case readwrite
        case readonly
        
        func flag() -> CVPixelBufferLockFlags {
            switch self {
            case .readonly:
                return .readOnly
            default:
                return CVPixelBufferLockFlags.init(rawValue: 0)
            }
        }
    }
    
    public func lock(_ flag: LockFlag, closure: (() -> Void)?) {
        if CVPixelBufferLockBaseAddress(self, flag.flag()) == kCVReturnSuccess {
            if let c = closure {
                c()
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, flag.flag())
    }
}

