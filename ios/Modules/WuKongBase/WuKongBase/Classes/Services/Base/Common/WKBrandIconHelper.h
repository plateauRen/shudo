//
//  WKBrandIconHelper.h
//  WuKongBase
//
//  Theme-colored circle + white SF Symbol (and system-account avatars).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKBrandIconHelper : NSObject

/// Theme-colored filled circle with a white SF Symbol (falls back to template asset tint if symbol missing).
+ (UIImage *)circleSymbol:(NSString *)symbolName size:(CGFloat)size;

+ (UIImage *)circleSymbol:(NSString *)symbolName
                     size:(CGFloat)size
                pointSize:(CGFloat)pointSize;

/// Tint an existing template image onto a theme-colored circle.
+ (UIImage *)circleTemplateImage:(UIImage *)image size:(CGFloat)size;

/// Brand avatar for file helper / system account; nil for normal users.
+ (nullable UIImage *)systemAvatarForUID:(nullable NSString *)uid size:(CGFloat)size;

/// Extract uid from avatar path like `users/{uid}/avatar` or full URL containing it.
+ (nullable NSString *)uidFromAvatarPath:(nullable NSString *)path;

@end

NS_ASSUME_NONNULL_END
