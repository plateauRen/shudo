//
//  WKHermesPayload.m
//  WuKongIMSDK
//

#import "WKHermesPayload.h"

NSString * const WKHermesCardMarker = @"::hermes_card::";
NSString * const WKHermesActionMarker = @"::hermes_action::";
NSString * const WKHermesTableMarker = @"::hermes_table::";
NSString * const WKHermesAudioMarker = @"::hermes_audio::";
const NSInteger WKHermesCardContentType = 21000;
const NSInteger WKHermesActionContentType = 21001;
const NSInteger WKHermesTableContentType = 21002;
const NSInteger WKHermesAudioContentType = 21003;

@implementation WKHermesPayload

+ (NSInteger)typeValue:(id)rawType {
    if ([rawType isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)rawType integerValue];
    }
    if ([rawType isKindOfClass:[NSString class]]) {
        return [(NSString *)rawType integerValue];
    }
    return 0;
}

+ (NSString *)displayLabelForAction:(NSString *)action preferred:(NSString *)preferred {
    if (preferred.length) return preferred;
    NSString *a = [action lowercaseString] ?: @"";
    if ([a isEqualToString:@"once"]) return @"✅ Allow Once";
    if ([a isEqualToString:@"session"]) return @"✅ Session";
    if ([a isEqualToString:@"always"]) return @"✅ Always";
    if ([a isEqualToString:@"deny"]) return @"❌ Deny";
    if ([a isEqualToString:@"other"]) return @"✏️ Other";
    if ([a hasPrefix:@"choice_"]) {
        return [NSString stringWithFormat:@"选项 %@", [a substringFromIndex:@"choice_".length]];
    }
    return action.length ? action : @"[Hermes]";
}

