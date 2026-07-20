//
//  WKHermesCardCell.m
//  WuKongBase
//
//  Buttons are attached to contentView (same pattern as WKSystemMessageCell invite
//  button) so they sit above the AsyncDisplayNode / bubble gesture stack.
//  Action callbacks are sent as 21001 but kept out of the chat UI (store intercept).
//

#import "WKHermesCardCell.h"
#import "WKHermesCardContent.h"
#import "WKHermesActionContent.h"
#import "WKTapLongTapOrDoubleTapGestureRecognizerEvent.h"
#import "UIView+WKCommon.h"
#import "WKNavigationManager.h"
#import "WuKongBase.h"

static const CGFloat kHermesCardWidth = 280.0f;
static const CGFloat kHermesPad = 12.0f;
static const CGFloat kHermesTitleFont = 16.0f;
static const CGFloat kHermesBodyFont = 13.0f;
static const CGFloat kHermesBtnH = 34.0f;
static const CGFloat kHermesBtnGap = 8.0f;

@interface WKHermesCardCell ()
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UILabel *bodyLbl;
@property(nonatomic, strong) UILabel *descLbl;
@property(nonatomic, strong) UILabel *statusLbl;
@property(nonatomic, strong) UIView *buttonBox;
@property(nonatomic, strong) NSMutableArray<UIButton *> *actionButtons;
@property(nonatomic, assign) CGFloat buttonsAreaTopInContent;
@end

@implementation WKHermesCardCell

+ (CGFloat)textHeight:(NSString *)text font:(UIFont *)font width:(CGFloat)width {
    if (!text.length) return 0;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];
    return ceil(rect.size.height);
}

+ (CGFloat)buttonsHeightForCount:(NSInteger)btnCount {
    if (btnCount <= 0) return 0;
    NSInteger rows = (btnCount + 1) / 2;
    return 8.0f + rows * kHermesBtnH + MAX(0, rows - 1) * kHermesBtnGap;
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKHermesCardContent *content = (WKHermesCardContent *)model.content;
    [content applyLocalActedState];
    CGFloat innerW = kHermesCardWidth - kHermesPad * 2;
    CGFloat h = kHermesPad;
    h += [self textHeight:content.title ?: @"" font:[UIFont boldSystemFontOfSize:kHermesTitleFont] width:innerW];
    h += 6.0f;
    if (content.body.length) {
        CGFloat bodyH = [self textHeight:content.body font:[UIFont systemFontOfSize:kHermesBodyFont] width:innerW];
        h += MIN(bodyH, 120.0f) + 6.0f;
    }
    if (content.descText.length) {
        h += [self textHeight:content.descText font:[UIFont systemFontOfSize:12.0f] width:innerW] + 6.0f;
    }
    // Keep button-area height when acted so cell height stays stable without reloadRows
    NSInteger btnCount = content.buttons.count;
    if (content.acted) {
        h += MAX([self buttonsHeightForCount:btnCount], 8.0f + kHermesBtnH);
    } else {
        h += [self buttonsHeightForCount:btnCount];
    }
    h += kHermesPad;
    return CGSizeMake(kHermesCardWidth, MAX(h, 72.0f));
}

- (void)initUI {
    [super initUI];
    self.actionButtons = [NSMutableArray array];

    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 8.0f;

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [UIFont boldSystemFontOfSize:kHermesTitleFont];
    self.titleLbl.numberOfLines = 2;
    self.titleLbl.userInteractionEnabled = NO;
    [self.messageContentView addSubview:self.titleLbl];

    self.bodyLbl = [[UILabel alloc] init];
    self.bodyLbl.font = [UIFont systemFontOfSize:kHermesBodyFont];
    self.bodyLbl.numberOfLines = 0;
    self.bodyLbl.userInteractionEnabled = NO;
    [self.messageContentView addSubview:self.bodyLbl];

    self.descLbl = [[UILabel alloc] init];
    self.descLbl.font = [UIFont systemFontOfSize:12.0f];
    self.descLbl.numberOfLines = 2;
    self.descLbl.userInteractionEnabled = NO;
    [self.messageContentView addSubview:self.descLbl];

    self.statusLbl = [[UILabel alloc] init];
    self.statusLbl.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
    self.statusLbl.numberOfLines = 1;
    self.statusLbl.textAlignment = NSTextAlignmentCenter;
    self.statusLbl.userInteractionEnabled = NO;
    self.statusLbl.layer.cornerRadius = 6.0f;
    self.statusLbl.layer.masksToBounds = YES;
    self.statusLbl.hidden = YES;
    [self.messageContentView addSubview:self.statusLbl];

    self.buttonBox = [[UIView alloc] init];
    self.buttonBox.userInteractionEnabled = YES;
    self.buttonBox.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.buttonBox];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKHermesCardContent *content = (WKHermesCardContent *)model.content;
    [content applyLocalActedState];

    [self setContentGesturesEnabled:NO];
    self.bubbleBackgroundView.userInteractionEnabled = NO;
    self.messageContentView.userInteractionEnabled = NO;

    self.messageContentView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.bodyLbl.textColor = [WKApp shared].config.messageRecvTextColor;
    self.descLbl.textColor = [WKApp shared].config.tipColor;

    self.titleLbl.text = content.title ?: @"Hermes";
    self.bodyLbl.text = content.body ?: @"";
    self.descLbl.text = content.descText ?: @"";

    if ([WKApp shared].config.style != WKSystemStyleDark) {
        self.trailingView.timeLbl.textColor = [WKApp shared].config.tipColor;
        self.trailingView.statusImgView.tintColor = [WKApp shared].config.tipColor;
    }
    self.trailingView.userInteractionEnabled = NO;

    [self applyActedUI:content];
    [self.contentView bringSubviewToFront:self.buttonBox];
}

