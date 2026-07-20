//
//  WKHermesCardContent.m
//  WuKongBase
//

#import "WKHermesCardContent.h"
#import "WKHermesActionStore.h"

@implementation WKHermesCardContent

- (instancetype)init {
    self = [super init];
    if (self) {
        _v = 1;
        _kind = @"hermes.approval";
        _title = @"";
        _contentText = @"";
        _buttons = @[];
    }
    return self;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"v"] = @(self.v > 0 ? self.v : 1);
    dict[@"kind"] = self.kind ?: @"hermes.approval";
    if (self.approvalId.length) dict[@"approval_id"] = self.approvalId;
    if (self.confirmId.length) dict[@"confirm_id"] = self.confirmId;
    if (self.clarifyId.length) dict[@"clarify_id"] = self.clarifyId;
    dict[@"title"] = self.title ?: @"";
    if (self.body.length) dict[@"body"] = self.body;
    if (self.descText.length) dict[@"description"] = self.descText;
    dict[@"content"] = self.contentText ?: @"";
    dict[@"buttons"] = self.buttons ?: @[];
    if (self.meta) dict[@"meta"] = self.meta;
    return dict;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    if (![contentDic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    self.v = [contentDic[@"v"] integerValue] ?: 1;
    self.kind = [contentDic[@"kind"] isKindOfClass:[NSString class]] ? contentDic[@"kind"] : @"hermes.approval";
    self.approvalId = [contentDic[@"approval_id"] isKindOfClass:[NSString class]] ? contentDic[@"approval_id"] : nil;
    self.confirmId = [contentDic[@"confirm_id"] isKindOfClass:[NSString class]] ? contentDic[@"confirm_id"] : nil;
    self.clarifyId = [contentDic[@"clarify_id"] isKindOfClass:[NSString class]] ? contentDic[@"clarify_id"] : nil;
    self.title = [contentDic[@"title"] isKindOfClass:[NSString class]] ? contentDic[@"title"] : @"";
    self.body = [contentDic[@"body"] isKindOfClass:[NSString class]] ? contentDic[@"body"] : nil;
    self.descText = [contentDic[@"description"] isKindOfClass:[NSString class]] ? contentDic[@"description"] : nil;
    NSString *content = contentDic[@"content"];
    self.contentText = [content isKindOfClass:[NSString class]] ? content : (self.title ?: @"");
    id buttons = contentDic[@"buttons"];
    if ([buttons isKindOfClass:[NSArray class]]) {
        self.buttons = buttons;
    } else {
        self.buttons = @[];
    }
    id meta = contentDic[@"meta"];
    self.meta = [meta isKindOfClass:[NSDictionary class]] ? meta : nil;
    [self applyLocalActedState];
}

+ (NSNumber *)contentType {
    return @(WK_HERMES_CARD);
}

- (NSString *)conversationDigest {
    if (self.acted && self.actedLabel.length) {
        return [NSString stringWithFormat:@"[已选] %@", self.actedLabel];
    }
    if (self.title.length) {
        return [NSString stringWithFormat:@"[Hermes] %@", self.title];
    }
    return @"[Hermes]";
}

- (NSString *)searchableWord {
    return self.contentText ?: self.title ?: @"Hermes";
}

- (nullable NSString *)cardId {
    if (self.approvalId.length) return self.approvalId;
    if (self.confirmId.length) return self.confirmId;
    if (self.clarifyId.length) return self.clarifyId;
    return nil;
}

- (NSString *)fallbackActionTextForButtonId:(NSString *)buttonId {
    NSString *cid = [self cardId] ?: @"";
    return [NSString stringWithFormat:@"::hermes_action::%@:%@", buttonId ?: @"", cid];
}

- (void)applyLocalActedState {
    NSDictionary *info = [WKHermesActionStore infoForCardId:[self cardId]];
    if (!info) {
        return;
    }
    self.acted = YES;
    NSString *action = [info[@"action"] isKindOfClass:[NSString class]] ? info[@"action"] : @"";
    NSString *label = [info[@"label"] isKindOfClass:[NSString class]] ? info[@"label"] : action;
    self.actedAction = action;
    self.actedLabel = label;
}

- (void)markActedWithAction:(NSString *)action label:(NSString *)label {
    self.acted = YES;
    self.actedAction = action ?: @"";
    self.actedLabel = label.length ? label : action;
    [WKHermesActionStore markActedForCardId:[self cardId]
                                     action:self.actedAction
                                      label:self.actedLabel];
}

@end
