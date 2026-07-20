//
//  WKRichComposerVC.h
//  WuKongBase
//
//  Expanded WYSIWYG composer (TipTap in WKWebView).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WKRichComposerVC;

@protocol WKRichComposerDelegate <NSObject>
- (void)richComposer:(WKRichComposerVC *)composer didSendHTML:(NSString *)html;
@end

@interface WKRichComposerVC : UIViewController

@property(nonatomic, weak, nullable) id<WKRichComposerDelegate> delegate;
@property(nonatomic, copy, nullable) NSString *initialHTML;

@end

NS_ASSUME_NONNULL_END
