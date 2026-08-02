//
//  WKSubChannelsVC.h
//  WuKongBase
//
//  父群内管理话题：列表、创建、改名、归档、删除
//

#import "WKBaseVC.h"
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSubChannelsVC : WKBaseVC
@property(nonatomic, strong) WKChannel *parentChannel;
@end

NS_ASSUME_NONNULL_END
