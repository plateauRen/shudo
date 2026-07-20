//
//  WKHermesTableCell.m
//  WuKongBase
//
//  Table grid lives inside messageContentView so long-press context extract shows it.
//  Only the "查看完整表格" button sits on contentView (above Texture), like Hermes cards.
//

#import "WKHermesTableCell.h"
#import "WKHermesTableContent.h"
#import "WKBubbleMessageDetailVC.h"
#import "WKTapLongTapOrDoubleTapGestureRecognizerEvent.h"
#import "WuKongBase.h"

static const CGFloat kTablePad = 10.0f;
static const CGFloat kTableCardW = 300.0f;
static const CGFloat kColMinW = 64.0f;
static const CGFloat kColMaxW = 140.0f;
static const CGFloat kRowH = 28.0f;
static const NSInteger kMaxVisibleRows = 30;
static const CGFloat kOpenBtnH = 32.0f;
static const CGFloat kHintH = 16.0f;

@interface WKHermesTableCell ()
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UILabel *captionLbl;
@property(nonatomic, strong) UILabel *hintLbl;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIView *gridView;
/// Open button host on contentView (outside Texture extract node).
@property(nonatomic, strong) UIView *buttonBox;
@property(nonatomic, strong) UIButton *openBtn;
@property(nonatomic, strong) NSArray<NSNumber *> *colWidths;
@property(nonatomic, assign) CGFloat gridContentW;
@property(nonatomic, assign) CGFloat openBtnTopInContent;
@end

@implementation WKHermesTableCell

+ (CGFloat)textHeight:(NSString *)text font:(UIFont *)font width:(CGFloat)width {
    if (!text.length) return 0;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];
    return ceil(rect.size.height);
}

+ (NSInteger)visibleRowCount:(WKHermesTableContent *)content {
    return MIN((NSInteger)content.rows.count, kMaxVisibleRows);
}

+ (CGFloat)measureWidth:(NSString *)text font:(UIFont *)font {
    if (!text.length) return kColMinW;
    CGSize sz = [text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, kRowH)
                                   options:NSStringDrawingUsesLineFragmentOrigin
                                attributes:@{NSFontAttributeName: font}
                                   context:nil].size;
    return ceil(sz.width) + 16.0f;
}

+ (NSArray<NSNumber *> *)columnWidthsForContent:(WKHermesTableContent *)content {
    NSArray *columns = content.columns ?: @[];
    NSArray *rows = content.rows ?: @[];
    NSInteger rowCount = [self visibleRowCount:content];
    UIFont *headerFont = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    UIFont *cellFont = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    for (NSInteger c = 0; c < (NSInteger)columns.count; c++) {
        NSDictionary *col = columns[c];
        if (![col isKindOfClass:[NSDictionary class]]) {
            [widths addObject:@(kColMinW)];
            continue;
        }
        NSString *label = [col[@"label"] isKindOfClass:[NSString class]] ? col[@"label"] : @"";
        NSString *colId = [col[@"id"] isKindOfClass:[NSString class]] ? col[@"id"] : @"";
        CGFloat w = [self measureWidth:label font:headerFont];
        for (NSInteger r = 0; r < rowCount; r++) {
            NSDictionary *row = rows[r];
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            id raw = colId.length ? row[colId] : nil;
            NSString *val = [raw isKindOfClass:[NSString class]] ? raw : ([raw description] ?: @"");
            w = MAX(w, [self measureWidth:val font:cellFont]);
        }
        [widths addObject:@(MIN(kColMaxW, MAX(kColMinW, w)))];
    }
    return widths;
}

