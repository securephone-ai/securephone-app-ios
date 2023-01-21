import Foundation
import UIKit
import PinLayout


// MARK: - HSMenu
public struct Menu {
  var icon: UIImage?
  var title: String?
  let action: () -> Void
  
  public init(icon: UIImage?, title: String?, action: @escaping () -> ()) {
    self.icon = icon
    self.title = title
    self.action = action
  }
}

// MARK: - HSPopupMenuDelegate
@objc public protocol PopupMenuDelegate {
  
  func popupMenu(_ popupMenu: PopupMenu, didSelectAt index: Int)
}

// MARK: - HSPopupMenu
public enum PopupMenuArrowDirection {
  case up
  case down
}

public class PopupMenu: UIView {
  
  private let CellID = "PopupMenuCell"
  public weak var delegate: PopupMenuDelegate?
  
  
  private let portraitMaxItemsCount = 6
  private let landscapeMaxItemsCount = 2
  private var viewMarginFromTap: CGFloat = 40.0
  private var menuCellSize: CGSize = CGSize(width: 130, height: 44)
  private var arrowDirection : PopupMenuArrowDirection = .down
  private var tapPoint: CGPoint = .zero
  private var tableViewStartPoint: CGPoint = .zero
  
  // MARK: - Views
  private lazy var tableView: UITableView = {
    let tableView = UITableView(frame: CGRect.zero, style: .plain)
//    tableView.backgroundColor = self.isDarkMode ? Constants.MessageContextMenuBackground : .white
    tableView.backgroundColor = .white
    tableView.bounces = false
    tableView.layer.cornerRadius = 5
    tableView.delegate = self
    tableView.dataSource = self
    tableView.clipsToBounds = true
    tableView.separatorStyle = .none
    tableView.tableFooterView = UIView()
    tableView.register(PopupMenuCell.self, forCellReuseIdentifier: CellID)
    tableView.isScrollEnabled = false
    return tableView
  }()
  
  private lazy var arrowView: Arrow = {
    let view = Arrow()
    return view
  }()
  
  private var menuItems: [Menu] = [] {
    didSet {
      self.tableView.reloadData()
    }
  }
  private var groupedItems: [Int: [Menu]] = [Int: [Menu]]() {
    didSet {
      self.tableView.reloadData()
    }
  }
  private var pageIndex: Int = 0 {
    didSet {
      tableView.reloadData()
      setNeedsLayout()
      layoutIfNeeded()
    }
  }
  private var pagesCount: Int {
    guard let orientation = screenOrientation else { return 0 }
    if orientation == .portrait {
      if menuItems.count == 6 {
        return 1
      } else {
        // We use 5 becasue the last row is reserved for the "more" cell
        return Int(CGFloat((CGFloat(menuItems.count)/5)).rounded(.up))
      }
    } else {
      if menuItems.count == 3 {
        return 1
      }
      // We use 2 becasue the last row is reserved for the "more" cell
      return Int(CGFloat((CGFloat(menuItems.count)/2)).rounded(.up))
    }
  }
  
  private lazy var moreButton: Menu = {
    let more = Menu(icon: UIImage(systemName: "ellipsis"), title: "More".localized()) {
      if self.pageIndex >= self.pagesCount-1 {
        self.pageIndex = 0
      } else {
        self.pageIndex += 1
      }
    }
    return more
  }()
  
