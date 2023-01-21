import UIKit

enum ChatBubbleType {
  case incoming
  case outgoing
  case incomingLast
  case outgoingLast
  
  case incomingArabic
  case outgoingArabic
  case incomingLastArabic
  case outgoingLastArabic
}

enum AlertBubble {
  case none
  case copy
  case forward
}

class BubbleView: UIView {
  
  var bubbleType: ChatBubbleType = .incomingLast {
    didSet {
      setBackgroundColor()
    }
  }
  let messageLayer = CAShapeLayer()
  
  var alertType: AlertBubble = .none {
    didSet {
      setBackgroundColor()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: .zero)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ rect: CGRect) {
    while layer.subviews.count > 0 {
      layer.subviews[0].removeFromSuperlayer()
    }
    let bezierPath = UIBezierPath()
    
    let width = frame.size.width
    let height = frame.size.height
    
    switch bubbleType {
    case .incoming, .outgoingArabic:
      let bubbleStartPoint: CGFloat = 10
      bezierPath.move(to: CGPoint(x: width, y: height-10))
      bezierPath.addCurve(to: CGPoint(x: width-10, y: height), controlPoint1: CGPoint(x: width, y: height-3), controlPoint2: CGPoint(x: width-3, y: height))
      bezierPath.addLine(to: CGPoint(x: bubbleStartPoint+10, y: height))
      bezierPath.addCurve(to: CGPoint(x: bubbleStartPoint, y: height-10), controlPoint1: CGPoint(x: bubbleStartPoint+3, y: height), controlPoint2: CGPoint(x: bubbleStartPoint, y: height-3))
      bezierPath.addLine(to: CGPoint(x: bubbleStartPoint, y: 10))
      bezierPath.addCurve(to: CGPoint(x: bubbleStartPoint+10, y: 0), controlPoint1: CGPoint(x: bubbleStartPoint+0, y: 3), controlPoint2: CGPoint(x: bubbleStartPoint+3, y: 0))
      bezierPath.addLine(to: CGPoint(x: width-10, y: 0))
      bezierPath.addCurve(to: CGPoint(x: width, y: 10), controlPoint1: CGPoint(x: width-3, y: 0), controlPoint2: CGPoint(x: width, y: 3))
      bezierPath.addLine(to: CGPoint(x: width, y: height-10))
    case .outgoing, .incomingArabic:
      let bubbleEndPoint: CGFloat = width-10
      bezierPath.move(to: CGPoint(x: bubbleEndPoint, y: height-10))
      bezierPath.addCurve(to: CGPoint(x: bubbleEndPoint-10, y: height), controlPoint1: CGPoint(x: bubbleEndPoint, y: height-3), controlPoint2: CGPoint(x: bubbleEndPoint-3, y: height))
      bezierPath.addLine(to: CGPoint(x: 10, y: height))
      bezierPath.addCurve(to: CGPoint(x: 0, y: height-10), controlPoint1: CGPoint(x: 3, y: height), controlPoint2: CGPoint(x: 0, y: height-3))
      bezierPath.addLine(to: CGPoint(x: 0, y: 10))
      bezierPath.addCurve(to: CGPoint(x: 10, y: 0), controlPoint1: CGPoint(x: 0, y: 3), controlPoint2: CGPoint(x: 3, y: 0))
      bezierPath.addLine(to: CGPoint(x: bubbleEndPoint-10, y: 0))
      bezierPath.addCurve(to: CGPoint(x: bubbleEndPoint, y: 10), controlPoint1: CGPoint(x: bubbleEndPoint-3, y: 0), controlPoint2: CGPoint(x: bubbleEndPoint, y: 3))
      bezierPath.addLine(to: CGPoint(x: bubbleEndPoint, y: height-10))
    case .incomingLast, .outgoingLastArabic:
      let bubbleStartPoint: CGFloat = 10
      bezierPath.move(to: CGPoint(x: width, y: height-10))
      bezierPath.addCurve(to: CGPoint(x: width-10, y: height), controlPoint1: CGPoint(x: width, y: height-3), controlPoint2: CGPoint(x: width-3, y: height))
      bezierPath.addLine(to: CGPoint(x: bubbleStartPoint+10, y: height))
      
      bezierPath.addCurve(to: CGPoint(x: bubbleStartPoint, y: height-5), controlPoint1: CGPoint(x: bubbleStartPoint+3, y: height), controlPoint2: CGPoint(x: bubbleStartPoint, y: height-3))
      // Punta
      bezierPath.addCurve(to: CGPoint(x: 0, y: height-9), controlPoint1: CGPoint(x: 8, y: height-5), controlPoint2: CGPoint(x: 0, y: height-8))
      
      bezierPath.addCurve(to: CGPoint(x: bubbleStartPoint, y: height-20), controlPoint1: CGPoint(x: 6, y: height-11), controlPoint2: CGPoint(x: bubbleStartPoint, y: height-15))
      
      bezierPath.addLine(to: CGPoint(x: bubbleStartPoint, y: 10))
      bezierPath.addCurve(to: CGPoint(x: bubbleStartPoint+10, y: 0), controlPoint1: CGPoint(x: bubbleStartPoint, y: 3), controlPoint2: CGPoint(x: bubbleStartPoint+3, y: 0))
      bezierPath.addLine(to: CGPoint(x: width-10, y: 0))
      bezierPath.addCurve(to: CGPoint(x: width, y: 10), controlPoint1: CGPoint(x: width-3, y: 0), controlPoint2: CGPoint(x: width, y: 3))
      bezierPath.addLine(to: CGPoint(x: width, y: height-10))
      

    case .outgoingLast, .incomingLastArabic:
      let bubbleEndPoint: CGFloat = width-10
      bezierPath.move(to: CGPoint(x: bubbleEndPoint, y: height-5))
      bezierPath.addCurve(to: CGPoint(x: bubbleEndPoint-10, y: height), controlPoint1: CGPoint(x: bubbleEndPoint, y: height-3), controlPoint2: CGPoint(x: bubbleEndPoint-3, y: height))
      bezierPath.addLine(to: CGPoint(x: 10, y: height))
      bezierPath.addCurve(to: CGPoint(x: 0, y: height-10), controlPoint1: CGPoint(x: 3, y: height), controlPoint2: CGPoint(x: 0, y: height-3))
      bezierPath.addLine(to: CGPoint(x: 0, y: 10))
      bezierPath.addCurve(to: CGPoint(x: 10, y: 0), controlPoint1: CGPoint(x: 0, y: 3), controlPoint2: CGPoint(x: 3, y: 0))
      bezierPath.addLine(to: CGPoint(x: bubbleEndPoint-10, y: 0))
      bezierPath.addCurve(to: CGPoint(x: bubbleEndPoint, y: 10), controlPoint1: CGPoint(x: bubbleEndPoint-3, y: 0), controlPoint2: CGPoint(x: bubbleEndPoint, y: 3))
      bezierPath.addLine(to: CGPoint(x: bubbleEndPoint, y: height-20))
      
      // punta
      bezierPath.addCurve(to: CGPoint(x: width, y: height-9), controlPoint1: CGPoint(x: bubbleEndPoint, y: height-15), controlPoint2: CGPoint(x: width-6, y: height-11))
      bezierPath.addCurve(to: CGPoint(x: bubbleEndPoint, y: height-5), controlPoint1: CGPoint(x: width, y: height-8), controlPoint2: CGPoint(x: width-7, y: height-5))
    }
    bezierPath.close()
    
    messageLayer.path = bezierPath.cgPath
    messageLayer.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
    
    messageLayer.masksToBounds = false
    messageLayer.shadowColor = UIColor.black.cgColor
    messageLayer.shadowOpacity = 0.3
    messageLayer.shadowOffset = CGSize(width: 0, height: 0.6)
    messageLayer.shadowRadius = 1
    messageLayer.shadowPath = bezierPath.cgPath
    messageLayer.shouldRasterize = true
    messageLayer.rasterizationScale = UIScreen.main.scale
    
    layer.addSublayer(messageLayer)
  }
  
