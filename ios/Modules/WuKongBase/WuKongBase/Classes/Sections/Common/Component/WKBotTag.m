//
//  WKBotTag.m
//  WuKongBase
//

#import "WKBotTag.h"
#import "WKApp.h"

@interface WKBotTag ()
@property(nonatomic, strong) UILabel *label;
@end

@implementation WKBotTag

- (instancetype)init {
    return [self initWithFrame:CGRectMake(0, 0, 30.0f, 16.0f)];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"Bot";
        [self addSubview:self.label];
        [self applyTheme];
        [self sizeToFitContent];
    }
    return self;
}

- (UILabel *)label {
    if (!_label) {
        _label = [[UILabel alloc] init];
        _label.text = @"Bot";
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [[WKApp shared].config appFontOfSizeSemibold:10.0f]
                          ?: [UIFont systemFontOfSize:10.0f weight:UIFontWeightSemibold];
    }
    return _label;
}

- (void)applyTheme {
    UIColor *theme = [WKApp shared].config.themeColor
                         ?: [UIColor colorWithRed:1 green:0x45 / 255.0 blue:0 alpha:1];
    if (@available(iOS 13.0, *)) {
        theme = [theme resolvedColorWithTraitCollection:self.traitCollection];
    }
    self.backgroundColor = theme;
    self.label.textColor = [UIColor whiteColor];
    self.layer.cornerRadius = 4.0f;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.clipsToBounds = YES;
    [self sizeToFitContent];
}

- (void)sizeToFitContent {
    [self.label sizeToFit];
    CGFloat hPad = 5.0f;
    CGFloat vPad = 1.5f;
    CGFloat w = ceil(self.label.bounds.size.width) + hPad * 2.0f;
    CGFloat h = MAX(16.0f, ceil(self.label.bounds.size.height) + vPad * 2.0f);
    self.bounds = CGRectMake(0, 0, w, h);
    self.label.frame = CGRectMake(hPad, (h - self.label.bounds.size.height) / 2.0f,
                                  self.label.bounds.size.width, self.label.bounds.size.height);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat hPad = 5.0f;
    [self.label sizeToFit];
    self.label.frame = CGRectMake(hPad,
                                  (self.bounds.size.height - self.label.bounds.size.height) / 2.0f,
                                  self.label.bounds.size.width,
                                  self.label.bounds.size.height);
}

- (CGSize)intrinsicContentSize {
    return self.bounds.size;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self applyTheme];
        }
    }
}

@end
