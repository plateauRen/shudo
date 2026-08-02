//
//  WKConversationListVC.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKConversationListVC.h"
#import "WKConversationListVM.h"
#import "WKConversationListCell.h"
#import <WuKongBase/WuKongBase.h>
#import "WKResource.h"
#import "WKPopMenuView.h"
#import "WKGlobalSearchController.h"
#import "WKSearchbarView.h"
#import "WKGlobalSearchResultController.h"
#import "WKNetworkListener.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKTypingManager.h"
#import "WKTypingContent.h"
#import "WKConversationAddItem.h"
#import "WKConversationPasswordVC.h"
#import "WKConversationListTableView.h"
#import "WKConversationListHeaderView.h"
#import "WKOnlineStatusManager.h"
#import "WKMD5Util.h"
#import "WKLiquidGlassHelper.h"
#import "WKFolderTabsView.h"
#import "WKFolderSettingVC.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import "WKPCOnlineVC.h"
@interface WKConversationListVC ()<UITableViewDelegate,UITableViewDataSource,UISearchControllerDelegate,WKConnectionManagerDelegate,WKChannelManagerDelegate,WKConversationManagerDelegate,WKNetworkListenerDelegate,WKChatManagerDelegate,WKTypingManagerDelegate,SwipeTableViewCellDelegate,WKOnlineStatusManagerDelegate>
@property(nonatomic,copy) NSString *_title;
@property(nonatomic,strong)  WKConversationListTableView *tableView;

@property(nonatomic,strong) WKConversationListVM *conversationListVM;

@property(nonatomic,strong) NSLock *connectLock; // 连接锁

@property(nonatomic,strong) NSRecursiveLock *conversationLock; // 最近会话锁

@property(nonatomic, nonnull,strong) UIView *rightAddItem; // 右边按钮

@property(nonatomic,strong) UIView *networkErroView; // 网络错误视图
@property(nonatomic,strong) UILabel *warnLbl;


//@property(nonatomic,strong) WKSearchbarView *searchbarView;

@property(nonatomic,strong) WKConversationListHeaderView *tableHeader;
@property(nonatomic,strong) WKSearchbarView *navSearchBar;
@property(nonatomic,strong) WKFolderTabsView *folderTabs;
@property(nonatomic,copy) NSString *currentFolderId;
@property(nonatomic,copy) NSArray<WKConversationWrapModel *> *visibleConversations;
@property(nonatomic,copy) void (^foldersListener)(void);
/// 网页/电脑已登录时替换左上角「叙叨」标题
@property(nonatomic,strong) UIControl *navDeviceOnlineView;
@property(nonatomic,strong) UIImageView *navDeviceOnlineIcon;
@property(nonatomic,strong) UILabel *navDeviceOnlineLabel;

//@property(nonatomic,strong) UIView *tableHeaderBottomEmptyView;

@property(nonatomic,strong) NSTimer *refreshTimer; // 定时刷新table的定时器

@end

@implementation WKConversationListVC
-(instancetype) initWithTitle:(NSString*)title {
    self = [super init];
    if(self) {
        self._title = title;
    }
    return self;
}
-(instancetype) init{
    self = [super init];
    if (!self) return self;
    self._title = [WKApp shared].config.appName;
    _conversationListVM = [WKConversationListVM shared];
    [_conversationListVM reset];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.currentFolderId = @"";
    self.visibleConversations = @[];
    [self.view addSubview:self.folderTabs];
    [self.view addSubview:self.tableView];
    self.connectLock = [[NSLock alloc] init];
    self.conversationLock = [[NSRecursiveLock alloc] init];
    [self addDelegates];
    [self.navigationBar addSubview:self.navSearchBar];
    [self.navigationBar addSubview:self.navDeviceOnlineView];
    
    // 加载最近会话列表数据
    __weak __typeof(self) weakSelf  = self;
    self.foldersListener = ^{
        [weakSelf.folderTabs reloadFolders];
        [weakSelf rebuildVisibleConversationsAndReload];
    };
    [[WKShudoOrgManager shared] addFoldersListener:self.foldersListener];
    [[WKShudoOrgManager shared] refreshFolders:^(NSError *error) {
        [weakSelf.folderTabs reloadFolders];
        [weakSelf rebuildVisibleConversationsAndReload];
    }];
    [[WKShudoOrgManager shared] refreshSubChannelMap:^(NSError *error) {
        [weakSelf rebuildVisibleConversationsAndReload];
    }];
    [_conversationListVM loadConversationList:^{
        if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
            [weakSelf.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[UIColor clearColor]];
        } else if([weakSelf.conversationListVM hasConversationTop]) {
            [weakSelf.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.backgroundColor];
        }else {
            [weakSelf.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        }
        [weakSelf rebuildVisibleConversationsAndReload];
        [weakSelf refreshBadge];

    }];
    
//    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerRefreshTable) userInfo:nil repeats:YES];
//
    [self refreshNavBrandForDeviceOnline];
    [self layoutNavSearchBar];
    [self layoutFolderTabsAndTable];
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutFolderTabsAndTable];
}

- (void)layoutFolderTabsAndTable {
    CGRect vis = [self visibleRect];
    CGFloat tabsH = 44.0f;
    self.folderTabs.frame = CGRectMake(vis.origin.x, vis.origin.y, vis.size.width, tabsH);
    self.tableView.frame = CGRectMake(vis.origin.x, vis.origin.y + tabsH, vis.size.width, MAX(0, vis.size.height - tabsH));
}