  func blink() {
    messageLayer.removeAnimation(forKey: "fillColor")
    
    //Animate colorFill
    let fillColorAnimation = CABasicAnimation(keyPath: "fillColor")
    fillColorAnimation.duration = 0.5
    if bubbleType == .incomingLast || bubbleType == .incoming {
      fillColorAnimation.toValue = Constants.IncomingBubbleBlinkColor.cgColor
    } else {
      fillColorAnimation.toValue = Constants.OutgoingBubbleBlinkColor.cgColor
    }
    fillColorAnimation.repeatCount = 1
    fillColorAnimation.autoreverses = true
    fillColorAnimation.fillMode = .forwards
    fillColorAnimation.isRemovedOnCompletion = true
    messageLayer.add(fillColorAnimation, forKey: "fillColor")
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.8) { [weak self] in
      guard let strongSelf = self else { return }
//      strongSelf.messageLayer.removeAnimation(forKey: "fillColor")
      
      
      
    }
  }

  private func setBackgroundColor() {
    if alertType != .none {
      messageLayer.fillColor = alertType == .copy ? Constants.AlertColorCopy.cgColor : Constants.AlertColorForward.cgColor
    } else if bubbleType == .incoming || bubbleType == .incomingLast || bubbleType == .incomingLastArabic || bubbleType == .incomingArabic {
      messageLayer.fillColor = Constants.IncomingBubbleColor.cgColor
    } else {
      messageLayer.fillColor = Constants.OutgoingBubbleColor.cgColor
    }
  }
  
  func setColor(color: UIColor) {
     messageLayer.fillColor = color.cgColor
  }
}

