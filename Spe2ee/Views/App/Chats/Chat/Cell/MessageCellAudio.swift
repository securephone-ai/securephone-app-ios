import UIKit
import Combine

class MessageCellAudio: MessageBaseCell {
  
  private var audioManager: AudioRecorderImpl?
  private var audioTimer = Timer()
  
  override var viewModel: MessageViewModel! {
    didSet {
      dateLabel.textColor = .systemGray2
      
      viewModel.$isAudioPlaying
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] (value) in
          guard let strongSelf = self else { return }
          if value {
            strongSelf.startAudio()
          } else {
            strongSelf.stopAudio()
          }
        }).store(in: &cancellableBag)
      
      viewModel.message.$fileTransferState.throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true).sink { [weak self](value) in
        guard let strongSelf = self else { return }
        
        if strongSelf.viewModel.showDownloadButton == false && value != 100 {
          if value < 100 {
            strongSelf.sliderLabel.text = "Dowloading...".localized()
            strongSelf.sliderLabel.sizeToFit()
          } else if value == 100 {
            strongSelf.updateTimerDuration()
          }
        }
        
      }.store(in: &cancellableBag)
      
      viewModel.message.$localFilename
        .receive(on: DispatchQueue.main)
        .filter({ [weak self](filePath) -> Bool in
          guard let strongSelf = self else { return false }
          return strongSelf.viewModel.message.type == .audio && !filePath.isEmpty
        })
        .sink { [weak self] (filePath) in
          guard let strongSelf = self else { return }
          strongSelf.updateTimerDuration()
      }.store(in: &cancellableBag)
      
      viewModel.message.$autoDownload.receive(on: DispatchQueue.main).sink { [weak self](value) in
        guard let strongSelf = self else { return }
        if value && strongSelf.viewModel.isDownloadComplete == false {
          strongSelf.viewModel.refreshFileTransferStateAsync()
        }
      }.store(in: &cancellableBag)
      
    }
  }
  
  private lazy var downloadButton: UIButton = {
    let button = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 30, weight: UIImage.SymbolWeight.light)
    button.setImage(UIImage(systemName: "arrow.down.circle", withConfiguration: config), for: .normal)
    button.addTarget(self, action: #selector(downloadButtonPressed), for: .touchUpInside)
    button.isHidden = true
    button.tintColor = .link
    button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
    return button
  }()
  
  private lazy var slider: UISlider = {
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
    messageContentView.addSubview(downloadButton)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if pan.state == .ended || pan.state == .possible {
      audioImageButton.pin.vCenter(-3).left(4).width(25)
      
      downloadButton.isHidden = !viewModel.showDownloadButton
      downloadButton.pin.vCenter(-4).right(8)
      
      if downloadButton.isHidden {
        slider.pin.centerLeft(to: audioImageButton.anchor.centerRight).marginLeft(12).right(8)
      } else {
        slider.value = 0
        audioManager = nil
        slider.pin.horizontallyBetween(audioImageButton, and: downloadButton, aligned: .center).marginLeft(12).marginRight(8)
      }
        
      if AppUtility.isArabic {
        sliderLabel.pin.right(to: slider.edge.right).vCenter(to: dateLabel.edge.vCenter)
      } else {
        sliderLabel.pin.left(to: slider.edge.left).vCenter(to: dateLabel.edge.vCenter)
      }
      
    }
  }
  override func prepareForReuse() {
    super.prepareForReuse()
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
      strongSelf.slider.maximumValue = Float(strongSelf.audioManager!.getAudioDuration())
      
      // Update the slider and the counter label
      strongSelf.slider.value = Float(_audioManager.getAudioCurrentTime())
      let totalSeconds = Int(strongSelf.slider.value)
      let minutes = (totalSeconds % 3600) / 60
      let seconds = (totalSeconds % 3600) % 60
      strongSelf.sliderLabel.text = String(format:"%02i:%02i", minutes, seconds)
    }
    RunLoop.main.add(audioTimer, forMode: RunLoop.Mode.common)
  
  }
  
  
  private func updateTimerDuration() {
    guard FileManager.default.fileExists(atPath: viewModel.message.localFilename) else { return }
    
      audioManager = AudioRecorderImpl(filepath: viewModel.message.localFilename, key: viewModel.message.fileKey, playerOnly: true)
    audioManager!.playerDelegate = self
    let duration = audioManager!.getAudioDuration()
    slider.maximumValue = Float(duration)
    
    let totalSeconds = Int(duration)
    let minutes = (totalSeconds % 3600) / 60
    let seconds = (totalSeconds % 3600) % 60
    sliderLabel.text = String(format:"%02i:%02i", minutes, seconds)
  }
  
  @objc private func downloadButtonPressed() {
    sliderLabel.text = "Dowloading...".localized()
    sliderLabel.sizeToFit()
    slider.value = 0
    slider.pin.centerLeft(to: audioImageButton.anchor.centerRight).marginLeft(12).right(8)
    downloadButton.isHidden = true
    viewModel.downloadFileAsync()
  }

}

extension MessageCellAudio: AudioPlayerDelegate {
  func didFinishPlaying(successfully flag: Bool) {
    if flag {
      viewModel.isAudioPlaying = false
      slider.value = slider.maximumValue
    }
  }
}
