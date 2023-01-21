import Foundation
import PinLayout
import Combine
import JGProgressHUD
import SCLAlertView

class ChangeGroupNameViewController: UIViewController {
  
  private var group: BBGroup
  private var cancellableBag = Set<AnyCancellable>()
  
  private lazy var headerView: UIView = {
    let view = UIView()
    view.addSubview(self.titleLabel)
    view.addSubview(self.cancelButton)
    view.addSubview(self.saveButton)
    view.backgroundColor = .white
    return view
  }()
  
  private var titleLabel: UILabel = {
    let label = UILabel()
    label.text = "Subject"
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.adjustsFontForContentSizeCategory = true
    return label
  }()
  
  private lazy var cancelButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cancel".localized(), for: .normal)
    button.addTarget(self, action: #selector(cancelPressed), for: .touchUpInside)
    return button
  }()
  
  private lazy var saveButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Save".localized(), for: .normal)
    button.addTarget(self, action: #selector(savePressed), for: .touchUpInside)
    button.isEnabled = false
    return button
  }()
  
  private lazy var nameTextField: CancellableTextField = {
    let view = CancellableTextField()
    view.textField.placeholder = group.description
    view.textField.text = group.description
    view.textField.setLeftPaddingPoints(14)
    view.backgroundColor = .white
    view.showBorderLines = true
    return view
  }()
  
  init(group: BBGroup) {
    self.group = group
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .systemGray6
    
    view.addSubview(headerView)
    view.addSubview(nameTextField)
    
    nameTextField.textField.textPublisher
      .receive(on: DispatchQueue.main)
      .map { (str) -> Bool in
        str.count > 0
    }.assign(to: \.isEnabled, on: saveButton).store(in: &cancellableBag)
    
    
    nameTextField.textField.becomeFirstResponder()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    cancelButton.sizeToFit()
    saveButton.sizeToFit()
    titleLabel.sizeToFit()
    
    headerView.pin.top().left().right().height(50)
    cancelButton.pin.left(14).vCenter()
    saveButton.pin.right(14).vCenter()
    titleLabel.pin.center()
    
    nameTextField.pin.height(46).below(of: headerView).marginTop(16).left().right()
    
    
  }
  
  @objc private func cancelPressed() {
    self.dismiss(animated: true, completion: nil)
  }
  
  @objc private func savePressed() {
    if let description = nameTextField.textField.text {
      nameTextField.textField.resignFirstResponder()
      let hud = JGProgressHUD(style: .dark)
      hud.show(in: self.view)
      group.updateDescriptionAsync(description: description) { (success) in
        DispatchQueue.main.async { [weak self] in
          guard let strongSelf = self else { return }
          hud.dismiss()
          if success {
            strongSelf.cancelPressed()
          }
          else {
            if let networkManager = Blackbox.shared.networkManager, networkManager.isReachable {
              SCLAlertView().showError("Error".localized(), subTitle: "We were unalbe to change the group name at this time. Please try again later".localized())
            } else {
              SCLAlertView().showError("Error".localized(), subTitle: "Please check your internet connection and try again".localized())
            }
          }
        }
      }
    }

  }
  
}
