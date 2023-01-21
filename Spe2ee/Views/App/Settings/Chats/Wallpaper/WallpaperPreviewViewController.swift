import UIKit
import PinLayout

class WallpaperPreviewViewController: UIViewController {
  
  private var imageName: String!
  private var wallpaperImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  private lazy var buttonsRootView: UIView = {
    let view = UIView()
    view.backgroundColor = .systemGray6
    view.addSubview(cancellButton)
    view.addSubview(setButton)
    view.addSubview(buttonsSeparatorLineView)
    return view
  }()
  
  private var buttonsSeparatorLineView: UIView = {
    let view = UIView()
    view.backgroundColor = .systemGray
    return view
  }()
  
  private lazy var cancellButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel".localized(), for: .normal)
    button.addTarget(self, action: #selector(cancellPressed), for: .touchUpInside)
    button.tintColor = .black
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    return button
  }()

  private lazy var setButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Set".localized(), for: .normal)
    button.addTarget(self, action: #selector(setPressed), for: .touchUpInside)
    button.tintColor = .black
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    return button
  }()
  
  init(imageName: String) {
    self.imageName = imageName
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    wallpaperImageView.image = UIImage(named: imageName)
    view.addSubview(wallpaperImageView)
    view.addSubview(buttonsRootView)
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    wallpaperImageView.pin.all()
    
    buttonsRootView.pin.bottom(self.view.pin.safeArea.bottom).left().right().height(56)
    cancellButton.pin.left().top().bottom().width(50%)
    setButton.pin.right().top().bottom().width(50%)
    buttonsSeparatorLineView.pin.hCenter().top().bottom().width(1)
  }
  
  
  @objc func cancellPressed() {
    dismiss(animated: true, completion: nil)
    navigationController?.popViewController()
  }
  
  @objc func setPressed() {
    UserDefaults.standard.set(imageName, forKey: "chat_wallpaper")
    cancellPressed()
  }
}

