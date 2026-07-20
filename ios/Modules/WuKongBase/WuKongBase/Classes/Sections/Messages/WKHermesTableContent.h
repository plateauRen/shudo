//
//  WKHermesTableContent.h
//  WuKongBase
//
//  Hermes table card (content type 21002).
//

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKHermesTableContent : WKMessageContent

@property(nonatomic, assign) NSInteger v;
@property(nonatomic, copy) NSString *kind; // hermes.table
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *caption;
@property(nonatomic, copy) NSString *contentText;
@property(nonatomic, copy) NSArray<NSDictionary *> *columns; // [{id,label,align,format}]
@property(nonatomic, copy) NSArray<NSDictionary *> *rows;    // [{colId: value, ...}]
@property(nonatomic, copy, nullable) NSDictionary *meta;

@end

NS_ASSUME_NONNULL_END