+ (CGFloat)gridWidthForWidths:(NSArray<NSNumber *> *)widths {
    CGFloat total = 0;
    for (NSNumber *n in widths) {
        total += n.doubleValue;
    }
    return total;
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKHermesTableContent *content = (WKHermesTableContent *)model.content;
    CGFloat cardW = kTableCardW;
    CGFloat innerW = cardW - kTablePad * 2;
    CGFloat h = kTablePad;
    h += [self textHeight:content.title.length ? content.title : @"表格"
                     font:[UIFont boldSystemFontOfSize:15]
                    width:innerW];
    h += 4.0f;
    if (content.caption.length) {
        h += [self textHeight:content.caption font:[UIFont systemFontOfSize:12] width:innerW] + 4.0f;
    }
    NSInteger rows = [self visibleRowCount:content] + 1;
    h += rows * kRowH + 2.0f;
    h += kHintH + 2.0f;
    h += kOpenBtnH + 4.0f;
    h += kTablePad;
    return CGSizeMake(cardW, MAX(h, 96.0f));
}

- (void)initUI {
    [super initUI];
    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 8.0f;

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [UIFont boldSystemFontOfSize:15];
    self.titleLbl.numberOfLines = 2;
    self.titleLbl.userInteractionEnabled = NO;
    [self.messageContentView addSubview:self.titleLbl];

    self.captionLbl = [[UILabel alloc] init];
    self.captionLbl.font = [UIFont systemFontOfSize:12];
    self.captionLbl.numberOfLines = 2;
    self.captionLbl.userInteractionEnabled = NO;
    [self.messageContentView addSubview:self.captionLbl];

    // Grid inside bubble so ContextController extract preview includes the table.
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsHorizontalScrollIndicator = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceHorizontal = YES;
    self.scrollView.bounces = YES;
    self.scrollView.directionalLockEnabled = YES;
    self.scrollView.delaysContentTouches = NO;
    self.scrollView.canCancelContentTouches = YES;
    [self.messageContentView addSubview:self.scrollView];

    self.gridView = [[UIView alloc] init];
    self.gridView.userInteractionEnabled = NO;
    [self.scrollView addSubview:self.gridView];

    self.hintLbl = [[UILabel alloc] init];
    self.hintLbl.font = [UIFont systemFontOfSize:11];
    self.hintLbl.userInteractionEnabled = NO;
    [self.messageContentView addSubview:self.hintLbl];

    // Open button above Texture (same pattern as Hermes card buttons).
    self.buttonBox = [[UIView alloc] init];
    self.buttonBox.userInteractionEnabled = YES;
    self.buttonBox.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.buttonBox];

    self.openBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.openBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.openBtn setTitle:@"查看完整表格" forState:UIControlStateNormal];
    self.openBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.openBtn.exclusiveTouch = YES;
    [self.openBtn addTarget:self action:@selector(onOpenTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.openBtn addTarget:self action:@selector(onOpenTouchUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.openBtn addTarget:self action:@selector(openDetail) forControlEvents:UIControlEventTouchUpInside];
    [self.buttonBox addSubview:self.openBtn];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKHermesTableContent *content = (WKHermesTableContent *)model.content;

    // Keep Texture ContextGesture (long-press menu) ON; only disable the tap-wrap
    // that would fight the open button. setContentGesturesEnabled:NO would kill the menu.
    [self setContentGesturesEnabled:YES];
    [self setTapGestureWrapEnabled:NO];

    self.bubbleBackgroundView.userInteractionEnabled = YES;
    self.messageContentView.userInteractionEnabled = YES;
    self.scrollView.userInteractionEnabled = YES;

    self.messageContentView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.captionLbl.textColor = [WKApp shared].config.tipColor;
    self.hintLbl.textColor = [WKApp shared].config.tipColor;
    UIColor *theme = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
    [self.openBtn setTitleColor:theme forState:UIControlStateNormal];

    self.titleLbl.text = content.title.length ? content.title : @"表格";
    self.captionLbl.text = content.caption ?: @"";
    self.captionLbl.hidden = (content.caption.length == 0);

    if ([WKApp shared].config.style != WKSystemStyleDark) {
        self.trailingView.timeLbl.textColor = [WKApp shared].config.tipColor;
    }
    self.trailingView.userInteractionEnabled = NO;

    [self rebuildGrid:content];
    [self.contentView bringSubviewToFront:self.buttonBox];
}

- (UIColor *)colorForValue:(NSString *)value format:(NSString *)format defaultColor:(UIColor *)def {
    if (![format isEqualToString:@"pct_color"] || !value.length) {
        return def;
    }
    if ([value hasPrefix:@"+"] || [value hasPrefix:@"＋"]) {
        return [UIColor systemRedColor];
    }
    if ([value hasPrefix:@"-"] || [value hasPrefix:@"－"] || [value hasPrefix:@"−"]) {
        return [UIColor systemGreenColor];
    }
    return def;
}

- (void)rebuildGrid:(WKHermesTableContent *)content {
    for (UIView *v in self.gridView.subviews) {
        [v removeFromSuperview];
    }
    NSArray *columns = content.columns ?: @[];
    self.colWidths = [[self class] columnWidthsForContent:content];
    self.gridContentW = [[self class] gridWidthForWidths:self.colWidths];

    if (columns.count == 0 || self.colWidths.count == 0) {
        self.hintLbl.text = @"";
        self.scrollView.contentSize = CGSizeZero;
        return;
    }

    NSInteger colCount = columns.count;
    NSInteger rowCount = [[self class] visibleRowCount:content];
    CGFloat gridH = (rowCount + 1) * kRowH;

    UIColor *headerBg = [[WKApp shared].config.lineColor ?: [UIColor colorWithWhite:0.92 alpha:1]
                         colorWithAlphaComponent:0.85];
    UIColor *line = [WKApp shared].config.lineColor ?: [UIColor colorWithWhite:0.85 alpha:1];
    UIColor *textColor = [WKApp shared].config.messageRecvTextColor ?: [UIColor darkTextColor];
    UIColor *headerText = [WKApp shared].config.defaultTextColor ?: [UIColor blackColor];

    CGFloat x = 0;
    for (NSInteger c = 0; c < colCount; c++) {
        NSDictionary *col = columns[c];
        CGFloat colW = self.colWidths[c].doubleValue;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, 0, colW, kRowH)];
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        lbl.textColor = headerText;
        lbl.backgroundColor = headerBg;
        lbl.textAlignment = [self alignFrom:col[@"align"]];
        lbl.text = [col[@"label"] isKindOfClass:[NSString class]] ? col[@"label"] : @"";
        lbl.layer.borderWidth = 0.5;
        lbl.layer.borderColor = line.CGColor;
        [self.gridView addSubview:lbl];
        x += colW;
    }

    for (NSInteger r = 0; r < rowCount; r++) {
        NSDictionary *row = content.rows[r];
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        x = 0;
        for (NSInteger c = 0; c < colCount; c++) {
            NSDictionary *col = columns[c];
            NSString *colId = [col[@"id"] isKindOfClass:[NSString class]] ? col[@"id"] : @"";
            id raw = colId.length ? row[colId] : nil;
            NSString *val = [raw isKindOfClass:[NSString class]] ? raw : ([raw description] ?: @"");
            NSString *format = [col[@"format"] isKindOfClass:[NSString class]] ? col[@"format"] : @"text";
            CGFloat colW = self.colWidths[c].doubleValue;

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, (r + 1) * kRowH, colW, kRowH)];
            lbl.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
            lbl.textColor = [self colorForValue:val format:format defaultColor:textColor];
            lbl.textAlignment = [self alignFrom:col[@"align"]];
            lbl.text = val;
            lbl.layer.borderWidth = 0.5;
            lbl.layer.borderColor = line.CGColor;
            if (r % 2 == 1) {
                lbl.backgroundColor = [headerBg colorWithAlphaComponent:0.35];
            }
            [self.gridView addSubview:lbl];
            x += colW;
        }
    }

    self.gridView.frame = CGRectMake(0, 0, self.gridContentW, gridH);
    self.scrollView.contentSize = CGSizeMake(self.gridContentW, gridH);

    BOOL canScrollX = self.gridContentW > (kTableCardW - kTablePad * 2) + 1.0f;
    if (content.rows.count > kMaxVisibleRows) {
        self.hintLbl.text = canScrollX
            ? [NSString stringWithFormat:@"← 左右滑动 · 仅显示前 %ld 行", (long)kMaxVisibleRows]
            : [NSString stringWithFormat:@"仅显示前 %ld 行", (long)kMaxVisibleRows];
    } else {
        self.hintLbl.text = canScrollX ? @"← 左右滑动查看更多列" : @"";
    }
}

