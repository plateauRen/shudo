//
//  WKRichEditorPool.m
//  WuKongBase
//

#import "WKRichEditorPool.h"
#import "WKRichEditorWebView.h"

@interface WKRichWeakScriptHandler : NSObject <WKScriptMessageHandler>
@property(nonatomic, weak) id<WKScriptMessageHandler> delegate;
@end

@implementation WKRichWeakScriptHandler
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    id<WKScriptMessageHandler> d = self.delegate;
    if (d) {
        [d userContentController:userContentController didReceiveScriptMessage:message];
    }
}
@end

@interface WKRichEditorPool () <WKScriptMessageHandler>
@property(nonatomic, strong) WKProcessPool *processPool;
@property(nonatomic, strong) WKRichWeakScriptHandler *scriptProxy;
@property(nonatomic, weak) id<WKScriptMessageHandler> activeDelegate;
@property(nonatomic, strong, nullable) WKWebView *warmWebView;
@property(nonatomic, copy, nullable) NSString *cachedHTML;
@property(nonatomic, strong, nullable) NSURL *cachedBaseURL;
@property(nonatomic, assign) BOOL ready;
@property(nonatomic, assign) BOOL loading;
@property(nonatomic, assign) BOOL borrowed;
@end

@implementation WKRichEditorPool

+ (instancetype)shared {
    static WKRichEditorPool *p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        p = [WKRichEditorPool new];
    });
    return p;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processPool = [[WKProcessPool alloc] init];
        _scriptProxy = [WKRichWeakScriptHandler new];
        _scriptProxy.delegate = self;
    }
    return self;
}

- (BOOL)isReady {
    return self.ready;
}

- (void)setScriptDelegate:(id<WKScriptMessageHandler>)delegate {
    self.activeDelegate = delegate;
}

- (NSBundle *)richEditorBundle {
    NSBundle *mod = [NSBundle bundleForClass:[self class]];
    NSURL *url = [mod URLForResource:@"WuKongBase_RichEditor" withExtension:@"bundle"];
    if (url) {
        NSBundle *b = [NSBundle bundleWithURL:url];
        if (b) return b;
    }
    NSString *path = [[mod resourcePath] stringByAppendingPathComponent:@"RichEditor"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [NSBundle bundleWithPath:path];
    }
    return mod;
}

- (void)invalidateCache {
    self.cachedHTML = nil;
    self.cachedBaseURL = nil;
    if (self.warmWebView && !self.borrowed) {
        self.ready = NO;
        self.loading = YES;
        [self ensureCachedHTML];
        [self loadEditorInto:self.warmWebView];
    }
}

- (void)ensureCachedHTML {
    if (self.cachedHTML.length) return;
    NSBundle *bundle = [self richEditorBundle];
    NSURL *indexURL = [bundle URLForResource:@"index" withExtension:@"html" subdirectory:@"RichEditor"];
    if (!indexURL) {
        indexURL = [bundle URLForResource:@"index" withExtension:@"html"];
    }
    if (!indexURL) return;

    NSString *html = [NSString stringWithContentsOfURL:indexURL encoding:NSUTF8StringEncoding error:nil];
    if (!html.length) return;

    NSURL *dir = [indexURL URLByDeletingLastPathComponent];
    NSURL *jsURL = [dir URLByAppendingPathComponent:@"bridge.js"];
    NSString *js = [NSString stringWithContentsOfURL:jsURL encoding:NSUTF8StringEncoding error:nil];

    // Inline bridge to avoid a second file round-trip (big win on first paint).
    if (js.length) {
        NSString *tag = @"<script src=\"./bridge.js\"></script>";
        NSString *inlineTag = [NSString stringWithFormat:@"<script>%@</script>", js];
        if ([html containsString:tag]) {
            html = [html stringByReplacingOccurrencesOfString:tag withString:inlineTag];
        } else {
            html = [html stringByReplacingOccurrencesOfString:@"</body>"
                                                   withString:[inlineTag stringByAppendingString:@"</body>"]];
        }
    }
    self.cachedHTML = html;
    self.cachedBaseURL = dir;
}

- (WKWebViewConfiguration *)makeConfiguration {
    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self.scriptProxy name:@"richEditor"];
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.userContentController = ucc;
    cfg.processPool = self.processPool;
    if (@available(iOS 14.0, *)) {
        cfg.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    cfg.allowsInlineMediaPlayback = YES;
    return cfg;
}

