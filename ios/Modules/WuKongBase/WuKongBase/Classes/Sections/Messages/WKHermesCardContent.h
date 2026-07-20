//
//  WKHermesCardContent.h
//  WuKongBase
//
//  Hermes interactive card (content type 21000).
//

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKHermesCardContent : WKMessageContent

@property(nonatomic, assign) NSInteger v;
@property(nonatomic, copy) NSString *kind; // hermes.approval / hermes.confirm / hermes.clarify
@property(nonatomic, copy, nullable) NSString *approvalId;
@property(nonatomic, copy, nullable) NSString *confirmId;
@property(nonatomic, copy, nullable) NSString *clarifyId;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *body;
@property(nonatomic, copy, nullable) NSString *descText;
@property(nonatomic, copy) NSString *contentText; // human-readable fallback / digest
@property(nonatomic, copy) NSArray<NSDictionary *> *buttons; // [{id,label,style}]
@property(nonatomic, copy, nullable) NSDictionary *meta;
/// Local-only: user already tapped a button on this card instance.
@property(nonatomic, assign) BOOL acted;
@property(nonatomic, copy, nullable) NSString *actedAction;
@property(nonatomic, copy, nullable) NSString *actedLabel;

- (nullable NSString *)cardId;
- (NSString *)fallbackActionTextForButtonId:(NSString *)buttonId;

/// Restore acted flags from local store (call after decode / before layout).
- (void)applyLocalActedState;

/// Persist choice and mark this content instance acted.
- (void)markActedWithAction:(NSString *)action label:(NSString *)label;

@end

NS_ASSUME_NONNULL_END