- (NSTextAlignment)alignFrom:(id)align {
    if (![align isKindOfClass:[NSString class]]) return NSTextAlignmentLeft;
    if ([align isEqualToString:@"right"]) return NSTextAlignmentRight;
    if ([align isEqualToString:@"center"]) return NSTextAlignmentCenter;
    return NSTextAlignmentLeft;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.messageModel) return;
    WKHermesTableContent *content = (WKHermesTableContent *)self.messageModel.content;

    CGFloat innerW = self.messageContentView.lim_width - kTablePad * 2;
    CGFloat y = kTablePad;

    self.titleLbl.frame = CGRectMake(kTablePad, y, innerW, 0);
    [self.titleLbl sizeToFit];
    self.titleLbl.lim_width = innerW;
    y = self.titleLbl.lim_bottom + 4.0f;

    if (!self.captionLbl.hidden) {
        self.captionLbl.frame = CGRectMake(kTablePad, y, innerW, 0);
        [self.captionLbl sizeToFit];
        self.captionLbl.lim_width = innerW;
        y = self.captionLbl.lim_bottom + 4.0f;
    }

    NSInteger rows = [[self class] visibleRowCount:content] + 1;
    CGFloat gridH = rows * kRowH;
    self.scrollView.frame = CGRectMake(kTablePad, y, innerW, gridH);
    y = self.scrollView.lim_bottom + 4.0f;

    if (self.hintLbl.text.length) {
        self.hintLbl.hidden = NO;
        self.hintLbl.frame = CGRectMake(kTablePad, y, innerW, kHintH);
        y = self.hintLbl.lim_bottom + 2.0f;
    } else {
        self.hintLbl.hidden = YES;
    }

    self.openBtnTopInContent = y;
    // Reserve space in-bubble; real button overlays from contentView.
    y += kOpenBtnH;

    CGRect contentInCell = [self.messageContentView convertRect:self.messageContentView.bounds
                                                         toView:self.contentView];
    CGFloat boxX = contentInCell.origin.x + kTablePad;
    CGFloat boxY = contentInCell.origin.y + self.openBtnTopInContent;
    CGFloat boxW = MAX(0, contentInCell.size.width - kTablePad * 2);
    self.buttonBox.frame = CGRectMake(boxX, boxY, boxW, kOpenBtnH);
    self.openBtn.frame = self.buttonBox.bounds;
    [self.contentView bringSubviewToFront:self.buttonBox];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.buttonBox && !self.buttonBox.hidden && self.buttonBox.userInteractionEnabled) {
        CGPoint p = [self convertPoint:point toView:self.buttonBox];
        if ([self.buttonBox pointInside:p withEvent:event]) {
            UIView *hit = [self.buttonBox hitTest:p withEvent:event];
            if (hit) return hit;
        }
    }
    return [super hitTest:point withEvent:event];
}

- (void)onOpenTouchDown {
    self.openBtn.alpha = 0.55;
}

- (void)onOpenTouchUp {
    self.openBtn.alpha = 1.0;
}

- (void)openDetail {
    self.openBtn.alpha = 1.0;
    if (![self.messageModel.content isKindOfClass:[WKHermesTableContent class]]) {
        return;
    }
    WKHermesTableContent *table = (WKHermesTableContent *)self.messageModel.content;
    WKBubbleMessageDetailVC *vc = [WKBubbleMessageDetailVC detailWithTableContent:table];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (BOOL)respondContentSingleTap {
    return NO;
}

- (WKTapLongTapOrDoubleTapGestureRecognizerEvent *)tapActionAtPoint:(CGPoint)point {
    // Fail cell tap-wrap; ContextGesture still handles long-press menu.
    return [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:WKTapLongTapOrDoubleTapGestureRecognizerActionFail];
}

+ (BOOL)hiddenBubble {
    return YES;
}

@end
