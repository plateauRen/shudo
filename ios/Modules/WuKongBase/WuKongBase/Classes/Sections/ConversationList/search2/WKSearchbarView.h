//
//  WKSearchbarView.h
//  AFNetworking
//
//  Created by tt on 2020/6/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSearchbarView : UIView

@property(nonatomic,copy) NSString *placeholder;

/// When YES, icon + placeholder hug the leading edge (nav-bar compact search).
@property(nonatomic,assign) BOOL leadingContent;

/// 搜索被点击
@property(nonatomic,copy) void(^onClick)(void);

@end

NS_ASSUME_NONNULL_END
