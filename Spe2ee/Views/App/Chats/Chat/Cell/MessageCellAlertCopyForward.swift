import UIKit
import PinLayout
import ImageViewer
import Combine

class MessageCellAlertCopyForward: MessageDefaultCell {
  
  override var viewModel: MessageViewModel! {
    didSet {
      
      sendReadReceipt()
      
      rootView.removeGestureRecognizers()
      
      switch viewModel.message.type {
      case .alertScreenshot:
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(previewLabelpressed))
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.delegate = self
        rootView.addGestureRecognizer(gestureRecognizer)
        
        previewLabel.isHidden = false
        alertTypeLabel.text = "Screenshot".localized().uppercased()
        let takenBy = "\("Taken by".localized()): ".localized()
        let attributedText = NSMutableAttributedString()
        
        let takenByAttrStr = NSMutableAttributedString(string: takenBy)
        let normalFont = UIFont.appFont(ofSize: 16)
        takenByAttrStr.addAttribute(NSAttributedString.Key.font, value: normalFont, range: NSRange(location: 0, length: takenBy.count))
        attributedText.append(takenByAttrStr)
        
        var name = "You".localized()
        if viewModel.isSent == false {
          name = viewModel.contact.getName()
        }
        
        let nameAttrStr = NSMutableAttributedString(string: name)
        let semiBoldFont = UIFont.appFontBold(ofSize: 16)
        nameAttrStr.addAttribute(NSAttributedString.Key.font, value: semiBoldFont, range: NSRange(location: 0, length: nameAttrStr.string.count))
        attributedText.append(nameAttrStr)
        
        contentLabel.attributedText = attributedText
        
        if viewModel.isDownloadComplete == false {
          // start updating the Status timer
          viewModel.downloadFileAsync()
        } else {
          viewModel.stopRefreshFileTransferState()
        }
        
        if viewModel.isSent == false {
          viewModel.message.$fileTransferState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (value) in
              guard let strongSelf = self else { return }
              if value < 0 {
                strongSelf.previewLabel.text = "\("Click here to preview".localized()) - ↓ 0%"
              }
              else {
                strongSelf.previewLabel.text = "\("Click here to preview".localized()) - ↓ \(value)%"
                if value == 100 {
                  strongSelf.previewLabel.text = "Click here to preview".localized()
                }
              }
              strongSelf.previewLabel.pin.below(of: strongSelf.dateLabel).marginTop(2).left(10).right(10).sizeToFit(.width)
          }.store(in: &cancellableBag)
        }
        
      case .alertScreenRecording:
        previewLabel.isHidden = true
        alertTypeLabel.text = "RECORDING".localized()
        let startedBy = "\("Started by".localized()): "
        let attributedText = NSMutableAttributedString()
        
        let startedByAttrStr = NSMutableAttributedString(string: startedBy)
        let normalFont = UIFont.appFont(ofSize: 16)
        startedByAttrStr.addAttribute(NSAttributedString.Key.font, value: normalFont, range: NSRange(location: 0, length: startedBy.count))
        attributedText.append(startedByAttrStr)
        
        var name = "You".localized()
        if viewModel.isSent == false {
          name = viewModel.contact.getName()
        }
        
        let nameAttrStr = NSMutableAttributedString(string: name)
        let semiBoldFont = UIFont.appFontSemiBold(ofSize: 16)
        nameAttrStr.addAttribute(NSAttributedString.Key.font, value: semiBoldFont, range: NSRange(location: 0, length: nameAttrStr.string.count))
        attributedText.append(nameAttrStr)
        
        contentLabel.attributedText = attributedText
      default:
        break
      }
      
      dateLabel.text = viewModel.messageSentTime
      
