#import <AppKit/AppKit.h>
#import <MetalKit/MetalKit.h>
@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@end

@interface ViewDelegate : NSObject <MTKViewDelegate>
@end
@implementation AppDelegate
@end
@implementation ViewDelegate
- (void)drawInMTKView:(MTKView *)view {
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}
@end
