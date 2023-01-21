import UIKit
import PinLayout
import SDWebImage
import Combine
import Lottie
import ImageViewer_swift
import ImageViewer
import CryptoKit
import WatermarkedImageView


class MessageCellText: MessageBaseCell {
  
  private var bodyLabel: UILabel = {
    let label = UILabel()
//    label.backgroundColor = .clear
    label.numberOfLines = 0
    return label
  }()
  
  override var viewModel: MessageViewModel! {
    didSet {
      if self.viewModel.message.isAlertMessage, let alertMsg = viewModel.message.alertMsg {
        bodyLabel.attributedText = alertMsg.getAttributedText(fontSize: 17)?.adjustDirectionBasedOnSystemLanguage()
        bodyLabel.textColor = .white
      }
      else {
        setBodyLabelText()
        
        viewModel.$searchedStringsRange.receive(on: DispatchQueue.main).sink { [weak self] (ranges) in
          guard let strongSelf = self else { return }
          if ranges.isEmpty {
            strongSelf.setBodyLabelText()
          } else {
            for range in ranges {
              let attributedString = NSMutableAttributedString(attributedString: strongSelf.bodyLabel.attributedText!)
              attributedString.addAttribute(NSAttributedString.Key.backgroundColor, value: UIColor.yellow, range: range)
              strongSelf.bodyLabel.attributedText = attributedString
            }
          }
        }.store(in: &cancellableBag)
      }
    }
  }
  
  private func setBodyLabelText() {
    if viewModel.message.body.isSingleEmoji {
      bodyLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 55)
      bodyLabel.textAlignment = .center
    } else {
      bodyLabel.attributedText = viewModel.message.body.getAttributedText(fontSize: 17)
      bodyLabel.textAlignment = viewModel.message.body.isArabic ? .right : .left
    }
  }
  
  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    // We insert these view at the specific index so that the DateLabel and the checkmark image remain on TOP
    messageContentView.insertSubview(bodyLabel, at: 0)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    bodyLabel.attributedText = nil
    bodyLabel.textColor = .black
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if pan.state == .ended || pan.state == .possible {
      bodyLabel.pin
        .top(1)
        .left(4)
        .right(4)
        .sizeToFit(.width)
    }
  }
}