      alertTypeLabel.sizeToFit()
      contentLabel.sizeToFit()
      dateLabel.sizeToFit()
    }
  }
  
  private var rootView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 12
    view.borderWidth = 1.5
    view.borderColor = .white
    view.backgroundColor = Constants.AlertColorScreenshot
    return view
  }()
  
  private var alertTypeLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontBold(ofSize: 16)
    label.textAlignment = .center
    label.textColor = .white
    label.numberOfLines = 0
    return label
  }()
  
  private var contentLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 16)
    label.textAlignment = .center
    label.textColor = .white
    label.numberOfLines = 0
    return label
  }()
  
  private var dateLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 16)
    label.textAlignment = .center
    label.textColor = .white
    label.numberOfLines = 0
    return label
  }()
  
  private lazy var previewLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 15)
    label.textAlignment = .center
    label.textColor = .white
    label.numberOfLines = 1
    label.text = "Click here to preview".localized()
    return label
  }()
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    backgroundColor = .clear
    selectionStyle = .none
    
    contentView.addSubview(rootView)
    rootView.addSubview(alertTypeLabel)
    rootView.addSubview(contentLabel)
    rootView.addSubview(dateLabel)
    rootView.addSubview(previewLabel)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    rootView.pin
      .top(4)
      .bottom(4)
      .width(80%)
      .hCenter()
    rootView.dropShadow(color: .black, opacity: 0.2, offSet: CGSize(width: 0, height: 0.6), radius: 1, scale: true)
    
//    contentLabel.pin.vCenter(-(contentLabel.height/1.6)).left(10).right(10)
//    dateLabel.pin.vCenter(dateLabel.height/1.6).left(10).right(10)
//    alertTypeLabel.pin.above(of: contentLabel).left(10).right(10).marginBottom(2)
//    previewLabel.pin.below(of: dateLabel, aligned: .center).sizeToFit(.content).marginTop(2)
    
    alertTypeLabel.pin.left(10).right(10).top(8)
    contentLabel.pin.below(of: alertTypeLabel).marginTop(2).left(10).right(10)
    dateLabel.pin.below(of: contentLabel).marginTop(2).left(10).right(10)
    if viewModel.message.type == .alertScreenshot {
      previewLabel.pin.below(of: dateLabel).marginTop(2).left(10).right(10).sizeToFit(.width)
    }
  }
  
  func sendReadReceipt() {
    if viewModel.isRead == false , viewModel.isSent == false {
      if let group = self.viewModel.group {
        group.sendReadReceiptAsync(of: self.viewModel.message)
      } else {
        self.viewModel.contact.sendReadReceiptAsync(of: self.viewModel.message)
      }
    }
  }
  
  @objc private func previewLabelpressed() {
    guard let vc = findViewController(),
      viewModel.isEditing.delete == false,
      viewModel.isEditing.forward == false,
      viewModel.message.fileTransferState == 100 else { return }
    
    let gallery = GalleryViewController(startIndex: 0, itemsDataSource: self, configuration: galleryConfiguration())
    gallery.swipedToDismissCompletion = {
      AppUtility.removeWatermarkFromWindow()
    }
    gallery.closedCompletion = {
      AppUtility.removeWatermarkFromWindow()
    }
    vc.presentImageGallery(gallery) {
//      AppUtility.addWatermarkToWindow()
    }
  }
}


extension MessageCellAlertCopyForward: GalleryItemsDataSource {
  
  func itemCount() -> Int {
    return 1
  }
  
  func provideGalleryItem(_ index: Int) -> GalleryItem {
      return GalleryItem.image {
          guard let data = AppUtility.decryptFile(self.viewModel.message.localFilename, key: self.viewModel.message.fileKey.base64Decoded ?? "") else {
              return $0(UIImage())
          }
          
          $0(UIImage(data: data))
      }
  }
  
  func galleryConfiguration() -> GalleryConfiguration {
    
    return [
      
      GalleryConfigurationItem.closeButtonMode(.builtIn),
      GalleryConfigurationItem.seeAllCloseButtonMode(.none),
      GalleryConfigurationItem.thumbnailsButtonMode(.none),
      GalleryConfigurationItem.deleteButtonMode(.none),
      GalleryConfigurationItem.activityViewByLongPress(false)
      
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
      //      GalleryConfigurationItem.blurDismissDuration(0.1),
      //      GalleryConfigurationItem.blurDismissDelay(0.4),
      //      GalleryConfigurationItem.colorDismissDuration(0.45),
      //      GalleryConfigurationItem.colorDismissDelay(0),
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
