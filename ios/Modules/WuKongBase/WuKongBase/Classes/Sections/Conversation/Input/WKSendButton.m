//
//  WKSendButton.m
//  WuKongBase
//
//  Created by tt on 2021/10/26.
//

#import "WKSendButton.h"
#import "WuKongBase.h"
#import "WKPanelDefaultFuncItem.h"

@interface WKSendButton ()
@property(nonatomic,assign) CGSize oldSize;
@end

@implementation WKSendButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.oldSize = frame.size;
        self.backgroundColor = [UIColor clearColor];
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = 6.0f;
        [self setImage:[[self class] paperPlaneImage] forState:UIControlStateNormal];
        self.adjustsImageWhenHighlighted = YES;
        self.accessibilityLabel = LLang(@"发送");
        _show = NO;
        [self applyShowStyle];
        [self addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

+ (UIImage *)paperPlaneImage {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:18
                                                            weight:UIImageSymbolWeightMedium
                                                             scale:UIImageSymbolScaleMedium];
        UIImage *img = [UIImage systemImageNamed:@"paperplane.fill" withConfiguration:cfg];
        if (img) {
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    UIImage *fallback = [WKApp.shared loadImage:@"Conversation/Panel/SendButton" moduleID:@"WuKongBase"];
    return [fallback imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)setShow:(BOOL)show {
    if (_show == show) return;
    _show = show;
    [self applyShowStyle];
}

- (void)applyShowStyle {
    UIColor *active = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:0x0E/255.0 green:0x74/255.0 blue:0x90/255.0 alpha:1];
    UIColor *inactive = [WKPanelDefaultFuncItem toolbarIconTint];
    self.enabled = self.show;
    self.tintColor = self.show ? active : inactive;
    self.alpha = self.show ? 1.0f : 0.45f;
    self.userInteractionEnabled = self.show;
}

-(void) sendPressed {
    if (!self.show) return;
    if(self.onSend) {
        self.onSend();
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end