- (WKFolderTabsView *)folderTabs {
    if (!_folderTabs) {
        _folderTabs = [[WKFolderTabsView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 44)];
        __weak typeof(self) weakSelf = self;
        _folderTabs.onSelectFolder = ^(NSString *folderId) {
            weakSelf.currentFolderId = folderId ?: @"";
            [weakSelf rebuildVisibleConversationsAndReload];
        };
        _folderTabs.onMore = ^{
            [weakSelf showFolderMoreMenu];
        };
    }
    return _folderTabs;
}

- (void)rebuildVisibleConversationsAndReload {
    NSArray<WKConversationWrapModel *> *all = [self.conversationListVM conversationList] ?: @[];
    if (!self.currentFolderId.length) {
        self.visibleConversations = all;
    } else {
        NSDictionary *folder = nil;
        for (NSDictionary *f in [WKShudoOrgManager shared].folders) {
            if ([f[@"folder_id"] isEqualToString:self.currentFolderId]) {
                folder = f;
                break;
            }
        }
        if (!folder) {
            self.visibleConversations = all;
        } else {
            NSMutableArray *filtered = [NSMutableArray array];
            for (WKConversationWrapModel *m in all) {
                if ([[WKShudoOrgManager shared] folder:folder containsChannel:m.channel.channelId type:m.channel.channelType]) {
                    [filtered addObject:m];
                }
            }
            self.visibleConversations = filtered;
        }
    }
    [self.tableView reloadData];
}

- (WKConversationWrapModel *)visibleConversationAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.visibleConversations.count) return nil;
    return self.visibleConversations[index];
}

- (BOOL)isFolderFilterActive {
    return self.currentFolderId.length > 0;
}

- (NSInteger)visibleIndexForChannel:(WKChannel *)channel {
    if (!channel) return -1;
    NSArray<WKConversationWrapModel *> *list = self.visibleConversations;
    for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
        if ([list[i].channel isEqual:channel]) return i;
    }
    return -1;
}

- (void)showFolderMoreMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"分组" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建分组" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf promptCreateFolder];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"管理分组" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        WKFolderSettingVC *vc = [WKFolderSettingVC new];
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)promptCreateFolder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建分组" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"分组名称";
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!name.length) return;
        [[WKShudoOrgManager shared] createFolder:name complete:^(NSDictionary *folder, NSError *error) {
            if (error) {
                [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"创建失败"];
                return;
            }
            NSString *fid = folder[@"folder_id"] ?: @"";
            if (fid.length) {
                weakSelf.currentFolderId = fid;
                weakSelf.folderTabs.selectedFolderId = fid;
            }
            [weakSelf.folderTabs reloadFolders];
            [weakSelf rebuildVisibleConversationsAndReload];
            [weakSelf.view showHUDWithHide:@"已创建分组"];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMoveToFolderForChannel:(WKChannel *)channel {
    if (!channel) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"移到分组" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    NSArray *containing = [[WKShudoOrgManager shared] foldersContainingChannel:channel.channelId type:channel.channelType];
    for (NSDictionary *f in [WKShudoOrgManager shared].folders) {
        NSString *fid = f[@"folder_id"] ?: @"";
        NSString *name = f[@"name"] ?: @"";
        BOOL already = [[WKShudoOrgManager shared] folder:f containsChannel:channel.channelId type:channel.channelType];
        if (already) continue;
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"移到分组：%@", name] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[WKShudoOrgManager shared] addChannel:channel.channelId type:channel.channelType toFolder:fid complete:^(NSError *error) {
                if (error) {
                    [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"操作失败"];
                } else {
                    [weakSelf.view showHUDWithHide:[NSString stringWithFormat:@"已加入「%@」", name]];
                    [weakSelf rebuildVisibleConversationsAndReload];
                }
            }];
        }]];
    }
    for (NSDictionary *f in containing) {
        NSString *fid = f[@"folder_id"] ?: @"";
        NSString *name = f[@"name"] ?: @"";
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"从「%@」移除", name] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[WKShudoOrgManager shared] removeChannel:channel.channelId type:channel.channelType fromFolder:fid complete:^(NSError *error) {
                if (error) {
                    [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"操作失败"];
                } else {
                    [weakSelf rebuildVisibleConversationsAndReload];
                }
            }];
        }]];
    }
    if (sheet.actions.count == 0) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"暂无可用分组，请先新建" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf promptCreateFolder];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

-(void) timerRefreshTable {
    [self refreshTableNoSort];
}

// 顶栏用常规标题字号，搜索框与标题同一行
- (BOOL)largeTitle {
    return false;
}

-(void) viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutNavSearchBar];
}

- (WKSearchbarView *)navSearchBar {
    if (!_navSearchBar) {
        _navSearchBar = [[WKSearchbarView alloc] initWithFrame:CGRectMake(0, 0, 160, 32)];
        _navSearchBar.placeholder = LLang(@"搜索");
        _navSearchBar.leadingContent = YES;
        __weak typeof(self) weakSelf = self;
        _navSearchBar.onClick = ^{
            (void)weakSelf;
            WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
            [[WKNavigationManager shared] pushViewController:vc animated:NO];
        };
    }
    return _navSearchBar;
}

