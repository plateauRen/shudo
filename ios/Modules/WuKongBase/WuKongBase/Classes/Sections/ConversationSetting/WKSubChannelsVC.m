//
//  WKSubChannelsVC.m
//  WuKongBase
//

#import "WKSubChannelsVC.h"
#import "WKShudoOrgManager.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "UIView+WKCommon.h"

@interface WKSubChannelsVC () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UITextField *nameField;
@property(nonatomic, copy) NSArray<NSDictionary *> *list;
@property(nonatomic, assign) BOOL showArchived;
@end

@implementation WKSubChannelsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"话题";
    self.list = @[];
    [self.view addSubview:self.tableView];
    UIBarButtonItem *archiveBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"显示归档"
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(toggleArchived)];
    if ([self isDmParent]) {
        self.navigationItem.rightBarButtonItems = @[archiveBtn];
    } else {
        UIBarButtonItem *syncBtn = [[UIBarButtonItem alloc]
            initWithTitle:@"同步成员"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(onSyncMembers)];
        self.navigationItem.rightBarButtonItems = @[archiveBtn, syncBtn];
    }
    [self reload];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

- (void)toggleArchived {
    self.showArchived = !self.showArchived;
    UIBarButtonItem *archiveBtn = self.navigationItem.rightBarButtonItems.firstObject;
    archiveBtn.title = self.showArchived ? @"隐藏归档" : @"显示归档";
    [self reload];
}

- (NSString *)parentKey {
    return [[WKShudoOrgManager shared] parentKeyForChannel:self.parentChannel fromUid:nil];
}

- (BOOL)isDmParent {
    return [[self parentKey] hasPrefix:@"dm:"];
}

- (void)onSyncMembers {
    if ([self isDmParent]) {
        [self.view showHUDWithHide:@"私聊话题无需同步成员"];
        return;
    }
    NSString *parent = [self parentKey];
    if (!parent.length) return;
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    [[WKShudoOrgManager shared] syncSubChannelMembers:parent complete:^(NSError *error) {
        [weakSelf.view hideHud];
        if (error) {
            [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"同步失败"];
        } else {
            [weakSelf.view showHUDWithHide:@"已同步父群成员到话题"];
        }
    }];
}

