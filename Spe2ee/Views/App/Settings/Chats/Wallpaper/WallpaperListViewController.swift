import UIKit


class WallpaperListViewController: UIViewController {

  private lazy var wallpapersCollectionView: UICollectionView = {
    //Build layout
    let layout = UICollectionViewFlowLayout()
    layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    layout.scrollDirection = .vertical
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    
    //Build collectin view
    let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
    collectionView.backgroundColor = ContactsPickerConfig.selectorStyle.backgroundColor
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(WallpaperCell.self, forCellWithReuseIdentifier: WallpaperCell.ID)
    return collectionView
  }()
  
  var wallpaperNames: [String] = [
    "Wallpaper_1",
    "Wallpaper_2",
    "Wallpaper_3",
    "Wallpaper_4",
    "Wallpaper_5",
    "Wallpaper_6",
    "Wallpaper_7",
    "Wallpaper_8",
    "Wallpaper_9"
  ]
  
  init() {
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true 
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Wallpaper Library".localized()
    
    view.backgroundColor = .systemGray6
    view.addSubview(wallpapersCollectionView)
    // Do any additional setup after loading the view.
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    wallpapersCollectionView.reloadData()
  }
  
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    wallpapersCollectionView.pin.top(view.pin.safeArea.top).left(4).right(4).bottom()
  }
}

extension WallpaperListViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return wallpaperNames.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WallpaperCell.ID, for: indexPath as IndexPath) as! WallpaperCell
    cell.wallpaperImageView.image = UIImage(named: wallpaperNames[indexPath.row])
    return cell
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    guard let orientation = view.screenOrientation else { return .zero }
    if orientation == .portrait {
      let width = collectionView.width / 3
      return CGSize(width: width, height: width*1.7)
    } else {
      let width = collectionView.width / 6
      return CGSize(width: width, height: width*1.7)
    }
  }
  
}
