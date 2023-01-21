import UIKit
import Pageboy

class WallpaperPreviewPagerViewController: PageboyViewController {
  
  private var imageNames: [String]
  private var startingIndex: Int = 0
  
  lazy var viewControllers: [UIViewController] = {
    var viewControllers = [UIViewController]()
    for name in imageNames {
      viewControllers.append(makeChildViewController(imageName: name))
    }
    return viewControllers
  }()
  
  init(wallpapersNames: [String], selectedIndex: Int = 0) {
    self.imageNames = wallpapersNames
    self.startingIndex = selectedIndex
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Wallpaper Preview".localized()
    
    isInfiniteScrollEnabled = true
    dataSource = self
    scrollToPage(.at(index: startingIndex), animated: false)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  private func makeChildViewController(imageName: String) -> UIViewController {
    return WallpaperPreviewViewController(imageName: imageName)
  }
    
}

// MARK: PageboyViewControllerDataSource
extension WallpaperPreviewPagerViewController: PageboyViewControllerDataSource {
  
  func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
    let count = viewControllers.count
    return count
  }
  
  func viewController(for pageboyViewController: PageboyViewController,
                      at index: PageboyViewController.PageIndex) -> UIViewController? {
    guard viewControllers.isEmpty == false else {
      return nil
    }
    return viewControllers[index]
  }
  
  func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
    return nil
  }
}