- (void)reload {
    NSString *parent = [self parentKey];
    if (!parent.length) return;
    __weak typeof(self) weakSelf = self;
    [[WKShudoOrgManager shared] listSubChannels:parent
                               includeArchived:self.showArchived
                                      complete:^(NSArray *list, NSError *error) {
        if (error) {
            [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"加载失败"];
        }
        weakSelf.list = [list isKindOfClass:NSArray.class] ? list : @[];
        [weakSelf.tableView reloadData];
    }];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : MAX((NSInteger)self.list.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [self isDmParent] ? @"新建话题（与对方）" : @"新建话题（自动加入父群全员）";
    }
    return self.showArchived ? @"全部话题（含归档）" : @"活跃话题";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"改名 / 归档不会解散群；删除将解散话题群且不可恢复。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"create"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"create"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(16, 8, WKScreenWidth - 120, 36)];
            tf.placeholder = @"话题名称，如 开发";
            tf.borderStyle = UITextBorderStyleRoundedRect;
            tf.clearButtonMode = UITextFieldViewModeWhileEditing;
            tf.returnKeyType = UIReturnKeyDone;
            [tf addTarget:self action:@selector(onCreate) forControlEvents:UIControlEventEditingDidEndOnExit];
            [cell.contentView addSubview:tf];
            self.nameField = tf;
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            [btn setTitle:@"创建" forState:UIControlStateNormal];
            btn.frame = CGRectMake(WKScreenWidth - 88, 10, 72, 32);
            [btn addTarget:self action:@selector(onCreate) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:btn];
        }
        return cell;
    }

    if (!self.list.count) {
        UITableViewCell *empty = [tableView dequeueReusableCellWithIdentifier:@"empty"];
        if (!empty) {
            empty = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"empty"];
            empty.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                empty.textLabel.textColor = [UIColor secondaryLabelColor];
            } else {
                empty.textLabel.textColor = [UIColor grayColor];
            }
        }
        empty.textLabel.text = self.showArchived ? @"暂无话题" : @"暂无活跃话题";
        return empty;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"item"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"item"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSDictionary *s = self.list[indexPath.row];
    NSString *title = s[@"title"] ?: @"";
    BOOL archived = [s[@"archived"] integerValue] != 0;
    cell.textLabel.text = [NSString stringWithFormat:@"#%@", title];
    if (@available(iOS 13.0, *)) {
        cell.textLabel.textColor = archived ? [UIColor secondaryLabelColor] : [UIColor labelColor];
    } else {
        cell.textLabel.textColor = archived ? [UIColor grayColor] : [UIColor blackColor];
    }
    cell.detailTextLabel.text = archived ? @"已归档 · 点按管理" : @"点按打开 · 左滑管理";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1 || !self.list.count) return;
    NSDictionary *s = self.list[indexPath.row];
    BOOL archived = [s[@"archived"] integerValue] != 0;
    if (archived) {
        [self presentManageSheet:s];
        return;
    }
    NSString *subNo = s[@"sub_group_no"] ?: @"";
    if (!subNo.length) return;
    [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:subNo channelType:WK_GROUP]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
    contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                        point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (indexPath.section != 1 || !self.list.count) return nil;
    NSDictionary *s = self.list[indexPath.row];
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        return [weakSelf manageMenuFor:s];
    }];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1 || !self.list.count) return nil;
    NSDictionary *s = self.list[indexPath.row];
    BOOL archived = [s[@"archived"] integerValue] != 0;
    __weak typeof(self) weakSelf = self;
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"改名"
                                                                       handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf renameItem:s];
        completionHandler(YES);
    }];
    UIContextualAction *archive = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:(archived ? @"恢复" : @"归档")
                                                                        handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf setArchived:!archived forItem:s];
        completionHandler(YES);
    }];
    if (@available(iOS 13.0, *)) {
        archive.backgroundColor = [UIColor systemOrangeColor];
    } else {
        archive.backgroundColor = [UIColor orangeColor];
    }
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:@"删除"
                                                                    handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf confirmDelete:s];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del, archive, rename]];
}

#pragma mark - Actions

