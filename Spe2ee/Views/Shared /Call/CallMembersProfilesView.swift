
import Foundation
import Combine

class CallMembersProfilesView: UIView {
  
  private let call: BBCall!
  private var cancellableBag = Set<AnyCancellable>()
  
  private let rootView = UIView()
  
  private lazy var firstAvatar: Avatar = {
    let avatar = Avatar(isSemiCircle: false, showCloseButton: self.call.isConference, object: self.call.members.count > 0 ? self.call.members[0] : nil)
    avatar.delegate = self
    return avatar
  }()
  private lazy var secondAvatar: Avatar = {
    let avatar = Avatar(isSemiCircle: true, showCloseButton: self.call.isConference, object: self.call.members.count > 1 ? self.call.members[1] : nil)
    avatar.delegate = self
    return avatar
  }()
  private lazy var thirdAvatar: Avatar = {
    let avatar = Avatar(isSemiCircle: true, showCloseButton: self.call.isConference, object: self.call.members.count > 2 ? self.call.members[2] : nil)
    avatar.delegate = self
    return avatar
  }()
  private lazy var fourthAvatar: Avatar = {
    let avatar = Avatar(isSemiCircle: true, showCloseButton: self.call.isConference, object: self.call.members.count > 3 ? self.call.members[3] : nil)
    avatar.delegate = self
    return avatar
  }()
  
  deinit {
    logi("CallMembersProfilesView Deinitialized")
  }
  
  init(call: BBCall) {
    self.call = call
    super.init(frame: .zero)
    
    addSubview(rootView)
    
//    if self.call.members.count > 0 {
//
//      if self.call.members.count == 4 {
//        addFourthAvatar(contact: self.call.members[3])
//      }
//
//      if self.call.members.count >= 3 {
//        addThirdAvatar(contact: self.call.members[2])
//      }
//
//      if self.call.members.count >= 2 {
//        addSecondAvatar(contact: self.call.members[1])
//      }
//
//      rootView.addSubview(firstAvatar)
//
//      if let imagePath = self.call.members[0].profilePhotoPath, let image = UIImage.fromPath(imagePath) {
//        firstAvatar.setImage(image)
//      }
//      firstAvatar.setObject(self.call.members[0])
//
//      self.call.members[0].callInfo.$callStatus.receive(on: DispatchQueue.main).sink { [weak self] (status) in
//        guard let strongSelf = self else { return }
//        strongSelf.firstAvatar.isEnabled = status == .answered
//      }.store(in: &cancellableBag)
//
//    }
    
    self.call.$members
      .filter { $0.count > 0 }
//      .debounce(for: .milliseconds(400), scheduler: DispatchQueue.global())
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (members) in
        guard let strongSelf = self else { return }
        
        strongSelf.isHidden = members.count > 0 || strongSelf.call.hasVideo
        
        guard members.count == 1 else { return }
        
        strongSelf.cancellableBag.cancellAndRemoveAll()
        strongSelf.rootView.removeSubviews()
        strongSelf.rootView.addSubview(strongSelf.firstAvatar)
        
        if let imagePath = strongSelf.call.members[0].profilePhotoPath, let image = UIImage.fromPath(imagePath) {
          strongSelf.firstAvatar.setImage(image)
        }
        strongSelf.firstAvatar.setObject(strongSelf.call.members[0])
        
        strongSelf.call.members[0].callInfo.$callStatus.receive(on: DispatchQueue.main).sink { [weak self] (status) in
          guard let strongSelf = self else { return }
          strongSelf.firstAvatar.isEnabled = status == .answered
        }.store(in: &strongSelf.cancellableBag)
        
//        let subviewsCount = strongSelf.rootView.subviews.count
//
//        if subviewsCount > members.count {
//          if members.count == 3 {
//            strongSelf.fourthAvatar.removeFromSuperview()
//          }
//          else if members.count == 2 {
//            strongSelf.thirdAvatar.removeFromSuperview()
//            strongSelf.fourthAvatar.removeFromSuperview()
//          }
//          else if members.count == 1 {
//            strongSelf.secondAvatar.removeFromSuperview()
//            strongSelf.thirdAvatar.removeFromSuperview()
//            strongSelf.fourthAvatar.removeFromSuperview()
//          }
//
//          if strongSelf.call.members.count >= 1 {
//            if let imagePath = members[0].profilePhotoPath, let image = UIImage.fromPath(imagePath), let resizedImage = strongSelf.resizeImage(image: image, newWidth: 100)  {
//              strongSelf.firstAvatar.setImage(resizedImage)
//            }
//            else if let image = UIImage(named: "avatar_profile"), let resizedImage = strongSelf.resizeImage(image: image, newWidth: 100) {
//              strongSelf.firstAvatar.setImage(resizedImage)
//            }
//            strongSelf.firstAvatar.setObject(members[0])
//          }
//
//          if strongSelf.call.members.count >= 2 {
//            if let imagePath = members[1].profilePhotoPath, let image = UIImage.fromPath(imagePath), let resizedImage = strongSelf.resizeImage(image: image, newWidth: 100) {
//              strongSelf.secondAvatar.setImage(resizedImage)
//            } else if let image = UIImage(named: "avatar_profile"), let resizedImage = strongSelf.resizeImage(image: image, newWidth: 100) {
//              strongSelf.secondAvatar.setImage(resizedImage)
//            }
//            strongSelf.secondAvatar.setObject(members[1])
//          }
//
//          if strongSelf.call.members.count >= 3 {
//            if let imagePath = members[2].profilePhotoPath, let image = UIImage.fromPath(imagePath), let resizedImage = strongSelf.resizeImage(image: image, newWidth: 100) {
//              strongSelf.thirdAvatar.setImage(resizedImage)
//            } else if let image = UIImage(named: "avatar_profile"), let resizedImage = strongSelf.resizeImage(image: image, newWidth: 100) {
//              strongSelf.thirdAvatar.setImage(resizedImage)
//            }
//            strongSelf.secondAvatar.setObject(members[2])
//          }
//
//          UIView.animate(withDuration: 0.2) {
//            strongSelf.layoutAnimatedViews()
//          }
//        }
//        else {
//          if members.count - subviewsCount > 0 {
//            for i in subviewsCount..<members.count {
//              if i == 1 {
//                strongSelf.addSecondAvatar(contact: members[1])
//              }
//              else if i == 2 {
//                strongSelf.addThirdAvatar(contact: members[2])
//              }
//              else if i == 3 {
//                strongSelf.addFourthAvatar(contact: members[3])
//              }
//            }
//
//            UIView.animate(withDuration: 0.2) {
//              strongSelf.layoutAnimatedViews()
//            }
//          }
//        }
        
    }.store(in: &cancellableBag)
    
