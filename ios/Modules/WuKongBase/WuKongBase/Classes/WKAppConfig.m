//
//  WKAppConfig.m
//  WuKongBase
//
//  Created by tt on 2021/8/25.
//

#import "WKAppConfig.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import <ZLPhotoBrowser/ZLPhotoBrowser-Swift.h>


@interface WKAppConfig ()

@property(nonatomic,assign) WKSystemStyle innerStyle;
@property(nonatomic,strong) NSNumber *innerdarkModeWithSystem;
@property(nonatomic,strong) NSNumber *innerBrandTheme;

@property(nonatomic,copy) NSString  *innerLangue;
@property(nonatomic,copy) NSString *innerReportUrl;

@end

@implementation WKAppConfig


-(instancetype) init {
    self = [super init];
    if(self) {
        self.appName = @"叙叨";
        self.shortName = @"Shudo ID";
        self.appID = @""; // appstore的id
        self.appSchemaPrefix = @"wukong";
        self.clusterOn = YES;
        
         // ---------- 基础配置（火焰旋风 B · 荧光橙）----------
        // Brand: fluorescent orange #FF4500 → #FF6B35 (primary #FF4500)
        self.themeColor = [UIColor colorWithRed:0xFF/255.0f green:0x45/255.0f blue:0x00/255.0f alpha:1.0]; // #FF4500
        self.backgroundColor = [self navBackgroudColorWithAlpha:1.0f];
        self.footerTipFontSize = 12.0f;
        self.defaultAvatar = [self imageName:@"Common/Index/DefaultAvatar"];
        self.defaultPlaceholder = [self placeholderImageWithSize:CGSizeMake(114.0f, 114.0f) image:[self imageName:@"Common/Index/Placeholder"]];
        
        self.defaultStickerPlaceholder = [self placeholderImageWithSize:CGSizeMake(114.0f, 114.0f) image:[self imageName:@"Common/Index/Placeholder"]];
        
        // Text primary #1F2329
        self.defaultTextColor = [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
        self.imageCacheDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"image"];
        
        self.fileStorageDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"wukongfiles"];
        
        self.imageMaxLimitBytes = 1024 * 500;
        
        // Soft warning (lower saturation than pure red)
        self.warnColor = [UIColor colorWithRed:0xDE/255.0f green:0x64/255.0f blue:0x5C/255.0f alpha:1.0f]; // #DE645C
        self.defaultFont = [self appFontOfSize:16.0f];
         // ---------- 消息相关 ----------
        self.messageTextFontSize = 16.0f;
        self.messageTipTimeFontSize = 14.0f;
        self.messageAvatarSize = CGSizeMake(40.0f, 40.0f);
        self.smallAvatarSize = CGSizeMake(24.0f, 24.0f);
        self.middleAvatarSize = CGSizeMake(48.0f, 48.0f);
        self.bigAvatarSize = CGSizeMake(96.0f, 96.0f);
        self.messageListAvatarSize =  CGSizeMake(64.0f, 64.0f);
        self.messageContentMaxWidth = WKScreenWidth - (10.0f + self.messageAvatarSize.width + 10.0f) * 2;
        self.systemMessageContentMaxWidth = WKScreenWidth - 60.0f;
        // Soft tip on pale send bubbles (was white@0.55 on solid orange)
        self.messageTipColor = [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
        self.unkownMessageText = @"[不支持的消息类型，或许可升级版本后查看]";
        self.signalErrorMessageText = @"[消息无法解密，因为双方密钥有发送变更]";
        self.messageTipTimeInterval = 60 * 5;
        self.messageTextMaxBytes = 1024*2;
        
        // ---------- 导航栏相关 ----------
        self.navBarTitleFont =  [self appFontOfSizeMedium:17.0f];
        self.navBackgroudColor =[self navBackgroudColorWithAlpha:1.0f];
        self.settingMemberAvatarSize = CGSizeMake(32.0f, 32.0f);
        // Secondary text #8F959E (static seed; getter is dynamic)
        self.tipColor = [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
        self.navHeight = 44.0f + [UIApplication sharedApplication].statusBarFrame.size.height;
        
        // 数据每页默认请求大小
        self.pageSize = 20;
        // 每页消息数量
        self.eachPageMsgLimit = 30;
        CGRect statusFrame = [UIApplication sharedApplication].statusBarFrame;
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets safeAreaInsets = [UIApplication sharedApplication].keyWindow.safeAreaInsets;
            UIEdgeInsets insets = UIEdgeInsetsMake(statusFrame.origin.y+statusFrame.size.height, 0.0f, safeAreaInsets.bottom, 0.0f);
            self.visibleEdgeInsets = insets;
        }
        
        self.inviteMsg = [NSString stringWithFormat:@"我正在使用【%@】app，体验还不错。你也赶快来下载玩玩吧！https://www.githubim.cn",self.appName];
        NSString *tempDir= NSTemporaryDirectory();
        self.videoCacheDir = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"wukong_video_cache"]];
        [WKFileUtil createDirectoryIfNotExist: self.videoCacheDir];
        
        self.systemUID = @"u_10000";
        self.fileHelperUID = @"fileHelper";
        
        self.contextMenu = [[WKThemeContextMenu alloc] init];
        
        self.defaultAnimationDuration = 0.25f;
    }
    return self;
}

