import UIKit
import PinLayout

protocol CallContactCellDelegate: class {
  func didTapOnCloseButton(indexPath: IndexPath)
}

class CallContactCell: ContactCell {
  weak var delegate: CallContactCellDelegate?
  
  lazy var activityIndicator: UIActivityIndicatorView = {
    let view = UIActivityIndicatorView(style: .medium)
    view.color = .white
    view.hidesWhenStopped = true
    view.stopAnimating()
    return view
  }()
  
  lazy var closeButton: UIButton = {
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
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    contentView.addSubview(closeButton)
    contentView.addSubview(activityIndicator)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    activityIndicator.stopAnimating()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    closeButton.pin.right(10).vCenter()
    activityIndicator.pin.center(to: avatar.anchor.center)
    
    backgroundColor = .clear
    contentView.backgroundColor = .clear
  }
  
  @objc func closeIconPressed() {
    guard let delegate = delegate, let indexPath = indexPath else { return }
    delegate.didTapOnCloseButton(indexPath: indexPath)
    activityIndicator.startAnimating()
  }
}

