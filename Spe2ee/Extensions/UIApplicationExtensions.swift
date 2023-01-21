extension UIApplication {
  
  var screenshot: UIImage? {
    UIGraphicsBeginImageContextWithOptions(UIScreen.main.bounds.size, false, 0)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    for window in windows {
      window.layer.render(in: context)
    }
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }
  
}
