//
//  WKHermesActionContent.m
//  WuKongBase
//

#import "WKHermesActionContent.h"

@implementation WKHermesActionContent

- (instancetype)init {
    self = [super init];
    if (self) {
        _v = 1;
        _kind = @"hermes.action";
        _action = @"";
        _contentText = @"";
    }
    return self;
}

+ (NSString *)displayLabelForAction:(NSString *)action preferredLabel:(NSString *)preferred {
    if (preferred.length) {
        return preferred;
    }
    NSString *a = [action lowercaseString] ?: @"";
    if ([a isEqualToString:@"once"]) return @"✅ Allow Once";
    if ([a isEqualToString:@"session"]) return @"✅ Session";
    if ([a isEqualToString:@"always"]) return @"✅ Always";
    if ([a isEqualToString:@"deny"]) return @"❌ Deny";
    if ([a isEqualToString:@"other"]) return @"✏️ Other";
    if ([a hasPrefix:@"choice_"]) {
        NSString *idx = [a substringFromIndex:@"choice_".length];
        return [NSString stringWithFormat:@"选项 %@", idx];
    }
    return action.length ? action : @"[Hermes]";
}

+ (instancetype)action:(NSString *)action
                 label:(NSString *)label
            approvalId:(NSString *)approvalId
             confirmId:(NSString *)confirmId
             clarifyId:(NSString *)clarifyId
       sourceMessageId:(NSString *)sourceMessageId {
    WKHermesActionContent *c = [WKHermesActionContent new];
    c.action = action ?: @"";
    c.label = [self displayLabelForAction:c.action preferredLabel:label];
    c.approvalId = approvalId;
    c.confirmId = confirmId;
    c.clarifyId = clarifyId;
    c.sourceMessageId = sourceMessageId;
    NSString *cardId = approvalId.length ? approvalId : (confirmId.length ? confirmId : (clarifyId ?: @""));
    // Keep protocol in content for digest/search; UI uses label.
    c.contentText = [NSString stringWithFormat:@"::hermes_action::%@:%@", c.action, cardId];
    return c;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"v"] = @(self.v > 0 ? self.v : 1);
    dict[@"kind"] = self.kind ?: @"hermes.action";
    dict[@"action"] = self.action ?: @"";
    if (self.label.length) dict[@"label"] = self.label;
    if (self.approvalId.length) dict[@"approval_id"] = self.approvalId;
    if (self.confirmId.length) dict[@"confirm_id"] = self.confirmId;
    if (self.clarifyId.length) dict[@"clarify_id"] = self.clarifyId;
    if (self.sourceMessageId.length) dict[@"source_message_id"] = self.sourceMessageId;
    // content = human label so session list / fallback UIs aren't raw protocol
    dict[@"content"] = self.label.length ? self.label : (self.contentText ?: @"");
    return dict;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    if (![contentDic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    self.v = [contentDic[@"v"] integerValue] ?: 1;
    self.kind = [contentDic[@"kind"] isKindOfClass:[NSString class]] ? contentDic[@"kind"] : @"hermes.action";
    self.action = [contentDic[@"action"] isKindOfClass:[NSString class]] ? contentDic[@"action"] : @"";
    self.label = [contentDic[@"label"] isKindOfClass:[NSString class]] ? contentDic[@"label"] : nil;
    self.approvalId = [contentDic[@"approval_id"] isKindOfClass:[NSString class]] ? contentDic[@"approval_id"] : nil;
    self.confirmId = [contentDic[@"confirm_id"] isKindOfClass:[NSString class]] ? contentDic[@"confirm_id"] : nil;
    self.clarifyId = [contentDic[@"clarify_id"] isKindOfClass:[NSString class]] ? contentDic[@"clarify_id"] : nil;
    self.sourceMessageId = [contentDic[@"source_message_id"] isKindOfClass:[NSString class]] ? contentDic[@"source_message_id"] : nil;
    NSString *content = contentDic[@"content"];
    self.contentText = [content isKindOfClass:[NSString class]] ? content : @"";
    if (!self.label.length) {
        // Prefer non-protocol content as label; else map from action id
        if (self.contentText.length && ![self.contentText hasPrefix:@"::hermes_action::"]) {
            self.label = self.contentText;
        } else {
            self.label = [[self class] displayLabelForAction:self.action preferredLabel:nil];
        }
    }
}

+ (NSNumber *)contentType {
    return @(WK_HERMES_ACTION);
}

- (NSString *)conversationDigest {
    NSString *label = self.label.length ? self.label : [[self class] displayLabelForAction:self.action preferredLabel:nil];
    return [NSString stringWithFormat:@"%@", label];
}

- (NSString *)searchableWord {
    return self.label ?: self.action ?: @"Hermes";
}

@end
