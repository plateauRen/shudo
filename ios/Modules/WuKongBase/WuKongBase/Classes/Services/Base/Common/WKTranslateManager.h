//
//  WKTranslateManager.h
//  WuKongBase
//
//  Server-backed message translation (auto + manual).
//

#import <Foundation/Foundation.h>

@class WKMessageModel;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const WKTranslateDidUpdateNotification;
FOUNDATION_EXPORT NSString * const WKTranslateUserInfoClientMsgNoKey;

@interface WKTranslateManager : NSObject

+ (instancetype)shared;

/// Auto-translate incoming text messages in conversation.
@property(nonatomic, assign) BOOL autoTranslateEnabled;

/// Target language BCP-47-ish code: zh-CN / en / ja / zh-TW ...
@property(nonatomic, copy) NSString *targetLanguage;

/// Optional override. Empty = derive from apiBaseUrl host + port 8091.
@property(nonatomic, copy, nullable) NSString *serviceBaseUrl;

- (NSString *)displayNameForLanguage:(NSString *)code;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)supportedLanguages;

- (nullable NSString *)cachedTranslationForText:(NSString *)text target:(NSString *)target;
- (nullable NSString *)translationAttachedToMessage:(WKMessageModel *)model;
- (BOOL)isTranslationHiddenForMessage:(WKMessageModel *)model;
- (void)setTranslationHidden:(BOOL)hidden forMessage:(WKMessageModel *)model;

- (BOOL)shouldAutoTranslateMessage:(WKMessageModel *)model;
- (NSString *)plainTextFromMessage:(WKMessageModel *)model;

/// Translate and cache. Attaches result to model.tmpObject and posts notification.
- (void)translateMessage:(WKMessageModel *)model
                force:(BOOL)force
           completion:(nullable void (^)(NSString *_Nullable translated, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
