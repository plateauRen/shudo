//
//  WKFolderSettingVC.m
//  WuKongBase
//

#import "WKFolderSettingVC.h"
#import "WKShudoOrgManager.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "UIView+WKCommon.h"

@interface WKFolderSettingVC () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UITextField *nameField;
@property(nonatomic, copy) NSArray<NSDictionary *> *folders;
@end

@implementation WKFolderSettingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"管理分组";
    [self.view addSubview:self.tableView];
    [self reload];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

- (void)reload {
    [[WKShudoOrgManager shared] refreshFolders:^(NSError *error) {
        self.folders = [WKShudoOrgManager shared].folders ?: @[];
        [self.tableView reloadData];
        if (error) {
            [self.view showHUDWithHide:error.localizedDescription ?: @"加载失败"];
        }
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.folders.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"新建分组";
    return @"已有分组（「话题」为系统分组，不可删除）";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"create"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"create"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(16, 8, WKScreenWidth - 120, 36)];
            tf.placeholder = @"新分组名称";
            tf.borderStyle = UITextBorderStyleRoundedRect;
            tf.clearButtonMode = UITextFieldViewModeWhileEditing;
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"folder"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"folder"];
    }
    NSDictionary *f = self.folders[indexPath.row];
    NSString *name = f[@"name"] ?: @"";
    NSArray *items = f[@"items"] ?: @[];
    cell.textLabel.text = name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu 个会话", (unsigned long)items.count];
    BOOL isTopics = [name isEqualToString:[WKShudoOrgManager topicsFolderName]];
    cell.accessoryType = isTopics ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;
    NSDictionary *f = self.folders[indexPath.row];
    NSString *name = f[@"name"] ?: @"";
    if ([name isEqualToString:[WKShudoOrgManager topicsFolderName]]) {
        [self.view showHUDWithHide:@"系统「话题」分组不可修改"];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:name message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"重命名" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf renameFolder:f];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[WKShudoOrgManager shared] deleteFolder:f[@"folder_id"] complete:^(NSError *error) {
            if (error) {
                [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"删除失败"];
            } else {
                [weakSelf reload];
            }
        }];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)renameFolder:(NSDictionary *)folder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名分组" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = folder[@"name"] ?: @"";
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *n = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!n.length) return;
        [[WKShudoOrgManager shared] renameFolder:folder[@"folder_id"] name:n complete:^(NSError *error) {
            if (error) {
                [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"重命名失败"];
            } else {
                [weakSelf reload];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onCreate {
    NSString *n = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!n.length) {
        [self.view showHUDWithHide:@"请输入名称"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[WKShudoOrgManager shared] createFolder:n complete:^(NSDictionary *folder, NSError *error) {
        if (error) {
            [weakSelf.view showHUDWithHide:error.localizedDescription ?: @"创建失败"];
        } else {
            weakSelf.nameField.text = @"";
            [weakSelf.view showHUDWithHide:@"已创建分组"];
            [weakSelf reload];
        }
    }];
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
