//
//  WKSlashCommandSuggestView.m
//  WuKongBase
//

#import "WKSlashCommandSuggestView.h"
#import "WuKongBase.h"
#import "WKLiquidGlassHelper.h"

static const CGFloat kRowHeight = 48.0f;
static const CGFloat kMaxVisibleRows = 5.0f;
static const CGFloat kCorner = 14.0f;

@implementation WKSlashCommandItem
+(instancetype)cmd:(NSString *)cmd remark:(NSString *)remark robotID:(NSString *)robotID {
    WKSlashCommandItem *item = [WKSlashCommandItem new];
    item.cmd = cmd ?: @"";
    item.remark = remark ?: @"";
    item.robotID = robotID;
    return item;
}
@end

@interface WKSlashCommandSuggestCell : UITableViewCell
@property(nonatomic, strong) UILabel *cmdLbl;
@property(nonatomic, strong) UILabel *remarkLbl;
@end

@implementation WKSlashCommandSuggestCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        _cmdLbl = [[UILabel alloc] init];
        _cmdLbl.font = [[WKApp shared].config appFontOfSizeMedium:15.0f];
        _cmdLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_cmdLbl];
        _remarkLbl = [[UILabel alloc] init];
        _remarkLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
        _remarkLbl.textColor = [WKApp shared].config.tipColor;
        _remarkLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_remarkLbl];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat left = 14.0f;
    CGFloat rightPad = 14.0f;
    [self.cmdLbl sizeToFit];
    self.cmdLbl.lim_left = left;
    self.cmdLbl.lim_centerY_parent = self.contentView;
    CGFloat remarkLeft = self.cmdLbl.lim_right + 10.0f;
    self.remarkLbl.frame = CGRectMake(remarkLeft,
                                      0,
                                      MAX(0, self.contentView.lim_width - remarkLeft - rightPad),
                                      self.contentView.lim_height);
}
- (void)refresh:(WKSlashCommandItem *)item {
    self.cmdLbl.text = item.cmd;
    self.remarkLbl.text = item.remark;
    [self setNeedsLayout];
}
@end

@interface WKSlashCommandSuggestView () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray<WKSlashCommandItem *> *items;
@property(nonatomic, strong, nullable) UIVisualEffectView *glassView;
@end

@implementation WKSlashCommandSuggestView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
        self.layer.cornerRadius = kCorner;
        self.layer.masksToBounds = YES;
        UIColor *solid = [WKApp shared].config.cellBackgroundColor;
        self.glassView = [WKLiquidGlassHelper installInView:self
                                              cornerRadius:kCorner
                                               interactive:YES
                                                solidColor:solid];
        if (!self.glassView) {
            self.backgroundColor = solid;
        }
        [self addSubview:self.tableView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glassView.frame = self.bounds;
    if (self.glassView) {
        [self sendSubviewToBack:self.glassView];
    }
    self.tableView.frame = self.bounds;
}

- (void)reloadItems:(NSArray<WKSlashCommandItem *> *)items {
    self.items = items ?: @[];
    NSInteger rows = MIN((NSInteger)self.items.count, (NSInteger)kMaxVisibleRows);
    CGFloat h = rows * kRowHeight;
    self.lim_height = h;
    self.tableView.frame = self.bounds;
    self.glassView.frame = self.bounds;
    self.tableView.scrollEnabled = self.items.count > (NSInteger)kMaxVisibleRows;
    [self.tableView reloadData];
    [WKLiquidGlassHelper materializeEffectView:self.glassView interactive:YES animated:YES completion:nil];
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.rowHeight = kRowHeight;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 14, 0, 14);
        _tableView.backgroundColor = UIColor.clearColor;
        _tableView.tableFooterView = [UIView new];
        [_tableView registerClass:WKSlashCommandSuggestCell.class forCellReuseIdentifier:@"cell"];
    }
    return _tableView;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKSlashCommandSuggestCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    [cell refresh:self.items[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.onSelect) {
        self.onSelect(self.items[indexPath.row]);
    }
}

@end
