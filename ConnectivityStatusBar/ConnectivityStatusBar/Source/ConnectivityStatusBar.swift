import Foundation
import UIKit
import Alamofire
import PinLayout
import DeviceKit

// Device.current.hasSensorHousing -> iPhone X or later
private let barHeight: CGFloat = Device.current.hasSensorHousing ? 64 : 44

public final class ConnectivityStatusBar {
  
  public static let shared = ConnectivityStatusBar()
  public var host: String = ""
  private var networkManager: NetworkReachabilityManager?
  
  private lazy var topBarView: ConnectivityStatusBarView = {
    let view = ConnectivityStatusBarView()
    return view
  }()
  
  public func startMonitoring() -> Bool {
    if host.isEmpty {
      print("ConnectivityStatusBar - Invalid Host")
      return false
    }
    
    networkManager = NetworkReachabilityManager(host: host)
    networkManager?.startListening { status in
      switch status {
      case .notReachable:
        print("The network is not reachable")
        
        if let window = self.getFirstWindow() {
          window.addSubview(self.topBarView)
          
          self.topBarView.pin.right().left().height(barHeight).top(-barHeight)
          
          UIView.animate(withDuration: 0.2) {
            window.subviews[0].pin.top(barHeight).height(UIScreen.main.bounds.size.height - barHeight)
            self.topBarView.pin.top()
          }
        }
      case .unknown :
        print("It is unknown whether the network is reachable")
      case .reachable(.ethernetOrWiFi), .reachable(.cellular):
        if let window = self.getFirstWindow() {
          UIView.animate(withDuration: 0.2, animations: {
            self.topBarView.pin.top(-barHeight)
            window.subviews[0].pin.top().height(UIScreen.main.bounds.size.height)
          }) { (_) in
            self.topBarView.removeFromSuperview()
          }
        }
        break
      }
    }
    
    return true
  }
}

fileprivate class ConnectivityStatusBarView: UIView {
  private lazy var contentView: UIView = {
    let view = UIView()
    view.backgroundColor = .red
    view.alpha = 0.5
    return view
  }()
  
  private lazy var statusLabel: UILabel = {
    let label = UILabel()
    label.text = NSLocalizedString("Waiting for connection", tableName: nil, bundle: Bundle(for: self.classForCoder), value: "", comment: "")
    label.textColor = .white
    label.font = UIFont.preferredFont(forTextStyle: .footnote)
    label.adjustsFontForContentSizeCategory = true
    return label
  }()
  
  init() {
    super.init(frame: .zero)
    
    self.backgroundColor = .white
    self.addSubview(contentView)
    self.addSubview(statusLabel)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    statusLabel.sizeToFit()
    
    contentView.pin.all()
    statusLabel.pin.hCenter().bottom(6)
    
  }
}

extension ConnectivityStatusBar {
  fileprivate func getFirstWindow() -> UIWindow? {
    if let window = UIApplication.shared.windows.first(where: { (window) -> Bool in
      return window.isKeyWindow
    }) {
      return window
    }
    return nil
  }
}
