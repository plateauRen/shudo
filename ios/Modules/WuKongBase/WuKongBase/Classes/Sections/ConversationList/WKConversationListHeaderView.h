//
//  WKConversationListHeaderView.h
//  WuKongBase
//
//  Created by tt on 2021/9/17.
//

#import <UIKit/UIKit.h>
#import "WuKongBase.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationListHeaderView : UIView


@property(nonatomic,assign) BOOL showNetworkError; // 是否显示网络错误

/// 兼容旧调用；UI 已迁至会话列表导航栏左上角，不再渲染列表横幅
@property(nonatomic,assign) BOOL showPCOnline;
@property(nonatomic,assign) WKDeviceFlagEnum pcDeviceFlag;

@property(nonatomic,strong) UIView *tableHeaderBottomEmptyView;

- (void)viewConfigChange:(WKViewConfigChangeType)type;

@end


@interface WKPCOnlineBarView : UIView

@property(nonatomic,strong) UILabel *tipLbl;

@end

NS_ASSUME_NONNULL_END
