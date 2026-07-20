//
//  WKBubbleMessageDetailVC.m
//  WuKongBase
//

#import "WKBubbleMessageDetailVC.h"
#import "WuKongBase.h"

static const CGFloat kPad = 12.0f;
static const CGFloat kBubblePad = 14.0f;
static const CGFloat kRowH = 34.0f;
static const CGFloat kColMinW = 72.0f;
static const CGFloat kColMaxW = 200.0f;
static const NSInteger kMaxRows = 200;

@interface WKBubbleMessageDetailVC () <UITextViewDelegate>
@property(nonatomic, strong) UIScrollView *pageScroll;
@property(nonatomic, strong) UIView *bubbleView;
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UILabel *captionLbl;
@property(nonatomic, strong) UIScrollView *tableScroll;
@property(nonatomic, strong) UIView *gridView;
@property(nonatomic, strong) UILabel *selectHintLbl;
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, assign) CGFloat gridW;
@property(nonatomic, assign) CGFloat gridH;
@end

@implementation WKBubbleMessageDetailVC

+ (instancetype)detailWithTableContent:(WKHermesTableContent *)tableContent {
    WKBubbleMessageDetailVC *vc = [WKBubbleMessageDetailVC new];
    vc.tableContent = tableContent;
    vc.navTitle = tableContent.title.length ? tableContent.title : @"表格";
    vc.selectableText = [self plainTextFromTableContent:tableContent];
    return vc;
}

+ (instancetype)detailWithTitle:(NSString *)title selectableText:(NSString *)text {
    WKBubbleMessageDetailVC *vc = [WKBubbleMessageDetailVC new];
    vc.navTitle = title.length ? title : @"消息";
    vc.selectableText = text ?: @"";
    return vc;
}

