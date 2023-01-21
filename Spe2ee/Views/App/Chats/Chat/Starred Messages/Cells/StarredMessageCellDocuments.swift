import UIKit
import PinLayout
import Combine
import QuickLook

class StarredMessageCellDocuments: StarredMessageBaseCell {
  //static let ID = "MessageCell"
  
  private var maxBubbleWidth: CGFloat {
    if viewModel.message.containAttachment {
      return contentView.frame.size.width * 0.80
    }
    return contentView.frame.size.width * 0.75
  }
  private var maxContentWidth: CGFloat {
    return maxBubbleWidth - MessageCell.bubbleContentMargin - 8 // 8 = left margin from superview
  }
  
  private lazy var filePreviewContentView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor(white: 0.0, alpha: 0.05)
    view.cornerRadius = 6
    
    view.addSubview(self.fileTypeImageView)
    view.addSubview(self.fileNameLabel)
    
    let gesture = UITapGestureRecognizer(target: self, action: #selector(openDocument))
    gesture.numberOfTapsRequired = 1
    view.addGestureRecognizer(gesture)
    
    return view
  }()
  
  private lazy var fileTypeImageView: UIImageView = {
    var imageView = UIImageView()
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  private lazy var fileNameLabel: UILabel = {
    var label = UILabel()
    label.frame = CGRect(x: 0, y: 0, width: 0, height: UILabel(text: "A").requiredHeight)
    label.numberOfLines = 1
    return label
  }()
  
  private lazy var fileInfoLabel: UILabel = {
    var label = UILabel()
    label.frame = CGRect(x: 0, y: 0, width: 0, height: UILabel(text: "A").requiredHeight)
    label.numberOfLines = 1
    label.textColor = .systemGray2
    return label
  }()
  
  
  private var cancellable: AnyCancellable?
  
  override var viewModel: MessageViewModel! {
    didSet {
      cancellable = self.viewModel.message.$localFilename.receive(on: DispatchQueue.main).sink { [weak self] (filePath) in
        guard let strongSelf = self else { return }
        
        strongSelf.updateFileInfoLabel()
        switch strongSelf.viewModel.message.type {
        case .document(let type):
          switch type {
          case .appleKeynote, .microsoftPowerPoint:
            strongSelf.fileTypeImageView.image = UIImage(named: "presentation_icon")
          case .appleNumbers, .microsoftExcel:
            strongSelf.fileTypeImageView.image = UIImage(named: "spreadshet_icon")
          case .microsoftWord, .applePages, .text, .generic:
            strongSelf.fileTypeImageView.image = UIImage(named: "doctext_icon")
          case .pdf:
            strongSelf.fileTypeImageView.image = UIImage(named: "pdf_icon")
          }
        default:
          break
        }
        
        strongSelf.dateLabel.textColor = .systemGray2
      }
      
      updateFileInfoLabel()
      fileNameLabel.attributedText = viewModel.message.originFilename.getAttributedText(fontSize: 17)
      fileNameLabel.sizeToFit()
    }
  }
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    // We insert these view at the specific index so that the DateLabel and the checkmark image remain on TOP
    messageContentView.insertSubview(filePreviewContentView, at: 0)
    messageContentView.insertSubview(fileInfoLabel, at: 1)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
  }
  
}

extension StarredMessageCellDocuments {
  
  override func layoutSubviews() {
    super.layoutSubviews()
    filePreviewContentView.pin.above(of: dateLabel).left().top().right().marginBottom(2)
    fileTypeImageView.pin.width(30).height(30).vCenter().left(4)
    fileNameLabel.pin.right(of: fileTypeImageView, aligned: .center).marginLeft(6).right(10)
    
    if AppUtility.isArabic {
      fileInfoLabel.pin.vCenter(to: dateLabel.edge.vCenter).right(4)
    } else {
      fileInfoLabel.pin.vCenter(to: dateLabel.edge.vCenter).left(4)
    }
    
    // Do something with the filPath
    fileNameLabel.attributedText = viewModel.message.originFilename.getAttributedText(fontSize: 17)
    fileNameLabel.lineBreakMode = .byTruncatingMiddle
  }
  
  private func updateFileInfoLabel() {
    let size = AppUtility.getFileSize(viewModel.message.localFilename)
    let fileExtension = (viewModel.message.originFilename as NSString).pathExtension
    
    var fileInfo = ""
    if size < 1000 {
      fileInfo = "\(size) Bytes"
    } else if size >= 1000 && size < 1000000 {
      fileInfo = "\(Int(size/1000)) KB"
    } else {
      fileInfo = "\(Int(size/1000000)) MB"
    }
    
    fileInfo = "\(fileInfo) • \(fileExtension.lowercased())"
    fileInfoLabel.attributedText = fileInfo.getAttributedText(fontSize: 14)
  }
  
}

// MARK: - Actions / Selectors
extension StarredMessageCellDocuments: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
  
  func previewControllerWillDismiss(_ controller: QLPreviewController) {
    
    //    waterMarkLabel.removeFromSuperview()
    
    let url = URL(fileURLWithPath: viewModel.message.localFilename)
    let tmpUrl = AppUtility.getTemporaryDirectory().appendingPathComponent(url.lastPathComponent).appendingPathExtension((viewModel.message.originFilename as NSString).pathExtension)
    do {
      try FileManager.default.removeItem(at: tmpUrl)
    } catch {
      loge(error)
    }
  }
  
  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    1
  }
  
  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    let url = URL(fileURLWithPath: viewModel.message.localFilename)
    let tmpUrl = AppUtility.getTemporaryDirectory().appendingPathComponent(url.lastPathComponent).appendingPathExtension((viewModel.message.originFilename as NSString).pathExtension)
    
    do {
      try FileManager.default.copyItem(at: url, to: tmpUrl)
    } catch {
      loge(error)
    }
    
    return tmpUrl as QLPreviewItem
  }
  
  @objc func openDocument() {
    if let vc = self.findViewController() {
      
        let navController = UINavigationController(rootViewController: DocsPreviewViewController(docUrl: URL(fileURLWithPath: viewModel.message.localFilename), key: viewModel.message.fileKey,
                                                                                               pathExtension: (viewModel.message.originFilename as NSString).pathExtension))
      navController.modalPresentationStyle = .fullScreen
      vc.present(navController, animated: true)
    }
    UIView.animate(withDuration: 0.07, animations: {
      self.filePreviewContentView.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
    }) { (result) in
      UIView.animate(withDuration: 0.07) {
        self.filePreviewContentView.backgroundColor = UIColor(white: 0.0, alpha: 0.05)
      }
    }
  }
  
}


