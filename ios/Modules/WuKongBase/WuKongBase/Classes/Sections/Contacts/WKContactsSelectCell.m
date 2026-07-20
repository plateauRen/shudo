//
//  WKContactsSelectCell.m
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import "WKContactsSelectCell.h"
#import "WKContacts.h"
#import "WuKongBase.h"
#import "WKBotTag.h"
#import "WKBrandIconHelper.h"

@implementation WKContactsSelect



@end

@interface WKContactsSelectCell()<WKCheckBoxDelegate>

@property(nonatomic, strong) WKBotTag *botTag;

@end
@implementation WKContactsSelectCell



-(void) setupUI{
    [super setupUI];
    self.bottomLineView.hidden = YES;
    _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 45.0f, 45.0f)];
    [self.contentView addSubview:_avatarImgView];
    
    _nameLbl = [[UILabel alloc] init];
    [_nameLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self addSubview:_nameLbl];
    [self addSubview:self.botTag];
    
    self.checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
    self.checkBox.onFillColor = [WKApp shared].config.themeColor;
    self.checkBox.onCheckColor = [UIColor whiteColor];
    self.checkBox.onTintColor = [WKApp shared].config.themeColor;
    self.checkBox.onAnimationType = BEMAnimationTypeBounce;
    self.checkBox.offAnimationType = BEMAnimationTypeBounce;
    self.checkBox.animationDuration = 0.0f;
    self.checkBox.lineWidth = 1.0f;
//    self.checkBox.tintColor = [UIColor grayColor];
    self.checkBox.delegate = self;
    [self addSubview:self.checkBox];
    
}

+(NSString*) cellId{
    return @"WKContactsSelectCell";
}

-(void) refreshWithModel:(id)cellModel{
    _contactSelectModel = cellModel;
    
    [self.nameLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    NSString *uid = _contactSelectModel.uid ?: @"";
    self.avatarImgView.uid = uid;
    UIImage *brand = [WKBrandIconHelper systemAvatarForUID:uid size:45.0f];
    if (brand) {
        self.avatarImgView.avatarImgView.image = brand;
    } else {
        self.avatarImgView.url = _contactSelectModel.avatar;
    }

    // Display name for system accounts
    if ([uid isEqualToString:[WKApp shared].config.fileHelperUID]) {
        self.nameLbl.text = LLang(@"文件传输助手");
    } else if ([uid isEqualToString:[WKApp shared].config.systemUID]) {
        self.nameLbl.text = LLang(@"系统通知");
    } else {
        self.nameLbl.text = _contactSelectModel.displayName.length ? _contactSelectModel.displayName : _contactSelectModel.name;
    }
    [self.nameLbl sizeToFit];
    self.checkBox.on = self.contactSelectModel.selected;

    BOOL isBot = NO;
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:uid]];
    if (info) {
        isBot = info.robot;
    }
    self.botTag.hidden = !isBot;
    if (isBot) {
        [self.botTag applyTheme];
    }
    
    if(_contactSelectModel.mode == WKContactsModeSingle) {
        self.checkBox.hidden = YES;
        self.avatarImgView.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.nameLbl.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.botTag.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
    }else {
        self.checkBox.hidden = NO;
        self.checkBox.userInteractionEnabled = !_contactSelectModel.disable;
        self.checkBox.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.avatarImgView.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.nameLbl.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.botTag.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
    }
}


- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat avatarLeft = 10.0f;
    CGFloat nameLeft = 10.0f;
    CGFloat checkBoxLeft = 10.0f;
    self.checkBox.lim_left = checkBoxLeft;
    self.checkBox.lim_top = self.lim_height/2.0f - self.checkBox.lim_height/2.0f;
    if(_contactSelectModel.mode == WKContactsModeSingle) {
        self.avatarImgView.lim_left =  avatarLeft;
    }else {
        self.avatarImgView.lim_left = self.checkBox.lim_right + avatarLeft;
    }
    
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeft;
    self.nameLbl.lim_top = self.lim_height/2.0f - self.nameLbl.lim_height/2.0f;

    if (!self.botTag.hidden) {
        self.botTag.lim_left = self.nameLbl.lim_right + 6.0f;
        self.botTag.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height / 2.0f - self.botTag.lim_height / 2.0f);
    }
}

- (WKBotTag *)botTag {
    if (!_botTag) {
        _botTag = [WKBotTag new];
        _botTag.hidden = YES;
    }
    return _botTag;
}

#pragma mark - WKCheckBoxDelegate
- (void)didTapCheckBox:(WKCheckBox*)checkBox {
    self.contactSelectModel.selected = checkBox.on;
    if(_stateChangeCheckBk) {
        _stateChangeCheckBk(self.contactSelectModel);
    }
}
@end
