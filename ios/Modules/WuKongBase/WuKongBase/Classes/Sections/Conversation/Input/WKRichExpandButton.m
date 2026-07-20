//
//  WKRichExpandButton.m
//  WuKongBase
//

#import "WKRichExpandButton.h"
#import "WKRichComposerVC.h"
#import "WKRichEditorPool.h"
#import "WKPanelDefaultFuncItem.h"
#import "WKNavigationManager.h"
#import "WuKongBase.h"

@implementation WKRichExpandButton

+ (UIImage *)expandIconImage {
    // Arrows pointing outward (expand) — opposite of composer collapse icon.
    if (@available(iOS 13.0, *)) {
        UIImage *sys = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"];
        if (sys) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
            UIImage *img = [sys imageByApplyingSymbolConfiguration:cfg];
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *color = [UIColor colorWithRed:0.56 green:0.58 blue:0.62 alpha:1];
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 1.6);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextMoveToPoint(ctx, 11, 3);
    CGContextAddLineToPoint(ctx, 17, 3);
    CGContextAddLineToPoint(ctx, 17, 9);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 17, 3);
    CGContextAddLineToPoint(ctx, 10.5, 9.5);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 9, 17);
    CGContextAddLineToPoint(ctx, 3, 17);
    CGContextAddLineToPoint(ctx, 3, 11);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 3, 17);
    CGContextAddLineToPoint(ctx, 9.5, 10.5);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (instancetype)buttonWithContext:(id<WKConversationContext>)context {
    WKRichExpandButton *btn = [WKRichExpandButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 32, 32);
    btn.conversationContext = context;
    btn.accessibilityLabel = LLang(@"展开富文本编辑");
    [btn setImage:[self expandIconImage] forState:UIControlStateNormal];
    btn.tintColor = [WKPanelDefaultFuncItem toolbarIconTint];
    [btn addTarget:btn action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    // Preload as soon as the input chrome appears.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WKRichEditorPool shared] prewarm];
    });
    return btn;
}

- (void)onTap {
    id<WKConversationContext> context = self.conversationContext;
    if (!context) return;

    // Start / finish prewarm BEFORE presenting (sync create on main).
    [[WKRichEditorPool shared] prewarm];

    WKRichComposerVC *vc = [WKRichComposerVC new];
    if ([context conformsToProtocol:@protocol(WKRichComposerDelegate)]) {
        vc.delegate = (id<WKRichComposerDelegate>)context;
    }
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent largeDetent],
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        }
    }
    UIViewController *top = [WKNavigationManager shared].topViewController;
    // Resign chat input first (no animation) so sheet + keyboard don't fight / bounce.
    [UIView performWithoutAnimation:^{
        [top.view endEditing:YES];
    }];
    [top presentViewController:nav animated:YES completion:nil];
}

@end
