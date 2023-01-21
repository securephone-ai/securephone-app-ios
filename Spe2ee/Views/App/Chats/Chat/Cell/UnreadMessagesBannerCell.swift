import Foundation


class UnreadMessagesBannerCell: MessageDefaultCell {
  
  private let rootView: UIView = {
    let view = UIView()
    view.backgroundColor = Constants.UnreadMessageBannerBackgroundLight
    return view
  }()
  
  let unreadMessagesLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.adjustsFontForContentSizeCategory = true
    label.textAlignment = .center
    return label
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(rootView)
    rootView.addSubview(unreadMessagesLabel)
    
    selectionStyle = .none
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    layer.backgroundColor = UIColor.clear.cgColor
    backgroundColor = .clear
    
    rootView.pin.left().right().top(5).bottom(5)
    unreadMessagesLabel.pin.all()
    
    rootView.dropShadow(color: .black, opacity: 0.2, offSet: CGSize(width: 0, height: 0.5), radius: 1, scale: true)
    
  }
  
}

