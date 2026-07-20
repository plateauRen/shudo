//
//  WKCountrySelectVC.m
//  WuKongLogin
//
//  Created by tt on 2020/6/8.
// 国家区号选择器
#import "NSString+PinYin.h"
#import "WKCountrySelectVC.h"

static const CGFloat kSearchHeight = 36.0f;
static const CGFloat kSearchVerticalPad = 10.0f;
static const CGFloat kSearchHorizontalPad = 16.0f;

@interface WKCountrySelectVC () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray *data;
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, strong) UIView *searchContainer;
@property(nonatomic, strong) UIButton *cancelBtn;
@property(nonatomic, copy) NSString *searchKeyword;
@property(nonatomic, copy) NSArray<NSString *> *indexTitles;

@end

@implementation WKCountrySelectVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LLang(@"选择国家和地区");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    // Modal is often wrapped in a plain UINavigationController — hide the system
    // bar so only WKBaseVC's custom navigationBar is visible (fixes island overlap).
    self.navigationController.navigationBarHidden = YES;
    [self.navigationBar setShowBackButton:NO];
    [self.navigationBar addSubview:self.cancelBtn];
    [self.navigationBar bringSubviewToFront:self.cancelBtn];

    [self.view addSubview:self.tableView];
    [self.view bringSubviewToFront:self.navigationBar];
    [self refreshData];
    [self requestCountriesAndRefreshData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutChrome];
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if (type == WKViewConfigChangeTypeStyle || type == WKViewConfigChangeTypeBrandTheme) {
        self.view.backgroundColor = [WKApp shared].config.backgroundColor;
        self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
        self.tableView.sectionIndexColor = [WKApp shared].config.themeColor;
        self.searchContainer.backgroundColor = [WKApp shared].config.backgroundColor;
        self.searchBar.barTintColor = [WKApp shared].config.cellBackgroundColor;
        if (@available(iOS 13.0, *)) {
            self.searchBar.searchTextField.backgroundColor = [WKApp shared].config.cellBackgroundColor;
            self.searchBar.searchTextField.textColor = [WKApp shared].config.defaultTextColor;
        }
        [self.cancelBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [self.tableView reloadData];
    }
}

#pragma mark - Layout

- (void)layoutChrome {
    CGFloat statusHeight = 0;
    if (@available(iOS 13.0, *)) {
        UIWindow *window = self.view.window ?: UIApplication.sharedApplication.windows.firstObject;
        statusHeight = window.windowScene.statusBarManager.statusBarFrame.size.height;
    }
    if (statusHeight < 1.0f) {
        statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    }

    CGFloat navContentH = self.navigationBar.lim_height - statusHeight;
    self.cancelBtn.lim_size = CGSizeMake(56.0f, 32.0f);
    self.cancelBtn.lim_left = 12.0f;
    self.cancelBtn.lim_top = statusHeight + (navContentH - self.cancelBtn.lim_height) / 2.0f;
    [self.navigationBar bringSubviewToFront:self.cancelBtn];

    CGRect visible = [self visibleRect];
    self.tableView.frame = visible;

    CGFloat headerH = kSearchHeight + kSearchVerticalPad * 2.0f;
    if (!self.searchContainer || fabs(self.searchContainer.lim_width - visible.size.width) > 0.5f ||
        fabs(self.searchContainer.lim_height - headerH) > 0.5f) {
        self.searchContainer.frame = CGRectMake(0, 0, visible.size.width, headerH);
        self.searchBar.frame = CGRectMake(kSearchHorizontalPad,
                                          kSearchVerticalPad,
                                          visible.size.width - kSearchHorizontalPad * 2.0f,
                                          kSearchHeight);
        self.tableView.tableHeaderView = self.searchContainer;
    }
}

#pragma mark - Data

- (void)requestCountriesAndRefreshData {
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:@"common/countries" parameters:nil].then(^(NSArray *data) {
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"countriesList"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [weakSelf refreshData];
    }).catch(^(NSError *error) {
        WKLogError(@"请求国家区号失败！-> %@", error);
    });
}

- (void)refreshData {
    NSArray *array = [[NSUserDefaults standardUserDefaults] objectForKey:@"countriesList"];
    NSMutableArray *filterArray = [[NSMutableArray alloc] init];
    NSString *keyword = [self.searchKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (keyword.length > 0) {
        for (NSDictionary *data in array) {
            NSString *name = data[@"name"] ?: @"";
            NSString *code = data[@"code"] ?: @"";
            if ([name containsString:keyword] || [code containsString:keyword]) {
                [filterArray addObject:data];
            }
        }
    } else if (array) {
        [filterArray addObjectsFromArray:array];
    }
    NSArray *indexArray = [filterArray arrayWithPinYinFirstLetterFormat];
    self.data = [NSMutableArray arrayWithArray:indexArray];

    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSDictionary *dict in self.data) {
        NSString *letter = dict[@"firstLetter"];
        if (letter.length) {
            [titles addObject:letter];
        }
    }
    self.indexTitles = titles;

    [self.tableView reloadData];
}