    self.call.$hasVideo
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (value) in
        guard let strongSelf = self else { return }
        strongSelf.isHidden = strongSelf.call.members.count > 0 || value
    }.store(in: &cancellableBag)
  }
  
  private func addSecondAvatar(contact: BBContact) {
    rootView.addSubview(secondAvatar)
    if let imagePath = contact.profilePhotoPath, let image = UIImage.fromPath(imagePath), let resizedImage = resizeImage(image: image, newWidth: 100) {
      secondAvatar.setImage(resizedImage)
    }
    secondAvatar.setObject(contact)
    
    contact.callInfo.$callStatus.receive(on: DispatchQueue.main).sink { [weak self] (status) in
      guard let strongSelf = self else { return }
      strongSelf.secondAvatar.isEnabled = status == .answered
    }.store(in: &cancellableBag)
  }
  
  private func addThirdAvatar(contact: BBContact) {
    rootView.addSubview(thirdAvatar)
    if let imagePath = contact.profilePhotoPath, let image = UIImage.fromPath(imagePath), let resizedImage = resizeImage(image: image, newWidth: 100) {
      thirdAvatar.setImage(resizedImage)
    }
    thirdAvatar.setObject(contact)
    
    contact.callInfo.$callStatus.receive(on: DispatchQueue.main).sink { [weak self] (status) in
      guard let strongSelf = self else { return }
      strongSelf.thirdAvatar.isEnabled = status == .answered
    }.store(in: &cancellableBag)

  }
  
  private func addFourthAvatar(contact: BBContact) {
    rootView.addSubview(fourthAvatar)
    if let imagePath = contact.profilePhotoPath, let image = UIImage.fromPath(imagePath), let resizedImage = resizeImage(image: image, newWidth: 100) {
      fourthAvatar.setImage(resizedImage)
    }
    fourthAvatar.setObject(contact)
    
    contact.callInfo.$callStatus.receive(on: DispatchQueue.main).sink { [weak self] (status) in
      guard let strongSelf = self else { return }
      strongSelf.fourthAvatar.isEnabled = status == .answered
    }.store(in: &cancellableBag)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    layoutAnimatedViews()

  }
  
  func layoutAnimatedViews() {
    if let call = call {

      // If more then 1, remove 18 width from the avatar width after the first avatar
      let width: CGFloat = call.members.count > 1 ? (firstAvatar.width * CGFloat(call.members.count)) - CGFloat((18 * (call.members.count-1))) : firstAvatar.width
      rootView.pin.top().bottom().width(width).hCenter()
      
      firstAvatar.pin.left().vCenter()
      secondAvatar.pin.right(of: firstAvatar, aligned: .center).marginLeft(-18)
      thirdAvatar.pin.right(of: secondAvatar, aligned: .center).marginLeft(-18)
      fourthAvatar.pin.right(of: thirdAvatar, aligned: .center).marginLeft(-18)
      
    }
  }
  
  func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage? {
    
//    let scale = newWidth / image.size.width
//    let newHeight = image.size.height * scale
    let newHeight = newWidth
    UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
    image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage
  }
  
  private func updateMembersImages() {
    
  }
}

