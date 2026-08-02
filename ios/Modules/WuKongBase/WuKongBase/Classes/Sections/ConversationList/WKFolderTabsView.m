//
//  WKFolderTabsView.m
//  WuKongBase
//

#import "WKFolderTabsView.h"
#import "WKShudoOrgManager.h"
#import "WKApp.h"
#import <objc/runtime.h>

static const char kFolderIdKey;

@interface WKFolderTabsView ()
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIButton *moreBtn;
@property(nonatomic, strong) UIView *bottomLine;
@end

@implementation WKFolderTabsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _selectedFolderId = @"";
        [self setupUI];
        [self reloadFolders];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    [self addSubview:self.scrollView];
    [self addSubview:self.moreBtn];
    [self addSubview:self.bottomLine];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0f);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat moreW = 36.0f;
    self.moreBtn.frame = CGRectMake(self.bounds.size.width - moreW - 4.0f, 0, moreW, self.bounds.size.height);
    self.scrollView.frame = CGRectMake(0, 0, self.moreBtn.frame.origin.x - 4.0f, self.bounds.size.height);
    self.bottomLine.frame = CGRectMake(0, self.bounds.size.height - (1.0f / UIScreen.mainScreen.scale),
                                       self.bounds.size.width, 1.0f / UIScreen.mainScreen.scale);
}

- (void)setSelectedFolderId:(NSString *)selectedFolderId {
    _selectedFolderId = selectedFolderId ?: @"";
    [self reloadFolders];
}

- (void)reloadFolders {
    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSMutableArray<NSDictionary *> *tabs = [NSMutableArray array];
    [tabs addObject:@{@"folder_id": @"", @"name": @"全部"}];
    for (NSDictionary *f in [WKShudoOrgManager shared].folders) {
        if ([f isKindOfClass:NSDictionary.class]) [tabs addObject:f];
    }

    CGFloat x = 10.0f;
    CGFloat h = 28.0f;
    CGFloat y = (44.0f - h) / 2.0f;
    UIColor *theme = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:0x0E/255.0 green:0x74/255.0 blue:0x90/255.0 alpha:1];
    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    UIColor *secondary = dark ? [UIColor colorWithWhite:0.7 alpha:1] : [UIColor colorWithWhite:0.45 alpha:1];

    for (NSDictionary *tab in tabs) {
        NSString *fid = tab[@"folder_id"] ?: @"";
        NSString *name = tab[@"name"] ?: @"";
        BOOL active = [fid isEqualToString:self.selectedFolderId ?: @""];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:active ? UIFontWeightSemibold : UIFontWeightRegular];
        [btn setTitleColor:active ? theme : secondary forState:UIControlStateNormal];
        btn.backgroundColor = active
            ? [theme colorWithAlphaComponent:dark ? 0.22 : 0.12]
            : [UIColor clearColor];
        btn.layer.cornerRadius = h / 2.0f;
        btn.clipsToBounds = YES;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        [btn sizeToFit];
        CGFloat w = MAX(48.0f, btn.bounds.size.width);
        btn.frame = CGRectMake(x, y, w, h);
        objc_setAssociatedObject(btn, &kFolderIdKey, fid, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(onTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:btn];
        x = CGRectGetMaxX(btn.frame) + 6.0f;
    }
    self.scrollView.contentSize = CGSizeMake(x + 8.0f, 44.0f);
    [self setNeedsLayout];
}

- (void)onTab:(UIButton *)sender {
    NSString *fid = objc_getAssociatedObject(sender, &kFolderIdKey) ?: @"";
    _selectedFolderId = fid;
    [self reloadFolders];
    if (self.onSelectFolder) self.onSelectFolder(fid);
}

- (void)onMoreTap {
    if (self.onMore) self.onMore();
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
    }
    return _scrollView;
}

- (UIButton *)moreBtn {
    if (!_moreBtn) {
        _moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            [_moreBtn setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
        } else {
            [_moreBtn setTitle:@"…" forState:UIControlStateNormal];
        }
        _moreBtn.tintColor = [UIColor colorWithWhite:0.45 alpha:1];
        [_moreBtn addTarget:self action:@selector(onMoreTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return _moreBtn;
}

- (UIView *)bottomLine {
    if (!_bottomLine) {
        _bottomLine = [[UIView alloc] init];
        _bottomLine.backgroundColor = [UIColor colorWithWhite:0 alpha:0.08];
    }
    return _bottomLine;
}

@end