- (UIControl *)navDeviceOnlineView {
    if (!_navDeviceOnlineView) {
        _navDeviceOnlineView = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 120, 32)];
        _navDeviceOnlineView.hidden = YES;
        [_navDeviceOnlineView addTarget:self action:@selector(onNavDeviceOnlineTap) forControlEvents:UIControlEventTouchUpInside];
        _navDeviceOnlineIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 7, 18, 18)];
        _navDeviceOnlineIcon.image = [self imageName:@"ConversationList/Index/PCOnline"];
        _navDeviceOnlineIcon.contentMode = UIViewContentModeScaleAspectFit;
        [_navDeviceOnlineView addSubview:_navDeviceOnlineIcon];
        _navDeviceOnlineLabel = [[UILabel alloc] init];
        _navDeviceOnlineLabel.font = [[WKApp shared].config appFontOfSizeMedium:17.0f];
        _navDeviceOnlineLabel.textColor = [WKApp shared].config.navBarTitleColor;
        _navDeviceOnlineLabel.lineBreakMode = NSLineBreakByClipping;
        [_navDeviceOnlineView addSubview:_navDeviceOnlineLabel];
    }
    return _navDeviceOnlineView;
}

- (BOOL)shouldShowNavDeviceOnline {
    if (![WKOnlineStatusManager shared].pcOnline) return NO;
    return [WKSDK shared].connectionManager.connectStatus == WKConnected;
}

- (void)refreshNavBrandForDeviceOnline {
    BOOL show = [self shouldShowNavDeviceOnline];
    self.navDeviceOnlineView.hidden = !show;
    self.navigationBar.titleLabel.hidden = show;
    if (!show) return;
    // 仅保留设备图标 +「叙叨」，不占多余文案
    self.navDeviceOnlineLabel.text = [WKApp shared].config.appName ?: @"叙叨";
    [self.navDeviceOnlineLabel sizeToFit];
    CGFloat iconW = 18.0f;
    CGFloat gap = 4.0f;
    CGFloat labelW = MIN(48.0f, self.navDeviceOnlineLabel.lim_width);
    self.navDeviceOnlineLabel.frame = CGRectMake(iconW + gap, 0, labelW, 32.0f);
    self.navDeviceOnlineIcon.frame = CGRectMake(0, 7, iconW, 18);
    self.navDeviceOnlineView.lim_size = CGSizeMake(iconW + gap + labelW, 32.0f);
}

- (void)onNavDeviceOnlineTap {
    WKPCOnlineVC *vc = [WKPCOnlineVC new];
    vc.mute = WKOnlineStatusManager.shared.muteOfApp;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)layoutNavSearchBar {
    if (!self.navSearchBar.superview) {
        return;
    }
    [self refreshNavBrandForDeviceOnline];
    if ([self shouldShowNavDeviceOnline]) {
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        CGFloat contentH = MAX(0.0f, self.navigationBar.lim_height - statusHeight);
        self.navDeviceOnlineView.lim_left = 16.0f;
        self.navDeviceOnlineView.lim_top = statusHeight + (contentH - self.navDeviceOnlineView.lim_height) / 2.0f;
        [self.navigationBar bringSubviewToFront:self.navDeviceOnlineView];

        UIView *right = self.navigationBar.rightView;
        BOOL hasRight = right && right.superview && right.lim_width > 1.0f;
        if (hasRight) {
            right.lim_left = self.navigationBar.lim_width - right.lim_width - 12.0f;
            right.lim_top = statusHeight + (contentH - right.lim_height) / 2.0f;
        }
        CGFloat rightEdge = hasRight ? right.lim_left : (self.navigationBar.lim_width - 16.0f);
        CGFloat searchH = 32.0f;
        CGFloat searchLeft = self.navDeviceOnlineView.lim_right + 10.0f;
        CGFloat searchW = MAX(96.0f, rightEdge - 10.0f - searchLeft);
        self.navSearchBar.frame = CGRectMake(searchLeft,
                                            statusHeight + (contentH - searchH) / 2.0f,
                                            searchW,
                                            searchH);
        [self.navigationBar bringSubviewToFront:self.navSearchBar];
        if (hasRight) {
            [self.navigationBar bringSubviewToFront:right];
        }
    } else {
        [self.navigationBar layoutLeadingTitleWithInlineSearchBar:self.navSearchBar];
    }
}

// 设置自定义标题
-(void) setCustomTitle:(NSString*)title {
    self.navigationBar.title = title;
    [self layoutNavSearchBar];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
   
    [self refreshTitle];
    // Avoid full table reload on every tab switch — refresh visible rows only.
    [self refreshVisibleConversationCells];
    [self hiddenRightItem:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
   
    if(!self.refreshTimer) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerRefreshTable) userInfo:nil repeats:YES];
    }
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if(self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
    
    [self hiddenRightItem:YES];
}


-(void) addDelegates {
    // 添加连接监听
    [[[WKSDK shared] connectionManager] addDelegate:self];
    // 频道信息监听
    [[[WKSDK shared] channelManager] addDelegate:self];
    // 最近会话监听
    [[[WKSDK shared] conversationManager] addDelegate:self];
    // 网络监听
    [[WKNetworkListener shared] addDelegate:self];
    // 消息监听
    [[WKSDK shared].chatManager addDelegate:self];
    // 正在输入...
    [[WKTypingManager shared] addDelegate:self];
    // 在线状态
    [[WKOnlineStatusManager shared] addDelegate:self];
}

-(void) removeDelegates {
    // 移除连接监听
    [[[WKSDK shared] connectionManager] removeDelegate:self];
    // 移除频道监听
    [[[WKSDK shared] channelManager] removeDelegate:self];
    // 移除最近会话监听
    [[[WKSDK shared] conversationManager] removeDelegate:self];
    // 网络监听
    [[WKNetworkListener shared] removeDelegate:self];
    // 移除消息监听
    [[WKSDK shared].chatManager removeDelegate:self];
    // 正在输入...
    [[WKTypingManager shared] removeDelegate:self];
    // 在线状态
    [[WKOnlineStatusManager shared] removeDelegate:self];
    if (self.foldersListener) {
        [[WKShudoOrgManager shared] removeFoldersListener:self.foldersListener];
        self.foldersListener = nil;
    }
}

