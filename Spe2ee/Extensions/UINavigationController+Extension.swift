

import UIKit

// MARK: - Methods
public extension UINavigationController {
  /// Pop to ViewController with completion handler.
  ///
  /// - Parameters:
  ///   - viewController: viewController to push.
  ///   - completion: optional completion handler (default is nil).
  func popToViewController(_ viewController: UIViewController, completion: (() -> Void)? = nil) {
    // https://github.com/cotkjaer/UserInterface/blob/master/UserInterface/UIViewController.swift
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    popToViewController(viewController, animated: true)
    CATransaction.commit()
  }
}
