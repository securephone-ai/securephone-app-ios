#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>


@interface BlackboxWrapper : NSObject

+ (void)setCA:(NSString *)file;
+ (NSString *) bundleFile:(NSString *)file;
+ (NSString *) getPwdConfString;

// IMG
+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
+ (uint8_t *)rgbBufferFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
+ (UIImage *)imageFromRGBBuffer:(uint8_t *)rgbBuffer width:(int)width height:(int)height;
+ (unsigned long)getRgbSizeFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