-(UIView*) rightAddItem {
    if (!_rightAddItem) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self action:@selector(rightAddPressed) forControlEvents:UIControlEventTouchUpInside];
        button.frame = CGRectMake(0.0f , 5.0f, 32.0f, 32.0f);
        UIImage *img = [self imageName:@"ConversationList/Index/Add"];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [button setImage:img forState:UIControlStateNormal];
        [button setBackgroundColor:[UIColor clearColor]];
        [button setTintColor:WKApp.shared.config.navBarButtonColor];
        _rightAddItem = [[UIView alloc] initWithFrame:CGRectMake(0.0f , 0.0f, 32.0f, 32.0f)];
        [_rightAddItem addSubview:button];
//        [button setBackgroundColor:[UIColor redColor]];
    }
    return _rightAddItem;
}

-(void) hiddenRightItem:(BOOL)hidden {
    UIView *rightItem = nil;
    if(!hidden) {
        rightItem = self.rightAddItem;
    }
    self.rightView = rightItem;
    [self layoutNavSearchBar];
}

-(void) rightAddPressed {
    
    NSArray<WKConversationAddItem*> *items = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONVERSATION_ADD param:nil];
    
    CGFloat statusHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    NSMutableArray *itemDicts = [NSMutableArray array];
    if(items && items.count>0) {
        for (WKConversationAddItem *item in items) {
            [itemDicts addObject:@{
                @"title":item.title?:@"",
                @"image": item.icon,
            }];
        }
    }
    [WKPopMenuView showWithItems:itemDicts width:140.0f triangleLocation:CGPointMake(WKScreenWidth-30, self.navigationController.navigationBar.lim_height + statusHeight-4.0f) action:^(NSInteger index) {
        WKConversationAddItem *item = [items objectAtIndex:index];
        if(item.onClick) {
            item.onClick();
        }
    }];
}

-(void) refreshTitle{
    WKConnectStatus status = [WKSDK shared].connectionManager.connectStatus;
    [self.connectLock lock];
    switch (status) {
        case WKConnecting:
            self._title = LLang(@"连接中");
            break;
        case WKPullingOffline:
            self._title = LLang(@"收取中");
            break;
        case WKConnected:
            self._title = [WKApp shared].config.appName;
            break;
        case WKDisconnected:
            self._title = LLang(@"已断开");
            break;
        default:
            break;
    }
//    if(self.tabBarController) {
//        self.tabBarController.title = self._title;
//    }
//    self.title = self._title;
    [self setCustomTitle:self._title];
    [self.connectLock unlock];
}

- (WKConversationListTableView *)tableView{
    if (!_tableView) {
        _tableView = [[WKConversationListTableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
//        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIEdgeInsets separatorInset = _tableView.separatorInset;
        separatorInset.right          = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(-0.1f, 0.0f, 0.0f, 0.0f);
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        if (@available(iOS 15.0, *)) {
            _tableView.sectionHeaderTopPadding = 0;
        }
        
        [self applyTableHeaderView];
        
        [_tableView registerClass:[WKConversationListCell class] forCellReuseIdentifier:@"WKConversationListCell"];
    }
    return _tableView;
}

/// 重新挂载 tableHeaderView，高度为 0 时真正收起，避免 Grouped 列表顶空隙
- (void)applyTableHeaderView {
    [self.tableHeader layoutIfNeeded];
    UIView *header = self.tableHeader;
    CGFloat h = header.bounds.size.height;
    if (h < 0.5f) {
        // 无横幅：不挂 header，会话紧贴分组 Tab
        self.tableView.tableHeaderView = nil;
        return;
    }
    header.frame = CGRectMake(0, 0, WKScreenWidth, h);
    self.tableView.tableHeaderView = header;
}

- (UIScrollView *)primaryScrollViewForLiquidGlass {
    return self.tableView;
}


#define networkErrorViewHeight 50.0f
-(WKConversationListHeaderView*) tableHeader {
    if(!_tableHeader) {
        _tableHeader = [[WKConversationListHeaderView alloc] init];
        _tableHeader.backgroundColor = [UIColor clearColor];
//        _tableHeader.showEmpty = true;
//        [_tableHeader addSubview:self.searchbarView];

//        _tableHeader.lim_height = self.searchbarView.frame.size.height+20.0f;
        
//        self.tableHeaderBottomEmptyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.searchbarView.lim_bottom+10.0f, WKScreenWidth, 10.0f)];
//        [self.tableHeaderBottomEmptyView setBackgroundColor:[UIColor whiteColor]];
//        [_tableHeader addSubview:self.tableHeaderBottomEmptyView];
    }
    return _tableHeader;
}

-(void) showNetworkError:(BOOL) show {
    self.tableHeader.showNetworkError = show;
    [self applyTableHeaderView];
    [self rebuildVisibleConversationsAndReload];
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    [self.navigationBar setBackgroundColor:[WKApp shared].config.navBackgroudColor];
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.navigationBar.style = WKNavigationBarStyleDark;
    }else {
        self.navigationBar.style = WKNavigationBarStyleDefault;
    }
    [self.tableHeader viewConfigChange:type];
    [self refreshTable];
}

- (UIView *)networkErroView {
    if(!_networkErroView) {
        _networkErroView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, networkErrorViewHeight)];
        UIImageView *warnIcon = [[UIImageView alloc] initWithFrame:CGRectMake(20.0f, 0.0f, 26.0f, 26.0f)];
        [warnIcon setImage:[self imageName:@"ConversationList/Index/NetworkStatusFail"]];
        warnIcon.lim_top = _networkErroView.lim_height/2.0f - warnIcon.lim_height/2.0f;
        [_networkErroView addSubview:warnIcon];
        
         _warnLbl = [[UILabel alloc] init];
        [_warnLbl setText:LLang(@"当前网络不可用，请检查网络设置")];
        [_warnLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_warnLbl sizeToFit];
        _warnLbl.lim_top = _networkErroView.lim_height/2.0f - _warnLbl.lim_height/2.0f;
        _warnLbl.lim_left = warnIcon.lim_right + 20.0f;
        [_networkErroView addSubview:_warnLbl];
    }
    return _networkErroView;
}

