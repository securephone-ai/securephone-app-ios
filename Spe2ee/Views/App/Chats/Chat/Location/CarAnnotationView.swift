
import UIKit
import MapKit
import PinLayout

class CarAnnotationView: MKPinAnnotationView {
  static let ID = "CarAnnotationView"
  let carButton = UIButton(frame: CGRect(x: 0, y: 0, width: 39, height: 39))
  
  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    
    canShowCallout = true
    let config = UIImage.SymbolConfiguration(scale: .large)
    carButton.setImage(UIImage(systemName: "car.fill", withConfiguration: config), for: .normal)
    carButton.tintColor = .link
    leftCalloutAccessoryView = carButton
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

}
