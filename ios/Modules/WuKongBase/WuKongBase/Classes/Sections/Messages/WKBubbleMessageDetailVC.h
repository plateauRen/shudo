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

/// HTML `<table>` for pasteboard (rich editor / Excel prefer this over TSV alone).
+ (NSString *)htmlFromTableContent:(WKHermesTableContent *)content;

/// Convert HTML (rich messages) to clipboard plain text, keeping tables as TSV.
+ (NSString *)plainTextFromMessageHTML:(NSString *)html;

/// Write plain + optional HTML so paste into 叙叨 rich composer keeps table structure.
+ (void)writePasteboardPlain:(NSString *)plain html:(nullable NSString *)html;

@end

NS_ASSUME_NONNULL_END