- (void)applyActedUI:(WKHermesCardContent *)content {
    UIColor *theme = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
    BOOL deny = [[content.actedAction lowercaseString] isEqualToString:@"deny"];

    if (content.acted) {
        self.buttonBox.hidden = YES;
        self.buttonBox.userInteractionEnabled = NO;
        for (UIView *v in self.buttonBox.subviews) {
            [v removeFromSuperview];
        }
        [self.actionButtons removeAllObjects];

        self.statusLbl.hidden = NO;
        NSString *label = content.actedLabel.length ? content.actedLabel : @"已选择";
        self.statusLbl.text = [NSString stringWithFormat:@"已选择：%@", label];
        if (deny) {
            self.statusLbl.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.12];
            self.statusLbl.textColor = [UIColor systemRedColor];
        } else {
            self.statusLbl.backgroundColor = [theme colorWithAlphaComponent:0.12];
            self.statusLbl.textColor = theme;
        }
    } else {
        self.statusLbl.hidden = YES;
        self.buttonBox.hidden = NO;
        self.buttonBox.userInteractionEnabled = YES;
        [self rebuildButtons:content];
    }
}

- (void)rebuildButtons:(WKHermesCardContent *)content {
    for (UIView *v in self.buttonBox.subviews) {
        [v removeFromSuperview];
    }
    [self.actionButtons removeAllObjects];

    NSArray *buttons = content.buttons ?: @[];
    for (NSInteger i = 0; i < buttons.count; i++) {
        NSDictionary *btnInfo = buttons[i];
        if (![btnInfo isKindOfClass:[NSDictionary class]]) continue;
        NSString *label = [btnInfo[@"label"] isKindOfClass:[NSString class]] ? btnInfo[@"label"] : @"OK";
        NSString *btnId = [btnInfo[@"id"] isKindOfClass:[NSString class]] ? btnInfo[@"id"] : @"";
        NSString *style = [btnInfo[@"style"] isKindOfClass:[NSString class]] ? btnInfo[@"style"] : @"secondary";

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:label forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
        btn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        btn.layer.cornerRadius = 6.0f;
        btn.layer.masksToBounds = YES;
        btn.tag = i;
        btn.enabled = YES;
        btn.exclusiveTouch = YES;
        btn.accessibilityIdentifier = btnId;
        [btn addTarget:self action:@selector(onActionButton:) forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(onButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [btn addTarget:self action:@selector(onButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];

        UIColor *theme = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
        if ([style isEqualToString:@"danger"]) {
            btn.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.9];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else if ([style isEqualToString:@"primary"]) {
            btn.backgroundColor = theme;
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [WKApp shared].config.lineColor ?: [UIColor colorWithWhite:0.92 alpha:1];
            [btn setTitleColor:theme forState:UIControlStateNormal];
        }

        [self.buttonBox addSubview:btn];
        [self.actionButtons addObject:btn];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.messageModel) return;
    WKHermesCardContent *content = (WKHermesCardContent *)self.messageModel.content;

    CGFloat innerW = self.messageContentView.lim_width - kHermesPad * 2;
    CGFloat y = kHermesPad;

    self.titleLbl.lim_left = kHermesPad;
    self.titleLbl.lim_top = y;
    self.titleLbl.lim_width = innerW;
    [self.titleLbl sizeToFit];
    self.titleLbl.lim_width = innerW;
    y = self.titleLbl.lim_bottom + 6.0f;

    self.bodyLbl.hidden = (self.bodyLbl.text.length == 0);
    if (!self.bodyLbl.hidden) {
        self.bodyLbl.lim_left = kHermesPad;
        self.bodyLbl.lim_top = y;
        self.bodyLbl.lim_width = innerW;
        CGFloat bodyH = [[self class] textHeight:self.bodyLbl.text font:self.bodyLbl.font width:innerW];
        self.bodyLbl.lim_height = MIN(bodyH, 120.0f);
        y = self.bodyLbl.lim_bottom + 6.0f;
    }

    self.descLbl.hidden = (self.descLbl.text.length == 0);
    if (!self.descLbl.hidden) {
        self.descLbl.lim_left = kHermesPad;
        self.descLbl.lim_top = y;
        self.descLbl.lim_width = innerW;
        [self.descLbl sizeToFit];
        self.descLbl.lim_width = innerW;
        y = self.descLbl.lim_bottom + 8.0f;
    } else {
        y += 2.0f;
    }

    self.buttonsAreaTopInContent = y;

    if (content.acted) {
        // Center status in the reserved button area height
        CGFloat areaH = MAX([[self class] buttonsHeightForCount:content.buttons.count] - 8.0f, kHermesBtnH);
        CGFloat statusY = y + MAX(0, (areaH - kHermesBtnH) / 2.0f);
        self.statusLbl.frame = CGRectMake(kHermesPad, statusY, innerW, kHermesBtnH);
        self.buttonBox.hidden = YES;
    } else {
        NSInteger count = self.actionButtons.count;
        CGFloat boxH = count > 0 ? [[self class] buttonsHeightForCount:count] - 8.0f : 0;
        CGRect contentInCell = [self.messageContentView convertRect:self.messageContentView.bounds toView:self.contentView];
        CGFloat boxY = contentInCell.origin.y + self.buttonsAreaTopInContent;
        CGFloat boxX = contentInCell.origin.x + kHermesPad;
        CGFloat boxW = MAX(0, contentInCell.size.width - kHermesPad * 2);
        self.buttonBox.frame = CGRectMake(boxX, boxY, boxW, MAX(boxH, 0));
        self.buttonBox.hidden = (count == 0);

        CGFloat colW = (boxW - kHermesBtnGap) / 2.0f;
        for (NSInteger i = 0; i < count; i++) {
            UIButton *btn = self.actionButtons[i];
            NSInteger row = i / 2;
            NSInteger col = i % 2;
            BOOL fullWidth = (i == count - 1) && (count % 2 == 1);
            btn.frame = CGRectMake(col * (colW + kHermesBtnGap),
                                   row * (kHermesBtnH + kHermesBtnGap),
                                   fullWidth ? boxW : colW,
                                   kHermesBtnH);
        }
        [self.contentView bringSubviewToFront:self.buttonBox];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.buttonBox.hidden && self.buttonBox.alpha > 0.01 && self.buttonBox.userInteractionEnabled) {
        CGPoint p = [self convertPoint:point toView:self.buttonBox];
        if ([self.buttonBox pointInside:p withEvent:event]) {
            UIView *hit = [self.buttonBox hitTest:p withEvent:event];
            if (hit) {
                return hit;
            }
        }
    }
    return [super hitTest:point withEvent:event];
}

- (void)onButtonTouchDown:(UIButton *)sender {
    sender.alpha = 0.65;
}

- (void)onButtonTouchUp:(UIButton *)sender {
    if (sender.enabled) {
        sender.alpha = 1.0;
    }
}

- (void)onActionButton:(UIButton *)sender {
    sender.alpha = 1.0;
    if (!self.messageModel || ![self.messageModel.content isKindOfClass:[WKHermesCardContent class]]) {
        return;
    }
    WKHermesCardContent *card = (WKHermesCardContent *)self.messageModel.content;
    [card applyLocalActedState];
    if (card.acted) {
        return;
    }
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)card.buttons.count) {
        return;
    }
    NSDictionary *btnInfo = card.buttons[idx];
    NSString *btnId = [btnInfo[@"id"] isKindOfClass:[NSString class]] ? btnInfo[@"id"] : @"";
    if (!btnId.length) {
        btnId = sender.accessibilityIdentifier ?: @"";
    }
    if (!btnId.length) {
        return;
    }
    NSString *btnLabel = [btnInfo[@"label"] isKindOfClass:[NSString class]] ? btnInfo[@"label"] : nil;
    NSString *displayLabel = [WKHermesActionContent displayLabelForAction:btnId preferredLabel:btnLabel];

    // 1) Instant local feedback + persist
    [card markActedWithAction:btnId label:displayLabel];
    [self applyActedUI:card];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    if (self.conversationContext) {
        [self.conversationContext refreshCell:self.messageModel];
    }

    UIView *toastHost = [WKNavigationManager shared].topViewController.view;
    if (toastHost) {
        [toastHost showMsg:[NSString stringWithFormat:@"已选择：%@", displayLabel]];
    }

    // 2) Silent callback (21001) — store intercept keeps it out of chat UI
    WKHermesActionContent *actionContent =
        [WKHermesActionContent action:btnId
                                label:displayLabel
                           approvalId:card.approvalId
                            confirmId:card.confirmId
                            clarifyId:card.clarifyId
                      sourceMessageId:self.messageModel.clientMsgNo];

    if (self.conversationContext) {
        [self.conversationContext sendMessage:actionContent];
    } else if (self.messageModel.channel) {
        [[WKSDK shared].chatManager sendMessage:actionContent channel:self.messageModel.channel];
    } else if (toastHost) {
        [toastHost showMsg:@"发送失败：无会话上下文"];
    }
}

- (BOOL)respondContentSingleTap {
    return NO;
}

- (WKTapLongTapOrDoubleTapGestureRecognizerEvent *)tapActionAtPoint:(CGPoint)point {
    return [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:WKTapLongTapOrDoubleTapGestureRecognizerActionFail];
}

+ (BOOL)hiddenBubble {
    return YES;
}

@end
