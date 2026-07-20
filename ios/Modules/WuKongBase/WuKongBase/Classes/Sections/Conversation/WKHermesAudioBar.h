//
//  WKHermesAudioBar.h
//  WuKongBase
//
//  Conversation top broadcast bar for Hermes audio (separate from voice bubbles).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKHermesAudioBar : UIView

@property(nonatomic, copy, nullable) void (^onVisibilityChange)(BOOL visible, CGFloat height);

+ (CGFloat)preferredHeight;
- (void)playURL:(NSString *)url title:(NSString *)title durationMs:(NSInteger)durationMs;
- (void)stopAndHide;
- (BOOL)isVisible;

@end

NS_ASSUME_NONNULL_END
