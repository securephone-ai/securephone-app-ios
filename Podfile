platform :ios, '13.2'
workspace 'xcurrency.xcworkspace'

use_frameworks!
install! 'cocoapods', :deterministic_uuids => false

def pinLayout_pods
	pod 'PinLayout'
end

def alamofire_pod
	pod 'Alamofire'
end

def devicekit_pod
	pod 'DeviceKit', '~> 2.0'
end

target 'Xcurrency' do
	project './Xcurrency.xcodeproj'

	pinLayout_pods
	alamofire_pod
	devicekit_pod

	pod 'CropViewController'
	pod 'RSKImageCropper'
	pod 'SwipeCellKit'
	pod 'FlexLayout'
	pod 'SDWebImage', '~> 5.0'
	pod 'Toast-Swift', '~> 5.0.1'
	pod "Player", "~> 0.13.2"
	pod 'lottie-ios'
	pod 'CwlUtils', :git => 'https://github.com/mattgallagher/CwlUtils.git'
	pod 'DifferenceKit'
	pod 'SVProgressHUD'
	pod 'JGProgressHUD'
	pod 'ImageViewer.swift', '~> 3.0'
	pod 'NextLevel', '~> 0.16.2'
	pod 'SCLAlertView'
	pod 'SwifterSwift'
	pod 'StepSlider', '~> 1.3.0'
	pod 'MarqueeLabel'
	pod 'Pageboy', '~> 3.6'
	pod 'AssetsPickerViewController', '~> 2.0'
	pod 'ChromaColorPicker'
	pod 'PINCache'
	pod 'CryptoSwift', '~> 1.0'
	
	target 'Xcurrency XTests' do
                inherit! :search_paths
        end

end

target 'NotificationView' do 
	project './NotificationView/NotificationView.xcodeproj'
	pinLayout_pods
end

target 'WatermarkedImageView' do 
	project './WatermarkedImageView/WatermarkedImageView.xcodeproj'
	pinLayout_pods
end
