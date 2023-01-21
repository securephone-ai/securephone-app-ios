import Foundation
import UIKit
import FlexLayout
import PinLayout

protocol MembersCollectionCellDlegate: class {
  func removedMember(at index: Int)
}

class MembersCollectionCell: UITableViewCell {
  static let ID = "MembersCollectionCell"
  
  weak var delegate: MembersCollectionCellDlegate?
  
  private var rootFlexContainer = UIView()
  var members: [BBContact]? {
    didSet {
      guard let members = self.members else { return }
      
      while rootFlexContainer.subviews.count > 0 {
        rootFlexContainer.subviews[0].removeFromSuperview()
      }
      
      rootFlexContainer.flex.direction(AppUtility.isArabic ? .rowReverse : .row).wrap(.wrap).define { (flex) in
        for (index, member) in members.enumerated() {
          let view = MemberCellView()
          view.memberNameLabel.text = member.name
          view.memberNameLabel.sizeToFit()
          view.removeButton.addTarget(self, action: #selector(removeMember), for: .touchUpInside)
          view.removeButton.tag = index
          
          view.memberImageView.backgroundColor = member.color
          view.memberNameInitialsLabel.text = member.getInitials()
          
          flex.addItem(view).height(90).width(80)
        }
      }
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    contentView.addSubview(rootFlexContainer)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    rootFlexContainer.pin.all()
    rootFlexContainer.flex.layout(mode: .adjustHeight)
  }
  
  @objc func removeMember(sender: UIButton) {
    let index = sender.tag
    
    guard let delegate = self.delegate else { return }
    delegate.removedMember(at: index)    
  }
  
}

extension MembersCollectionCell {
  public static func calculateHeight(members: [BBContact], tableWidth: CGFloat) -> CGFloat {
    let rootFlexContainer = UIView(frame: CGRect(x: 0, y: 0, width: tableWidth, height: 0))
    
    rootFlexContainer.flex.direction(.row).wrap(.wrap).define { (flex) in
      for member in members {
        let view = MemberCellView(frame: CGRect(x: 0, y: 0, width: 74, height: 90))
        view.memberNameLabel.text = member.name
        view.memberNameLabel.sizeToFit()
        flex.addItem(view)
      }
    }
    
    // 2) Let the flexbox container layout itself and adjust the height
    rootFlexContainer.flex.layout(mode: .adjustHeight)
    
    return rootFlexContainer.frame.height
  }
}
