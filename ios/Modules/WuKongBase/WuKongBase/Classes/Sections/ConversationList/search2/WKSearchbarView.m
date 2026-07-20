//
//  WKSearchbarView.m
//  AFNetworking
//
//  Created by tt on 2020/6/8.
//

#import "WKSearchbarView.h"
#import "WKResource.h"
#import "WuKongBase.h"
#import "WKLiquidGlassHelper.h"
@interface WKSearchbarView ()

@property(nonatomic,strong) UIImageView *searchIconImgView;
@property(nonatomic,strong) UILabel *placeholderLbl;
@property(nonatomic,strong,nullable) UIVisualEffectView *liquidGlassView;

@end

@implementation WKSearchbarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    self.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    [tap addTarget:self action:@selector(tap)];
    [self addGestureRecognizer:tap];
    
    if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
        self.backgroundColor = [UIColor clearColor];
        self.liquidGlassView = [WKLiquidGlassHelper installInView:self
                                                     cornerRadius:18.0f
                                                      interactive:YES
                                                       solidColor:nil];
    } else {
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = 4.0f;
    }
    [self addSubview:self.searchIconImgView];
    [self addSubview:self.placeholderLbl];
}

-(void) tap {
    if(self.onClick) {
        self.onClick();
    }
}

- (UIImageView *)searchIconImgView {
    if(!_searchIconImgView) {
        _searchIconImgView = [[UIImageView alloc] initWithImage:[self imageName:@"Common/Index/IconSearch2"]];
        [_searchIconImgView setFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
    }
    return _searchIconImgView;
}

- (UILabel *)placeholderLbl {
    if(!_placeholderLbl) {
        _placeholderLbl = [[UILabel alloc] init];
        [_placeholderLbl setTextColor:[UIColor grayColor]];
    }
    return _placeholderLbl;
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholderLbl.text = placeholder;
    [_placeholderLbl sizeToFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (self.liquidGlassView) {
        self.backgroundColor = [UIColor clearColor];
        self.liquidGlassView.frame = self.bounds;
        [self sendSubviewToBack:self.liquidGlassView];
    } else {
        [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
    CGFloat searchIconRightSpace = 5.0f;
    CGFloat contentWidth = self.searchIconImgView.lim_width + self.placeholderLbl.lim_width + searchIconRightSpace;
    
    CGFloat searchIconLeft = self.lim_width/2.0f - contentWidth/2.0f;
    
    self.searchIconImgView.lim_left = searchIconLeft;
    self.searchIconImgView.lim_top = self.lim_height/2.0f - self.searchIconImgView.lim_height/2.0f;
    
    self.placeholderLbl.lim_left = self.searchIconImgView.lim_right +searchIconRightSpace;
    self.placeholderLbl.lim_top = self.lim_height/2.0f - self.placeholderLbl.lim_height/2.0f;
    
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