- (void)setStyle:(WKSystemStyle)style {
    _innerStyle = style;
    if(style == WKSystemStyleDark) {
        [WKApp shared].loginInfo.extra[@"systemStyle"] = @"dark";
        [[WKApp shared].loginInfo save];
    }else {
        [WKApp shared].loginInfo.extra[@"systemStyle"] = @"light";
        [[WKApp shared].loginInfo save];
    }
    [self applyWindowInterfaceStyle];
}

- (void)applyWindowInterfaceStyle {
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle uiStyle;
        if (self.darkModeWithSystem) {
            // Critical: Unspecified so the app tracks system day/night.
            uiStyle = UIUserInterfaceStyleUnspecified;
        } else if (self.style == WKSystemStyleDark) {
            uiStyle = UIUserInterfaceStyleDark;
        } else {
            uiStyle = UIUserInterfaceStyleLight;
        }
        UIApplication *app = [UIApplication sharedApplication];
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                window.overrideUserInterfaceStyle = uiStyle;
            }
        }
        if (app.keyWindow) {
            app.keyWindow.overrideUserInterfaceStyle = uiStyle;
        }
        BOOL dark;
        if (self.darkModeWithSystem) {
            dark = (UIScreen.mainScreen.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        } else {
            dark = (self.style == WKSystemStyleDark);
        }
        app.statusBarStyle = dark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
    }
}

- (NSString *)bundleID {
    if(!_bundleID) {
        _bundleID =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    }
    return _bundleID;
}

- (WKSystemStyle)style {
    if(_innerStyle == WKSystemStyleUnknown) {
       NSString *mode = [WKApp shared].loginInfo.extra[@"systemStyle"];
        if(mode && [mode isEqualToString:@"dark"]) {
            _innerStyle = WKSystemStyleDark;
        }else {
            _innerStyle = WKSystemStyleLight;
        }
    }
    return _innerStyle;
}

- (UIColor *)lineColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0x2B/255.0f green:0x2F/255.0f blue:0x36/255.0f alpha:1.0f]; // #2B2F36
            }
            return [UIColor colorWithRed:0xE5/255.0f green:0xE6/255.0f blue:0xEB/255.0f alpha:1.0f]; // #E5E6EB
        }];
    }
    return [UIColor colorWithRed:0xE5/255.0f green:0xE6/255.0f blue:0xEB/255.0f alpha:1.0f];
}

- (UIColor *)tipColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
        }];
    }
    return _tipColor ?: [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
}

- (WKBrandTheme)brandTheme {
    if (!self.innerBrandTheme) {
        NSString *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"lim_brand_theme"];
        if ([saved isEqualToString:@"blue"]) {
            self.innerBrandTheme = @(WKBrandThemeBlue);
        } else {
            self.innerBrandTheme = @(WKBrandThemeOrange);
        }
    }
    return (WKBrandTheme)self.innerBrandTheme.unsignedIntegerValue;
}

- (void)setBrandTheme:(WKBrandTheme)brandTheme {
    if (self.innerBrandTheme && self.innerBrandTheme.unsignedIntegerValue == brandTheme) {
        return;
    }
    self.innerBrandTheme = @(brandTheme);
    [[NSUserDefaults standardUserDefaults] setObject:(brandTheme == WKBrandThemeBlue ? @"blue" : @"orange")
                                              forKey:@"lim_brand_theme"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_BRAND_THEME_CHANGE object:nil];
}