#pragma mark -- WKOnlineStatusManagerDelegate

// 我的pc/网页状态改变 —— 提示放在左上角标题位，不占列表行
- (void)onlineStatusManagerMyPCOnlineChange:(WKOnlineStatusManager *)manager status:(WKPCOnlineResp *)status {
    (void)manager;
    (void)status;
    [self refreshTitle];
    [self layoutNavSearchBar];
}

#pragma mark - WKTypingManagerDelegate

- (void)typingAdd:(WKTypingManager *)manager message:(WKMessage *)message {
    if(message.fromUid && [message.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    WKChannel *channel = message.channel;
    NSInteger index =  [self.conversationListVM indexAtChannel:channel];
    if(index!=-1) {
        WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
        if(model) {
            WKTypingContent *content = (WKTypingContent*)message.content;
            model.typing = YES;
            model.typer = content.typingName;
            NSInteger vis = [self visibleIndexForChannel:channel];
            if(vis != -1) {
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:vis inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
    }
    
}

- (void)typingRemove:(WKTypingManager *)manager message:(WKMessage *)message newMessage:(WKMessage *)newMessage{
    if(message.fromUid && [message.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    WKChannel *channel = message.channel;
    NSInteger index =  [self.conversationListVM indexAtChannel:channel];
    if(index!=-1) {
        WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
        model.typing = NO;
        NSInteger vis = [self visibleIndexForChannel:channel];
        if(vis != -1) {
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:vis inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

-(void) typingReplace:(WKTypingManager*)manager newmessage:(WKMessage*)newmessage oldmessage:(WKMessage*)oldmessage {
    [self typingAdd:manager message:newmessage];
}


#pragma mark - WKChatManagerDelegate

-(void) onMessageUpdate:(WKMessage*) message left:(NSInteger)left{
   
    NSInteger index = [self.conversationListVM indexAtChannel:message.channel];
    if(index!=-1) {
        WKConversationWrapModel *conversation = [self.conversationListVM modelAtIndex:index];
        if([conversation.lastClientMsgNo isEqualToString:message.clientMsgNo]) {
            [conversation setLastMessage:message];
        }
        NSInteger vis = [self visibleIndexForChannel:message.channel];
        if(vis != -1) {
            WKConversationListCell *cell =  [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:vis inSection:0]];
            [cell refreshWithModel:conversation];
        }
    }
    
    if(left == 0 ) {
        [self refreshTable];
    }
}

#pragma mark - WKConnectionManagerDelegate

/**
 连接状态改变
 */
-(void) onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode {
    [self refreshTitle];
}

#pragma mark - WKConversationManagerDelegate

// 更新最近会话
- (void)onConversationUpdate:(NSArray<WKConversation*>*)conversations{
    if(!conversations || conversations.count<=0) {
        return;
    }
//    for (WKConversation *conversation in conversations) {
//        if([WKApp shared].currentChatChannel && [conversation.channel isEqual:[WKApp shared].currentChatChannel]) {
//            conversation.unreadCount = 0;
//            break;
//        }
//    }
    if(conversations.count>1) { // 批量更新：合并模型后防抖整表刷新，避免连打 reloadData
        for (WKConversation *conversation in conversations) {
            [self onlyAddOrUpdateConversation:conversation];
        }
        [self scheduleDebouncedConversationReload];
        [self refreshBadge];
        return;
    }
   
   WKConversation *conversation = conversations[0];
    [self uiAddOrUpdateConversationForOne:conversation];
    [self refreshBadge];
    
}
// 单个会话添加或更新(大量会话不要使用此方法，容易卡顿)
-(void) uiAddOrUpdateConversationForOne:(WKConversation*)conversation {
    WKConversationWrapModel *newModel = [self.conversationListVM getRealShowConversationWrap:[[WKConversationWrapModel alloc] initWithConversation:conversation]];
    
    // 分组过滤时行索引与 VM 不一致，整表重建可见列表
    if ([self isFolderFilterActive]) {
        NSInteger oldIndex =[self.conversationListVM indexAtChannel:newModel.channel];
        if(oldIndex!=-1) {
            [self.conversationListVM removeAtIndex:oldIndex];
        }
        NSInteger insertPlace = [self.conversationListVM findInsertPlace:newModel];
        [self.conversationListVM insert:newModel atIndex:insertPlace];
        [self rebuildVisibleConversationsAndReload];
        return;
    }
    
    NSInteger oldIndex =[self.conversationListVM indexAtChannel:newModel.channel];
    if(oldIndex!=-1) {
        
        NSInteger insertPlace =  [self.conversationListVM findInsertPlace:newModel];
        if(oldIndex==insertPlace) {
            [self.conversationListVM replaceAtChannel:newModel atChannel:newModel.channel];
            WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:oldIndex inSection:0]];
            if(cell) {
                [cell refreshWithModel:newModel];
            }
            // 保持 visible 与 VM 同步（全部 Tab）
            self.visibleConversations = [self.conversationListVM conversationList] ?: @[];
            return;
        }
        
        if(oldIndex>self.conversationListVM.conversationCount || insertPlace>self.conversationListVM.conversationCount) {
            return;
        }
       
        [self.conversationListVM removeAtIndex:oldIndex];
        [self.conversationListVM insert:newModel atIndex:insertPlace];
        self.visibleConversations = [self.conversationListVM conversationList] ?: @[];
        @try {
            [self.tableView beginUpdates];
            [self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:oldIndex inSection:0] toIndexPath:[NSIndexPath indexPathForRow:insertPlace inSection:0]];
            [self.tableView endUpdates];
        } @catch (NSException *exception) { // moveRowAtIndexPath 有时会引起异常。原因还没找到
            WKLogError(@"moveRowAtIndexPath is error -> %@",exception);
            [self rebuildVisibleConversationsAndReload];
        }
       
        WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:insertPlace inSection:0]];
        if(cell) {
            [cell refreshWithModel:newModel];
        }
        
        
    }else {
        [self uiAddConversation:conversation];
    }
}


-(void) uiAddConversation:(WKConversation*)conversation {
    WKConversationWrapModel *model = [[WKConversationWrapModel alloc] initWithConversation:conversation];
    NSInteger insertPlace = [self.conversationListVM insert:model];
    if ([self isFolderFilterActive]) {
        [self rebuildVisibleConversationsAndReload];
        return;
    }
    self.visibleConversations = [self.conversationListVM conversationList] ?: @[];
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:insertPlace inSection:0] ] withRowAnimation:UITableViewRowAnimationFade];
}
// 删除最近会话
- (void)onConversationDelete:(WKChannel *)channel {
    [self.conversationListVM removeAtChannnel:channel];
    [self refreshTable];
    [self refreshBadge];
}