+ (NSString *)plainTextFromTableContent:(WKHermesTableContent *)content {
    if (!content) return @"";
    NSMutableString *out = [NSMutableString string];
    if (content.title.length) {
        [out appendString:content.title];
        [out appendString:@"\n"];
    }
    if (content.caption.length) {
        [out appendString:content.caption];
        [out appendString:@"\n"];
    }
    if (out.length) {
        [out appendString:@"\n"];
    }

    NSArray *columns = content.columns ?: @[];
    NSArray *rows = content.rows ?: @[];
    if (columns.count > 0) {
        NSMutableArray *headers = [NSMutableArray array];
        for (NSDictionary *col in columns) {
            if (![col isKindOfClass:[NSDictionary class]]) continue;
            NSString *label = [col[@"label"] isKindOfClass:[NSString class]] ? col[@"label"] : @"";
            [headers addObject:label.length ? label : (col[@"id"] ?: @"")];
        }
        [out appendString:[headers componentsJoinedByString:@"\t"]];
        [out appendString:@"\n"];
        NSInteger limit = MIN((NSInteger)rows.count, kMaxRows);
        for (NSInteger r = 0; r < limit; r++) {
            NSDictionary *row = rows[r];
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            NSMutableArray *cells = [NSMutableArray array];
            for (NSDictionary *col in columns) {
                if (![col isKindOfClass:[NSDictionary class]]) continue;
                NSString *colId = [col[@"id"] isKindOfClass:[NSString class]] ? col[@"id"] : @"";
                id raw = colId.length ? row[colId] : nil;
                NSString *val = [raw isKindOfClass:[NSString class]] ? raw : ([raw description] ?: @"");
                [cells addObject:val];
            }
            [out appendString:[cells componentsJoinedByString:@"\t"]];
            [out appendString:@"\n"];
        }
    } else if (content.contentText.length) {
        [out appendString:content.contentText];
    }
    return [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.navTitle.length ? self.navTitle : @"消息";

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyBtn setTitle:@"复制全部" forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [copyBtn addTarget:self action:@selector(copyAllText) forControlEvents:UIControlEventTouchUpInside];
    [copyBtn sizeToFit];
    self.rightView = copyBtn;

    self.pageScroll = [[UIScrollView alloc] init];
    self.pageScroll.alwaysBounceVertical = YES;
    self.pageScroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    if (@available(iOS 11.0, *)) {
        self.pageScroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:self.pageScroll];

    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.layer.cornerRadius = 12.0f;
    self.bubbleView.layer.masksToBounds = YES;
    self.bubbleView.backgroundColor = [WKApp shared].config.cellBackgroundColor ?: [UIColor secondarySystemBackgroundColor];
    [self.pageScroll addSubview:self.bubbleView];

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [UIFont boldSystemFontOfSize:17];
    self.titleLbl.numberOfLines = 0;
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    [self.bubbleView addSubview:self.titleLbl];

    self.captionLbl = [[UILabel alloc] init];
    self.captionLbl.font = [UIFont systemFontOfSize:13];
    self.captionLbl.numberOfLines = 0;
    self.captionLbl.textColor = [WKApp shared].config.tipColor;
    [self.bubbleView addSubview:self.captionLbl];

    self.tableScroll = [[UIScrollView alloc] init];
    self.tableScroll.alwaysBounceHorizontal = YES;
    self.tableScroll.showsHorizontalScrollIndicator = YES;
    self.tableScroll.showsVerticalScrollIndicator = NO;
    [self.bubbleView addSubview:self.tableScroll];

    self.gridView = [[UIView alloc] init];
    [self.tableScroll addSubview:self.gridView];

    self.selectHintLbl = [[UILabel alloc] init];
    self.selectHintLbl.font = [UIFont systemFontOfSize:12];
    self.selectHintLbl.textColor = [WKApp shared].config.tipColor;
    self.selectHintLbl.text = @"长按下方文字可选中，使用系统复制";
    self.selectHintLbl.numberOfLines = 1;
    [self.bubbleView addSubview:self.selectHintLbl];

    self.textView = [[UITextView alloc] init];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.scrollEnabled = NO; // size to content; page scrolls
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.textView.textContainer.lineFragmentPadding = 0;
    self.textView.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
    self.textView.textColor = [WKApp shared].config.defaultTextColor ?: [UIColor labelColor];
    self.textView.dataDetectorTypes = UIDataDetectorTypeNone;
    // System selection menu (Copy / Select All / Share…)
    self.textView.delegate = self;
    [self.bubbleView addSubview:self.textView];

    [self applyContent];
}

- (void)applyContent {
    BOOL hasTable = self.tableContent && self.tableContent.columns.count > 0;
    if (hasTable) {
        self.titleLbl.hidden = NO;
        self.titleLbl.text = self.tableContent.title.length ? self.tableContent.title : (self.navTitle ?: @"表格");
        NSString *caption = self.tableContent.caption ?: @"";
        self.captionLbl.text = caption;
        self.captionLbl.hidden = (caption.length == 0);
    } else {
        // Plain bubble: no separate title chrome — full body is selectable.
        self.titleLbl.hidden = YES;
        self.captionLbl.hidden = YES;
    }

    self.textView.text = self.selectableText.length ? self.selectableText : @"";

    self.tableScroll.hidden = !hasTable;
    self.gridView.hidden = !hasTable;
    if (hasTable) {
        [self rebuildGrid];
    } else {
        self.gridW = 0;
        self.gridH = 0;
    }
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.navigationBar.lim_bottom + 12.0f;
    CGFloat pageW = self.view.lim_width;
    self.pageScroll.frame = CGRectMake(0, top, pageW, self.view.lim_height - top);

    CGFloat bubbleW = pageW - kPad * 2;
    CGFloat innerW = bubbleW - kBubblePad * 2;
    CGFloat y = kBubblePad;

    if (!self.titleLbl.hidden) {
        CGSize titleSz = [self.titleLbl sizeThatFits:CGSizeMake(innerW, CGFLOAT_MAX)];
        self.titleLbl.frame = CGRectMake(kBubblePad, y, innerW, titleSz.height);
        y = self.titleLbl.lim_bottom + 6.0f;
    }

    if (!self.captionLbl.hidden) {
        CGSize capSz = [self.captionLbl sizeThatFits:CGSizeMake(innerW, CGFLOAT_MAX)];
        self.captionLbl.frame = CGRectMake(kBubblePad, y, innerW, capSz.height);
        y = self.captionLbl.lim_bottom + 10.0f;
    }

    if (!self.tableScroll.hidden && self.gridH > 0) {
        self.tableScroll.frame = CGRectMake(kBubblePad, y, innerW, MIN(self.gridH, 280.0f));
        self.tableScroll.contentSize = CGSizeMake(MAX(self.gridW, innerW), self.gridH);
        self.gridView.frame = CGRectMake(0, 0, self.gridW, self.gridH);
        y = self.tableScroll.lim_bottom + 12.0f;
    }

    self.selectHintLbl.frame = CGRectMake(kBubblePad, y, innerW, 16.0f);
    y = self.selectHintLbl.lim_bottom + 6.0f;

    CGSize textSz = [self.textView sizeThatFits:CGSizeMake(innerW, CGFLOAT_MAX)];
    self.textView.frame = CGRectMake(kBubblePad, y, innerW, MAX(textSz.height, 40.0f));
    y = self.textView.lim_bottom + kBubblePad;

    self.bubbleView.frame = CGRectMake(kPad, 8.0f, bubbleW, y);
    self.pageScroll.contentSize = CGSizeMake(pageW, self.bubbleView.lim_bottom + 24.0f);
}

#pragma mark - Grid

- (UIColor *)colorForValue:(NSString *)value format:(NSString *)format defaultColor:(UIColor *)def {
    if (![format isEqualToString:@"pct_color"] || !value.length) return def;
    if ([value hasPrefix:@"+"] || [value hasPrefix:@"＋"]) return [UIColor systemRedColor];
    if ([value hasPrefix:@"-"] || [value hasPrefix:@"－"] || [value hasPrefix:@"−"]) return [UIColor systemGreenColor];
    return def;
}

- (NSTextAlignment)alignFrom:(id)align {
    if (![align isKindOfClass:[NSString class]]) return NSTextAlignmentLeft;
    if ([align isEqualToString:@"right"]) return NSTextAlignmentRight;
    if ([align isEqualToString:@"center"]) return NSTextAlignmentCenter;
    return NSTextAlignmentLeft;
}

- (CGFloat)measureWidth:(NSString *)text font:(UIFont *)font {
    if (!text.length) return kColMinW;
    CGSize sz = [text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, kRowH)
                                   options:NSStringDrawingUsesLineFragmentOrigin
                                attributes:@{NSFontAttributeName: font}
                                   context:nil].size;
    return ceil(sz.width) + 20.0f;
}

