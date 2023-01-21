#import "NSString+extensions.h"

@implementation NSString (toCharPointer)
- (char *)toCharPointer {
  return (char*)self.UTF8String;
}
@end