extension CallMembersProfilesView: AvatarDelegate {
  func didTapClose(object: Any?) {
    if let contact = object as? BBContact {
      call.endCallWith(contact: contact)
    }
  }
}

fileprivate protocol AvatarDelegate: class {
  func didTapClose(object: Any?)
}

fileprivate class Avatar: UIView {
  weak var delegate: AvatarDelegate?
  
  private var object: Any?
  
  private let avatarParentView: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.cornerRadius = 50
    view.clipsToBounds = true
    view.borderWidth = 2
    view.borderColor = .white
    return view
  }()
  private let avatarImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFill
    imageView.image = UIImage(named: "avatar_profile")
    return imageView
  }()
  private lazy var closeButton: UIButton = {
    let button = UIButton(type: .system)
    button.contentMode = .scaleAspectFill
    button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
    button.imageView?.contentMode = .scaleAspectFill
    button.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
    button.tintColor = .darkGray
    button.backgroundColor = .white
    button.cornerRadius = button.height/2
    button.addTarget(self, action: #selector(closeIconPressed), for: .touchUpInside)
    
    return button
  }()
  private let mainLayer = CAShapeLayer()
  private var path: UIBezierPath!
  private var image: UIImage?
  private var disabledView: UIView = {
    let view = UIView()
    view.backgroundColor = .black
    view.alpha = 0.75
    view.isHidden = false
    return view
  }()
  
  var isEnabled: Bool = false {
    didSet {
      self.disabledView.isHidden = isEnabled
      if isEnabled {
        avatarParentView.borderColor = .white
      } else {
        avatarParentView.borderColor = .orange
      }
    }
  }

  init(isSemiCircle: Bool, showCloseButton: Bool = false, object: Any? = nil) {
    self.object = object
    super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    self.addSubview(avatarParentView)
    avatarParentView.addSubview(avatarImageView)
    avatarParentView.addSubview(disabledView)
    
    self.addSubview(closeButton)
    if isSemiCircle {
      avatarParentView.mask(withPath: semiCirlePath(), inverse: true)
    }
    
    closeButton.isHidden = !showCloseButton
  }
  
  override init(frame: CGRect) {
    super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    self.cornerRadius = 50
    self.addSubview(avatarImageView)
    self.addSubview(disabledView)
    self.mask(withPath: semiCirlePath(), inverse: true)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()

    avatarImageView.pin.all()
    disabledView.pin.all()
    closeButton.pin.top(4).right(7)
  }
  
  func setImage(_ image: UIImage) {
    avatarImageView.image = image
  }
  
  func setObject(_ object: Any?) {
    self.object = object
  }
  
  private func semiCirlePath() -> UIBezierPath {
    let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
    path.move(to: CGPoint(x: 50, y: 0))
    path.addCurve(to: CGPoint(x: 12, y: 17.5), controlPoint1: CGPoint(x: 34.8, y: 0), controlPoint2: CGPoint(x: 21.2, y: 6.8))
    path.addCurve(to: CGPoint(x: 24.5, y: 50.5), controlPoint1: CGPoint(x: 19.8, y: 26.3), controlPoint2: CGPoint(x: 24.5, y: 37.9))
    path.addCurve(to: CGPoint(x: 12.5, y: 83), controlPoint1: CGPoint(x: 24.5, y: 62.9), controlPoint2: CGPoint(x: 20, y: 74.3))
    path.addCurve(to: CGPoint(x: 50, y: 100), controlPoint1: CGPoint(x: 21.6, y: 93.4), controlPoint2: CGPoint(x: 35, y: 100))
    path.addCurve(to: CGPoint(x: 100, y: 50), controlPoint1: CGPoint(x: 77.6, y: 100), controlPoint2: CGPoint(x: 100, y: 77.6))
    path.addCurve(to: CGPoint(x: 50, y: 0), controlPoint1: CGPoint(x: 100, y: 22.4), controlPoint2: CGPoint(x: 77.6, y: 0))
    path.close()
    
    return path
  }
  
  @objc private func closeIconPressed() {
    guard let delegate = self.delegate else { return }
    delegate.didTapClose(object: object)
  }
}


fileprivate extension UIImage {
  
  func imageByApplyingClippingBezierPath(_ path: UIBezierPath) -> UIImage {
    // Mask image using path
    let maskedImage = imageByApplyingMaskingBezierPath(path)
    
    // Crop image to frame of path
    let croppedImage = UIImage(cgImage: maskedImage.cgImage!.cropping(to: path.bounds)!)
    return croppedImage
  }
  
  func imageByApplyingMaskingBezierPath(_ path: UIBezierPath) -> UIImage {
    // Define graphic context (canvas) to paint on
    UIGraphicsBeginImageContext(size)
    let context = UIGraphicsGetCurrentContext()!
    context.saveGState()
    
    // Set the clipping mask
    path.addClip()
    draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    
    let maskedImage = UIGraphicsGetImageFromCurrentImageContext()!
    
    // Restore previous drawing context
    context.restoreGState()
    UIGraphicsEndImageContext()
    
    return maskedImage
  }

}