- (NSString *)brandThemeDisplayName {
    switch (self.brandTheme) {
        case WKBrandThemeBlue:
            return LLang(@"荧光蓝");
        case WKBrandThemeOrange:
        default:
            return LLang(@"荧光橙");
    }
}

- (UIColor *)themeColor {
    // Brand accent — orange or blue; slightly lighter in dark mode for contrast
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark);
            if (self.brandTheme == WKBrandThemeBlue) {
                if (dark) {
                    return [UIColor colorWithRed:0x00/255.0f green:0xC6/255.0f blue:0xFF/255.0f alpha:1.0f]; // #00C6FF
                }
                return [UIColor colorWithRed:0x00/255.0f green:0x66/255.0f blue:0xFF/255.0f alpha:1.0f]; // #0066FF
            }
            if (dark) {
                return [UIColor colorWithRed:0xFF/255.0f green:0x6B/255.0f blue:0x35/255.0f alpha:1.0f]; // #FF6B35
            }
            return [UIColor colorWithRed:0xFF/255.0f green:0x45/255.0f blue:0x00/255.0f alpha:1.0f]; // #FF4500
        }];
    }
    if (self.brandTheme == WKBrandThemeBlue) {
        return [UIColor colorWithRed:0x00/255.0f green:0x66/255.0f blue:0xFF/255.0f alpha:1.0f];
    }
    return _themeColor ?: [UIColor colorWithRed:0xFF/255.0f green:0x45/255.0f blue:0x00/255.0f alpha:1.0f];
}

// 跟随系统
- (BOOL)darkModeWithSystem {
    if(!self.innerdarkModeWithSystem) {
        NSString *darkModeWithSystem = [WKApp shared].loginInfo.extra[@"darkModeWithSystem"];
        if([darkModeWithSystem isEqualToString:@"off"]) {
            self.innerdarkModeWithSystem = @(NO);
        } else {
            // Default ON when unset / "on" / empty
            self.innerdarkModeWithSystem = @(YES);
        }
    }
    return self.innerdarkModeWithSystem.boolValue;
}

- (void)setDarkModeWithSystem:(BOOL)darkModeWithSystem {
    self.innerdarkModeWithSystem = @(darkModeWithSystem);
    
    [WKApp shared].loginInfo.extra[@"darkModeWithSystem"] = darkModeWithSystem?@"on":@"off";
    [[WKApp shared].loginInfo save];
    if (darkModeWithSystem) {
        // Sync style from real system appearance (window must be Unspecified first).
        [self applyWindowInterfaceStyle];
        if (@available(iOS 13.0, *)) {
            if (UIScreen.mainScreen.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                _innerStyle = WKSystemStyleDark;
                [WKApp shared].loginInfo.extra[@"systemStyle"] = @"dark";
            } else {
                _innerStyle = WKSystemStyleLight;
                [WKApp shared].loginInfo.extra[@"systemStyle"] = @"light";
            }
            [[WKApp shared].loginInfo save];
        }
        [self applyWindowInterfaceStyle];
    } else {
        [self applyWindowInterfaceStyle];
    }
}

- (UIColor *)navBackgroudColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0x17/255.0f green:0x18/255.0f blue:0x1A/255.0f alpha:1.0f]; // #17181A
            }
            return [UIColor colorWithRed:0xF5/255.0f green:0xF6/255.0f blue:0xF7/255.0f alpha:1.0f]; // #F5F6F7
        }];
    }
    return _navBackgroudColor;
}

- (UIColor *)backgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0x17/255.0f green:0x18/255.0f blue:0x1A/255.0f alpha:1.0f]; // #17181A
            }
            return [UIColor colorWithRed:0xF5/255.0f green:0xF6/255.0f blue:0xF7/255.0f alpha:1.0f]; // #F5F6F7
        }];
    }
    return _backgroundColor;
}

- (UIColor *)cellBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f]; // #1F2329
            }
            return [UIColor whiteColor];
        }];
    }
    return [UIColor whiteColor];
}

- (UIColor *)defaultTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0xC9/255.0f green:0xCD/255.0f blue:0xD4/255.0f alpha:1.0f]; // #C9CDD4
            }
            return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f]; // #1F2329
        }];
    }
    return _defaultTextColor;
}
- (UIColor *)navBarTitleColor {
    if(!_navBarTitleColor) {
        return [self defaultTextColor];
    }
    return _navBarTitleColor;
}

