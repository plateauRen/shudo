//
//  WKHermesPayload.h
//  WuKongIMSDK
//
//  Unwrap TangSeng robot text envelopes into Hermes payloads.
//    ::hermes_card::{json}   → 21000
//    ::hermes_action::a:id  → 21001
//    ::hermes_table::{json}  → 21002
//    ::hermes_audio::{json}  → 21003
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const WKHermesCardMarker;
FOUNDATION_EXPORT NSString * const WKHermesActionMarker;
FOUNDATION_EXPORT NSString * const WKHermesTableMarker;
FOUNDATION_EXPORT NSString * const WKHermesAudioMarker;
FOUNDATION_EXPORT const NSInteger WKHermesCardContentType;   // 21000
FOUNDATION_EXPORT const NSInteger WKHermesActionContentType; // 21001
FOUNDATION_EXPORT const NSInteger WKHermesTableContentType;  // 21002
FOUNDATION_EXPORT const NSInteger WKHermesAudioContentType;  // 21003

@interface WKHermesPayload : NSObject

+ (BOOL)unwrapCardIfNeeded:(NSDictionary *_Nonnull *_Nonnull)payloadDict
               contentType:(NSInteger *_Nullable)contentType;

+ (BOOL)unwrapCardDataIfNeeded:(NSData *_Nonnull *_Nonnull)contentData
                   contentType:(NSInteger *_Nonnull)contentType;

@end

NS_ASSUME_NONNULL_END
