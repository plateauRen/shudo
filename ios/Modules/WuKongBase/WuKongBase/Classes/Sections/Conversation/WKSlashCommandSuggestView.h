//
//  WKSlashCommandSuggestView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSlashCommandItem : NSObject
@property(nonatomic, copy) NSString *cmd;
@property(nonatomic, copy) NSString *remark; // 中文说明
@property(nonatomic, copy, nullable) NSString *robotID;
+(instancetype)cmd:(NSString *)cmd remark:(NSString *)remark robotID:(nullable NSString *)robotID;
@end

@interface WKSlashCommandSuggestView : UIView
@property(nonatomic, copy, nullable) void (^onSelect)(WKSlashCommandItem *item);
-(void)reloadItems:(NSArray<WKSlashCommandItem *> *)items;
@end

NS_ASSUME_NONNULL_END