-(void) onlyAddOrUpdateConversation:(WKConversation*)conversation {
    WKConversationWrapModel *model =  [self.conversationListVM modelAtChannel:conversation.channel];
    if(model) {
        [model setConversation:conversation];
    }else {
        [self.conversationListVM insert:[[WKConversationWrapModel alloc] initWithConversation:conversation] atIndex:0];
    }
}
// 更新最近会话未读数
- (void)onConversationUnreadCountUpdate:(WKChannel*)channel unreadCount:(NSInteger)unreadCount {
    
    NSInteger index = [self.conversationListVM indexAtChannel:channel];
    if(index!=-1) {
        WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
        model.unreadCount = unreadCount;
        NSInteger vis = [self visibleIndexForChannel:channel];
        if(vis != -1) {
            WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:vis inSection:0]];
            if(cell) {
                [cell refreshWithModel:model];
                [cell layoutSubviews];
            }
        }
        [self refreshBadge];
    }
}
// 删除所有最近会话
- (void)onConversationAllDelete {
    [self.conversationListVM removeAll];
    [self refreshTable];
    [self refreshBadge];
}


-(void) refreshBadge {
    NSInteger unreadCount = [self.conversationListVM getAllUnreadCount];
    if(unreadCount>0) {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%ld",(long)unreadCount];
    }else {
        self.tabBarItem.badgeValue = nil;
    }
    
}

#pragma mark - WKNetworkListenerDelegate

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
     [self showNetworkError:!listener.hasNetwork];
}

#pragma mark - WKChannelManagerDelegate

