//
//  WKLiquidGlassHelper.m
//  WuKongBase
//

#import "WKLiquidGlassHelper.h"

@implementation WKLiquidGlassHelper

+ (BOOL)isLiquidGlassAvailable {
    if (@available(iOS 26.0, *)) {
        return YES;
    }
    return NO;
}

+ (nullable UIVisualEffectView *)installInView:(UIView *)host
                                 cornerRadius:(CGFloat)cornerRadius
                                  interactive:(BOOL)interactive
                                   solidColor:(nullable UIColor *)solidColor {
    if (!host) {
        return nil;
    }

    host.backgroundColor = [UIColor clearColor];

    if (@available(iOS 26.0, *)) {
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
        effectView.userInteractionEnabled = NO;
        effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        effectView.frame = host.bounds;
        [self applyCornerRadius:cornerRadius toEffectView:effectView];
        [host insertSubview:effectView atIndex:0];

        UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        glass.interactive = interactive;
        effectView.effect = glass;
        return effectView;
    }

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:blur];
        effectView.userInteractionEnabled = NO;
        effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        effectView.frame = host.bounds;
        effectView.layer.cornerRadius = cornerRadius;
        effectView.clipsToBounds = YES;
        [host insertSubview:effectView atIndex:0];
        return effectView;
    }

    if (solidColor) {
        host.backgroundColor = solidColor;
    }
    return nil;
}

+ (void)applyCornerRadius:(CGFloat)cornerRadius toEffectView:(UIVisualEffectView *)effectView {
    if (!effectView) {
        return;
    }
    if (@available(iOS 26.0, *)) {
        UICornerRadius *radius = [UICornerRadius fixedRadius:cornerRadius];
        effectView.cornerConfiguration = [UICornerConfiguration configurationWithUniformRadius:radius];
    } else {
        effectView.layer.cornerRadius = cornerRadius;
        effectView.clipsToBounds = YES;
    }
}

+ (void)materializeEffectView:(UIVisualEffectView *)effectView
                  interactive:(BOOL)interactive
                     animated:(BOOL)animated
                   completion:(void (^)(void))completion {
    if (!effectView) {
        if (completion) completion();
        return;
    }

    if (@available(iOS 26.0, *)) {
        UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        glass.interactive = interactive;
        void (^apply)(void) = ^{
            effectView.effect = glass;
        };
        if (animated) {
            [UIView animateWithDuration:0.28
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:apply
                             completion:^(BOOL finished) {
                if (completion) completion();
            }];
        } else {
            apply();
            if (completion) completion();
        }
        return;
    }

    if (!effectView.effect) {
        if (@available(iOS 13.0, *)) {
            effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        }
    }
    if (completion) completion();
}

+ (void)dematerializeEffectView:(UIVisualEffectView *)effectView
                       animated:(BOOL)animated
                     completion:(void (^)(void))completion {
    if (!effectView) {
        if (completion) completion();
        return;
    }

    if (@available(iOS 26.0, *)) {
        void (^clear)(void) = ^{
            effectView.effect = nil;
        };
        if (animated) {
            [UIView animateWithDuration:0.22
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:clear
                             completion:^(BOOL finished) {
                if (completion) completion();
            }];
        } else {
            clear();
            if (completion) completion();
        }
        return;
    }

    if (completion) completion();
}

+ (void)attachScrollEdgeInteractionToView:(UIView *)overlay
                               scrollView:(UIScrollView *)scrollView
                                     edge:(UIRectEdge)edge {
    if (!overlay || !scrollView) {
        return;
    }
    if (@available(iOS 26.0, *)) {
        for (id<UIInteraction> existing in overlay.interactions) {
            if ([existing isKindOfClass:[UIScrollEdgeElementContainerInteraction class]]) {
                UIScrollEdgeElementContainerInteraction *old = (UIScrollEdgeElementContainerInteraction *)existing;
                if (old.edge == edge) {
                    old.scrollView = scrollView;
                    return;
                }
            }
        }
        UIScrollEdgeElementContainerInteraction *interaction = [[UIScrollEdgeElementContainerInteraction alloc] init];
        interaction.scrollView = scrollView;
        interaction.edge = edge;
        [overlay addInteraction:interaction];
    }
}

+ (void)applyGlassListStyleToTableView:(UITableView *)tableView {
    if (!tableView) return;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.backgroundView = nil;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0;
    }
    if ([self isLiquidGlassAvailable]) {
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
}

+ (void)applyGlassCellBackground:(UITableViewCell *)cell {
    if (!cell || ![self isLiquidGlassAvailable]) {
        return;
    }
    cell.backgroundColor = [UIColor clearColor];
    UIColor *fill = [[UIColor secondarySystemGroupedBackgroundColor] colorWithAlphaComponent:0.55];
    if (@available(iOS 14.0, *)) {
        UIBackgroundConfiguration *cfg = [UIBackgroundConfiguration listGroupedCellConfiguration];
        cfg.backgroundColor = fill;
        cell.backgroundConfiguration = cfg;
    } else {
        cell.contentView.backgroundColor = fill;
    }
}

@end
