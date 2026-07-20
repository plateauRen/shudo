//
//  WKHermesActionCell.m
//  WuKongBase
//

#import "WKHermesActionCell.h"
#import "WKHermesActionContent.h"
#import "WuKongBase.h"

@interface WKHermesActionCell ()
@property(nonatomic, strong) UILabel *textLbl;
@end

@implementation WKHermesActionCell

+ (NSString *)displayTextForContent:(WKHermesActionContent *)content {
    if (content.label.length) {
        return content.label;
    }
    return [WKHermesActionContent displayLabelForAction:content.action preferredLabel:nil];
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKHermesActionContent *content = (WKHermesActionContent *)model.content;
    NSString *text = [self displayTextForContent:content];
    CGFloat maxW = [WKApp shared].config.messageContentMaxWidth;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(maxW - 24, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14.0f weight:UIFontWeightMedium]}
                                     context:nil];
    return CGSizeMake(MIN(maxW, ceil(rect.size.width) + 24), MAX(34.0f, ceil(rect.size.height) + 14));
}

- (void)initUI {
    [super initUI];
    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 8.0f;
    self.textLbl = [[UILabel alloc] init];
    self.textLbl.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightMedium];
    self.textLbl.numberOfLines = 0;
    self.textLbl.textAlignment = NSTextAlignmentCenter;
    [self.messageContentView addSubview:self.textLbl];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKHermesActionContent *content = (WKHermesActionContent *)model.content;
    UIColor *theme = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
    BOOL deny = [[content.action lowercaseString] isEqualToString:@"deny"];
    if (deny) {
        self.messageContentView.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.12];
        self.textLbl.textColor = [UIColor systemRedColor];
    } else {
        self.messageContentView.backgroundColor = [theme colorWithAlphaComponent:0.12];
        self.textLbl.textColor = theme;
    }
    self.textLbl.text = [[self class] displayTextForContent:content];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.textLbl.lim_left = 12.0f;
    self.textLbl.lim_top = 7.0f;
    self.textLbl.lim_width = self.messageContentView.lim_width - 24.0f;
    self.textLbl.lim_height = self.messageContentView.lim_height - 14.0f;
}

+ (BOOL)hiddenBubble {
    return YES;
}

@end
