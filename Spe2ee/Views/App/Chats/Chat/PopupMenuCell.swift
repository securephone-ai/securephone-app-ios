//
//  HSPopupMenuCell.swift
//  HSPopupMenu
//
//  Created by Hanson on 2018/1/30.
//

import UIKit
import PinLayout

class PopupMenuCell: UITableViewCell {
  
  fileprivate static let titleFont = UIFont.appFont(ofSize: 16)
  
  private lazy var menuTextColor: UIColor = {
    return .black
//    return isDarkMode ? .white : .black
  }()
  
  private lazy var menuIconColor: UIColor = {
    return .darkGray
//    return isDarkMode ? .white : .darkGray
  }()
  
  var menu: Menu?
  
  lazy var iconView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  lazy var titleLabel: UILabel = {
    let label = UILabel(text: "A")
    label.font = PopupMenuCell.titleFont
    label.frame = CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: label.requiredHeight)
    label.text = ""
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 1
    return label
  }()
  lazy var line: UIView = UIView()
  
  
  // MARK: - Initialization
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    setUpCell()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setUpCell() {
    titleLabel.textColor = menuTextColor
    
    iconView.contentMode = .scaleAspectFit
    iconView.tintColor = menuIconColor
    
    line.backgroundColor = .darkGray
    
    self.backgroundColor = UIColor.clear
    self.contentView.addSubview(self.iconView)
    self.contentView.addSubview(self.titleLabel)
    self.contentView.addSubview(self.line)
  }
}

// MARK: - Function
extension PopupMenuCell {
  override func layoutSubviews() {
    iconView.pin.left(15).vCenter().height(titleLabel.height).width(titleLabel.height)
    titleLabel.pin.centerLeft(to: iconView.anchor.centerRight).marginLeft(15).right(15)
    line.pin.bottom().left().right().height(0.5)
  }
}

extension PopupMenuCell {
  func configureCell(menu: Menu) {
    titleLabel.text = menu.title
    
    if let icon = menu.icon {
      iconView.image = icon
      
    } else {
      iconView.isHidden = true
//      titleLabel.pin.left(8).right(8).top(5).bottom(5)
    }
    
    self.menu = menu
  }
  
  static func getRequiredHeight() -> CGFloat {
    let label = UILabel(text: "A")
    label.font = titleFont
    label.adjustsFontForContentSizeCategory = true
    return label.requiredHeight + 26
  }
}