- (UIColor *)navBarSubtitleColor {
    if(!_navBarSubtitleColor) {
        return [self tipColor];
    }
    return _navBarSubtitleColor;
}

- (UIColor *)navBarButtonColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0xC9/255.0f green:0xCD/255.0f blue:0xD4/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
        }];
    }
    return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
}


- (UIColor *)messageSendBubbleColor {
    // Soft send bubble aligned with current brand theme
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark);
            if (self.brandTheme == WKBrandThemeBlue) {
                if (dark) {
                    return [UIColor colorWithRed:0x1A/255.0f green:0x2F/255.0f blue:0x55/255.0f alpha:1.0f]; // #1A2F55
                }
                return [UIColor colorWithRed:0xD6/255.0f green:0xE8/255.0f blue:0xFF/255.0f alpha:1.0f]; // #D6E8FF
            }
            if (dark) {
                return [UIColor colorWithRed:0x55/255.0f green:0x2B/255.0f blue:0x1A/255.0f alpha:1.0f]; // #552B1A
            }
            return [UIColor colorWithRed:0xFF/255.0f green:0xE4/255.0f blue:0xD6/255.0f alpha:1.0f]; // #FFE4D6
        }];
    }
    if (self.brandTheme == WKBrandThemeBlue) {
        return [UIColor colorWithRed:0xD6/255.0f green:0xE8/255.0f blue:0xFF/255.0f alpha:1.0f];
    }
    return _messageSendBubbleColor ?: [UIColor colorWithRed:0xFF/255.0f green:0xE4/255.0f blue:0xD6/255.0f alpha:1.0f];
}

- (UIColor *)messageSendTextColor {
    // Dark text on pale send bubbles (Feishu)
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0xC9/255.0f green:0xCD/255.0f blue:0xD4/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
        }];
    }
    return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
}

- (UIColor *)messageTipColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
        }];
    }
    return _messageTipColor ?: [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
}
- (UIColor *)messageRecvTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0xC9/255.0f green:0xCD/255.0f blue:0xD4/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
        }];
    }
    return [UIColor colorWithRed:0x1F/255.0f green:0x23/255.0f blue:0x29/255.0f alpha:1.0f];
}

- (void)setReportUrl:(NSString *)reportUrl {
    _innerReportUrl = reportUrl;
}

- (NSString *)reportUrl {
    if(_innerReportUrl) {
        if([_innerReportUrl containsString:@"?"]) {
            return [NSString stringWithFormat:@"%@&lang=%@&uid=%@&token=%@&mode=%@",_innerReportUrl,self.langue,[WKApp shared].loginInfo.uid,[WKApp shared].loginInfo.token,self.style==WKSystemStyleDark?@"dark":@"light"];
        }
        return [NSString stringWithFormat:@"%@?lang=%@&uid=%@&token=%@&mode=%@",_innerReportUrl,self.langue,[WKApp shared].loginInfo.uid,[WKApp shared].loginInfo.token,self.style==WKSystemStyleDark?@"dark":@"light"];
    }
    return _innerReportUrl;
}


/**
 传入需要的占位图尺寸 获取占位图

 @param size 需要的站位图尺寸
 @return 占位图
 */
- (UIImage *)placeholderImageWithSize:(CGSize)size image:(UIImage*)image{
    
    // 占位图的背景色
    UIColor *backgroundColor = [UIColor whiteColor];
    // 根据占位图需要的尺寸 计算 中间LOGO的宽高
    CGFloat logoWH = (size.width > size.height ? size.height : size.width) * 0.5;
    CGSize logoSize = CGSizeMake(logoWH, logoWH);
    // 打开上下文
    UIGraphicsBeginImageContextWithOptions(size,0, [UIScreen mainScreen].scale);
    // 绘图
    [backgroundColor set];
    UIRectFill(CGRectMake(0,0, size.width, size.height));
    CGFloat imageX = (size.width / 2) - (logoSize.width / 2);
    CGFloat imageY = (size.height / 2) - (logoSize.height / 2);
    [image drawInRect:CGRectMake(imageX, imageY, logoSize.width, logoSize.height)];
    UIImage *resImage =UIGraphicsGetImageFromCurrentImageContext();
    // 关闭上下文
    UIGraphicsEndImageContext();
    
    return resImage;
    
}

