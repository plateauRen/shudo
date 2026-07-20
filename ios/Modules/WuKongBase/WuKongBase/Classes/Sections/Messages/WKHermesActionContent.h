//
//  WKHermesActionContent.h
//  WuKongBase
//
//  Hermes button callback (content type 21001).
//

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKHermesActionContent : WKMessageContent

@property(nonatomic, assign) NSInteger v;
@property(nonatomic, copy) NSString *kind; // hermes.action
@property(nonatomic, copy, nullable) NSString *approvalId;
@property(nonatomic, copy, nullable) NSString *confirmId;
@property(nonatomic, copy, nullable) NSString *clarifyId;
@property(nonatomic, copy) NSString *action;
@property(nonatomic, copy, nullable) NSString *label; // UI display, e.g. "✅ Allow Once"
@property(nonatomic, copy, nullable) NSString *sourceMessageId;
@property(nonatomic, copy) NSString *contentText; // digest / protocol fallback

+ (instancetype)action:(NSString *)action
                 label:(nullable NSString *)label
            approvalId:(nullable NSString *)approvalId
             confirmId:(nullable NSString *)confirmId
             clarifyId:(nullable NSString *)clarifyId
       sourceMessageId:(nullable NSString *)sourceMessageId;

/// Human-readable label for known action ids.
+ (NSString *)displayLabelForAction:(NSString *)action preferredLabel:(nullable NSString *)preferred;

@end

NS_ASSUME_NONNULL_END
