//
//  WKRichComposerVC.m
//  WuKongBase
//

#import "WKRichComposerVC.h"
#import "WKRichEditorPool.h"
#import "WuKongBase.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static __weak UIView *gWKRichInputAccessory;

@interface WKRichComposerVC () <WKScriptMessageHandler>
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@property(nonatomic, strong) UIView *emptyAccessory;
@property(nonatomic, assign) BOOL editorReady;
@property(nonatomic, assign) BOOL recycled;
@property(nonatomic, assign) BOOL didInitialFocus;
@end

@implementation WKRichComposerVC

+ (UIImage *)collapseIconImage {
    // Arrows pointing inward (collapse) — opposite of expand.
    if (@available(iOS 13.0, *)) {
        UIImage *sys = [UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left"];
        if (sys) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
            return [[sys imageByApplyingSymbolConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *color = [UIColor colorWithRed:0.2 green:0.22 blue:0.26 alpha:1];
    if (@available(iOS 13.0, *)) {
        color = [UIColor labelColor];
    }
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 1.6);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    // Top-right ↙ (point into center)
    CGContextMoveToPoint(ctx, 17, 3);
    CGContextAddLineToPoint(ctx, 11, 9);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 12, 3);
    CGContextAddLineToPoint(ctx, 17, 3);
    CGContextAddLineToPoint(ctx, 17, 8);
    CGContextStrokePath(ctx);
    // Bottom-left ↗ (point into center)
    CGContextMoveToPoint(ctx, 3, 17);
    CGContextAddLineToPoint(ctx, 9, 11);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 8, 17);
    CGContextAddLineToPoint(ctx, 3, 17);
    CGContextAddLineToPoint(ctx, 3, 12);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"富文本编辑");
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
    self.edgesForExtendedLayout = UIRectEdgeNone;

    UIButton *collapseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    collapseBtn.frame = CGRectMake(0, 0, 32, 32);
    [collapseBtn setImage:[WKRichComposerVC collapseIconImage] forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        collapseBtn.tintColor = [UIColor labelColor];
    } else {
        collapseBtn.tintColor = [UIColor darkTextColor];
    }
    collapseBtn.accessibilityLabel = LLang(@"收起");
    [collapseBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    // Collapse on the right (pair with expand entry on the input bar).
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:collapseBtn];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    WKRichEditorPool *pool = [WKRichEditorPool shared];
    [pool setScriptDelegate:self];
    self.webView = [pool borrowWebView];
    self.editorReady = pool.isReady;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 11.0, *)) {
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    self.webView.scrollView.contentInset = UIEdgeInsetsZero;
    self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    self.webView.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeNone;
    [self.view addSubview:self.webView];

    // Hide system ↑↓✓ accessory — send lives in web toolbar.
    self.emptyAccessory = [[UIView alloc] initWithFrame:CGRectZero];
    [self installWebViewAccessory];

    if (@available(iOS 13.0, *)) {
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.spinner];

    // Keep toolbar above home-indicator / rounded corners (not flush to screen bottom).
    NSLayoutAnchor *bottomAnchor = self.view.bottomAnchor;
    if (@available(iOS 11.0, *)) {
        bottomAnchor = self.view.safeAreaLayoutGuide.bottomAnchor;
    }
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:bottomAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    if (!self.editorReady) {
        [self.spinner startAnimating];
        self.webView.alpha = 0.2;
    } else {
        // Warm webview may still have old layout — reload once if needed.
        self.webView.alpha = 1;
        if (self.initialHTML.length) {
            [self setHTML:self.initialHTML];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self syncEditorTheme];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self syncEditorTheme];
        }
    }
}

- (BOOL)isEditorDark {
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) return YES;
    }
    return [WKApp shared].config.style == WKSystemStyleDark;
}

- (void)syncEditorTheme {
    BOOL dark = [self isEditorDark];
    UIColor *bg = dark
        ? [UIColor colorWithRed:0x17/255.0 green:0x18/255.0 blue:0x1A/255.0 alpha:1]
        : [UIColor colorWithRed:0xFF/255.0 green:0xFF/255.0 blue:0xFF/255.0 alpha:1];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.webView.backgroundColor = [UIColor systemBackgroundColor];
        self.webView.scrollView.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = bg;
        self.webView.backgroundColor = bg;
        self.webView.scrollView.backgroundColor = bg;
    }
    NSString *mode = dark ? @"dark" : @"light";
    NSString *js = [NSString stringWithFormat:
                    @"try{window.RichEditorBridge&&window.RichEditorBridge.setTheme('%@');"
                    @"document.documentElement.setAttribute('data-theme','%@');}catch(e){}",
                    mode, mode];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.editorReady && !self.didInitialFocus) {
        self.didInitialFocus = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self focusEditorQuietly];
        });
    }
}