-(UIFont*) appFontOfSize:(CGFloat)size {
    return [UIFont fontWithName:@"PingFangSC-Regular" size:size];
}
-(UIFont*) appFontOfSizeSemibold:(CGFloat)size {
    return [UIFont fontWithName:@"PingFangSC-Semibold" size:size];
}
-(UIFont*) appFontOfSizeMedium:(CGFloat)size {
    return [UIFont fontWithName:@"PingFangSC-Medium" size:size];
}

- (NSString *)fileBrowseUrl {
    if(!_fileBrowseUrl) {
        return _fileBaseUrl;
    }
    return _fileBrowseUrl;
}

-(NSString*) scanURLPrefix {
    if(!_scanURLPrefix) {
        return [NSString stringWithFormat:@"%@%@",_apiBaseUrl,@"qrcode/"];
    }
    return _scanURLPrefix;
}
-(UIImage*) imageName:(NSString*)name {
//    NSBundle *bundle = [WKResource.shared imageBundleInClass:self.class];
    return [WKResource.shared imageNamed:name inClass:self.class];
//    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

- (UIColor *)navBackgroudColorWithAlpha:(CGFloat) alpha{
    // Feishu page gray #F5F6F7
    return [UIColor colorWithRed:0xF5/255.0f green:0xF6/255.0f blue:0xF7/255.0f alpha:alpha];
}

//    zh-Hans 中文 en 英语  俄罗斯语  ru  蒙古语 mn  bo-CN 藏语   fr 法语
//    kk-KZ 哈萨克语
//    tk-TM 土耳其语  ky-KG 柯尔克孜 ug 维吾尔语
//    it-CH 意大利语简称
- (NSString *)langue {
    if(!_innerLangue) {
        NSString *lang = [[NSUserDefaults standardUserDefaults] objectForKey:@"lim_langue"];
        if(!lang || [lang isEqualToString:@""]) {
            return @"zh-Hans";
        }
        _innerLangue = lang;
    }
    return _innerLangue;
}

- (void)setLangue:(NSString *)langue {
    BOOL needNotify = false;
    if(!_innerLangue && langue) {
        needNotify = true;
    }
    if(_innerLangue && langue && ![_innerLangue isEqualToString:langue]) {
        needNotify = true;
    }
    _innerLangue = langue;
    [[NSUserDefaults standardUserDefaults] setObject:langue forKey:@"lim_langue"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if(needNotify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_LANG_CHANGE object:nil];
    }
    if(langue && [langue isEqualToString:@"zh-Hans"]) {
        [ZLPhotoUIConfiguration default].languageType = ZLLanguageTypeChineseSimplified;
    }else{
        [ZLPhotoUIConfiguration default].languageType = ZLLanguageTypeEnglish;
    }
    
}

-(void) setThemeStyleButton:(UIButton*)btn {
//    NSString *name = @"btn_theme_layer";
//    CAGradientLayer *gl = [CAGradientLayer layer];
//    gl.name = name;
//    gl.frame =btn.bounds;
//    gl.startPoint = CGPointMake(0, 0);
//    gl.endPoint = CGPointMake(1, 1);
//    if(self.style == WKSystemStyleDark) {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:63/255.0 green:64/255.0 blue:185/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:113/255.0 green:68/255.0 blue:178/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }else {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:78/255.0 green:80/255.0 blue:252/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:149/255.0 green:85/255.0 blue:241/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }
//
//    NSArray<CALayer*> *layers = [btn.layer sublayers];
//    if(layers) {
//        for (CALayer *layer in layers) {
//            if(layer.name && [layer.name isEqualToString:name]) {
//                [layer removeFromSuperlayer];
//                break;
//            }
//        }
//    }
//    [btn.layer insertSublayer:gl atIndex:0];
}

-(void) setThemeStyleNavigation:(UIView*)view {
//    NSString *name = @"btn_theme_layer";
//    CAGradientLayer *gl = [CAGradientLayer layer];
//    gl.name = name;
//    gl.frame =view.bounds;
//    gl.startPoint = CGPointMake(0, 0);
//    gl.endPoint = CGPointMake(1, 1);
//    if(self.style == WKSystemStyleDark) {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:63/255.0 green:64/255.0 blue:185/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:113/255.0 green:68/255.0 blue:178/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }else {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:78/255.0 green:80/255.0 blue:252/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:149/255.0 green:85/255.0 blue:241/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }
//
//    NSArray<CALayer*> *layers = [view.layer sublayers];
//    if(layers) {
//        for (CALayer *layer in layers) {
//            if(layer.name && [layer.name isEqualToString:name]) {
//                [layer removeFromSuperlayer];
//                break;
//            }
//        }
//    }
//    [view.layer insertSublayer:gl atIndex:0];
}


@end

@interface WKAppRemoteConfig ()

@property(nonatomic,assign) BOOL startRequest;

@property(nonatomic,assign) BOOL startRequestAppModule;

@end

@implementation WKAppRemoteConfig

-(void) requestConfig:(void(^)(NSError  * __nullable error))callback {
    
    __weak typeof(self) weakSelf = self;
    if(!self.requestSuccess && !self.startRequest) {
        self.startRequest = true;
        [[WKAPIClient sharedClient] GET:@"common/appconfig" parameters:@{}].then(^(NSDictionary *resultDict){
            weakSelf.webURL =  resultDict[@"web_url"]?:@"";
            if(resultDict[@"phone_search_off"]) {
                weakSelf.phoneSearchOff = [resultDict[@"phone_search_off"] boolValue];
            }
            if(resultDict[@"shortno_edit_off"]) {
                weakSelf.shortnoEditOff = [resultDict[@"shortno_edit_off"] boolValue];
            }
            if(resultDict[@"revoke_second"]) {
                weakSelf.revokeSecond = [resultDict[@"revoke_second"] integerValue];
            }
            if(resultDict[@"register_invite_on"]) {
                weakSelf.registerInviteOn = [resultDict[@"register_invite_on"] boolValue];
            }
            
            if(resultDict[@"invite_system_account_join_group_on"]) {
                weakSelf.inviteSystemAccountJoinGroupOn =  [resultDict[@"invite_system_account_join_group_on"] boolValue];
            }
            if(resultDict[@"register_user_must_complete_info_on"]) {
                weakSelf.registerUserMustCompleteInfoOn = [resultDict[@"register_user_must_complete_info_on"] boolValue];
            }
           
            
            weakSelf.requestSuccess = true;
            weakSelf.startRequest = false;
            if(callback) {
                callback(nil);
            }
        }).catch(^(NSError *error){
            WKLogError(@"请求远程配置失败！->%@",error);
            weakSelf.startRequest = false;
            if(callback) {
                callback(error);
            }
        });
    }
    if(!self.requestAppModuleSuccess && !self.startRequestAppModule) {
        self.startRequestAppModule = true;
        [WKAPIClient.sharedClient GET:@"common/appmodule" parameters:@{} model:WKAppModuleResp.class].then(^(NSArray<WKAppModuleResp*> *models){
            weakSelf.modules = models;
            weakSelf.requestAppModuleSuccess = true;
            weakSelf.startRequestAppModule = false;
            if(callback) {
                callback(nil);
            }
        }).catch(^(NSError *error){
            weakSelf.startRequestAppModule = false;
            WKLogError(@"请求app模块失败！->%@",error);
            if(callback) {
                callback(error);
            }
        });
    }
    
    
}

-(void) modules:(NSString*)sid on:(BOOL)on {
    NSString *enableKey = @"modules_enable";
    NSString *disableKey = @"modules_disable";
    
    NSArray<NSString*> *enableModules =  WKApp.shared.loginInfo.extra[enableKey];
    
    NSArray<NSString*> *disableModules =  WKApp.shared.loginInfo.extra[disableKey];
    NSMutableArray *newEnableModules = [NSMutableArray arrayWithArray:enableModules];
    NSMutableArray *newDisableModules = [NSMutableArray arrayWithArray:disableModules];
    if(on) {
        if(![newEnableModules containsObject:sid]) {
            [newEnableModules addObject:sid];
        }
        if([newDisableModules containsObject:sid]) {
            [newDisableModules removeObject:sid];
        }
        WKApp.shared.loginInfo.extra[enableKey] = newEnableModules;
        WKApp.shared.loginInfo.extra[disableKey] = newDisableModules;
    }else {
        if(![newDisableModules containsObject:sid]) {
            [newDisableModules addObject:sid];
        }
        if([newEnableModules containsObject:sid]) {
            [newEnableModules removeObject:sid];
        }
        WKApp.shared.loginInfo.extra[enableKey] = newEnableModules;
        WKApp.shared.loginInfo.extra[disableKey] = newDisableModules;
    }
    [WKApp.shared.loginInfo save];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_MODULE_CHANGE object:nil];
}

