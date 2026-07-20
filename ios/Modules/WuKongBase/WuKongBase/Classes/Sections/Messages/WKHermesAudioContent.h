//
//  WKHermesAudioContent.h
//  WuKongBase
//
//  Hermes audio broadcast (content type 21003) — plays in conversation top bar.
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKHermesAudioContent : WKMessageContent

@property(nonatomic, assign) NSInteger v;
@property(nonatomic, copy) NSString *kind; // hermes.audio
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *contentText;
@property(nonatomic, copy) NSString *url; // http(s) or downloadable path
@property(nonatomic, assign) NSInteger durationMs;
@property(nonatomic, copy, nullable) NSString *mime;
@property(nonatomic, copy, nullable) NSDictionary *meta;

@end

NS_ASSUME_NONNULL_END
