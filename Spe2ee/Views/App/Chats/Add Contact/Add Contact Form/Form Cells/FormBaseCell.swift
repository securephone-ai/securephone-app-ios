import UIKit
import PinLayout
import Combine

class FormBaseCell: UITableViewCell {
  static let ID = "FormBaseCell"
  static let totalHeight: CGFloat = 55
  
  var cancellable: AnyCancellable?
  
  public var title: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 16)
    label.text = "Name".localized()
    label.sizeToFit()
    return label
  }()
  public var cancellableTextField: CancellableTextField = {
    let textField = CancellableTextField()
    return textField
  }()
  
  override func prepareForReuse() {
    cancellable?.cancel()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    selectionStyle = .none
    contentView.backgroundColor = .white
    
    contentView.addSubview(title)
    contentView.addSubview(cancellableTextField)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    title.sizeToFit()
    title.pin.left(18).width(18%).top(16)
    cancellableTextField.pin.right(of: title).vCenter(to: title.edge.vCenter).marginLeft(47).right().height(50)
  }

}