- (void)attachOffscreen:(WKWebView *)wv {
    CGRect screen = [UIScreen mainScreen].bounds;
    // Real-ish size so TipTap/layout initialize like production (2×2 stalls JS).
    wv.frame = CGRectMake(-screen.size.width, 0, screen.size.width, screen.size.height * 0.7);
    wv.alpha = 0.01;
    wv.hidden = NO;
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    if (!win) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
    }
    if (win) {
        [win insertSubview:wv atIndex:0];
    }
}

- (void)prewarm {
    if (self.warmWebView || self.borrowed) return;
    if (self.loading && self.warmWebView) return;

    void (^create)(void) = ^{
        if (self.warmWebView || self.borrowed) return;
        self.loading = YES;
        [self ensureCachedHTML];
        WKWebView *wv = [[WKRichEditorWebView alloc] initWithFrame:CGRectZero
                                                     configuration:[self makeConfiguration]];
        wv.opaque = NO;
        if (@available(iOS 13.0, *)) {
            wv.backgroundColor = [UIColor systemBackgroundColor];
            wv.scrollView.backgroundColor = [UIColor systemBackgroundColor];
        } else {
            wv.backgroundColor = [UIColor whiteColor];
        }
        [self attachOffscreen:wv];
        self.warmWebView = wv;
        [self loadEditorInto:wv];
    };

    if ([NSThread isMainThread]) {
        create();
    } else {
        dispatch_async(dispatch_get_main_queue(), create);
    }
}

- (void)loadEditorInto:(WKWebView *)webView {
    [self ensureCachedHTML];
    if (self.cachedHTML.length && self.cachedBaseURL) {
        [webView loadHTMLString:self.cachedHTML baseURL:self.cachedBaseURL];
        return;
    }
    NSBundle *bundle = [self richEditorBundle];
    NSURL *index = [bundle URLForResource:@"index" withExtension:@"html" subdirectory:@"RichEditor"];
    if (!index) {
        index = [bundle URLForResource:@"index" withExtension:@"html"];
    }
    if (!index) {
        self.loading = NO;
        return;
    }
    [webView loadFileURL:index allowingReadAccessToURL:[index URLByDeletingLastPathComponent]];
}

- (WKWebView *)borrowWebView {
    if (self.warmWebView) {
        WKWebView *wv = self.warmWebView;
        self.borrowed = YES;
        self.warmWebView = nil;
        self.loading = NO;
        [wv removeFromSuperview];
        wv.alpha = 1;
        wv.hidden = NO;
        return wv;
    }
    // Ensure create happens immediately on cold path
    [self prewarm];
    if (self.warmWebView) {
        return [self borrowWebView];
    }
    self.borrowed = YES;
    self.ready = NO;
    self.loading = YES;
    [self ensureCachedHTML];
    WKWebView *wv = [[WKRichEditorWebView alloc] initWithFrame:CGRectZero
                                                 configuration:[self makeConfiguration]];
    wv.opaque = NO;
    if (@available(iOS 13.0, *)) {
        wv.backgroundColor = [UIColor systemBackgroundColor];
        wv.scrollView.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        wv.backgroundColor = [UIColor whiteColor];
    }
    [self loadEditorInto:wv];
    return wv;
}

- (void)recycleWebView:(WKWebView *)webView {
    if (!webView) return;
    self.activeDelegate = nil;
    [webView evaluateJavaScript:
         @"try{window.RichEditorBridge&&window.RichEditorBridge.setHTML('')}catch(e){}"
              completionHandler:nil];
    [webView endEditing:YES];
    [webView removeFromSuperview];
    [self attachOffscreen:webView];
    self.warmWebView = webView;
    self.borrowed = NO;
    self.loading = NO;
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"richEditor"]) {
        NSString *body = nil;
        if ([message.body isKindOfClass:[NSString class]]) {
            body = message.body;
        } else if ([message.body isKindOfClass:[NSDictionary class]]) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:message.body options:0 error:nil];
            body = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        }
        if (body.length) {
            NSData *jsonData = [body dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"type"] isEqualToString:@"ready"]) {
                self.ready = YES;
                self.loading = NO;
            }
        }
    }
    id<WKScriptMessageHandler> d = self.activeDelegate;
    if (d && d != self) {
        [d userContentController:userContentController didReceiveScriptMessage:message];
    }
}

@end