- (void)onCreate {
    NSString *n = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    n = [n stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
    if (!n.length) {
        [self.view showHUDWithHide:@"请输入名称"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    void (^onDone)(NSDictionary *, NSError *) = ^(NSDictionary *info, NSError *error) {
        [weakSelf.view hideHud];
        if (error) {
            [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"创建失败"];
            return;
        }
        weakSelf.nameField.text = @"";
        [weakSelf.view showHUDWithHide:@"已创建话题"];
        [weakSelf reload];
        NSString *subNo = info[@"sub_group_no"];
        if (subNo.length) {
            [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:subNo channelType:WK_GROUP]];
        }
    };
    if ([self isDmParent]) {
        NSString *peer = [[WKShudoOrgManager shared] resolvePersonPeerUid:self.parentChannel.channelId fromUid:nil];
        if (!peer.length) peer = self.parentChannel.channelId ?: @"";
        [[WKShudoOrgManager shared] createTopicFromPerson:peer
                                                    title:n
                                                  fromUid:nil
                                              seedPayload:nil
                                              seedFromUid:nil
                                                 complete:onDone];
    } else {
        NSString *parent = [self parentKey];
        [[WKShudoOrgManager shared] createSubChannel:n
                                            inParent:parent
                                            complete:onDone];
    }
}

- (void)presentManageSheet:(NSDictionary *)s {
    NSString *title = s[@"title"] ?: @"";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"#%@", title]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    BOOL archived = [s[@"archived"] integerValue] != 0;
    if (!archived) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"打开会话" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *subNo = s[@"sub_group_no"] ?: @"";
            if (subNo.length) {
                [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:subNo channelType:WK_GROUP]];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"改名" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf renameItem:s];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(archived ? @"取消归档" : @"归档")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf setArchived:!archived forItem:s];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [weakSelf confirmDelete:s];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (UIMenu *)manageMenuFor:(NSDictionary *)s API_AVAILABLE(ios(13.0)) {
    __weak typeof(self) weakSelf = self;
    BOOL archived = [s[@"archived"] integerValue] != 0;
    NSMutableArray *actions = [NSMutableArray array];
    if (!archived) {
        [actions addObject:[UIAction actionWithTitle:@"打开会话" image:nil identifier:nil handler:^(__kindof UIAction *action) {
            NSString *subNo = s[@"sub_group_no"] ?: @"";
            if (subNo.length) {
                [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:subNo channelType:WK_GROUP]];
            }
        }]];
    }
    [actions addObject:[UIAction actionWithTitle:@"改名" image:nil identifier:nil handler:^(__kindof UIAction *action) {
        [weakSelf renameItem:s];
    }]];
    [actions addObject:[UIAction actionWithTitle:(archived ? @"取消归档" : @"归档") image:nil identifier:nil handler:^(__kindof UIAction *action) {
        [weakSelf setArchived:!archived forItem:s];
    }]];
    UIAction *del = [UIAction actionWithTitle:@"删除" image:nil identifier:nil handler:^(__kindof UIAction *action) {
        [weakSelf confirmDelete:s];
    }];
    del.attributes = UIMenuElementAttributesDestructive;
    [actions addObject:del];
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (void)renameItem:(NSDictionary *)s {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"改名" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = s[@"title"] ?: @"";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *n = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        n = [n stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
        if (!n.length) return;
        NSString *subNo = s[@"sub_group_no"] ?: @"";
        [[WKShudoOrgManager shared] renameSubChannel:subNo title:n complete:^(NSDictionary *info, NSError *error) {
            if (error) {
                [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"改名失败"];
            } else {
                [weakSelf.view showHUDWithHide:@"已改名"];
                [weakSelf reload];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setArchived:(BOOL)archived forItem:(NSDictionary *)s {
    NSString *subNo = s[@"sub_group_no"] ?: @"";
    NSString *title = s[@"title"] ?: @"";
    NSString *msg = archived
        ? [NSString stringWithFormat:@"「#%@」将从列表与「话题」分组隐藏，会话记录保留。", title]
        : [NSString stringWithFormat:@"恢复「#%@」到活跃列表。", title];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(archived ? @"归档话题？" : @"取消归档？")
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:(archived ? @"归档" : @"恢复") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[WKShudoOrgManager shared] setSubChannel:subNo archived:archived complete:^(NSDictionary *info, NSError *error) {
            if (error) {
                [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"操作失败"];
            } else {
                [weakSelf.view showHUDWithHide:(archived ? @"已归档" : @"已恢复")];
                [weakSelf reload];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmDelete:(NSDictionary *)s {
    NSString *subNo = s[@"sub_group_no"] ?: @"";
    NSString *title = s[@"title"] ?: @"";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除话题？"
                                                                   message:[NSString stringWithFormat:@"将删除「#%@」并解散该群。此操作不可恢复。", title]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[WKShudoOrgManager shared] deleteSubChannel:subNo disband:YES complete:^(NSError *error) {
            if (error) {
                [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"删除失败"];
            } else {
                [weakSelf.view showHUDWithHide:@"已删除"];
                [weakSelf reload];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UITableView *)tableView {
    if (!_tableView) {
        UITableViewStyle style = UITableViewStyleGrouped;
        if (@available(iOS 13.0, *)) {
            style = UITableViewStyleInsetGrouped;
        }
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.rowHeight = 52;
    }
    return _tableView;
}

@end
