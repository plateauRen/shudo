//
//  WKTranslateManager.m
//  WuKongBase
//

#import "WKTranslateManager.h"
#import "WKApp.h"
#import "WKAPIClient.h"
#import "WKMessageModel.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMD5Util.h"

NSNotificationName const WKTranslateDidUpdateNotification = @"WKTranslateDidUpdateNotification";
NSString * const WKTranslateUserInfoClientMsgNoKey = @"clientMsgNo";

static NSString * const kAutoKey = @"lim_auto_translate_on";
static NSString * const kTargetKey = @"lim_translate_target_lang";
static NSString * const kServiceURLKey = @"lim_translate_service_url";
static NSString * const kTmpTextKey = @"wk_translation";
static NSString * const kTmpHiddenKey = @"wk_translation_hidden";
static NSString * const kTmpLoadingKey = @"wk_translation_loading";

@interface WKTranslateManager ()
@property(nonatomic, strong) NSCache<NSString *, NSString *> *memoryCache;
@property(nonatomic, strong) NSMutableSet<NSString *> *inflight;
@property(nonatomic, strong) dispatch_queue_t queue;
@end

@implementation WKTranslateManager

+ (instancetype)shared {
    static WKTranslateManager *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [[WKTranslateManager alloc] init];
    });
    return m;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memoryCache = [[NSCache alloc] init];
        _memoryCache.countLimit = 500;
        _inflight = [NSMutableSet set];
        _queue = dispatch_queue_create("com.platoren.tsdd.translate", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Settings

- (BOOL)autoTranslateEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kAutoKey];
}

- (void)setAutoTranslateEnabled:(BOOL)autoTranslateEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:autoTranslateEnabled forKey:kAutoKey];
}

- (NSString *)targetLanguage {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:kTargetKey];
    return v.length ? v : @"zh-CN";
}

- (void)setTargetLanguage:(NSString *)targetLanguage {
    [[NSUserDefaults standardUserDefaults] setObject:targetLanguage ?: @"zh-CN" forKey:kTargetKey];
}

- (NSString *)serviceBaseUrl {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kServiceURLKey];
}

