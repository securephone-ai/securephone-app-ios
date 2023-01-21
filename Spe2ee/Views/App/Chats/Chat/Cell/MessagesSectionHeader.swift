

import UIKit

class MessagesSectionHeader: UITableViewHeaderFooterView {

  static let height: CGFloat = 30
  
  lazy var labelBackgroundView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 8
    view.backgroundColor = Constants.MessagesHeaderDateBackgroundColor
    return view
  }()
  
  lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFontSemiBold(ofSize: 13)
    label.textAlignment = .center
    label.numberOfLines = 1
    return label
  }()
  
  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    labelBackgroundView.addSubview(titleLabel)
    contentView.addSubview(labelBackgroundView)
    contentView.backgroundColor = .clear
    backgroundView = UIView()
    backgroundView!.backgroundColor = .clear
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    layer.backgroundColor = UIColor.clear.cgColor
    backgroundColor = .clear
    
    titleLabel.sizeToFit()
    
    labelBackgroundView.pin
      .height(titleLabel.frame.size.height+6)
      .width(titleLabel.frame.size.width+20)
      .vCenter()
      .hCenter()
    titleLabel.pin.vCenter().hCenter()
    
    labelBackgroundView.dropShadow(color: UIColor.black, opacity: 0.2, offSet: CGSize(width: 0, height: 0.6), radius: 1, scale: true)
  }
  
  override func prepareForReuse() {
    titleLabel.text = ""
  }
}
