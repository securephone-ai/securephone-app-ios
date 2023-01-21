import Foundation


extension UITableView {
  
  /// Safely delete the row at indexPath or reload the table data
  /// - Parameters:
  ///   - indexPath: indexPath to delete
  ///   - animation: the animation to use
  func safeDeleteRow(at indexPath: IndexPath, with animation: RowAnimation) {
    if isValidIndexPath(indexPath) {
      deleteRows(at: [indexPath], with: animation)
    } else {
      reloadData()
    }
  }
  
  /// Safely delete the rows at indexPath array or reload the table data
  /// - Parameters:
  ///   - indexPath: indexPaths to delete
  ///   - animation: the animation to use
  func safeDeleteRows(at indexPaths: [IndexPath], with animation: RowAnimation) {
    for indexPath in indexPaths {
      if isValidIndexPath(indexPath) == false {
        reloadData()
        return
      }
    }
    deleteRows(at: indexPaths, with: animation)
  }
  
  func isTableAtBottom(bottomInsetDistance: CGFloat = 0) -> Bool {
    let offset = contentOffset
    let bounds = self.bounds
    let size = contentSize
    let inset = contentInset
    let y = offset.y + bounds.size.height - inset.bottom
    let h = size.height
    
//    let reload_distance:CGFloat = 10.0
    if y > (h - bottomInsetDistance) {
      return true
    }
    return false
  }
  
}

