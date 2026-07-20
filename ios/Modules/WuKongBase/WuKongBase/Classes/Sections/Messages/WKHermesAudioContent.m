//
//  WKHermesAudioContent.m
//  WuKongBase
//

#import "WKHermesAudioContent.h"
#import <WuKongIMSDK/WKHermesPayload.h>
#import <WuKongIMSDK/WKConst.h>

@implementation WKHermesAudioContent

- (instancetype)init {
    self = [super init];
    if (self) {
        _v = 1;
        _kind = @"hermes.audio";
        _title = @"";
        _contentText = @"";
        _url = @"";
        _durationMs = 0;
    }
    return self;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"v"] = @(self.v > 0 ? self.v : 1);
    dict[@"kind"] = self.kind ?: @"hermes.audio";
    dict[@"title"] = self.title ?: @"";
    dict[@"content"] = self.contentText ?: @"";
    dict[@"url"] = self.url ?: @"";
    if (self.durationMs > 0) dict[@"duration_ms"] = @(self.durationMs);
    if (self.mime.length) dict[@"mime"] = self.mime;
    if (self.meta) dict[@"meta"] = self.meta;
    return dict;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    if (![contentDic isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *payload = contentDic;
    NSInteger unwrappedType = 0;
    NSDictionary *probe = contentDic;
    if ([WKHermesPayload unwrapCardIfNeeded:&probe contentType:&unwrappedType] &&
        unwrappedType == WKHermesAudioContentType) {
        payload = probe;
    } else if ([contentDic[@"content"] isKindOfClass:[NSString class]] &&
               [contentDic[@"content"] containsString:WKHermesAudioMarker]) {
        NSDictionary *envelope = @{@"type": @1, @"content": contentDic[@"content"]};
        if ([WKHermesPayload unwrapCardIfNeeded:&envelope contentType:&unwrappedType] &&
            unwrappedType == WKHermesAudioContentType) {
            payload = envelope;
        }
    }
    self.v = [payload[@"v"] integerValue] ?: 1;
    self.kind = [payload[@"kind"] isKindOfClass:[NSString class]] ? payload[@"kind"] : @"hermes.audio";
    self.title = [payload[@"title"] isKindOfClass:[NSString class]] ? payload[@"title"] : @"";
    NSString *content = payload[@"content"];
    self.contentText = [content isKindOfClass:[NSString class]] ? content : (self.title ?: @"");
    self.url = [payload[@"url"] isKindOfClass:[NSString class]] ? payload[@"url"] : @"";
    self.durationMs = [payload[@"duration_ms"] integerValue];
    self.mime = [payload[@"mime"] isKindOfClass:[NSString class]] ? payload[@"mime"] : nil;
    self.meta = [payload[@"meta"] isKindOfClass:[NSDictionary class]] ? payload[@"meta"] : nil;
}

+ (NSNumber *)contentType {
    return @(WK_HERMES_AUDIO);
}

- (NSString *)conversationDigest {
    if (self.title.length) {
        return [NSString stringWithFormat:@"[音频] %@", self.title];
    }
    return @"[音频]";
}

- (NSString *)searchableWord {
    return self.contentText ?: self.title ?: @"音频";
}

@end
