
import Foundation
import PinLayout
import SwipeCellKit
import Combine

class CallHistoryCell: SwipeTableViewCell {
  static let ID = "CallHistoryCell"
  
  fileprivate enum AnimationState {
    case edit
    case normal
  }
  
//  var deleteImage = UIButton(type: .custom)
  
  private lazy var deleteImage: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "minus.circle.fill"))
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .red
    imageView.isUserInteractionEnabled = true
    let gesture = UITapGestureRecognizer(target: self, action: #selector(deleteCall))
    gesture.cancelsTouchesInView = true
    imageView.addGestureRecognizer(gesture)
    
    return imageView
  }()
  
  private var contactsImage: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: "avatar_profile.png"))
    imageView.frame = CGRect(x: 0, y: 0, width: 42, height: 42)
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = 21
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  private var contactsNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 16)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .black
    label.frame = CGRect(x: 0, y: 0, width: 0, height: UILabel(text: "A", style: .body).requiredHeight)
    return label
  }()
  
  private var callDirectionLabel = UILabel()
  private var callDateLabel = UILabel()
  private var callTypeImage = UIImageView()
  private lazy var infoButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
    button.setImage(UIImage(systemName: "info.circle"), for: .normal)
    button.addTarget(self, action: #selector(infoButtonPressed), for: .touchUpInside)
    return button
  }()
  
  // Edit Mode
  fileprivate var animationState = AnimationState.normal
  var isAnimating = false
  
  var cancellableBag = Set<AnyCancellable>()
  
  var viewModel: CallHistoryCellViewModel! {
    didSet {
      cancellableBag.cancellAndRemoveAll()
      
      switch viewModel.callGroup.direction {
      case .inbound:
        callDirectionLabel.text = "Incoming".localized()
      case .outbound:
        callDirectionLabel.text = "Outgoing".localized()
      case .missed:
        callDirectionLabel.text = "Missed".localized()
        contactsNameLabel.textColor = .red
      }
      
      switch viewModel.callGroup.type {
      case .call:
        callTypeImage.image = UIImage(systemName: "phone.fill")
      case .video:
        callTypeImage.image = UIImage(systemName: "video.fill")
      }
      
      viewModel.$isEditing.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (value) in
        if value {
          self?.animationState = .edit
          self?.selectionStyle = .none
        } else {
          self?.animationState = .normal
          self?.selectionStyle = .default
        }
        
        // If the Cell was already in Editing mode don't do any animation
        if value, self?.deleteImage.alpha == 1 {
          self?.layoutViews()
        } else {
          UIView.animate(withDuration: 0.3, animations: {
            self?.isAnimating = true
            self?.layoutViews()
          }, completion: { (_) in
            self?.isAnimating = false
          })
        }
        
      }).store(in: &cancellableBag)
      
      if let contact = viewModel.callGroup.contact {
        contactsNameLabel.text = "\(contact.getName()) (\(self.viewModel.totalCalls))"
        
        if let path = contact.profilePhotoPath {
         contactsImage.image = UIImage.fromPath(path)
        } else {
          contactsImage.image = UIImage(named: "avatar_profile")
        }
        
        contact.$profilePhotoPath.receive(on: DispatchQueue.main)
          .filter { $0 != nil }
          .map { $0! }
          .sink(receiveValue: { [weak self](path) in
            guard let strongSelf = self else { return }
            strongSelf.contactsImage.image = UIImage.fromPath(path)
          }).store(in: &cancellableBag)
        
      } else if let contacts = self.viewModel.callGroup.contacts {
        contactsNameLabel.text = contacts.map({ (contact) -> String in
          return contact.getName()
        }).joined(separator: ", ")
        contactsNameLabel.text = "\(contactsNameLabel.text!) (\(self.viewModel.totalCalls))"
      }
      
      callDateLabel.text = self.viewModel.callDate
      
//      contactsNameLabel.sizeToFit()
      callDateLabel.sizeToFit()
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
  func setupCell() {
    separatorInset = UIEdgeInsets(top: 0, left: 78, bottom: 0, right: 0)
    
    callDirectionLabel.font = UIFont.appFont(ofSize: 15)
    callDirectionLabel.textColor = .systemGray
    
    callDateLabel.font = UIFont.appFont(ofSize: 15)
    callDateLabel.textColor = .systemGray
    
    callTypeImage.tintColor = .systemGray
    callTypeImage.contentMode = .scaleAspectFit
    
    contentView.addSubview(deleteImage)
    contentView.addSubview(contactsImage)
    contentView.addSubview(contactsNameLabel)
    contentView.addSubview(callDirectionLabel)
    contentView.addSubview(callDateLabel)
    contentView.addSubview(callTypeImage)
    contentView.addSubview(infoButton)
    
  }
  
  @objc func deleteCall() {
    viewModel?.deleteRequest = true
    showSwipe(orientation: .right)
    viewModel?.deleteRequest = false
  }
  
  @objc func infoButtonPressed() {
    guard let viewController = self.findViewController() else {
      return
    }
    if let contact = viewModel.contact {
//      let transition = CATransition()
//      transition.duration = 0.2
//      transition.type = CATransitionType.push
//      transition.subtype = CATransitionSubtype.fromRight
//      transition.timingFunction = CAMediaTimingFunction(name:CAMediaTimingFunctionName.easeInEaseOut)
//      viewController.view.window!.layer.add(transition, forKey: kCATransition)
//      let vc = ContactInfoViewController(contact: contact)
//      let navController = UINavigationController(rootViewController: vc)
//      navController.modalPresentationStyle = .fullScreen
//      viewController.present(navController, animated: false, completion: nil)
      viewController.title = ""
      viewController.navigationController?.pushViewController(ContactInfoViewController(contact: contact))
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellableBag.cancellAndRemoveAll()
    
    contactsNameLabel.textColor = .black
    isAnimating = false
  }
}

extension CallHistoryCell {
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard !isAnimating else { return }
    layoutViews()
  }
  
  func layoutViews() {
    let size = CGSize(width: contactsNameLabel.height, height: contactsNameLabel.height)
    deleteImage.pin.size(size)
    
    switch animationState {
    case .normal:
      deleteImage.alpha = 0
      deleteImage.pin.vCenter().left(-deleteImage.width)
      infoButton.pin.vCenter().right(18)
      break
    case .edit:
      deleteImage.alpha = 1
      deleteImage.pin.vCenter().left(20)
      infoButton.pin.vCenter().right(-20)
      break
    }
    
    infoButton.pin
      .size(CGSize(width: 25, height: 25))
      .vCenter()
      .right(18)
    
    callDateLabel.pin
      .sizeToFit()
      .centerRight(to: infoButton.anchor.centerLeft)
      .marginRight(8)
    
    contactsImage.pin
      .size(CGSize(width: 42, height: 42 ))
      .centerLeft(to: deleteImage.anchor.centerRight)
      .marginHorizontal(20)
    
    contactsNameLabel.pin
      .horizontallyBetween(contactsImage, and: callDateLabel)
      .marginLeft(10)
      .marginRight(5)
      .vCenter(-(contactsNameLabel.height/2))
    
    callTypeImage.pin
      .size(CGSize(width: 16, height: 16))
      .below(of: contactsNameLabel, aligned: .left)
      .marginTop(4)
    
    callDirectionLabel.pin
      .sizeToFit()
      .centerLeft(to: callTypeImage.anchor.centerRight)
      .marginLeft(5)
    
  }
}
