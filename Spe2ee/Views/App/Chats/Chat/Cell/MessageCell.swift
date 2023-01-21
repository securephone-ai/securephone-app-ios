import UIKit
import PinLayout
import SDWebImage
import Combine
import Lottie
import ImageViewer
import CryptoKit
import WatermarkedImageView
import BlackboxCore


class MessageCell: MessageBaseCell {
  //static let ID = "MessageCell"
  private var fileStatusTimer: DispatchTimer?
  private var maxBubbleWidth: CGFloat {
    if viewModel.message.containAttachment {
      return contentView.frame.size.width * 0.80
    }
    return contentView.frame.size.width * 0.75
  }
  private var maxContentWidth: CGFloat {
    return maxBubbleWidth - MessageCell.bubbleContentMargin - 8 // 8 = left margin from superview
  }
  
  private lazy var downloadButton: UIButton = {
    let button = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 70, weight: UIImage.SymbolWeight.light)
    button.setImage(UIImage(systemName: "arrow.down.circle", withConfiguration: config), for: .normal)
    button.addTarget(self, action: #selector(downloadButtonPressed), for: .touchUpInside)
    button.isHidden = true
    button.tintColor = .link
    button.frame = CGRect(x: 0, y: 0, width: 70, height: 70)
    return button
  }()
  
  // MARK: - UI
  private var fileUploadProgressLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.adjustsFontForContentSizeCategory = true
    label.text = "A"
    label.frame = CGRect(x: 0, y: 0, width: 100, height: label.requiredHeight)
    label.text = ""
    label.isHidden = true
    label.textAlignment = .center
    label.textColor = .darkGray
    return label
  }()
  
  private var filePreviewImageView: WatermarkedImageView = {
    var imageView = WatermarkedImageView()
    imageView.isHidden = true
    return imageView
  }()

  private var filePreviewShadoImageView: UIImageView = {
    var imageView = UIImageView()
    imageView.image = UIImage(named: "bottom_right_shadow")
    imageView.contentMode = .scaleAspectFill
    imageView.layer.cornerRadius = 6
    imageView.layer.masksToBounds = true
    imageView.isHidden = true
    return imageView
  }()
  
  private var encryptionAnimationView: AnimationView = {
    let view = AnimationView(name: "FileEncryption")
    view.contentMode = .scaleAspectFit
    view.loopMode = .loop
    view.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
    view.isHidden = true
    return view
  }()
  
  private var videoPlayImage: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 58, height: 58))
    imageView.image = UIImage(systemName: "play.circle.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
    imageView.contentMode = .scaleAspectFill
    imageView.tintColor = .systemGray3
    imageView.backgroundColor = .darkGray
    imageView.layer.cornerRadius = 30
    imageView.isHidden = true
    return imageView
  }()
  
  private var bodyLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .clear
    label.numberOfLines = 0
    return label
  }()
  
  override var viewModel: MessageViewModel! {
    didSet {
      
      bodyLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 17)
      
      if viewModel.message.containAttachment {
        
        viewModel.message.$fileTransferState
          .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
          .receive(on: DispatchQueue.main).sink { [weak self] (value) in
            guard let strongSelf = self else { return }
            if value <= 0 {
              strongSelf.fileUploadProgressLabel.text = "0%"
            }
            else {
              strongSelf.fileUploadProgressLabel.text = "\(value)%"
              if value == 100 {
                strongSelf.setupFileViews(filePath: strongSelf.viewModel.message.localFilename)
              }
            }
        }.store(in: &cancellableBag)
        
        viewModel.message.$localFilename
          .filter({ [weak self] (_) -> Bool in
            guard let strongSelf = self else { return false }
            return strongSelf.viewModel.message.containAttachment
          })
          .receive(on: DispatchQueue.main)
          .sink { [weak self] (filePath) in
            guard let strongSelf = self else { return }
             
            strongSelf.setupFileViews(filePath: filePath)
            
        }.store(in: &cancellableBag)
        
        viewModel.message.$autoDownload.receive(on: DispatchQueue.main).sink { [weak self] (value) in
          guard let strongSelf = self else { return }
          if value {
            strongSelf.setupFileViews(filePath: strongSelf.viewModel.message.localFilename)
          }
        }.store(in: &cancellableBag)
        
        dateLabel.textColor = viewModel.message.body.isEmpty ? .white : .systemGray2
        
        if viewModel.message.localFilename.isEmpty == false {
          setupFileViews(filePath: viewModel.message.localFilename)
        }
        
      } else {
        filePreviewImageView.isHidden = true
        filePreviewShadoImageView.isHidden = true
      }
    }
  }
  
  private func setupFileViews(filePath: String) {
    
    if viewModel.showDownloadButton {
      viewModel.message.fileTransferState = 0
      downloadButton.isHidden = false
      
      encryptionAnimationView.isHidden = true
      fileUploadProgressLabel.isHidden = true
      filePreviewImageView.isHidden = true
      filePreviewShadoImageView.isHidden = true
      if encryptionAnimationView.isAnimationPlaying {
        encryptionAnimationView.stop()
      }
      
      dateLabel.textColor = .systemGray2
    }
    else {
      dateLabel.textColor = viewModel.message.body.isEmpty ? .white : .systemGray2
      downloadButton.isHidden = true
      
      if viewModel.isDownloadComplete {

        // Stop the refresh timer
        viewModel.stopRefreshFileTransferState()
        
        filePreviewImageView.isHidden = false
        filePreviewShadoImageView.isHidden = false
        
        // Stop and Hide the encrypotion animation view
        encryptionAnimationView.isHidden = true
        fileUploadProgressLabel.isHidden = true
        if encryptionAnimationView.isAnimationPlaying {
          encryptionAnimationView.stop()
        }
        
        // Add the image or video thumbnail
        switch viewModel.message.type {
        case .photo:
          
          if filePreviewImageView.imageView.image == nil {
              
              guard !viewModel.message.fileKey.isEmpty,
                    let data = AppUtility.decryptFile(viewModel.message.localFilename, key: viewModel.message.fileKey.base64Decoded ?? "") else {
                  filePreviewImageView.imageView.sd_setImage(with: URL(fileURLWithPath: viewModel.message.localFilename), completed: nil)
                  return
              }
                filePreviewImageView.image = UIImage(data: data)
              }
          
          let gesture = UITapGestureRecognizer(target: self, action: #selector(openFile))
          gesture.cancelsTouchesInView = false
          filePreviewImageView.isUserInteractionEnabled = true
          filePreviewImageView.addGestureRecognizer(gesture)
          
        case .video:
          
          videoPlayImage.isHidden = false
          
          if let image = viewModel.getVideoThumbnail() {
            filePreviewImageView.imageView.image = image
          }
          
          let gesture = UITapGestureRecognizer(target: self, action: #selector(openFile))
          gesture.cancelsTouchesInView = false
          
          filePreviewImageView.isUserInteractionEnabled = true
          filePreviewImageView.addGestureRecognizer(gesture)
          
        default:
          break
        }
      }
      else {
        dateLabel.textColor = viewModel.message.body.isEmpty ? .white : .systemGray2
        downloadButton.isHidden = true
        
        viewModel.message.fileTransferState = 0
        encryptionAnimationView.isHidden = false
        fileUploadProgressLabel.isHidden = false
        filePreviewImageView.isHidden = true
        if encryptionAnimationView.isAnimationPlaying == false {
          encryptionAnimationView.play()
        }
        
        // start updating the Status timer
        viewModel.refreshFileTransferStateAsync()
      }
    }

//    setNeedsLayout()
//    layoutIfNeeded()
  }
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    // We insert these view at the specific index so that the DateLabel and the checkmark image remain on TOP
    messageContentView.insertSubview(bodyLabel, at: 0)
    messageContentView.insertSubview(encryptionAnimationView, at: 1)
    messageContentView.insertSubview(filePreviewImageView, at: 2)
    messageContentView.insertSubview(fileUploadProgressLabel, at: 3)
    messageContentView.insertSubview(filePreviewShadoImageView, at: 4)
    messageContentView.insertSubview(videoPlayImage, at: 5)
    messageContentView.insertSubview(downloadButton, at: 6)
    
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    bodyLabel.attributedText = nil
    bodyLabel.textColor = .black
    
    filePreviewImageView.imageView.image = nil
    filePreviewImageView.removeGestureRecognizers()
    
    videoPlayImage.isHidden = true
    encryptionAnimationView.isHidden = true
    fileUploadProgressLabel.isHidden = true
    
    // Stop the refresh timer
//    viewModel.stopRefreshFileTransferState()
  }

}