-(void) channelInfoUpdate:(WKChannelInfo *)channelInfo oldChannelInfo:(WKChannelInfo *)oldChannelInfo{
   //[self refreshTable];
    NSInteger index = [self.conversationListVM indexAtChannel:channelInfo.channel];
    if(index!= -1) {
        WKConversationWrapModel *oldModel = [self.conversationListVM modelAtIndex:index];
        WKConversation *conversation = [[oldModel getConversation] copy];
        conversation.mute = channelInfo.mute;
        conversation.stick = channelInfo.stick;
        if([self hasChange:channelInfo oldChannelInfo:oldChannelInfo]) {
            [self uiAddOrUpdateConversationForOne:conversation];
        }else{
            NSInteger vis = [self visibleIndexForChannel:channelInfo.channel];
            if(vis != -1) {
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:vis inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        [self resetHeaderBottomEmptyBackgroundColor];
    }
}

-(BOOL) hasChange:(WKChannelInfo*)channelInfo oldChannelInfo:(WKChannelInfo*)oldChannelInfo {
    if(oldChannelInfo==nil) {
        return false;
    }
    if(channelInfo.stick != oldChannelInfo.stick) {
        return true;
    }
    if(channelInfo.mute != oldChannelInfo.mute) {
        return true;
    }
    if(![channelInfo.displayName isEqualToString:oldChannelInfo.displayName]) {
        return true;
    }
    return false;
}

#pragma mark-  UITableViewDataSource && UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{

    return 88.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return (NSInteger)self.visibleConversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    WKConversationListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationListCell" forIndexPath:indexPath];
    cell.swipeDelegate = self;
    
//    [cell setDisplaySeparator:YES];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKConversationListCell *conversationListCell = (WKConversationListCell*)cell;
    WKConversationWrapModel *conversationModel = [self visibleConversationAtIndex:indexPath.row];
    if(conversationModel) {
        [conversationListCell refreshWithModel:conversationModel];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKConversationWrapModel *conversationModel = [self visibleConversationAtIndex:indexPath.row];
    if(conversationModel) {
        [conversationModel cancelChannelRequest];
    }
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
     WKConversationWrapModel *conversationModel = [self visibleConversationAtIndex:indexPath.row];
    // 防止重复点击
    WKChannel *channel = conversationModel.channel;
    static bool canSelect = true;
    if (canSelect){
        canSelect = false;
        dispatch_async(dispatch_get_main_queue(), ^{
            canSelect = true;
            
            NSString *chatPwd = [WKApp shared].loginInfo.extra[@"chat_pwd"];
            if(conversationModel.channelInfo && chatPwd && ![chatPwd isEqualToString:@""]) {
                __weak typeof(self) weakSelf = self;
                BOOL chatPwdOn = [conversationModel.channelInfo settingForKey:WKChannelExtraKeyChatPwd defaultValue:false];
                if(chatPwdOn) {
                    __block NSInteger errorCount = [self getChatPwdErrorCount:channel];
                    WKPwdKeyboardInputView *vw = [WKPwdKeyboardInputView new];
                    vw.remark = LLang(@"聊天密码");
                    [vw setFinishBlock:^(NSString * _Nonnull pwd) {
                        if([[self digestPwd:pwd] isEqualToString:chatPwd]) {
                            [weakSelf toConversation:conversationModel];
                            [weakSelf setChatPwdErrorCount:0 channel:channel];
                        }else {
                            errorCount++;
                            [weakSelf setChatPwdErrorCount:errorCount channel:channel];
                            if(errorCount >=3) {
                                [WKAlertUtil alert:LLang(@"连续错误次数太多，已删除该聊天记录！") title:LLangW(@"错误密码",weakSelf)];
                            }else{
                                [WKAlertUtil alert:[NSString stringWithFormat:LLang(@"还连续%ld次输入错误，将会清空该聊天记录！\n如果您忘记聊天密码，您可以重置聊天密码"),3- (long)errorCount] title:LLangW(@"错误密码",weakSelf)];
                            }
                           
                            if(errorCount>=3) {
                                [[WKMessageManager shared] clearMessages:conversationModel.channel];
                                [weakSelf setChatPwdErrorCount:0 channel:channel];
                            }
                        }
                        
                    }];
                    [vw setOtherButtonClickBlock:^(UIButton *btn) {
                        WKConversationPasswordVC *vc = [WKConversationPasswordVC new];
                        [[WKNavigationManager shared] pushViewController:vc animated:YES];
                    }];
                    [vw show];
                    return;
                }
            };
            [self toConversation:conversationModel];
        });
    }
    else
        return;
}

-(NSString*) digestPwd:(NSString*)pwd {
    return [WKMD5Util md5HexDigest:[NSString stringWithFormat:@"%@%@",pwd,[WKApp shared].loginInfo.uid]];
}

#pragma  mark -- SwipeTableViewCellDelegate

- (SwipeTableCellStyle)tableView:(UITableView *)tableView styleOfSwipeButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return SwipeTableCellStyleRightToLeft;
}

/**
 *  右滑cell时显示的button
 *
 *  @param indexPath cell的位置
 */
- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView rightSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath {

    WKConversationWrapModel *conversationModel = [self visibleConversationAtIndex:indexPath.row];
    if (!conversationModel) return @[];
    
    // ---------- 免打扰 ----------
    NSString *muteTitle;
    NSString *muteAnimationNamed;
    if(conversationModel.mute) {
        muteTitle = LLang(@"打开通知");
        muteAnimationNamed = @"Other/list_icon_sound_on";
    }else {
        muteTitle = LLang(@"关闭通知");
        muteAnimationNamed = @"Other/list_icon_sound_off";
    }
    
    SwipeButton *muteBtn = [self swipeButton:muteTitle backgroundColor:[UIColor colorWithRed:252.0f/255.0f green:174.0f/255.0f blue:66.0f/255.0f alpha:1.0f] animationNamed:muteAnimationNamed touchBlock:^{
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WKChannelSettingManager shared] channel:conversationModel.channel mute:!conversationModel.mute];
        });
    }];
    
    // ---------- 置顶 ----------
    NSString *stickTitle;
    NSString *stickAnimationNamed;
    if(conversationModel.stick) {
        stickTitle = LLang(@"取消置顶");
        stickAnimationNamed = @"Other/list_icon_toppin";
    }else {
        stickTitle = LLang(@"置顶");
        stickAnimationNamed = @"Other/list_icon_toppin";
    }
    
    SwipeButton *stickBtn = [self swipeButton:stickTitle backgroundColor:[UIColor colorWithRed:37.0f/255.0f green:167.0f/255.0f blue:90.0f/255.0f alpha:1.0f] animationNamed:stickAnimationNamed touchBlock:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WKChannelSettingManager shared] channel:conversationModel.channel stick:!conversationModel.stick];
        });
    }];
    
    // ---------- 删除 ----------
    
    __weak typeof(self) weakSelf =  self;
    WKChannel *delChannel = conversationModel.channel;
    SwipeButton *deleteBtn = [self swipeButton:LLang(@"删除") backgroundColor:[UIColor redColor] animationNamed:@"Other/list_icon_delete" touchBlock:^{
        WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"清空聊天记录") onClick:^{
            [[WKMessageManager shared] clearMessages:delChannel];
        }]];
        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"确认删除") onClick:^{
            NSInteger realIdx = [weakSelf.conversationListVM indexAtChannel:delChannel];
            if (realIdx >= 0) {
                [weakSelf.conversationListVM removeConversationAtIndex:realIdx];
            }
            [[WKSDK shared].conversationManager deleteConversation:delChannel];
            [weakSelf rebuildVisibleConversationsAndReload];
        }]];
        [sheet show];
    }];

    // ---------- 分组 ----------
    SwipeButton *folderBtn = [self swipeButton:@"分组" backgroundColor:[UIColor colorWithRed:90.0f/255.0f green:120.0f/255.0f blue:220.0f/255.0f alpha:1.0f] animationNamed:stickAnimationNamed touchBlock:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf showMoveToFolderForChannel:delChannel];
        });
    }];
    
    // ---------- 话题（父频道：创建/管理；话题内：所属群） ----------
    NSMutableArray *btns = [NSMutableArray arrayWithObjects:deleteBtn, stickBtn, muteBtn, folderBtn, nil];
    WKChannel *channel = conversationModel.channel;
    BOOL canHost = [[WKShudoOrgManager shared] canHostTopicsInChannel:channel];
    BOOL isTopic = channel.channelType == WK_GROUP &&
        [[WKShudoOrgManager shared] subChannelMeta:channel.channelId] != nil;
    if (canHost || isTopic) {
        SwipeButton *topicBtn = [self swipeButton:LLang(@"话题") backgroundColor:[WKApp shared].config.themeColor animationNamed:stickAnimationNamed touchBlock:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[WKShudoOrgManager shared] presentTopicActionsForChannel:channel];
            });
        }];
        [btns insertObject:topicBtn atIndex:0];
    }
    return btns;
}

- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView leftSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

-(SwipeButton*) swipeButton:(NSString*)title backgroundColor:(UIColor*)backgroundColor animationNamed:(NSString*)animationNamed touchBlock:(void(^)(void))touchBlock {
    SwipeButton *spBtn = [SwipeButton createSwipeButtonWithTitle:title font:14.0f textColor:[UIColor whiteColor] backgroundColor:backgroundColor image:[self imageName:@"ConversationList/Index/PlaceHo"] touchBlock:touchBlock];
    
    LOTAnimationView *spAnimationView = [LOTAnimationView animationNamed:animationNamed inBundle:[WKApp.shared resourceBundle:@"WuKongBase"]];
    spAnimationView.loopAnimation = NO;
    spAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    [spBtn.imageView addSubview:spAnimationView];
    [spAnimationView play];
    
    return spBtn;
}


-(void) setChatPwdErrorCount:(NSInteger)count channel:(WKChannel*)channel{
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:[self chatPwdErrorKey:channel]];
}

-(NSInteger) getChatPwdErrorCount:(WKChannel*)channel {
    return [[NSUserDefaults standardUserDefaults] integerForKey:[self chatPwdErrorKey:channel]];
}
-(NSString*) chatPwdErrorKey:(WKChannel*)channel {
    return [NSString stringWithFormat:@"chatpwderror_%@_%@_%hhu",[WKApp shared].loginInfo.uid,channel.channelId,channel.channelType];
}

-(void) toConversation:(WKConversationWrapModel*)conversationModel {
    // 显示聊天UI
    [WKApp.shared pushConversation:conversationModel.channel];
}


//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSLog(@"commitEditingStyle--");
//    [self.conversationListVM removeConversationAtIndex:indexPath.row];
//    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
//}
//- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return @"删除";
//}
//
//- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __weak typeof(self) weakSelf = self;
//    UITableViewRowAction *action = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:LLang(@"删除") handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
//        WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
//        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"清空聊天记录") onClick:^{
//            WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
//            [[WKMessageManager shared] clearMessages:conversationModel.channel];
//        }]];
//        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"确认删除") onClick:^{
//            WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
//            [weakSelf.conversationListVM removeConversationAtIndex:indexPath.row];
//            [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
//            if(conversationModel) {
//                [[WKSDK shared].conversationManager deleteConversation:conversationModel.channel];
//            }
//        }]];
//        [sheet show];
//    }];
//    WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
//    UITableViewRowAction *action1 = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title: conversationModel.unreadCount>0?LLang(@"标为已读"):LLang(@"标为未读") handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
//            // 退出编辑模式
////        [self.tableView setEditing:NO animated:YES];
//        int unreadCount = conversationModel.unreadCount>0?0:1;
//        conversationModel.unreadCount = unreadCount;
//        [[WKConversationDB shared] setConversationUnreadCount:conversationModel.channel unread:unreadCount];
//        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section]] withRowAnimation:UITableViewRowAnimationRight];
//
//    }];
//
//    return @[action,action1];
//}

-(void) refreshTableNoSort {
    [self refreshHeader];
    [self rebuildVisibleConversationsAndReload];
}

-(void) refreshTable {
    [self.conversationListVM sortConversationList];
    [self refreshHeader];
    [self rebuildVisibleConversationsAndReload];
}

- (void)refreshVisibleConversationCells {
    NSArray<NSIndexPath *> *paths = self.tableView.indexPathsForVisibleRows;
    if (paths.count == 0) return;
    NSInteger count = (NSInteger)self.visibleConversations.count;
    for (NSIndexPath *ip in paths) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
        if (![cell isKindOfClass:[WKConversationListCell class]]) continue;
        if (ip.row >= count) continue;
        WKConversationWrapModel *model = [self visibleConversationAtIndex:ip.row];
        if (!model) continue;
        [(WKConversationListCell *)cell refreshWithModel:model];
    }
}

- (void)scheduleDebouncedConversationReload {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshTable) object:nil];
    [self performSelector:@selector(refreshTable) withObject:nil afterDelay:0.12];
}

-(void) refreshHeader {
    [self resetHeaderBottomEmptyBackgroundColor];
    [self applyTableHeaderView];
}

-(void) resetHeaderBottomEmptyBackgroundColor {
    if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
        [self.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[UIColor clearColor]];
        return;
    }
    if([self.conversationListVM hasConversationTop]) {
        [self.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.backgroundColor];
    }else{
        [self.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}
-(void) dealloc {
    NSLog(@"WKConversationListVC dealloc ....");
    [self removeDelegates];
}

@end
