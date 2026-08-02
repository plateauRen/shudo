//
//  WKFolderTabsView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKFolderTabsView : UIView

/// 空字符串表示「全部」
@property(nonatomic, copy) NSString *selectedFolderId;
@property(nonatomic, copy, nullable) void (^onSelectFolder)(NSString *folderId);
@property(nonatomic, copy, nullable) void (^onMore)(void);

- (void)reloadFolders;

@end

NS_ASSUME_NONNULL_END
