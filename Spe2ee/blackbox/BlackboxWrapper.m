#import "BlackboxWrapper.h"
#include "NSString+extensions.h"


#define clamp(a) (a>255?255:(a<0?0:a))

@implementation BlackboxWrapper

/// Used by Swift
+ (NSString *) getPwdConfString {
  NSString *conf = [NSUserDefaults.standardUserDefaults stringForKey:@"pwdconf"];
  if (conf.length > 0) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:conf options:0];
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
  }
  return @"";
}

/// Internal API
+ (char *) getPwdConf {
  NSString *conf = [NSUserDefaults.standardUserDefaults stringForKey:@"pwdconf"];
  if (conf.length > 0) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:conf options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    return [decodedString toCharPointer];
  } else {
    // empty.
    return [@"" toCharPointer];
  }
}

+ (void)setCA:(NSString *)file {
  
}

+ (NSString *) bundleFile:(NSString *)file {
  return [[NSBundle mainBundle] pathForResource:[file stringByDeletingPathExtension] ofType:[file pathExtension]];
}

// MARK: Image manipulation
+ (unsigned long)getRgbSizeFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer,0);
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  int bytesPerPixel = 4;
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  return width * height * bytesPerPixel;
}

+ (uint8_t *)rgbBufferFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer,0);
  
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  uint8_t *yBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
  size_t yPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
  uint8_t *cbCrBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
  size_t cbCrPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
  
  int bytesPerPixel = 4;
  uint8_t *rgbBuffer = malloc(width * height * bytesPerPixel);
  
  for(int y = 0; y < height; y++) {
    uint8_t *rgbBufferLine = &rgbBuffer[y * width * bytesPerPixel];
    uint8_t *yBufferLine = &yBuffer[y * yPitch];
    uint8_t *cbCrBufferLine = &cbCrBuffer[(y >> 1) * cbCrPitch];
    
    for(int x = 0; x < width; x++) {
      int16_t y = yBufferLine[x];
      int16_t cb = cbCrBufferLine[x & ~1] - 128;
      int16_t cr = cbCrBufferLine[x | 1] - 128;
      
      uint8_t *rgbOutput = &rgbBufferLine[x*bytesPerPixel];
      
      int16_t r = (int16_t)roundf( y + cr *  1.4 );
      int16_t g = (int16_t)roundf( y + cb * -0.343 + cr * -0.711 );
      int16_t b = (int16_t)roundf( y + cb *  1.765);
      
      rgbOutput[0] = 0xff;
      rgbOutput[1] = clamp(b);
      rgbOutput[2] = clamp(g);
      rgbOutput[3] = clamp(r);
    }
  }
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  return rgbBuffer;
}

+ (UIImage *)imageFromRGBBuffer:(uint8_t *)rgbBuffer width:(int)width height:(int)height {
  int bytesPerPixel = 4;
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(rgbBuffer, width, height, 8, width * bytesPerPixel, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
  CGImageRef quartzImage = CGBitmapContextCreateImage(context);
  UIImage *image = [UIImage imageWithCGImage:quartzImage];
  
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  CGImageRelease(quartzImage);
  return image;
}


+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer,0);
  
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  uint8_t *yBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
  size_t yPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
  uint8_t *cbCrBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
  size_t cbCrPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
  
  int bytesPerPixel = 4;
  uint8_t *rgbBuffer = malloc(width * height * bytesPerPixel);
  
  for(int y = 0; y < height; y++) {
    uint8_t *rgbBufferLine = &rgbBuffer[y * width * bytesPerPixel];
    uint8_t *yBufferLine = &yBuffer[y * yPitch];
    uint8_t *cbCrBufferLine = &cbCrBuffer[(y >> 1) * cbCrPitch];
    
    for(int x = 0; x < width; x++) {
      int16_t y = yBufferLine[x];
      int16_t cb = cbCrBufferLine[x & ~1] - 128;
      int16_t cr = cbCrBufferLine[x | 1] - 128;
      
      uint8_t *rgbOutput = &rgbBufferLine[x*bytesPerPixel];
      
      int16_t r = (int16_t)roundf( y + cr *  1.4 );
      int16_t g = (int16_t)roundf( y + cb * -0.343 + cr * -0.711 );
      int16_t b = (int16_t)roundf( y + cb *  1.765);
      
      rgbOutput[0] = 0xff;
      rgbOutput[1] = clamp(b);
      rgbOutput[2] = clamp(g);
      rgbOutput[3] = clamp(r);
    }
  }
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(rgbBuffer, width, height, 8, width * bytesPerPixel, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
  CGImageRef quartzImage = CGBitmapContextCreateImage(context);
  UIImage *image = [UIImage imageWithCGImage:quartzImage];
  
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  CGImageRelease(quartzImage);
  free(rgbBuffer);
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  return image;
}

@end