- (BOOL)moduleOn:(NSString *)sid {
    NSArray<NSString*> *modules =  WKApp.shared.loginInfo.extra[@"modules_enable"];
    if(modules && [modules containsObject:sid]) {
        return true;
    }
    NSArray<NSString*> *disableModules = WKApp.shared.loginInfo.extra[@"modules_disable"];
    if(disableModules && [disableModules containsObject:sid]) {
        return false;
    }
//    return [self mustModule:sid];
    if(self.modules && self.modules.count>0) {
        WKAppModuleResp *existResp;
        for (WKAppModuleResp *resp in self.modules) {
            if([resp.sid isEqualToString:sid]) {
                existResp = resp;
                break;
            }
        }
        if(!existResp) {
            return true;
        }
        return existResp.status != WKAppModuleStatusDisable;
    }
    return true;
}

// 是否是必须支持的模块
static NSMutableArray *mustSupportModules;
-(BOOL) mustModule:(NSString*)sid {
    if(!mustSupportModules) {
        mustSupportModules = [NSMutableArray arrayWithArray:@[@"WuKongBase",@"WuKongLogin",@"WuKongContacts"]];
    }
    return [mustSupportModules containsObject:sid];
}

- (BOOL)moduleHasSetting:(NSString *)sid {
    NSArray<NSString*> *enableModules =  WKApp.shared.loginInfo.extra[@"modules_enable"];
    if(enableModules && [enableModules containsObject:sid]) {
        return true;
    }
    NSArray<NSString*> *disableModules = WKApp.shared.loginInfo.extra[@"modules_disable"];
    if(disableModules && [disableModules containsObject:sid]) {
        return true;
    }
    return false;
}

