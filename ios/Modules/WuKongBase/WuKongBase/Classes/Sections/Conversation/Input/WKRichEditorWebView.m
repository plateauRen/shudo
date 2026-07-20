//
//  WKRichEditorWebView.m
//  WuKongBase
//

#import "WKRichEditorWebView.h"
#import <objc/runtime.h>

@implementation WKRichEditorWebView

+ (void)load {
    // Keyboard / menu paste hits WKContentView, not WKWebView — swizzle there.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"WKContentView");
        if (!cls) return;
        SEL sel = NSSelectorFromString(@"paste:");
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) return;
        IMP original = method_getImplementation(m);
        IMP replacement = imp_implementationWithBlock(^void(id contentView, id sender) {
            WKRichEditorWebView *web = [WKRichEditorWebView webViewOwningContentView:contentView];
            if (web && [web tryPasteTableFromPasteboard]) {
                return;
            }
            ((void (*)(id, SEL, id))original)(contentView, sel, sender);
        });
        method_setImplementation(m, replacement);
    });
}

+ (WKRichEditorWebView *)webViewOwningContentView:(UIView *)contentView {
    UIView *v = contentView;
    while (v) {
        if ([v isKindOfClass:[WKRichEditorWebView class]]) {
            return (WKRichEditorWebView *)v;
        }
        v = v.superview;
    }
    return nil;
}

- (NSString *)jsString:(NSString *)s {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[ s ?: @"" ] options:0 error:nil];
    NSString *arr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (arr.length >= 2) {
        return [arr substringWithRange:NSMakeRange(1, arr.length - 2)];
    }
    return @"\"\"";
}

- (NSString *)pasteboardHTML {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    NSData *htmlData = [pb dataForPasteboardType:@"public.html"];
    if (htmlData.length) {
        NSString *html = [[NSString alloc] initWithData:htmlData encoding:NSUTF8StringEncoding];
        if (html.length) return html;
    }
    for (NSDictionary *item in pb.items) {
        id v = item[@"public.html"];
        if ([v isKindOfClass:[NSData class]]) {
            NSString *html = [[NSString alloc] initWithData:v encoding:NSUTF8StringEncoding];
            if (html.length) return html;
        } else if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) {
            return v;
        }
    }
    return nil;
}

- (BOOL)pasteboardLooksLikeTableText:(NSString *)text {
    if (!text.length) return NO;
    if ([text containsString:@"\t"]) return YES;
    if ([text containsString:@"|"] && [text containsString:@"\n"]) return YES;
    return NO;
}

- (BOOL)tryPasteTableFromPasteboard {
    NSString *html = [self pasteboardHTML];
    if (html.length && [html.lowercaseString containsString:@"<table"]) {
        NSString *js = [NSString stringWithFormat:
                        @"window.RichEditorBridge && window.RichEditorBridge.insertHTML(%@)",
                        [self jsString:html]];
        [self evaluateJavaScript:js completionHandler:nil];
        return YES;
    }
    NSString *text = [UIPasteboard generalPasteboard].string;
    if ([self pasteboardLooksLikeTableText:text]) {
        NSString *js = [NSString stringWithFormat:
                        @"window.RichEditorBridge && window.RichEditorBridge.insertPlain(%@)",
                        [self jsString:text]];
        [self evaluateJavaScript:js completionHandler:nil];
        return YES;
    }
    return NO;
}

- (void)paste:(id)sender {
    if ([self tryPasteTableFromPasteboard]) return;
    [super paste:sender];
}

@end
