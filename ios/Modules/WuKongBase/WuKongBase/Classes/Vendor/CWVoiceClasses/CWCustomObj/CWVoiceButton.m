//
//  CWVoiceButton.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/9/14.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWVoiceButton.h"
#import "UIView+CWChat.h"
#import "WKApp.h"

@implementation CWVoiceButton

+ (UIImage *)cw_circleImageWithSize:(CGSize)size color:(UIColor *)color {
    CGFloat w = MAX(1.0f, size.width);
    CGFloat h = MAX(1.0f, size.height);
    CGSize canvas = CGSizeMake(w, h);
    UIGraphicsBeginImageContextWithOptions(canvas, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *fill = color ?: [UIColor colorWithRed:1 green:0x45 / 255.0 blue:0 alpha:1];
    if (@available(iOS 13.0, *)) {
        fill = [fill resolvedColorWithTraitCollection:UITraitCollection.currentTraitCollection];
    }
    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGFloat inset = 0.5f;
    CGContextFillEllipseInRect(ctx, CGRectMake(inset, inset, w - inset * 2.0f, h - inset * 2.0f));
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: [[UIImage alloc] init];
}

+ (UIColor *)cw_pressColorFrom:(UIColor *)color {
    UIColor *base = color ?: [UIColor colorWithRed:1 green:0x45 / 255.0 blue:0 alpha:1];
    if (@available(iOS 13.0, *)) {
        base = [base resolvedColorWithTraitCollection:UITraitCollection.currentTraitCollection];
    }
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![base getRed:&r green:&g blue:&b alpha:&a]) {
        return base;
    }
    return [UIColor colorWithRed:MAX(0, r * 0.85f)
                           green:MAX(0, g * 0.85f)
                            blue:MAX(0, b * 0.85f)
                           alpha:a];
}

+ (UIImage *)cw_whiteSymbol:(NSString *)name pointSize:(CGFloat)pointSize {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:UIImageSymbolWeightMedium];
        UIImage *sys = [UIImage systemImageNamed:name withConfiguration:cfg];
        if (sys) {
            return [sys imageWithTintColor:[UIColor whiteColor]
                             renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }
    return nil;
}

+ (instancetype)buttonWithBackImageNor:(NSString *)backImageNor backImageSelected:(NSString *)backImageSelected imageNor:(NSString *)imageNor imageSelected:(NSString *)imageSelected frame:(CGRect)frame isMicPhone:(BOOL)isMicPhone{
    
    UIImage *assetNor = [self imageName:backImageNor];
    UIImage *assetSel = [self imageName:backImageSelected];
    CGSize circleSize = assetNor.size.width > 0 ? assetNor.size : CGSizeMake(100, 100);

    UIImage *normalImage = assetNor;
    UIImage *selectedImage = assetSel;
    UIImage *iconNor = [self imageName:imageNor];
    UIImage *iconSel = [self imageName:imageSelected];

    if (isMicPhone) {
        UIColor *theme = [WKApp shared].config.themeColor;
        normalImage = [self cw_circleImageWithSize:circleSize color:theme];
        selectedImage = [self cw_circleImageWithSize:circleSize color:[self cw_pressColorFrom:theme]];
        CGFloat symbolSize = MAX(28.0f, circleSize.width * 0.34f);
        // Prefer mic for talk-back; keep start/stop glyphs for record mode assets.
        BOOL looksLikeRecordToggle = [imageNor containsString:@"aio_record_start"] ||
                                     [imageNor containsString:@"aio_record_stop"];
        if (looksLikeRecordToggle) {
            UIImage *start = [self cw_whiteSymbol:@"mic.fill" pointSize:symbolSize];
            UIImage *stop = [self cw_whiteSymbol:@"stop.fill" pointSize:symbolSize * 0.85f];
            if (start) iconNor = start;
            if (stop) iconSel = stop;
        } else {
            UIImage *mic = [self cw_whiteSymbol:@"mic.fill" pointSize:symbolSize];
            if (mic) {
                iconNor = mic;
                iconSel = mic;
            }
        }
    }

    CWVoiceButton *btn = [CWVoiceButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.cw_size = circleSize;
    if (isMicPhone) {
        [btn setBackgroundImage:normalImage forState:UIControlStateNormal];
        [btn setBackgroundImage:selectedImage forState:UIControlStateSelected];
    }
    btn.norImage = normalImage;
    btn.selectedImage = selectedImage;
    [btn setImage:iconNor forState:UIControlStateNormal];
    [btn setImage:iconSel forState:UIControlStateSelected];
    btn.imageView.backgroundColor = [UIColor clearColor];
    if (!isMicPhone) {
        btn.backgroudLayer.contents = (__bridge id _Nullable)(normalImage.CGImage);
    }
    
    return btn;
}

+(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}


- (CALayer *)backgroudLayer {
    if (_backgroudLayer == nil) {
        CALayer *layer = [[CALayer alloc] init];
        layer.frame = self.bounds;
        [self.layer insertSublayer:layer atIndex:0];
        _backgroudLayer = layer;
    }
    return _backgroudLayer;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    // 取消CALayer的隐式动画
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIImage *image = selected ? self.selectedImage : self.norImage;
    self.backgroudLayer.contents = (__bridge id _Nullable)(image.CGImage);
    [CATransaction commit];
    
}




- (BOOL)isHighlighted {
    return NO;
}


@end
