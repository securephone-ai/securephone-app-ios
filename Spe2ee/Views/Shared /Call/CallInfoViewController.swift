import Foundation
import PinLayout
import Combine

class CallInfoViewController: UIViewController {
  
  private var call: BBCall?
  private var cancellableBag = Set<AnyCancellable>()
  
  private let rootView = UIView()
  private let gradient = CAGradientLayer()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    label.text = "Calc voice call".localized().uppercased()
    label.font = UIFont.appFont(ofSize: 19)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .white
    label.sizeToFit()
    label.textAlignment = .center
    return label
  }()
  
  private lazy var backButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 12, y: 12, width: 35, height: 35)
    let config = UIImage.SymbolConfiguration(pointSize: 18.5, weight: UIImage.SymbolWeight.regular)
    let image = UIImage(systemName: "chevron.left", withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = .white
    button.addTarget(self, action: #selector(backButtonPressed), for: .touchUpInside)
    return button
  }()
  
  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.ID)
    tableView.dataSource = self
    tableView.delegate = self
    tableView.tableFooterView = UIView()
    tableView.backgroundColor = .clear
    tableView.separatorColor = UIColor.init(white: 1, alpha: 0.3)
    return tableView
  }()
  
  init(call: BBCall) {
    self.call = call
    super.init(nibName: nil, bundle: nil)
    
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(rootView)
    rootView.addSubview(titleLabel)
    rootView.addSubview(backButton)
    rootView.addSubview(tableView)
    rootView.layer.insertSublayer(gradient, at: 0)
    
    view.backgroundColor = .white
    
    guard let call = call else { return }
    for member in call.members {
      member.callInfo.$callStatus.receive(on: DispatchQueue.main).sink {  [weak self] (status) in
        guard let strongSelf = self else { return }
        strongSelf.tableView.reloadData()
      }.store(in: &cancellableBag)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    UIDevice.current.isProximityMonitoringEnabled = false
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    UIDevice.current.isProximityMonitoringEnabled = true
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    rootView.pin.all()
    gradient.colors = [Constants.AppMainColorGreen.cgColor, Constants.AppMainColorGreen.cgColor]
    gradient.frame = CGRect(x: 0.0, y: 0.0, width: rootView.width, height: rootView.height)
    
    backButton.pin.top(self.view.pin.safeArea.top + 8).left(self.view.pin.safeArea.left + 5)
    tableView.pin.below(of: backButton).marginTop(20).left().right().bottom()
    titleLabel.pin.right(of: backButton, aligned: .center).marginLeft(20).right(backButton.frame.origin.x+backButton.width+20)
    
  }
  
  @objc private func backButtonPressed() {
    self.dismiss(animated: true, completion: nil)
  }
  
}

extension CallInfoViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let call = call {
      return call.members.count
    }
    return 0
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return ContactCell.getCellRequiredHeight()
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let call = call else {
      return UITableViewCell()
    }
    let contact = call.members[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.ID) as! ContactCell
    cell.contactName.textColor = .white
    cell.contactName.text = contact.getName()
    cell.contactNumber.textColor = .white
//    cell.contactNumber.text = contact.callInfo.callStatus.toString()
    
    switch contact.callInfo.callStatus {
    case .setup:
      cell.contactNumber.text = "calling".localized().lowercased()
    case .ringing:
      cell.contactNumber.text = "ringing".localized().lowercased()
    case .answered, .answeredAudioOnly, .active:
      cell.contactNumber.text = "Outgoing".localized().lowercased()
    default:
      cell.contactNumber.text = "".localized().lowercased()
    }
    
    if let imagePath = contact.profilePhotoPath {
      cell.avatar.contentMode = .scaleAspectFill
      cell.avatar.image = UIImage.fromPath(imagePath)
    }
    cell.contentView.backgroundColor = .clear
    cell.backgroundColor = .clear
    return cell
  }
  
  
}