  // MARK: - Initialization
  public init(menuItems: [Menu],
              tapPoint: CGPoint,
              superview: UIVisualEffectView,
              navbarHeight: CGFloat = .zero,
              statusBarHeight: CGFloat = .zero) {
    super.init(frame: .zero)
    
    superview.contentView.addSubview(self)
    
    backgroundColor = .clear
    
    addSubview(tableView)
    
    self.tapPoint = tapPoint
    self.menuItems = menuItems
    
    if navbarHeight != .zero {
      self.tapPoint.y += navbarHeight
    }
    if statusBarHeight != .zero {
      self.tapPoint.y += statusBarHeight
    }
    
    guard let orientation = screenOrientation else { return }
    
    var tableHeight: CGFloat = .zero
    if orientation == .portrait {
      tableHeight = PopupMenuCell.getRequiredHeight() * CGFloat(menuItems.count)
    } else {
      viewMarginFromTap = 30
      tableHeight = PopupMenuCell.getRequiredHeight() * 3
    }
    
    // 10 in the minimum bottom to superview
    arrowDirection = self.tapPoint.y - tableHeight - viewMarginFromTap > 10 ? .down : .up
    
    // Add the arrow
    arrowView = Arrow(arrowDirection: arrowDirection , color: .white)
    addSubview(arrowView)
    
    if orientation == .portrait {
      let n = menuItems.count / portraitMaxItemsCount
      let reminder = menuItems.count % portraitMaxItemsCount
      
      var menuItemIndex = 0
      for i in 0..<n {
        for _ in 0..<portraitMaxItemsCount {
          if groupedItems[i] == nil {
            groupedItems[i] = [menuItems[menuItemIndex]]
          } else {
            groupedItems[i]?.append(menuItems[menuItemIndex])
          }
          menuItemIndex += 1
        }

        if n > 1 {
          // add the "More.." Item
          groupedItems[i]?.append(moreButton)
        }

      }
      
      if reminder != 0 {
        for i in n..<menuItems.count {
          if groupedItems[n] == nil {
            groupedItems[n] = [menuItems[i]]
          } else {
            groupedItems[n]?.append(menuItems[i])
          }
        }
        // add the "More.." Item
        if n > 0 {
          groupedItems[n]?.append(moreButton)
        }
      }
    }
    else {
      
      if menuItems.count <= 3 {
        for item in menuItems {
          if groupedItems[0] == nil {
            groupedItems[0] = [item]
          } else {
            groupedItems[0]?.append(item)
          }
        }
      } else {
        let n = menuItems.count / landscapeMaxItemsCount
        let reminder = menuItems.count % landscapeMaxItemsCount
        
        var menuItemIndex = 0
        for i in 0..<n {
          for _ in 0..<landscapeMaxItemsCount {
            if groupedItems[i] == nil {
              groupedItems[i] = [menuItems[menuItemIndex]]
            } else {
              groupedItems[i]?.append(menuItems[menuItemIndex])
            }
            menuItemIndex += 1
          }
          
          if n > 1 {
            // add the "More.." Item
            groupedItems[i]?.append(moreButton)
          }
          
        }
        
        if reminder != 0 {
          for i in n..<menuItems.count {
            if groupedItems[n] == nil {
              groupedItems[n] = [menuItems[i]]
            } else {
              groupedItems[n]?.append(menuItems[i])
            }
          }
          // add the "More.." Item
          if n > 0 {
            groupedItems[n]?.append(moreButton)
          }
        }
      }
    }
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}

extension PopupMenu {
  public override func layoutSubviews() {
    super.layoutSubviews()
    guard let superview = self.superview, let orientation = screenOrientation else { return }
    
    let isLandscape = orientation.isPortrait ? false : true
    
    let cellMaxWidth = getCurrentPageMaxCellWidth(isLandscape: isLandscape)
    
    // 20 in the minimum left and right margin to superview
    if (tapPoint.x - (cellMaxWidth/2)) <= 20 {
      pin.left(20)
    }
    else if (tapPoint.x + (cellMaxWidth/2)) >= superview.frame.width {
      pin.left(UIScreen.main.bounds.width - 20 - cellMaxWidth)
    }
    else {
      pin.left(tapPoint.x - (cellMaxWidth/2))
    }
    
    let tableHeight = PopupMenuCell.getRequiredHeight() * CGFloat(getCurrentPageItemsCount())
    
    let totalHeight = tableHeight + 12 // 12 is the arrow height
    
    if arrowDirection == .down {
      pin.top(self.tapPoint.y - tableHeight - viewMarginFromTap).width(cellMaxWidth).height(totalHeight)
      tableView.pin.left().right().top().bottom(12)
      tableView.dropShadow(color: UIColor.black, opacity: 0.2, offSet: CGSize(width: 0, height: 1), radius: 1, scale: true)
      arrowView.pin.hCenter().bottom()
    } else {
      pin.top(self.tapPoint.y + viewMarginFromTap).width(cellMaxWidth).height(totalHeight)
      tableView.pin.left().right().bottom().top(12)
      tableView.dropShadow(color: UIColor.black, opacity: 0.2, offSet: CGSize(width: 0, height: -1), radius: 1, scale: true)
      arrowView.pin.hCenter().top()
    }
  }
}

// MARK: - Public Function
extension PopupMenu {
  public func popUp() {
    let frame = self.tableView.frame
    //self.tableView.transform = CGAffineTransform(scaleX: 0, y: 0)
    tableView.frame = CGRect(x: tableViewStartPoint.x, y: tableViewStartPoint.y, width: 0, height: 0)
    UIView.animate(withDuration: 0.1) {
      //self.tableView.transform = CGAffineTransform(scaleX: 1, y: 1)
      self.tableView.frame = frame
    }
  }
  
