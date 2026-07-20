//
//  WKRichEditorPool.h
//  WuKongBase
//
//  Prewarms TipTap WKWebView so the rich composer opens instantly.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKRichEditorPool : NSObject

+ (instancetype)shared;

/// Start loading editor assets (idempotent). Safe to call early / often.
- (void)prewarm;

/// Drop inlined HTML cache and reload warm webview (after asset rebuild).
- (void)invalidateCache;

/// Editor JS finished booting at least once.
- (BOOL)isReady;

/// Take the warm webview (or create one).
- (WKWebView *)borrowWebView;

/// Return webview after dismiss; content is cleared for next open.
- (void)recycleWebView:(WKWebView *)webView;

/// Forward script messages to the active composer.
- (void)setScriptDelegate:(nullable id<WKScriptMessageHandler>)delegate;

@end

NS_ASSUME_NONNULL_END
