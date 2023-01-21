

import UIKit
import MapKit
import CoreLocation


class SendLocationViewController: UIViewController {

  let locationPicker: LocationPicker?
  fileprivate let locationManager: CLLocationManager = CLLocationManager()
  
  // Main View
  lazy var mapView: MKMapView = {
    let map = MKMapView()
    map.showsUserLocation = true
    map.removeAppleLogo()
    return map
  }()
  lazy var shareLocationButton: UIButton = {
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.setTitle("Send Current Location".localized(), for: .normal)
    button.setTitleColor(.link, for: .normal)
    button.layer.borderWidth = 0.6
    button.layer.borderColor = UIColor.link.cgColor
    button.layer.cornerRadius = 6
    button.addTarget(self, action: #selector(sendCurrentLocation), for: .touchUpInside)
    return button
  }()
  
  // Nav bar buttons
  var leftButtonBar = UIBarButtonItem()
  var rightButtonBar = UIBarButtonItem()
  
  init(locationPicker: LocationPicker) {
    self.locationPicker = locationPicker
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    self.locationPicker = nil
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Share Location".localized()
    view.backgroundColor = .white
    modalPresentationStyle = .fullScreen
    
    leftButtonBar = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissView))
    rightButtonBar = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(reloadPosition))
    self.navigationItem.leftBarButtonItem = leftButtonBar
    self.navigationItem.rightBarButtonItem = rightButtonBar
    
    view.addSubview(mapView)
    view.addSubview(shareLocationButton)
    
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.delegate = self
    
    //Zoom to user location
    if let userLocation = locationManager.location?.coordinate {
      let viewRegion = MKCoordinateRegion(center: userLocation, latitudinalMeters: 550, longitudinalMeters: 550)
      mapView.setRegion(viewRegion, animated: false)
    }
   
    DispatchQueue.main.async {
      self.locationManager.startUpdatingLocation()
    }
  }
}

extension SendLocationViewController {
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    mapView.pin.left().right().top(view.pin.safeArea.top).bottom(view.pin.safeArea.bottom)
    shareLocationButton.pin.bottom(20).horizontally(100).height(50)
    
    // Shadow must be applied after the view has been rendered.
    shareLocationButton.dropShadow(color: .black, opacity: 0.25, offSet: CGSize(width: 0, height: 1))
  }
}

extension SendLocationViewController {
  /// Selector for left button
  @objc public func dismissView() {
    self.dismiss(animated: true, completion: nil)
  }
  
  /// Selector for left button
  @objc public func reloadPosition() {
    // RELOAD POSITION
  }
  
  // Send the current location
  @objc public func sendCurrentLocation() {
    
    self.dismiss(animated: true) {
      // Current location
      if let userLocation = self.locationManager.location?.coordinate {
        guard let delegate = self.locationPicker?.delegate else { return }
        delegate.didSelectLocation(coordinate: userLocation)
      }
    }
  }
}

extension SendLocationViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    loge(error.localizedDescription)
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if locations.first != nil {
//      logi("latitude: $\(String(describing: locations.first?.coordinate.latitude))")
//      logi("longitude: $\(String(describing: locations.first?.coordinate.longitude))")
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .denied, status == .restricted, status == .notDetermined {
      locationManager.requestLocation()
    }
  }
}
