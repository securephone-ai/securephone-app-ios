import UIKit
import Combine


class StarredMessageCellAudio: StarredMessageBaseCell {
  
  private var audioManager: AudioRecorderImpl?
  private var audioTimer = Timer()
  
  override var viewModel: MessageViewModel! {
    didSet {
      dateLabel.textColor = .systemGray2
      
      viewModel.$isAudioPlaying
        .receive(on: DispatchQueue.main)
        .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
        .sink(receiveValue: { [weak self] (value) in
          guard let strongSelf = self else { return }
          if value {
            strongSelf.startAudio()
          } else {
            strongSelf.stopAudio()
          }
        }).store(in: &cancellableBag)
      
      viewModel.message.$localFilename
        .receive(on: DispatchQueue.main)
        .filter({ [weak self](filePath) -> Bool in
          guard let strongSelf = self else { return false }
          return strongSelf.viewModel.message.type == .audio && !filePath.isEmpty
        })
        .sink { [weak self](filePath) in
          guard let strongSelf = self else { return }
            strongSelf.audioManager = AudioRecorderImpl(filepath: strongSelf.viewModel.message.localFilename, key: strongSelf.viewModel.message.fileKey, playerOnly: true)
          strongSelf.audioManager!.playerDelegate = self
          let duration = strongSelf.audioManager!.getAudioDuration()
          strongSelf.slider.maximumValue = Float(duration)
          
          let totalSeconds = Int(duration)
          let minutes = (totalSeconds % 3600) / 60
          let seconds = (totalSeconds % 3600) % 60
          strongSelf.sliderLabel.text = String(format:"%02i:%02i", minutes, seconds)
      }.store(in: &cancellableBag)
      
    }
  }
  
  private var slider: UISlider = {
    let slider = UISlider()
    let image = UIImage(named: "slider_thumb")
    slider.setThumbImage(image, for: .normal)
    slider.minimumTrackTintColor = .systemGray
    slider.minimumValue = 0.0
    slider.isUserInteractionEnabled = true
    return slider
  }()
  
  private lazy var sliderLabel: UILabel = {
    let label = UILabel()
    label.textColor = dateLabel.textColor
    label.font = dateLabel.font
    label.text = "00:00"
    label.sizeToFit()
    return label
  }()
  
  private lazy var audioImageButton: UIButton = {
    let config = UIImage.SymbolConfiguration(scale: .large)
    let button = UIButton(type: .system )
    button.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
    button.tintColor = .systemGray
    button.addTarget(self, action: #selector(playOrPauseAudio), for: .touchUpInside)
    button.sizeToFit()
    return button
  }()
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
  private func setupCell() {
    messageContentView.addSubview(audioImageButton)
    messageContentView.addSubview(slider)
    messageContentView.addSubview(sliderLabel)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    audioImageButton.pin.vCenter(-3).left(4).width(25)
    
    slider.pin.centerLeft(to: audioImageButton.anchor.centerRight).marginLeft(12).right(8)
    
    if AppUtility.isArabic {
      sliderLabel.pin.right(to: slider.edge.right).vCenter(to: dateLabel.edge.vCenter)
    } else {
      sliderLabel.pin.left(to: slider.edge.left).vCenter(to: dateLabel.edge.vCenter)
    }
  }
  
  @objc func playOrPauseAudio() {
    viewModel.isAudioPlaying = !viewModel.isAudioPlaying
  }
  
  private func stopAudio() {
    guard let _audioManager = self.audioManager else { return }
    let config = UIImage.SymbolConfiguration(scale: .large)
    audioImageButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
    _audioManager.stopPlaying()
    audioTimer.invalidate()
  }
  
  private func startAudio() {
    guard let _audioManager = self.audioManager else { return }
    let config = UIImage.SymbolConfiguration(scale: .large)
    audioImageButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
    _audioManager.play(from: nil, currentTime: TimeInterval(slider.value))
    
    audioTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] timer in
      guard let strongSelf = self else {
        timer.invalidate()
        return
      }
      
      // Update the slider and the counter label
      strongSelf.slider.value = Float(_audioManager.getAudioCurrentTime())
      let totalSeconds = Int(strongSelf.slider.value)
      let minutes = (totalSeconds % 3600) / 60
      let seconds = (totalSeconds % 3600) % 60
      strongSelf.sliderLabel.text = String(format:"%02i:%02i", minutes, seconds)
    }
    RunLoop.main.add(audioTimer, forMode: RunLoop.Mode.common)
    
  }
  
}

extension StarredMessageCellAudio: AudioPlayerDelegate {
  
  func didFinishPlaying(successfully flag: Bool) {
    if flag {
      viewModel.isAudioPlaying = false
      slider.value = slider.maximumValue
    }
  }
  
}
