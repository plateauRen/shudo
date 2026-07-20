//
//  WKFuncItemButton.m
//  WuKongBase
//
//  Created by tt on 2020/2/24.
//

#import "WKFuncItemButton.h"

@implementation WKFuncItemButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.adjustsImageWhenHighlighted = YES;
    }
    return self;
}

- (CGRect)imageRectForContentRect:(CGRect)contentRect {
    // Keep SF Symbol line icons centered (not stretched to fill).
    CGFloat side = MIN(contentRect.size.width, contentRect.size.height) * 0.70;
    CGFloat x = contentRect.origin.x + (contentRect.size.width - side) * 0.5;
    CGFloat y = contentRect.origin.y + (contentRect.size.height - side) * 0.5;
    return CGRectMake(x, y, side, side);
}

- (CGRect)titleRectForContentRect:(CGRect)contentRect {
    return CGRectZero;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    if(self.onSelected) {
        self.onSelected();
    }
}

@end
