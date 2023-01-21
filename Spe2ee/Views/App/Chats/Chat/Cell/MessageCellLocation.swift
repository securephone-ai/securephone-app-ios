
import UIKit
import MapKit

class MessageCellLocation: MessageBaseCell {
  
  lazy var mapView: MKMapView = {
    let map = MKMapView()
    map.layer.cornerRadius = 8
    map.isScrollEnabled = false
    map.isZoomEnabled = false
    map.layer.borderWidth = 0
    map.delegate = self
    map.removeAppleLogo()
    return map
  }()
  var coordinate = CLLocationCoordinate2D()
  
  override var viewModel: MessageViewModel! {
    didSet {
      
      guard let latitude  = CLLocationDegrees(String(viewModel.message.body.split(separator: ",")[0])) else { return }
      guard let longitude  = CLLocationDegrees(String(viewModel.message.body.split(separator: ",")[1])) else { return }
      
      dateLabel.textColor = .darkGray
      coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      
      let location = MKPointAnnotation()
      location.title = "London"
      location.coordinate = coordinate
      mapView.addAnnotation(location)
      
      //Zoom to user location
      let viewRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 550, longitudinalMeters: 550)
      mapView.setRegion(viewRegion, animated: false)
      
    }
  }

  // MARK: - Setup
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCell()
  }
  
  fileprivate func setupCell() {
    messageContentView.insertSubview(mapView, at: 0)
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openMap))
    tapGesture.numberOfTapsRequired = 1
    mapView.addGestureRecognizer(tapGesture)
    
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if pan.state == .ended || pan.state == .possible {
      if viewModel.message.isGroupChat, !viewModel.isSent {
        mapView.pin.below(of: senderNameTextView).left().right().marginVertical(3).bottom()
      } else {
        mapView.pin.all()
      }
    }
  }
  
  @objc func openMap(sender: Any) {
    guard let viewController = self.findViewController() else { return }
    let mapVC = MapViewController(coordinate: coordinate)
    viewController.navigationController?.pushViewController(mapVC, animated: true)
  }
 
}

// MARK: Map delegate
extension MessageCellLocation: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
    view.image = UIImage(named: "pin")
    view.canShowCallout = false
    view.isEnabled = false
    view.pin.width(15).height(50)
    view.centerOffset = CGPoint(x: view.centerOffset.x, y: view.centerOffset.y-25)
    return view
  }
}