  public func dismiss() {
    UIView.animate(withDuration: 0.1, animations: {
      self.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
      //self.tableView.frame = CGRect(x: self.tableViewStartPoint.x, y: self.tableViewStartPoint.y, width: 0, height: 0)
    }) { (finished) in
      guard let contentView = self.superview, let superview  = contentView.superview as? UIVisualEffectView else {
        return
      }
      contentView.removeFromSuperview()
      superview.removeFromSuperview()
    }
  }
  
  private func getCurrentPageItemsCount() -> Int {
    guard let items = groupedItems[pageIndex] else { return 0 }
    return items.count
  }
  
  private func getCurrentPageMaxCellWidth(isLandscape: Bool) -> CGFloat {
    guard let items = groupedItems[pageIndex] else { return 0 }
    
    var maxWidth: CGFloat = .zero
    let label = UILabel()
    label.font = UIFont.appFont(ofSize: 17)
    label.adjustsFontForContentSizeCategory = true
    
    items.forEach {
      label.text = $0.title
      label.sizeToFit()
      /**
       65 derive from the cell margins and icon size:
       15            txt height             15              text lenght                20
       |----------|----------------|----------|--------------------------------|------------|
       margin       icon          marign                text                    margin
       */
      let cellWidth = label.frame.size.width + 50 + label.height
      if maxWidth <= cellWidth  {
        maxWidth = cellWidth
      }
    }
    return maxWidth < UIScreen.main.bounds.size.width - 60 ?  maxWidth : UIScreen.main.bounds.size.width - 60
  }
  
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension PopupMenu: UITableViewDelegate, UITableViewDataSource {
  
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return getCurrentPageItemsCount()
  }
  
  public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return PopupMenuCell.getRequiredHeight()
  }
  
  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //guard let orientation = interfaceOrientation else { return UITableViewCell() }
    guard let items = groupedItems[pageIndex] else { return UITableViewCell() }
    let cell = tableView.dequeueReusableCell(withIdentifier: CellID, for: indexPath) as! PopupMenuCell
    
    let menu = items[indexPath.row]
    cell.configureCell(menu: menu)
    
    cell.line.isHidden = indexPath.row == items.count-1
    
    return cell
  }
  
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if let cell = tableView.cellForRow(at: indexPath) as? PopupMenuCell, let menu = cell.menu {     
      if cell.titleLabel.text != "More".localized() {
        self.dismiss()
      }
      menu.action()
    }
  }
  
}

// MARK: - Arrow View
fileprivate class Arrow: UIView {
  fileprivate var direction: PopupMenuArrowDirection
  fileprivate var color: UIColor

  init(arrowDirection: PopupMenuArrowDirection = .down, color: UIColor = .white) {
    self.direction = arrowDirection
    self.color = color
    super.init(frame: CGRect(x: 0, y: 0, width: 20, height: 13))
    self.backgroundColor = .clear
    self.layer.masksToBounds = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ rect: CGRect) {
    let context = UIGraphicsGetCurrentContext()
    context?.beginPath()
    
    let startX = frame.size.width/2
    var shadowOffset = CGSize.zero
    if direction == .up {
      let startY = CGFloat.zero
      context?.move(to: CGPoint(x: startX, y: startY))
      context?.addLine(to: CGPoint(x: startX-10, y: 13))
      context?.addLine(to: CGPoint(x: startX+10, y: 13))
      
      shadowOffset = CGSize(width: 0, height: -1)
    } else {
      let startY = frame.size.height
      context?.move(to: CGPoint(x: startX, y: startY))
      context?.addLine(to: CGPoint(x: startX-10, y: startY-13))
      context?.addLine(to: CGPoint(x: startX+10, y: startY-13))
      
      shadowOffset = CGSize(width: 0, height: 1)
    }
    context?.setShadow(offset: shadowOffset, blur: 1, color: UIColor(white: 0, alpha: 0.2).cgColor)
    context?.setFillColor(color.cgColor)
    context?.closePath()
    context?.drawPath(using: .fill)
  }
}
