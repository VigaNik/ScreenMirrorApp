#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Interface declarations for CGVirtualDisplay classes.
// The actual implementations live inside CoreGraphics.framework (macOS 12.4+).
// We only declare the interfaces here so Swift/ObjC code can call them;
// the linker resolves the symbols from the framework at link time.

NS_ASSUME_NONNULL_BEGIN

@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic)       CGSize    sizeInMillimeters;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic) int32_t hiDPI;
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(NSUInteger)width
                       height:(NSUInteger)height
                  refreshRate:(double)refreshRate;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@property (readonly, nonatomic) double     refreshRate;
@end

@interface CGVirtualDisplay : NSObject
- (nullable instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings
             modeList:(NSArray<CGVirtualDisplayMode *> *)modeList;
@property (readonly, nonatomic) CGDirectDisplayID displayID;
@end

NS_ASSUME_NONNULL_END
