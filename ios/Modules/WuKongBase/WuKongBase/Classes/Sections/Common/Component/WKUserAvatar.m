//
//  WKUserAvatar.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKUserAvatar.h"

#import "WKApp.h"
#import "UIView+WK.h"
#import "WKBrandIconHelper.h"
#import <SDWebImage/SDWebImage.h>


@interface WKUserAvatar ()
@property(nonatomic,strong) UIView *avatarBox;

@end

@implementation WKUserAvatar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.borderWidth = 0.0f;
        [self setupUI];
    }
    return self;
}
- (instancetype)init
{
    return [self initWithFrame:CGRectMake(0.0f, 0.0f, WKDefaultAvatarSize.width, WKDefaultAvatarSize.height)];;
}

-(void) setupUI {
    [self addSubview:self.avatarBox];
    [self.avatarBox addSubview:self.avatarImgView];
}

- (UIImageView *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKImageView alloc] initWithFrame:CGRectMake(self.borderWidth/2.0f, self.borderWidth/2.0f, self.frame.size.width -self.borderWidth, self.frame.size.height - self.borderWidth)];
        _avatarImgView.layer.masksToBounds = YES;
        _avatarImgView.layer.cornerRadius = _avatarImgView.frame.size.width*0.4;
    }
    return _avatarImgView;
}

- (void)setUid:(NSString *)uid {
    _uid = [uid copy];
    if ([self applyBrandAvatarIfPossible]) {
        return;
    }
    if (_url.length) {
        [_avatarImgView loadImage:[NSURL URLWithString:_url] placeholderImage:[WKApp shared].config.defaultAvatar];
    }
}

- (void)setUrl:(NSString *)url {
    _url = url;
    if ([self applyBrandAvatarIfPossible]) {
        return;
    }
    [_avatarImgView loadImage:[NSURL URLWithString:url] placeholderImage:[WKApp shared].config.defaultAvatar];
}

- (BOOL)applyBrandAvatarIfPossible {
    NSString *resolvedUID = self.uid;
    if (!resolvedUID.length) {
        resolvedUID = [WKBrandIconHelper uidFromAvatarPath:self.url];
    }
    CGFloat size = MAX(self.bounds.size.width, self.avatarImgView.bounds.size.width);
    if (size < 1.0f) {
        size = WKDefaultAvatarSize.width;
    }
    UIImage *brand = [WKBrandIconHelper systemAvatarForUID:resolvedUID size:size];
    if (!brand) {
        return NO;
    }
    // Cancel any in-flight remote load so CDN logos cannot overwrite brand icons.
    [self.avatarImgView sd_cancelCurrentImageLoad];
    self.avatarImgView.image = brand;
    return YES;
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    _borderWidth = borderWidth;
    self.avatarImgView.frame = CGRectMake(borderWidth/2.0f, borderWidth/2.0f, self.frame.size.width -borderWidth, self.frame.size.height - borderWidth);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.avatarBox setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
}


- (UIView *)avatarBox {
    if(!_avatarBox) {
        _avatarBox = [[UIView alloc] initWithFrame:self.bounds];
        _avatarBox.layer.masksToBounds = YES;
        _avatarBox.layer.cornerRadius = _avatarBox.frame.size.width*0.4;
    }
    return _avatarBox;
}

@end
