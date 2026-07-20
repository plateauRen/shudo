//
//  WKBrandIconHelper.m
//  WuKongBase
//

#import "WKBrandIconHelper.h"
#import "WKApp.h"

@implementation WKBrandIconHelper

+ (UIImage *)circleSymbol:(NSString *)symbolName size:(CGFloat)size {
    CGFloat point = MAX(12.0f, size * 0.46f);
    return [self circleSymbol:symbolName size:size pointSize:point];
}

+ (UIImage *)circleSymbol:(NSString *)symbolName
                     size:(CGFloat)size
                pointSize:(CGFloat)pointSize {
    UIImage *glyph = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:UIImageSymbolWeightMedium];
        UIImage *sys = [UIImage systemImageNamed:symbolName];
        if (sys) {
            glyph = [[sys imageByApplyingSymbolConfiguration:cfg]
                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    return [self circleTemplateImage:glyph size:size];
}

+ (UIImage *)circleTemplateImage:(UIImage *)image size:(CGFloat)size {
    CGFloat s = MAX(1.0f, size);
    CGSize canvas = CGSizeMake(s, s);
    UIGraphicsBeginImageContextWithOptions(canvas, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *fill = [WKApp shared].config.themeColor;
    if (!fill) {
        fill = [UIColor colorWithRed:1.0 green:0x45 / 255.0 blue:0 alpha:1.0];
    }
    if (@available(iOS 13.0, *)) {
        fill = [fill resolvedColorWithTraitCollection:UITraitCollection.currentTraitCollection];
    }
    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, s, s));

    if (image) {
        CGFloat maxGlyph = s * 0.52f;
        CGFloat scale = MIN(maxGlyph / MAX(image.size.width, 1.0),
                            maxGlyph / MAX(image.size.height, 1.0));
        CGFloat gw = image.size.width * scale;
        CGFloat gh = image.size.height * scale;
        CGRect glyphRect = CGRectMake((s - gw) / 2.0f, (s - gh) / 2.0f, gw, gh);

        // Flip for CGImage mask draw, then fill white through the glyph mask.
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, 0, s);
        CGContextScaleCTM(ctx, 1.0, -1.0);
        CGRect flipped = CGRectMake(glyphRect.origin.x, glyphRect.origin.y, gw, gh);
        CGContextClipToMask(ctx, flipped, image.CGImage);
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillRect(ctx, flipped);
        CGContextRestoreGState(ctx);
    }

    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: [[UIImage alloc] init];
}

+ (NSString *)uidFromAvatarPath:(NSString *)path {
    if (!path.length) {
        return nil;
    }
    NSRange range = [path rangeOfString:@"users/"];
    if (range.location == NSNotFound) {
        return nil;
    }
    NSString *rest = [path substringFromIndex:range.location + range.length];
    NSArray<NSString *> *parts = [rest componentsSeparatedByString:@"/"];
    NSString *uid = parts.firstObject;
    return uid.length ? uid : nil;
}

+ (UIImage *)systemAvatarForUID:(NSString *)uid size:(CGFloat)size {
    if (!uid.length) {
        return nil;
    }
    NSString *fileHelper = [WKApp shared].config.fileHelperUID ?: @"fileHelper";
    NSString *systemUID = [WKApp shared].config.systemUID ?: @"u_10000";
    if ([uid isEqualToString:fileHelper]) {
        return [self circleSymbol:@"folder.fill" size:size];
    }
    if ([uid isEqualToString:systemUID]) {
        return [self circleSymbol:@"bell.badge.fill" size:size];
    }
    return nil;
}

@end
