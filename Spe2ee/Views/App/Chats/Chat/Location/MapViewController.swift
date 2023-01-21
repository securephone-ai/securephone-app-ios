
import UIKit
import MapKit
import CoreLocation


class MapViewController: UIViewController {
  
  var coordinates = CLLocationCoordinate2D()
  fileprivate let locationManager: CLLocationManager = CLLocationManager()
  
  // MARK: UI Elements
  lazy var mapView: MKMapView = {
    let map = MKMapView()
    map.showsUserLocation = true
    map.mapType = .standard
    map.delegate = self
    map.removeAppleLogo()
    map.register(CarAnnotationView.self, forAnnotationViewWithReuseIdentifier: CarAnnotationView.ID)
    return map
  }()
  
  lazy var bottomView: UIView = {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
    view.backgroundColor = .systemGray6
    return view
  }()
  
  lazy var segmentControl: UISegmentedControl = {
    let control = UISegmentedControl(items: [
      "Map".localized(),
      "Hybrid".localized(),
      "Satellite".localized()
    ])
    control.ensureiOS12Style()
    control.addTarget(self, action: #selector(changeMapType), for: .valueChanged)
    control.selectedSegmentIndex = 0
    return control
  }()
  
  lazy var searchButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
    let conf = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: conf), for: .normal)
    
    button.addTarget(self, action: #selector(zoomOnCoordinate), for: .touchUpInside)
    return button
  }()
  
  lazy var openInMapButton: UIButton = {
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
    let conf = UIImage.SymbolConfiguration(scale: .large)
    button.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: conf), for: .normal)
    
    button.addTarget(self, action: #selector(openInAppleMap), for: .touchUpInside)
    return button
  }()
  
  init(coordinate: CLLocationCoordinate2D) {
    self.coordinates = coordinate
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    setupView()
  }
  
  func setupView() {
    view.addSubview(bottomView)
    view.addSubview(mapView)
    bottomView.addSubview(searchButton)
    bottomView.addSubview(openInMapButton)
    bottomView.addSubview(segmentControl)
    
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.delegate = self
    
    // Add Pint to coordinates
    let location = MKPointAnnotation()
    location.title = "Shared location".localized()
    location.coordinate = coordinates
    mapView.addAnnotation(location)
    
    //Zoom to user location
    zoomOnCoordinate()
    
    DispatchQueue.main.async {
      self.locationManager.startUpdatingLocation()
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    bottomView.pin.bottom().left().right().height(44 + view.pin.safeArea.bottom)
    mapView.pin.above(of: bottomView).top(view.pin.safeArea.top).left().right()
    segmentControl.pin.hCenter().top(6).height(36)
    searchButton.pin.size(CGSize(width: 34, height: 34)).top(5).right(10)
    openInMapButton.pin.size(CGSize(width: 34, height: 34)).top(5).left(10)
  }
  
  /// Selector for left button
  @objc func dismissView() {
    self.dismiss(animated: true, completion: nil)
  }
  
  @objc func zoomOnCoordinate() {
    let viewRegion = MKCoordinateRegion(center: coordinates, latitudinalMeters: 550, longitudinalMeters: 550)
    mapView.setRegion(viewRegion, animated: false)
  }
  
  /// Handler for when custom Segmented Control changes and will change the
  /// background color of the view depending on the selection.
  /// - Parameter sender: control
  @objc func changeMapType(sender: UISegmentedControl) {
    switch sender.selectedSegmentIndex {
    case 0:
      mapView.mapType = .standard
    case 1:
      mapView.mapType = .hybrid
    case 2:
      mapView.mapType = .satellite
    default:
      break
    }
  }
  
}

extension MapViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is MKUserLocation { return nil }
    
    if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: CarAnnotationView.ID) as? CarAnnotationView {
      annotationView.annotation = annotation
      annotationView.carButton.addTarget(self, action: #selector(openInAppleMap), for: .touchDown)
      return annotationView
    } else {
      return CarAnnotationView(annotation: annotation, reuseIdentifier: CarAnnotationView.ID)
    }
  }
  
  @objc func openInAppleMap() {
    let regionDistance:CLLocationDistance = 550
    let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
    let options = [
      MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
      MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
    ]
    let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = "Shared Location".localized()
    mapItem.openInMaps(launchOptions: options)
  }
}

extension MapViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    logi(error.localizedDescription)
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
