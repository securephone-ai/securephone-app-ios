import UIKit
import AVFoundation

protocol NotificationSoundSelectionViewControllerDelegate: class {
  func didSelectTone(named: String)
}

class NotificationSoundSelectionViewController: UIViewController {
  
  weak var  delegate: NotificationSoundSelectionViewControllerDelegate?
  
  private var player: AVAudioPlayer?
  private let tones: [String] = [
    "default",
    "tones-1.wav",
    "tones-2.wav",
    "tones-3.wav",
    "tones-4.wav",
    "tones-5.wav",
    "tones-6.wav",
    "tones-7.wav",
    "tones-8.wav",
    "tones-9.wav",
    "tones-10.wav"
  ]
  private var preSelectedTone: String
  private var selectedIndexPath: IndexPath?
  
  private var isGroup = false
  
  private let titleLabel: UILabel = {
    let label = UILabel(text: "Sound".localized(), style: .body)
    label.font = UIFont.appFont(ofSize: 17)
    label.adjustsFontForContentSizeCategory = true
    label.sizeToFit()
    label.textColor = .black
    return label
  }()
  
  private lazy var cancelButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel".localized(), for: .normal)
    button.addTarget(self, action: #selector(cancellButtonPressed), for: .touchUpInside)
    button.tintColor = .link
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.sizeToFit()
    return button
  }()
  
  private lazy var saveButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Save".localized(), for: .normal)
    button.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)
    button.tintColor = .link
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.sizeToFit()
    return button
  }()
  
  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    tableView.tableFooterView = UIView()
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(SoundSelectionCell.self, forCellReuseIdentifier: SoundSelectionCell.ID)
    return tableView
  }()
  
  init(preSelectedTone: String = "Default") {
    if tones.contains(preSelectedTone) {
      self.preSelectedTone = preSelectedTone
    } else {
      self.preSelectedTone = "Default"
    }
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemGray6
    view.addSubview(titleLabel)
    view.addSubview(cancelButton)
    view.addSubview(saveButton)
    view.addSubview(tableView)
    
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    titleLabel.pin.hCenter().top(16)
    cancelButton.pin.vCenter(to: titleLabel.edge.vCenter).left(14)
    saveButton.pin.vCenter(to: titleLabel.edge.vCenter).right(14)
    tableView.pin.below(of: titleLabel).left().right().bottom().marginTop(16)
  }
  
  @objc func cancellButtonPressed() {
    dismiss(animated: true, completion: nil)
    navigationController?.popViewController()
  }
  
  @objc func saveButtonPressed() {
    guard let selectedIndexPath = self.selectedIndexPath else {
      cancellButtonPressed()
      return
    }
    let filename = "tones-\(selectedIndexPath.row)"
    if selectedIndexPath.row == 0 {
      guard let delegate = delegate else { return }
      delegate.didSelectTone(named: "Default")
    } else {
      guard let delegate = delegate else { return }
      delegate.didSelectTone(named: "\(filename).wav")
    }
    cancellButtonPressed()
  }
  
  func playSound(fileName: String) {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav") else { return }
    
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      
      /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
      player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
      
      /* iOS 10 and earlier require the following line:
       player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
      
      guard let player = player else { return }
      
      player.play()
      
    } catch let error {
      loge(error.localizedDescription)
    }
  }
}

extension NotificationSoundSelectionViewController: UITableViewDataSource, UITableViewDelegate {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tones.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: SoundSelectionCell.ID) as! SoundSelectionCell
    if indexPath.row == 0 {
      cell.toneNameLabel.text = "Default".localized()
      cell.checkImageView.isHidden = preSelectedTone == "Default" ? false : true
    } else {
      var name = tones[indexPath.row].components(separatedBy: "-")[0]
      name.removeLast()
      cell.toneNameLabel.text = "\("tone".localized()) - \(indexPath.row)"
      cell.checkImageView.isHidden = preSelectedTone == tones[indexPath.row] ? false : true
    }

    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    selectedIndexPath = indexPath
    
    
    
    let cell = tableView.cellForRow(at: indexPath) as! SoundSelectionCell
    cell.checkImageView.isHidden = false
    
    if let visibleCellsIndexPaths = tableView.indexPathsForVisibleRows {
      for ip in visibleCellsIndexPaths {
        if ip != indexPath {
          let _cell = tableView.cellForRow(at: ip) as! SoundSelectionCell
          _cell.checkImageView.isHidden = true
        }
      }
    }
    let filename = "tones-\(indexPath.row)"
    playSound(fileName: filename)
  }
}

