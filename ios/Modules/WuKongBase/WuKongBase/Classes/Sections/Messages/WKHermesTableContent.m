//
//  WKHermesTableContent.m
//  WuKongBase
//

#import "WKHermesTableContent.h"
#import <WuKongIMSDK/WKHermesPayload.h>

@implementation WKHermesTableContent

- (instancetype)init {
    self = [super init];
    if (self) {
        _v = 1;
        _kind = @"hermes.table";
        _title = @"";
        _contentText = @"";
        _columns = @[];
        _rows = @[];
    }
    return self;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"v"] = @(self.v > 0 ? self.v : 1);
    dict[@"kind"] = self.kind ?: @"hermes.table";
    dict[@"title"] = self.title ?: @"";
    if (self.caption.length) dict[@"caption"] = self.caption;
    dict[@"content"] = self.contentText ?: @"";
    dict[@"columns"] = self.columns ?: @[];
    dict[@"rows"] = self.rows ?: @[];
    if (self.meta) dict[@"meta"] = self.meta;
    return dict;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    if (![contentDic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    // Recover if blob is still a type=1 envelope under content_type=21002.
    NSDictionary *payload = contentDic;
    NSInteger unwrappedType = 0;
    NSDictionary *probe = contentDic;
    if ([WKHermesPayload unwrapCardIfNeeded:&probe contentType:&unwrappedType] &&
        unwrappedType == WKHermesTableContentType) {
        payload = probe;
    } else if ([contentDic[@"content"] isKindOfClass:[NSString class]] &&
               [contentDic[@"content"] containsString:WKHermesTableMarker]) {
        NSDictionary *envelope = @{@"type": @1, @"content": contentDic[@"content"]};
        if ([WKHermesPayload unwrapCardIfNeeded:&envelope contentType:&unwrappedType] &&
            unwrappedType == WKHermesTableContentType) {
            payload = envelope;
        }
    }

    self.v = [payload[@"v"] integerValue] ?: 1;
    self.kind = [payload[@"kind"] isKindOfClass:[NSString class]] ? payload[@"kind"] : @"hermes.table";
    self.title = [payload[@"title"] isKindOfClass:[NSString class]] ? payload[@"title"] : @"";
    self.caption = [payload[@"caption"] isKindOfClass:[NSString class]] ? payload[@"caption"] : nil;
    NSString *content = payload[@"content"];
    self.contentText = [content isKindOfClass:[NSString class]] ? content : (self.title ?: @"");
    id columns = payload[@"columns"];
    self.columns = [columns isKindOfClass:[NSArray class]] ? columns : @[];
    id rows = payload[@"rows"];
    self.rows = [rows isKindOfClass:[NSArray class]] ? rows : @[];
    id meta = payload[@"meta"];
    self.meta = [meta isKindOfClass:[NSDictionary class]] ? meta : nil;
}

+ (NSNumber *)contentType {
    return @(WK_HERMES_TABLE);
}

- (NSString *)conversationDigest {
    if (self.title.length) {
        return [NSString stringWithFormat:@"[表格] %@", self.title];
    }
    return @"[表格]";
}

- (NSString *)searchableWord {
    return self.contentText ?: self.title ?: @"表格";
}

@end
