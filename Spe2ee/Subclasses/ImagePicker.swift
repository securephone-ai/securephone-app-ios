import UIKit
import CropViewController

public protocol ImagePickerDelegate: class {
  func didSelect(image: UIImage?)
}

open class ImagePicker: NSObject {
  
  private let pickerController: UIImagePickerController
  private weak var presentationController: UIViewController?
  private weak var delegate: ImagePickerDelegate?
  
  private var selectedImage: UIImage?
  private var cropImage: Bool
  
  public init(presentationController: UIViewController, delegate: ImagePickerDelegate?, cropImage: Bool = true) {
    self.pickerController = UIImagePickerController()
    self.pickerController.modalPresentationStyle = .fullScreen
    self.cropImage = cropImage
    
    super.init()
    
    self.presentationController = presentationController
    self.pickerController.delegate = self
    self.pickerController.mediaTypes = ["public.image"]
    
    self.delegate = delegate
  }
  
  func setDelegate(delegate: ImagePickerDelegate) {
    self.delegate = delegate
  }
  
  public func present(from sourceView: UIView) {
    
    let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    
    let deleteAction = UIAlertAction(title: "Delete".localized(), style: .destructive, handler: { _ in
      self.selectedImage = nil
      self.delegate?.didSelect(image: nil)
    })
    let takePhotoAction = UIAlertAction(title: "Take Photo".localized(), style: .default, handler: { _ in
      self.pickerController.sourceType = .camera
      self.presentationController?.present(self.pickerController, animated: true)
    })
    let choosePhotoAction = UIAlertAction(title: "Choose Photo".localized(), style: .default, handler: { _ in
      self.pickerController.sourceType = .photoLibrary
      self.presentationController?.present(self.pickerController, animated: true)
    })
    
    if selectedImage != nil {
      alertController.addAction(deleteAction)
    }
    
    alertController.addAction(takePhotoAction)
    alertController.addAction(choosePhotoAction)
    
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    if UIDevice.current.userInterfaceIdiom == .pad {
      alertController.popoverPresentationController?.sourceView = sourceView
      alertController.popoverPresentationController?.sourceRect = sourceView.bounds
      alertController.popoverPresentationController?.permittedArrowDirections = [.down, .up]
    }
    
    // iOS Bug: https://stackoverflow.com/a/58666480/1232289
    for subView in alertController.view.subviews {
      for constraint in subView.constraints where constraint.debugDescription.contains("width == - 16") {
        subView.removeConstraint(constraint)
      }
    }
    
    self.presentationController?.present(alertController, animated: true)
  }
  
  private func pickerController(_ controller: UIImagePickerController, didSelect image: UIImage?) {
    controller.dismiss(animated: false, completion: {
      guard let img = image, let viewController = self.presentationController else { return }
      
      if self.cropImage {
        let cropViewController = CropViewController(croppingStyle: .circular, image: img)
        cropViewController.delegate = self
        cropViewController.modalPresentationStyle = .fullScreen
        viewController.present(cropViewController, animated: false)
      } else {
        guard let delegate = self.delegate else { return }
        delegate.didSelect(image: image)
      }
    })
  }
  
  public func deleteImage() {
    selectedImage = nil
    self.delegate?.didSelect(image: nil)
  }
}

extension ImagePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    pickerController(picker, didSelect: nil)
  }
  
  public func imagePickerController(_ picker: UIImagePickerController,
                                    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    guard let image = info[.originalImage] as? UIImage else {
      return pickerController(picker, didSelect: nil)
    }
    pickerController(picker, didSelect: image)
  }
}

extension ImagePicker: CropViewControllerDelegate {
  public func cropViewController(_ cropViewController: CropViewController, didCropToCircularImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
    cropViewController.dismiss(animated: false)
    selectedImage = image;
    self.delegate?.didSelect(image: image)
  }
}