extension MessageCell {
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if pan.state == .ended || pan.state == .possible {
      
      if viewModel.message.containAttachment {
        guard let orientation = screenOrientation else { return }
        let imageHeight: CGFloat = orientation.isPortrait ? 320 : 170
        
        if viewModel.message.localFilename.isEmpty || AppUtility.getFileSize(viewModel.message.localFilename) == 0 {
          encryptionAnimationView.pin.left().top().right().height(imageHeight)
          fileUploadProgressLabel.pin.vCenter(to: encryptionAnimationView.edge.vCenter).marginTop(35).left().right()
        }
        
        if viewModel.message.type == .video {
          videoPlayImage.pin.vCenter().hCenter()
        }
        
        if viewModel.isSent {
          if viewModel.message.body.count == 0 {
            filePreviewImageView.pin.all()
          }
          else {
            filePreviewImageView.pin.left().top().right().height(imageHeight)
          }
        }
        else {
          if viewModel.message.isGroupChat == false {
            if viewModel.message.body.count == 0 {
              filePreviewImageView.pin.all()
            } else {
              filePreviewImageView.pin.left().top().right().height(imageHeight)
            }
          }
          else {
            if viewModel.message.body.count == 0 {
              filePreviewImageView.pin.all()
            }
            else {
              filePreviewImageView.pin.left().top().right().height(imageHeight)
            }
          }
        }
        
        filePreviewShadoImageView.pin.topLeft(to: filePreviewImageView.anchor.topLeft).bottomRight(to: filePreviewImageView.anchor.bottomRight)
        
        bodyLabel.pin
          .below(of: filePreviewImageView)
          .marginTop(1)
          .left(4)
          .right(4)
          .sizeToFit(.width)

        downloadButton.pin.vCenter().hCenter()
      }
      else {
        bodyLabel.pin
          .top(1)
          .left(4)
          .right(4)
          .sizeToFit(.width)
      }
      
      bodyLabel.textAlignment = viewModel.message.body.isArabic ? .right : .left
      
    }
  }
  
}

