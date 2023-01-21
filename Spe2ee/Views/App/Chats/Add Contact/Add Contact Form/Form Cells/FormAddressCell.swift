import UIKit
import PinLayout
import FlexLayout
import Combine

class FormAddressCell: UITableViewCell {
  static let ID = "FormAddressCell"
  static let totalHeight: CGFloat = 220.0
  
  private var rootFlexContainer = UIView()
  
  private var cancellableBag = Set<AnyCancellable>()
  var viewController: UIViewController?
  
  var addressJson: AddressJson? {
    didSet {
      guard let addressJson = self.addressJson else { return }
      
      street.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.street, on: addressJson).store(in: &cancellableBag)
      city.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.city, on: addressJson).store(in: &cancellableBag)
      state.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.state, on: addressJson).store(in: &cancellableBag)
      zip.textField.textPublisher.receive(on: DispatchQueue.main).assign(to: \.zip, on: addressJson).store(in: &cancellableBag)
      
      street.textField.text = addressJson.street
      city.textField.text = addressJson.city
      state.textField.text = addressJson.state
      zip.textField.text = addressJson.zip
      
      countryButton.setTitle(addressJson.country, for: .normal)
    }
  }
  
  private var title: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.text = "Address".localized()
    label.sizeToFit()
    return label
  }()
  
  private var street: CancellableTextField = {
    let cancellableTextField = CancellableTextField()
    cancellableTextField.textField.placeholder = "Street".localized()
    return cancellableTextField
  }()
  
  private var city: CancellableTextField = {
    let cancellableTextField = CancellableTextField()
    cancellableTextField.textField.placeholder = "City".localized()
    return cancellableTextField
  }()
  
  private var state: CancellableTextField = {
    let cancellableTextField = CancellableTextField()
    cancellableTextField.textField.placeholder = "State".localized()
    return cancellableTextField
  }()
  
  private var zip: CancellableTextField = {
    let cancellableTextField = CancellableTextField()
    cancellableTextField.textField.placeholder = "Zip".localized()
    return cancellableTextField
  }()
  
  private lazy var countryButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Saudi Arabia".localized(), for: .normal)
    button.titleLabel?.font = UIFont.appFont(ofSize: 17)
    button.tintColor = .black
    button.contentHorizontalAlignment = .left
    button.addTarget(self, action: #selector(countryButtonTap), for: .touchUpInside)
    return button
  }()
  
  private var countryButtonRightArrow: UIImageView = {
    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))
    imageView.tintColor = .systemGray4
    return imageView
  }()

  private var separator: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.3))
    view.backgroundColor = .systemGray4
    return view
  }()
  
  private var separator2: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.3))
    view.backgroundColor = .systemGray4
    return view
  }()
  
  private var separator3: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.3))
    view.backgroundColor = .systemGray4
    return view
  }()
  
  private var verticalSeparator: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 0.3, height: 0))
    view.backgroundColor = .systemGray4
    return view
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(title)
    contentView.addSubview(street)
    contentView.addSubview(separator)
    contentView.addSubview(city)
    contentView.addSubview(separator2)
    contentView.addSubview(state)
    contentView.addSubview(verticalSeparator)
    contentView.addSubview(zip)
    contentView.addSubview(separator3)
    contentView.addSubview(countryButtonRightArrow)
    contentView.addSubview(countryButton)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    title.pin.left(18).width(18%).top(16)
    
    street.pin.right(of: title).marginLeft(50).top().right().height(50)
    separator.pin.topLeft(to: street.anchor.bottomLeft).right()
    city.pin.topLeft(to: street.anchor.bottomLeft).right().height(50)
    separator2.pin.topLeft(to: city.anchor.bottomLeft).right()
    state.pin.topLeft(to: city.anchor.bottomLeft).width(32%).height(50)
    verticalSeparator.pin.right(of: state).height(50).vCenter(to: state.edge.vCenter)
    zip.pin.centerLeft(to: state.anchor.centerRight).marginLeft(4).right().height(50)
    separator3.pin.topLeft(to: state.anchor.bottomLeft).right()
    countryButton.pin.topLeft(to: state.anchor.bottomLeft).right().height(50)
    countryButtonRightArrow.pin.vCenter(to: countryButton.edge.vCenter).right(10)
    
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellableBag.cancellAndRemoveAll()
    
    if rootFlexContainer.isDescendant(of: contentView) {
      rootFlexContainer.removeFromSuperview()
    }

  }
  
  @objc func countryButtonTap() {
    guard let viewController = self.viewController else { return }
    let vc = CountryCodeTableViewController()
    vc.delegate = self
    viewController.navigationController?.pushViewController(vc, animated: true)
  }
}

extension FormAddressCell: CountryCodeTableViewControllerDelegate {
  func didSelect(countryCode: CountryCode) {
    countryButton.setTitle(countryCode.name, for: .normal)
    countryButton.sizeToFit()
    addressJson?.country = countryCode.name
  }
}
extension FormAddressCell {
  private func addSeparator(flex: Flex) {
    // Separator
    flex.addItem().height(0.3).backgroundColor(.systemGray4)
  }
  
  private func addItem(flex: Flex, item: UIView) {
    flex.addItem(item).height(50).width(100%)
    addSeparator(flex: flex)
  }
}
