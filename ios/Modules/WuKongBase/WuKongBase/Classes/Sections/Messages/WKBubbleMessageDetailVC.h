//
//  WKBubbleMessageDetailVC.h
//  WuKongBase
//
//  Full-screen bubble-style message viewer with system text selection/copy.
//

#import "WKBaseVC.h"
#import "WKHermesTableContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKBubbleMessageDetailVC : WKBaseVC

/// Navigation title (defaults to “消息”).
@property(nonatomic, copy, nullable) NSString *navTitle;

/// Plain text shown in a selectable UITextView (system select / copy).
@property(nonatomic, copy) NSString *selectableText;

/// Optional structured table rendered above the selectable text.
@property(nonatomic, strong, nullable) WKHermesTableContent *tableContent;

+ (instancetype)detailWithTableContent:(WKHermesTableContent *)tableContent;
+ (instancetype)detailWithTitle:(nullable NSString *)title selectableText:(NSString *)text;
+ (NSString *)plainTextFromTableContent:(WKHermesTableContent *)content;

@end

NS_ASSUME_NONNULL_END
