//
//  WKHermesActionStore.h
//  WuKongBase
//
//  Persist Hermes card button choices locally (by card id).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKHermesActionStore : NSObject

+ (void)markActedForCardId:(NSString *)cardId
                    action:(NSString *)action
                     label:(NSString *)label;

+ (BOOL)isActed:(nullable NSString *)cardId;

/// @{ @"action": NSString, @"label": NSString } or nil
+ (nullable NSDictionary *)infoForCardId:(nullable NSString *)cardId;

@end

NS_ASSUME_NONNULL_END