// MARK: - Actions / Selectors
extension MessageCell {
  @objc func openFile() {
    guard let vc = findViewController(), viewModel.isEditing.delete == false, viewModel.isEditing.forward == false  else { return }
    
    if viewModel.message.type == .photo {
      let gallery = GalleryViewController(startIndex: 0, itemsDataSource: self, configuration: galleryConfiguration())
      
      
      gallery.swipedToDismissCompletion = {
        AppUtility.removeWatermarkFromWindow()
      }
      gallery.closedCompletion = {
        AppUtility.removeWatermarkFromWindow()
      }
      vc.presentImageGallery(gallery) {
//        AppUtility.addWatermarkToWindow()
      }
      
    } else {
        let videoPlayerVC = VideoPlayerViewController(videoPath: viewModel.message.localFilename, key: viewModel.message.fileKey.base64Decoded ?? "")
      vc.navigationController?.pushViewController(videoPlayerVC, animated: true)
    }
  }
  
  @objc private func downloadButtonPressed() {
    downloadButton.isHidden = true
    encryptionAnimationView.isHidden = false
    fileUploadProgressLabel.isHidden = false
    if encryptionAnimationView.isAnimationPlaying == false {
      encryptionAnimationView.play()
    }
    
    viewModel.downloadFileAsync()
  }
}


extension MessageCell: GalleryItemsDataSource {
  
  func itemCount() -> Int {
    return 1
  }
  
  func provideGalleryItem(_ index: Int) -> GalleryItem {
      return GalleryItem.image { $0(self.filePreviewImageView.image) }
  }
  
  func galleryConfiguration() -> GalleryConfiguration {
    
    return [
      
      GalleryConfigurationItem.closeButtonMode(.builtIn),
      GalleryConfigurationItem.seeAllCloseButtonMode(.none),
      GalleryConfigurationItem.thumbnailsButtonMode(.none),
      GalleryConfigurationItem.deleteButtonMode(.none),
      GalleryConfigurationItem.activityViewByLongPress(false),
      
//      GalleryConfigurationItem.pagingMode(.standard),
//      GalleryConfigurationItem.presentationStyle(.displacement),
//      GalleryConfigurationItem.hideDecorationViewsOnLaunch(false),
//
//      GalleryConfigurationItem.swipeToDismissMode(.vertical),
//      GalleryConfigurationItem.toggleDecorationViewsBySingleTap(false),
//      GalleryConfigurationItem.activityViewByLongPress(false),
//
//      GalleryConfigurationItem.overlayColor(UIColor(white: 0.035, alpha: 1)),
//      GalleryConfigurationItem.overlayColorOpacity(1),
//      GalleryConfigurationItem.overlayBlurOpacity(1),
//      GalleryConfigurationItem.overlayBlurStyle(UIBlurEffect.Style.light),
//
//      GalleryConfigurationItem.videoControlsColor(.white),
//
//      GalleryConfigurationItem.maximumZoomScale(8),
//      GalleryConfigurationItem.swipeToDismissThresholdVelocity(500),
//
//      GalleryConfigurationItem.doubleTapToZoomDuration(0.15),
//
//      GalleryConfigurationItem.blurPresentDuration(0.5),
//      GalleryConfigurationItem.blurPresentDelay(0),
//      GalleryConfigurationItem.colorPresentDuration(0.25),
//      GalleryConfigurationItem.colorPresentDelay(0),
//
      GalleryConfigurationItem.blurDismissDuration(0.2),
      GalleryConfigurationItem.blurDismissDelay(0),
      GalleryConfigurationItem.colorDismissDuration(0.2),
      GalleryConfigurationItem.colorDismissDelay(0),
//
//      GalleryConfigurationItem.itemFadeDuration(0.3),
//      GalleryConfigurationItem.decorationViewsFadeDuration(0.15),
//      GalleryConfigurationItem.rotationDuration(0.15),
//
//      GalleryConfigurationItem.displacementDuration(0.55),
//      GalleryConfigurationItem.reverseDisplacementDuration(0.25),
//      GalleryConfigurationItem.displacementTransitionStyle(.springBounce(0.7)),
//      GalleryConfigurationItem.displacementTimingCurve(.linear),
//
//      GalleryConfigurationItem.statusBarHidden(true),
//      GalleryConfigurationItem.displacementKeepOriginalInPlace(false),
//      GalleryConfigurationItem.displacementInsetMargin(50)
    ]
  }

}