#pragma mark - Views

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 28);
        _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
        _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        _tableView.sectionIndexColor = [WKApp shared].config.themeColor;
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.sectionIndexTrackingBackgroundColor = [UIColor clearColor];
        _tableView.rowHeight = 48.0f;
        _tableView.estimatedSectionHeaderHeight = 28.0f;
        if (@available(iOS 15.0, *)) {
            _tableView.sectionHeaderTopPadding = 0;
        }
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cellID"];
    }
    return _tableView;
}

- (UIView *)searchContainer {
    if (!_searchContainer) {
        _searchContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.lim_width, kSearchHeight + kSearchVerticalPad * 2.0f)];
        _searchContainer.backgroundColor = [WKApp shared].config.backgroundColor;
        [_searchContainer addSubview:self.searchBar];
    }
    return _searchContainer;
}

- (UISearchBar *)searchBar {
    if (!_searchBar) {
        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
        _searchBar.placeholder = LLang(@"搜索");
        _searchBar.searchBarStyle = UISearchBarStyleMinimal;
        _searchBar.delegate = self;
        _searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _searchBar.returnKeyType = UIReturnKeyDone;
        if (@available(iOS 13.0, *)) {
            _searchBar.searchTextField.backgroundColor = [WKApp shared].config.cellBackgroundColor;
            _searchBar.searchTextField.textColor = [WKApp shared].config.defaultTextColor;
            _searchBar.searchTextField.layer.cornerRadius = 10.0f;
            _searchBar.searchTextField.clipsToBounds = YES;
        }
    }
    return _searchBar;
}

- (UIButton *)cancelBtn {
    if (!_cancelBtn) {
        _cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
        _cancelBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
        [_cancelBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        _cancelBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_cancelBtn addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cancelBtn;
}

#pragma mark - UITableView

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.view endEditing:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cellID" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    cell.textLabel.textColor = [WKApp shared].config.defaultTextColor;
    cell.textLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
    cell.accessoryType = UITableViewCellAccessoryNone;

    NSDictionary *dict = self.data[indexPath.section];
    NSArray *array = dict[@"content"];
    NSDictionary *item = array[indexPath.row];
    NSString *code = [item[@"code"] description] ?: @"";
    if (code.length >= 2) {
        code = [code stringByReplacingCharactersInRange:NSMakeRange(0, 2) withString:@"+"];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)", item[@"name"] ?: @"", code];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.data.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *dict = self.data[section];
    NSArray *array = dict[@"content"];
    return array.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 28.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    // Sticky headers span the full table width and would paint over the section
    // index; keep the index strip clear and only fill the content area.
    CGFloat width = CGRectGetWidth(tableView.bounds);
    CGFloat indexStrip = 28.0f;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 28.0f)];
    header.backgroundColor = [UIColor clearColor];
    header.clipsToBounds = YES;

    UIView *fill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MAX(0, width - indexStrip), 28.0f)];
    fill.backgroundColor = [WKApp shared].config.backgroundColor;
    fill.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [header addSubview:fill];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 0, 80.0f, 28.0f)];
    titleLabel.textColor = [WKApp shared].config.tipColor ?: [WKApp shared].config.defaultTextColor;
    titleLabel.font = [[WKApp shared].config appFontOfSizeSemibold:13.0f]
                          ?: [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    titleLabel.text = self.data[section][@"firstLetter"];
    [fill addSubview:titleLabel];
    return header;
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    // Only letters that exist in data — keeps left headers and right index 1:1.
    return self.indexTitles;
}

- (NSInteger)tableView:(UITableView *)tableView
    sectionForSectionIndexTitle:(NSString *)title
                        atIndex:(NSInteger)index {
    // Map by letter content, not UILocalizedIndexedCollation (which assumes A–Z).
    if (index >= 0 && index < (NSInteger)self.indexTitles.count) {
        NSString *letter = self.indexTitles[index];
        for (NSInteger i = 0; i < (NSInteger)self.data.count; i++) {
            if ([self.data[i][@"firstLetter"] isEqualToString:letter]) {
                return i;
            }
        }
        return index;
    }
    for (NSInteger i = 0; i < (NSInteger)self.data.count; i++) {
        if ([self.data[i][@"firstLetter"] isEqualToString:title]) {
            return i;
        }
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.onFinished) {
        return;
    }
    NSDictionary *dict = self.data[indexPath.section];
    NSArray *array = dict[@"content"];
    NSDictionary *data = array[indexPath.row];
    void (^finished)(NSDictionary *) = self.onFinished;
    [self dismissViewControllerAnimated:YES completion:^{
        if (finished) {
            finished(data);
        }
    }];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchKeyword = searchText;
    [self refreshData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Actions

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backPressed {
    [self closePressed];
}

@end