@end

@implementation WKThemeContextMenu

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (UIColor *)primaryColor {
    if(WKApp.shared.config.style == WKSystemStyleDark) {
        return [UIColor colorWithRed:255.0f green:255.0f blue:255.0f alpha:1.0f];
    }
    return [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
}


@end

@implementation WKAppModuleResp

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKAppModuleResp *resp = [WKAppModuleResp new];
    
    NSString *sid = dictory[@"sid"]?:@"";
    if([sid isEqualToString:@"base"]) {
        sid = @"WuKongBase";
    }else if([sid isEqualToString:@"login"]) {
        sid = @"WuKongLogin";
    }else if([sid isEqualToString:@"scan"]) {
        sid = @"WuKongScan";
        resp.hidden = YES;
    }else if([sid isEqualToString:@"push"]) {
        sid = @"WuKongPush";
        resp.hidden = YES;
    }else if([sid isEqualToString:@"rtc"]) {
        sid = @"WuKongRTC";
    }else if([sid isEqualToString:@"moment"]) {
        sid = @"WuKongMoment";
    }else if([sid isEqualToString:@"sticker"]) {
        sid = @"WuKongStickerStore";
    }else if([sid isEqualToString:@"advanced"]) {
        sid = @"WuKongAdvanced";
    }else if([sid isEqualToString:@"groupManager"]) {
        sid = @"WuKongGroupManager";
    }else if([sid isEqualToString:@"wallet"]) {
        sid = @"WuKongWallet";
    }else if([sid isEqualToString:@"redpacket"]) {
        sid = @"WuKongRedPackets";
    }else if([sid isEqualToString:@"transfer"]) {
        sid = @"WuKongTransfer";
    }else if([sid isEqualToString:@"security"]) {
        sid = @"WuKongSecurity";
        resp.hidden = YES;
    }else if([sid isEqualToString:@"video"]) {
        sid = @"WuKongSmallVideo";
    }else if([sid isEqualToString:@"favorite"]) {
        sid = @"WuKongFavorite";
    }else if([sid isEqualToString:@"file"]) {
        sid = @"WuKongFile";
    }else if([sid isEqualToString:@"map"]) {
        sid = @"WuKongLocation";
    }else if([sid isEqualToString:@"customerService"]) {
        sid = @"WuKongCustomerService";
    }else if([sid isEqualToString:@"rich"]) {
        sid = @"WuKongRichTextEditor";
    }else if([sid isEqualToString:@"label"]) {
        sid = @"WuKongLabel";
    }
    resp.sid = sid;
    resp.name = dictory[@"name"]?:@"";
    resp.status = [dictory[@"status"] integerValue];
    resp.desc = dictory[@"desc"]?:@"";
    return resp;
}
@end
