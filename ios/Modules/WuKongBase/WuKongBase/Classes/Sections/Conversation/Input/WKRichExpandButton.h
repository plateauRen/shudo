//
//  WKRichExpandButton.h
//  WuKongBase
//
//  Feishu-style expand control on the right of the text field.
//

#import <UIKit/UIKit.h>
#import "WKConversationContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKRichExpandButton : UIButton

@property(nonatomic, weak, nullable) id<WKConversationContext> conversationContext;

+ (instancetype)buttonWithContext:(id<WKConversationContext>)context;

@end

NS_ASSUME_NONNULL_END