- (void)rebuildGrid {
    for (UIView *v in self.gridView.subviews) {
        [v removeFromSuperview];
    }
    NSArray *columns = self.tableContent.columns ?: @[];
    NSArray *rows = self.tableContent.rows ?: @[];
    if (columns.count == 0) {
        self.gridW = self.gridH = 0;
        return;
    }

    NSInteger colCount = columns.count;
    NSInteger rowCount = MIN((NSInteger)rows.count, kMaxRows);
    UIFont *headerFont = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    UIFont *cellFont = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];

    NSMutableArray<NSNumber *> *colWidths = [NSMutableArray arrayWithCapacity:colCount];
    CGFloat totalW = 0;
    for (NSInteger c = 0; c < colCount; c++) {
        NSDictionary *col = columns[c];
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
        w = MIN(kColMaxW, MAX(kColMinW, w));
        [colWidths addObject:@(w)];
        totalW += w;
    }

    CGFloat gridH = (rowCount + 1) * kRowH;
    UIColor *headerBg = [[WKApp shared].config.lineColor ?: [UIColor colorWithWhite:0.92 alpha:1]
                         colorWithAlphaComponent:0.85];
    UIColor *line = [WKApp shared].config.lineColor ?: [UIColor colorWithWhite:0.85 alpha:1];
    UIColor *textColor = [WKApp shared].config.defaultTextColor ?: [UIColor darkTextColor];

    CGFloat x = 0;
    for (NSInteger c = 0; c < colCount; c++) {
        NSDictionary *col = columns[c];
        CGFloat colW = colWidths[c].doubleValue;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, 0, colW, kRowH)];
        lbl.font = headerFont;
        lbl.textColor = textColor;
        lbl.backgroundColor = headerBg;
        lbl.textAlignment = [self alignFrom:col[@"align"]];
        lbl.text = [col[@"label"] isKindOfClass:[NSString class]] ? col[@"label"] : @"";
        lbl.layer.borderWidth = 0.5;
        lbl.layer.borderColor = line.CGColor;
        [self.gridView addSubview:lbl];
        x += colW;
    }

    for (NSInteger r = 0; r < rowCount; r++) {
        NSDictionary *row = rows[r];
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        x = 0;
        for (NSInteger c = 0; c < colCount; c++) {
            NSDictionary *col = columns[c];
            NSString *colId = [col[@"id"] isKindOfClass:[NSString class]] ? col[@"id"] : @"";
            id raw = colId.length ? row[colId] : nil;
            NSString *val = [raw isKindOfClass:[NSString class]] ? raw : ([raw description] ?: @"");
            NSString *format = [col[@"format"] isKindOfClass:[NSString class]] ? col[@"format"] : @"text";
            CGFloat colW = colWidths[c].doubleValue;
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, (r + 1) * kRowH, colW, kRowH)];
            lbl.font = cellFont;
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

    self.gridW = totalW;
    self.gridH = gridH;
}

#pragma mark - Actions

- (void)copyAllText {
    NSString *text = self.textView.text ?: self.selectableText ?: @"";
    if (!text.length) return;
    [UIPasteboard generalPasteboard].string = text;
    [self.view showHUDWithHide:@"已复制"];
}

@end
