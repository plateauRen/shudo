//
//  WKLiquidGlassHelper.h
//  WuKongBase
//
//  Liquid Glass (iOS 26+) with blur/solid fallbacks for older systems.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKLiquidGlassHelper : NSObject

+ (BOOL)isLiquidGlassAvailable;

/// Inserts a glass/blur effect view at the back of `host`.
/// On iOS 26+ uses UIGlassEffect; on older systems uses UIBlurEffect when possible,
/// otherwise applies `solidColor` to `host` and returns nil.
+ (nullable UIVisualEffectView *)installInView:(UIView *)host
                                 cornerRadius:(CGFloat)cornerRadius
                                  interactive:(BOOL)interactive
                                   solidColor:(nullable UIColor *)solidColor;

+ (void)applyCornerRadius:(CGFloat)cornerRadius toEffectView:(UIVisualEffectView *)effectView;

/// Materialize glass (iOS 26+) or ensure blur is applied. Safe no-op if effectView is nil.
+ (void)materializeEffectView:(nullable UIVisualEffectView *)effectView
                  interactive:(BOOL)interactive
                     animated:(BOOL)animated
                   completion:(nullable void (^)(void))completion;

/// Dematerialize glass (iOS 26+) then optionally hide. Safe no-op if effectView is nil.
+ (void)dematerializeEffectView:(nullable UIVisualEffectView *)effectView
                       animated:(BOOL)animated
                     completion:(nullable void (^)(void))completion;

/// Soft edge treatment where a floating overlay meets a scroll view (iOS 26+).
+ (void)attachScrollEdgeInteractionToView:(UIView *)overlay
                               scrollView:(UIScrollView *)scrollView
                                     edge:(UIRectEdge)edge;

@end

NS_ASSUME_NONNULL_END
