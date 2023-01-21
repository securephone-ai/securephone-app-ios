import UIKit
import PinLayout
import SDWebImage
import Combine
import Lottie
import ImageViewer_swift
import ImageViewer


class MessageCellDeleted: MessageBaseCell {
  //static let ID = "MessageCell"
  
  private var maxBubbleWidth: CGFloat {
    if viewModel.message.containAttachment {
      return contentView.frame.size.width * 0.80
    }
    return contentView.frame.size.width * 0.75
  }
  private var maxContentWidth: CGFloat {
    return maxBubbleWidth - MessageCell.bubbleContentMargin - 8 // 8 = left margin from superview
  }
  
  private var bodyLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .clear
    label.numberOfLines = 0
    label.textColor = .gray
    return label
  }()
  
  private var stopIcon: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "nosign"))
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .gray
    return imageView
  }()
  
  override var viewModel: MessageViewModel! {
    didSet {
      bodyLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 17)
    }
  }
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    // We insert these view at the specific index so that the DateLabel and the checkmark image remain on TOP
    messageContentView.insertSubview(bodyLabel, at: 0)
    messageContentView.insertSubview(stopIcon, at: 1)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    bodyLabel.text = nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let size = CGSize(width: maxContentWidth, height: .infinity)
    let bodySize = bodyLabel.sizeThatFits(size)
    
    bodyLabel.pin
      .top(1)
      .left(8 + (dateLabel.height * 1.1))
      .right(4)
      .sizeToFit(.width)
    stopIcon.pin.topRight(to: bodyLabel.anchor.topLeft).marginRight(4).marginTop(1).height(dateLabel.height * 1.2).width(dateLabel.height * 1.2)
    
  }
  
}