+ (BOOL)unwrapJSONMarker:(NSString *)marker
                    text:(NSString *)text
              forceType:(NSInteger)forceType
             fallbackContent:(NSString *)fallback
             payloadDict:(NSDictionary *__autoreleasing *)payloadDict
             contentType:(NSInteger *)contentType {
    NSRange range = [text rangeOfString:marker];
    if (range.location == NSNotFound) {
        return NO;
    }
    NSString *jsonStr = [[text substringFromIndex:range.location + range.length]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!jsonStr.length) {
        return NO;
    }
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) {
        return NO;
    }
    id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSMutableDictionary *obj = [((NSDictionary *)parsed) mutableCopy];
    obj[@"type"] = @(forceType);
    if (![obj[@"content"] isKindOfClass:[NSString class]] || ![obj[@"content"] length]) {
        NSString *readable = range.location > 0
            ? [[text substringToIndex:range.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            : @"";
        obj[@"content"] = readable.length ? readable : fallback;
    }
    *payloadDict = obj;
    if (contentType) {
        *contentType = forceType;
    }
    return YES;
}

+ (BOOL)unwrapActionText:(NSString *)text
             payloadDict:(NSDictionary *__autoreleasing *)payloadDict
             contentType:(NSInteger *)contentType {
    NSRange range = [text rangeOfString:WKHermesActionMarker];
    if (range.location == NSNotFound) {
        return NO;
    }
    NSString *tail = [[text substringFromIndex:range.location + range.length]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray<NSString *> *parts = [tail componentsSeparatedByString:@":"];
    if (parts.count < 2) {
        return NO;
    }
    NSString *action = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *cardId = [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@":"];
    cardId = [cardId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange cut = [cardId rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cut.location != NSNotFound) {
        cardId = [cardId substringToIndex:cut.location];
    }
    if (!action.length || !cardId.length) {
        return NO;
    }
    NSString *readable = range.location > 0
        ? [[text substringToIndex:range.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    NSString *label = [self displayLabelForAction:action preferred:readable];

    NSMutableDictionary *actionPayload = [NSMutableDictionary dictionary];
    actionPayload[@"type"] = @(WKHermesActionContentType);
    actionPayload[@"v"] = @1;
    actionPayload[@"kind"] = @"hermes.action";
    actionPayload[@"action"] = action;
    actionPayload[@"label"] = label;
    actionPayload[@"content"] = label;
    actionPayload[@"approval_id"] = cardId;

    *payloadDict = actionPayload;
    if (contentType) {
        *contentType = WKHermesActionContentType;
    }
    return YES;
}

+ (BOOL)unwrapCardIfNeeded:(NSDictionary *__autoreleasing *)payloadDict
               contentType:(NSInteger *)contentType {
    if (!payloadDict || !*payloadDict) {
        return NO;
    }
    NSDictionary *payload = *payloadDict;
    NSInteger typeVal = [self typeValue:payload[@"type"]];
    if (typeVal != 0 && typeVal != 1) {
        return NO;
    }
    id contentObj = payload[@"content"];
    if (![contentObj isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *text = (NSString *)contentObj;

    if ([self unwrapJSONMarker:WKHermesCardMarker
                          text:text
                     forceType:WKHermesCardContentType
              fallbackContent:@"[Hermes]"
                   payloadDict:payloadDict
                   contentType:contentType]) {
        return YES;
    }
    if ([self unwrapJSONMarker:WKHermesTableMarker
                          text:text
                     forceType:WKHermesTableContentType
              fallbackContent:@"[表格]"
                   payloadDict:payloadDict
                   contentType:contentType]) {
        return YES;
    }
    if ([self unwrapJSONMarker:WKHermesAudioMarker
                          text:text
                     forceType:WKHermesAudioContentType
              fallbackContent:@"[音频]"
                   payloadDict:payloadDict
                   contentType:contentType]) {
        return YES;
    }
    return [self unwrapActionText:text payloadDict:payloadDict contentType:contentType];
}

+ (BOOL)payloadLooksStructured:(NSDictionary *)payload type:(NSInteger)type {
    if (type == WKHermesTableContentType) {
        return [payload[@"columns"] isKindOfClass:[NSArray class]];
    }
    if (type == WKHermesAudioContentType) {
        return [payload[@"url"] isKindOfClass:[NSString class]] ||
               [payload[@"kind"] isKindOfClass:[NSString class]];
    }
    if (type == WKHermesCardContentType) {
        return [payload[@"buttons"] isKindOfClass:[NSArray class]] ||
               [payload[@"kind"] isKindOfClass:[NSString class]];
    }
    if (type == WKHermesActionContentType) {
        return [payload[@"action"] isKindOfClass:[NSString class]];
    }
    return NO;
}

+ (BOOL)textHasHermesMarker:(NSString *)text {
    if (![text isKindOfClass:[NSString class]] || !text.length) {
        return NO;
    }
    return [text containsString:WKHermesCardMarker] ||
           [text containsString:WKHermesTableMarker] ||
           [text containsString:WKHermesAudioMarker] ||
           [text containsString:WKHermesActionMarker];
}

+ (BOOL)unwrapCardDataIfNeeded:(NSData *__autoreleasing *)contentData
                   contentType:(NSInteger *)contentType {
    if (!contentData || !*contentData || !contentType) {
        return NO;
    }
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:*contentData options:0 error:nil];
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSInteger payloadType = [self typeValue:payload[@"type"]];
    // Already structured Hermes JSON — keep blob, sync content_type from payload.
    if ([self payloadLooksStructured:payload type:payloadType]) {
        *contentType = payloadType;
        return NO;
    }

    // Bug case: DB content_type was rewritten to 2100x but blob is still a type=1 envelope.
    // Do NOT early-return on *contentType; inspect the blob instead.
    NSDictionary *mutablePayload = payload;
    id contentObj = payload[@"content"];
    if ([self textHasHermesMarker:contentObj] && payloadType != 0 && payloadType != 1) {
        mutablePayload = @{@"type": @1, @"content": contentObj};
    }

    if (![self unwrapCardIfNeeded:&mutablePayload contentType:contentType]) {
        return NO;
    }
    NSData *newData = [NSJSONSerialization dataWithJSONObject:mutablePayload options:0 error:nil];
    if (!newData) {
        return NO;
    }
    *contentData = newData;
    return YES;
}

@end