- (void)setServiceBaseUrl:(NSString *)serviceBaseUrl {
    if (serviceBaseUrl.length) {
        [[NSUserDefaults standardUserDefaults] setObject:serviceBaseUrl forKey:kServiceURLKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kServiceURLKey];
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)supportedLanguages {
    return @[
        @{@"code": @"zh-CN", @"name": @"简体中文"},
        @{@"code": @"zh-TW", @"name": @"繁體中文"},
        @{@"code": @"en", @"name": @"English"},
        @{@"code": @"ja", @"name": @"日本語"},
        @{@"code": @"ko", @"name": @"한국어"},
        @{@"code": @"fr", @"name": @"Français"},
        @{@"code": @"de", @"name": @"Deutsch"},
        @{@"code": @"es", @"name": @"Español"},
        @{@"code": @"ru", @"name": @"Русский"},
    ];
}

- (NSString *)displayNameForLanguage:(NSString *)code {
    for (NSDictionary *item in [self supportedLanguages]) {
        if ([item[@"code"] isEqualToString:code]) {
            return item[@"name"];
        }
    }
    return code ?: @"";
}

#pragma mark - Message helpers

- (NSString *)plainTextFromMessage:(WKMessageModel *)model {
    if (![model.content isKindOfClass:[WKTextContent class]]) {
        return @"";
    }
    WKTextContent *content = (WKTextContent *)model.content;
    if (model.remoteExtra.contentEdit && [model.remoteExtra.contentEdit isKindOfClass:[WKTextContent class]]) {
        content = (WKTextContent *)model.remoteExtra.contentEdit;
    }
    NSString *text = content.content ?: @"";
    if ([content.format isEqualToString:@"html"]) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
        text = [re stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    }
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)shouldAutoTranslateMessage:(WKMessageModel *)model {
    if (!self.autoTranslateEnabled) {
        return NO;
    }
    if (!model || model.isSend) {
        return NO;
    }
    if (model.contentType != WK_TEXT) {
        return NO;
    }
    if ([self isTranslationHiddenForMessage:model]) {
        return NO;
    }
    NSString *text = [self plainTextFromMessage:model];
    return text.length > 0;
}

- (NSString *)cacheKeyForText:(NSString *)text target:(NSString *)target {
    NSString *raw = [NSString stringWithFormat:@"%@|%@", target ?: @"", text ?: @""];
    return [WKMD5Util md5HexDigest:raw] ?: raw;
}

- (NSString *)cachedTranslationForText:(NSString *)text target:(NSString *)target {
    if (!text.length) {
        return nil;
    }
    NSString *key = [self cacheKeyForText:text target:target];
    NSString *mem = [self.memoryCache objectForKey:key];
    if (mem) {
        return mem;
    }
    NSString *disk = [[NSUserDefaults standardUserDefaults] stringForKey:[@"lim_tr_" stringByAppendingString:key]];
    if (disk) {
        [self.memoryCache setObject:disk forKey:key];
    }
    return disk;
}

- (void)storeTranslation:(NSString *)translated text:(NSString *)text target:(NSString *)target {
    if (!translated.length || !text.length) {
        return;
    }
    NSString *key = [self cacheKeyForText:text target:target];
    [self.memoryCache setObject:translated forKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:translated forKey:[@"lim_tr_" stringByAppendingString:key]];
}

- (NSString *)translationAttachedToMessage:(WKMessageModel *)model {
    id v = model.tmpObject[kTmpTextKey];
    if ([v isKindOfClass:[NSString class]] && [v length]) {
        return v;
    }
    NSString *text = [self plainTextFromMessage:model];
    return [self cachedTranslationForText:text target:self.targetLanguage];
}

- (BOOL)isTranslationHiddenForMessage:(WKMessageModel *)model {
    return [model.tmpObject[kTmpHiddenKey] boolValue];
}

- (void)setTranslationHidden:(BOOL)hidden forMessage:(WKMessageModel *)model {
    model.tmpObject[kTmpHiddenKey] = @(hidden);
}

#pragma mark - Network

- (NSURL *)translateURL {
    NSString *override = self.serviceBaseUrl;
    if (override.length) {
        NSString *base = override;
        if (![base hasSuffix:@"/"]) {
            base = [base stringByAppendingString:@"/"];
        }
        return [NSURL URLWithString:[base stringByAppendingString:@"common/translate"]];
    }

    // Prefer dedicated translate service on :8091 (same host as apiBaseUrl).
    NSString *api = [WKApp shared].config.apiBaseUrl ?: @"";
    NSURL *apiURL = [NSURL URLWithString:api];
    if (apiURL.host.length) {
        NSString *scheme = apiURL.scheme ?: @"http";
        NSString *host = apiURL.host;
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@:8091/v1/common/translate", scheme, host]];
    }
    return [NSURL URLWithString:@"http://127.0.0.1:8091/v1/common/translate"];
}

- (void)translateMessage:(WKMessageModel *)model
                   force:(BOOL)force
              completion:(void (^)(NSString *, NSError *))completion {
    if (!model) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"WKTranslate" code:1 userInfo:@{NSLocalizedDescriptionKey: @"invalid message"}]);
        }
        return;
    }
    NSString *text = [self plainTextFromMessage:model];
    if (!text.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"WKTranslate" code:2 userInfo:@{NSLocalizedDescriptionKey: @"empty text"}]);
        }
        return;
    }

    NSString *target = self.targetLanguage;
    NSString *cached = [self cachedTranslationForText:text target:target];
    if (cached.length && !force) {
        model.tmpObject[kTmpTextKey] = cached;
        model.tmpObject[kTmpHiddenKey] = @(NO);
        if (completion) {
            completion(cached, nil);
        }
        [self postUpdateForMessage:model];
        return;
    }

    NSString *inflightKey = [NSString stringWithFormat:@"%@|%@", model.clientMsgNo ?: @"", target];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        if ([weakSelf.inflight containsObject:inflightKey]) {
            return;
        }
        [weakSelf.inflight addObject:inflightKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            model.tmpObject[kTmpLoadingKey] = @(YES);
        });

        NSURL *url = [weakSelf translateURL];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *token = [WKApp shared].loginInfo.token;
        if (token.length) {
            [req setValue:token forHTTPHeaderField:@"token"];
            [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
        }
        NSDictionary *body = @{
            @"text": text,
            @"target": target ?: @"zh-CN",
            @"source": @"auto",
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        req.timeoutInterval = 30.0;

        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(weakSelf.queue, ^{
                [weakSelf.inflight removeObject:inflightKey];
            });
            dispatch_async(dispatch_get_main_queue(), ^{
                model.tmpObject[kTmpLoadingKey] = @(NO);
                if (error) {
                    if (completion) {
                        completion(nil, error);
                    }
                    return;
                }
                NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
                NSDictionary *json = nil;
                if (data) {
                    json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                }
                if (http.statusCode >= 400 || ![json isKindOfClass:[NSDictionary class]]) {
                    NSString *msg = json[@"detail"] ?: json[@"msg"] ?: @"翻译失败";
                    if (![msg isKindOfClass:[NSString class]]) {
                        msg = @"翻译失败";
                    }
                    NSError *err = [NSError errorWithDomain:@"WKTranslate" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey: msg}];
                    if (completion) {
                        completion(nil, err);
                    }
                    return;
                }
                NSString *translated = json[@"translated"] ?: json[@"text"];
                if (![translated isKindOfClass:[NSString class]] || !translated.length) {
                    if (completion) {
                        completion(nil, [NSError errorWithDomain:@"WKTranslate" code:3 userInfo:@{NSLocalizedDescriptionKey: @"空译文"}]);
                    }
                    return;
                }
                // Identical text → treat as no need to show.
                if ([translated isEqualToString:text]) {
                    model.tmpObject[kTmpTextKey] = translated;
                    model.tmpObject[kTmpHiddenKey] = @(YES);
                    [weakSelf storeTranslation:translated text:text target:target];
                    if (completion) {
                        completion(translated, nil);
                    }
                    [weakSelf postUpdateForMessage:model];
                    return;
                }
                [weakSelf storeTranslation:translated text:text target:target];
                model.tmpObject[kTmpTextKey] = translated;
                model.tmpObject[kTmpHiddenKey] = @(NO);
                if (completion) {
                    completion(translated, nil);
                }
                [weakSelf postUpdateForMessage:model];
            });
        }] resume];
    });
}

- (void)postUpdateForMessage:(WKMessageModel *)model {
    if (!model.clientMsgNo.length) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:WKTranslateDidUpdateNotification
                                                        object:nil
                                                      userInfo:@{WKTranslateUserInfoClientMsgNoKey: model.clientMsgNo}];
}

@end
