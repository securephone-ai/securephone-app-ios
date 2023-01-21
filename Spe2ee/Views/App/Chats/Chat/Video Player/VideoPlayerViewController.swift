import UIKit
import Player
import PinLayout
import AVFoundation
import CryptoKit
import BlackboxCore

class VideoPlayerViewController: UIViewController {
    fileprivate var player = Player()
    private var videoPath: String!
    private var videoUrl: URL!
    
    private lazy var topBarView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 100))
        view.backgroundColor = UIColor(white: 1, alpha: 0.9)
        return view
    }()
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        let image = UIImage(named: "slider_thumb")
        slider.setThumbImage(image, for: .normal)
        slider.minimumTrackTintColor = .systemGray
        slider.minimumValue = 0.0
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var timerLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(ofSize: 14)
        label.textColor = .black
        label.text = "00:00"
        label.sizeToFit()
        return label
    }()
    
    private lazy var bottomBarView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 100))
        view.backgroundColor = .systemGray5
        return view
    }()
    
    private lazy var playAndPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .link
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.backgroundColor = .systemGray5
        button.addTarget(self, action: #selector(playAndPauseTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var waterMarkLabel: UILabel = {
        let sideSize = UIScreen.main.bounds.size.height > UIScreen.main.bounds.size.width ? UIScreen.main.bounds.size.height * 1.5 : UIScreen.main.bounds.size.width * 1.5
        let label = UILabel(frame: CGRect(x: -sideSize/2, y: -sideSize/2, width: sideSize, height: sideSize*2))
        label.isUserInteractionEnabled = false
        label.textColor = .gray
        label.alpha = 0.30
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 18)
        label.adjustsFontForContentSizeCategory = true
        
        let inputString = "\(Blackbox.shared.account.registeredNumber ?? "")51e3eb37471db46a4c4f9472deb594d4a56ceae0a163728aa45b6a06ed1d43cb"
        let inputData = Data(inputString.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        if let hash = hashString.slicing(from: 0, length: 16) {
            var finalStr = "Top Secret \(hash) #Calc"
            for _ in 1..<120 {
                finalStr = "\(finalStr) # Top Secret \(hash) #Calc"
            }
            label.text = "\(finalStr)"
        }
        
        label.isHidden = true
        
        return label
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        imageView.image = UIImage(named: "logo-green")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.alpha = 0.15
        return imageView
    }()
    
    init(videoPath: String, key: String) {
        self.videoPath = videoPath
        self.videoUrl = URL(fileURLWithPath: videoPath, isDirectory: false)
        
        var fileUrl = URL(fileURLWithPath: videoPath, isDirectory: false, relativeTo: nil)
        if !key.isEmpty,
            let data = AppUtility.decryptFile(videoPath, key: key) {
            fileUrl.appendPathExtension("MOV")
            try? data.write(to: fileUrl)
            self.videoUrl = fileUrl
        } else {
            let newPath = fileUrl.appendingPathExtension("MOV")
            try? FileManager.default.copyItem(at: fileUrl, to: newPath)
            self.videoUrl = newPath
        }
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: object lifecycle
    deinit {
        self.player.willMove(toParent: nil)
        self.player.view.removeFromSuperview()
        self.player.removeFromParent()
        
        do {
            try FileManager.default.removeItem(at: videoUrl)
        } catch {
            print("unable to delete file")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.player.playerDelegate = self
        self.player.playbackDelegate = self
        self.player.view.frame = self.view.bounds
        self.player.playerView.playerBackgroundColor = .black
        
        self.addChild(self.player)
        self.view.addSubview(self.player.view)
        self.player.didMove(toParent: self)
        
        self.player.url = videoUrl
        
        self.player.playbackLoops = false
        
        let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGestureRecognizer(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        self.player.view.addGestureRecognizer(tapGestureRecognizer)
        
        waterMarkLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 5)
        self.view.addSubview(waterMarkLabel)
        self.view.addSubview(logoImageView)
        
        self.view.addSubview(bottomBarView)
        bottomBarView.addSubview(playAndPauseButton)
        
        self.view.addSubview(topBarView)
        topBarView.addSubview(slider)
        topBarView.addSubview(timerLabel)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        timerLabel.sizeToFit()
        // Top Bar layout
        topBarView.pin.top(view.pin.safeArea.top).left(view.pin.safeArea.left).right(view.pin.safeArea.right).height(50)
        slider.pin.vCenter().left(20).right(60)
        timerLabel.pin.centerLeft(to: slider.anchor.centerRight).marginLeft(4)
        // Bottom Bar layout
        bottomBarView.pin.bottom().left().right().height(view.pin.safeArea.bottom+50)
        playAndPauseButton.pin.vCenter().hCenter()
        // Player layout
        player.view.pin.verticallyBetween(topBarView, and: bottomBarView, aligned: .center)
        //    player.view.pin.above(of: bottomBarView).top().left().right()
        
        logoImageView.pin.center()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //    AppUtility.addWatermarkToWindow()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        waterMarkLabel.isHidden = true
        AppUtility.removeWatermarkFromWindow()
    }
    
}

// MARK: - UIGestureRecognizer
extension VideoPlayerViewController {
    @objc func handleTapGestureRecognizer(_ gestureRecognizer: UITapGestureRecognizer) {
        switch self.player.playbackState {
        case .stopped:
            self.player.playFromBeginning()
            break
        case .paused:
            self.player.playFromCurrentTime()
            break
        case .playing:
            self.player.pause()
            break
        case .failed:
            self.player.pause()
            break
        }
    }
    
    @objc func playAndPauseTap() {
        switch player.playbackState {
        case .playing, .failed:
            self.player.pause()
        case .paused:
            self.player.playFromCurrentTime()
        case .stopped:
            self.player.playFromBeginning()
        }
    }
    
    @objc func sliderValueChanged() {
        player.pause()
        player.seekToTime(to: CMTime(seconds: Double(slider.value), preferredTimescale: 1000),
                          toleranceBefore: .zero,
                          toleranceAfter: .zero)
    }
}

// MARK: - PlayerDelegate
extension VideoPlayerViewController: PlayerDelegate {
    
    func playerReady(_ player: Player) {
        self.slider.maximumValue = Float(player.maximumDuration)
        player.playFromBeginning()
    }
    
    func playerPlaybackStateDidChange(_ player: Player) {
        switch player.playbackState {
        case .playing, .failed:
            self.playAndPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        case .paused, .stopped:
            self.playAndPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    func playerBufferingStateDidChange(_ player: Player) {
    }
    
    func playerBufferTimeDidChange(_ bufferTime: Double) {
    }
    
    func player(_ player: Player, didFailWithError error: Error?) {
        loge(error.debugDescription)
    }
    
}

// MARK: - PlayerPlaybackDelegate
extension VideoPlayerViewController: PlayerPlaybackDelegate {
    
    func playerCurrentTimeDidChange(_ player: Player) {
        slider.value = Float(CMTimeGetSeconds(player.currentTime))
        
        let totalSeconds = Int(slider.value)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = (totalSeconds % 3600) % 60
        timerLabel.text = String(format:"%02i:%02i", minutes, seconds)
        timerLabel.sizeToFit()
    }
    
    func playerPlaybackWillStartFromBeginning(_ player: Player) {
    }
    
    func playerPlaybackDidEnd(_ player: Player) {
    }
    
    func playerPlaybackWillLoop(_ player: Player) {
    }
    
    func playerPlaybackDidLoop(_ player: Player) {
    }
}