- (void)dealloc {
    [self recycleIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.isMovingFromParentViewController) {
        [self recycleIfNeeded];
    }
}

- (void)installWebViewAccessory {
    gWKRichInputAccessory = self.emptyAccessory;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"WKContentView");
        if (!cls) return;
        SEL sel = @selector(inputAccessoryView);
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) return;
        IMP original = method_getImplementation(m);
        id (*origFn)(id, SEL) = (id (*)(id, SEL))original;
        IMP replacement = imp_implementationWithBlock(^id(id _self) {
            UIView *custom = gWKRichInputAccessory;
            if (custom) return custom;
            return origFn(_self, sel);
        });
        method_setImplementation(m, replacement);
    });
}

- (void)focusEditorQuietly {
    UIScrollView *sv = self.webView.scrollView;
    CGPoint offset = sv.contentOffset;
    [self.webView evaluateJavaScript:@"window.RichEditorBridge && window.RichEditorBridge.focus()"
                   completionHandler:^(__unused id r, __unused NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [sv setContentOffset:offset animated:NO];
            if (sv.contentOffset.y < 0) {
                [sv setContentOffset:CGPointZero animated:NO];
            }
        });
    }];
}

- (void)onEditorReady {
    self.editorReady = YES;
    [self.spinner stopAnimating];
    self.webView.alpha = 1;
    [self syncEditorTheme];
    if (self.initialHTML.length) {
        [self setHTML:self.initialHTML];
    }
    if (self.isViewLoaded && self.view.window && !self.didInitialFocus) {
        self.didInitialFocus = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self focusEditorQuietly];
        });
    }
}

- (void)recycleIfNeeded {
    if (self.recycled || !self.webView) return;
    self.recycled = YES;
    gWKRichInputAccessory = nil;
    WKRichEditorPool *pool = [WKRichEditorPool shared];
    [pool setScriptDelegate:nil];
    [self.webView removeFromSuperview];
    [pool recycleWebView:self.webView];
    self.webView = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WKRichEditorPool shared] prewarm];
    });
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"richEditor"]) return;
    NSString *body = nil;
    if ([message.body isKindOfClass:[NSString class]]) {
        body = message.body;
    } else if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:message.body options:0 error:nil];
        body = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    }
    if (!body.length) return;
    NSData *jsonData = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return;
    NSString *type = obj[@"type"];
    if ([type isEqualToString:@"ready"]) {
        [self onEditorReady];
    } else if ([type isEqualToString:@"send"]) {
        [self onSend];
    }
}

- (void)setHTML:(NSString *)html {
    NSString *escaped = [self jsString:html ?: @""];
    NSString *js = [NSString stringWithFormat:@"window.RichEditorBridge && window.RichEditorBridge.setHTML(%@)", escaped];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (NSString *)jsString:(NSString *)s {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[ s ?: @"" ] options:0 error:nil];
    NSString *arr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (arr.length >= 2) {
        return [arr substringWithRange:NSMakeRange(1, arr.length - 2)];
    }
    return @"\"\"";
}

- (void)onClose {
    [self.view endEditing:YES];
    [self dismissOrPop];
}

- (void)onSend {
    if (!self.editorReady || !self.webView) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:@"window.RichEditorBridge ? window.RichEditorBridge.getHTML() : ''"
                   completionHandler:^(id result, NSError *error) {
        NSString *html = [result isKindOfClass:[NSString class]] ? result : @"";
        NSString *plain = [html stringByReplacingOccurrencesOfString:@"<[^>]+>"
                                                           withString:@""
                                                              options:NSRegularExpressionSearch
                                                                range:NSMakeRange(0, html.length)];
        plain = [plain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!plain.length) {
            return;
        }
        if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(richComposer:didSendHTML:)]) {
            [weakSelf.delegate richComposer:weakSelf didSendHTML:html];
        }
        [weakSelf dismissOrPop];
    }];
}

- (void)dismissOrPop {
    UIViewController *target = self.navigationController ?: self;
    if (target.presentingViewController) {
        [target dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
