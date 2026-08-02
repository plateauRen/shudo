//
//  WKConversationListHeaderView.m
//  WuKongBase
//
//  Created by tt on 2021/9/17.
//

#import "WKConversationListHeaderView.h"
#import "WuKongBase.h"
#import "WKSearchbarView.h"
#import "WKGlobalSearchResultController.h"
#import "WKPCOnlineVC.h"
#import "WKLiquidGlassHelper.h"
#define networkErrorViewHeight 50.0f

@interface WKConversationListHeaderView ()

@property(nonatomic,strong) UIView *contentView;

@property(nonatomic,assign) BOOL showEmpty; // 是否显示空白部分

// ---------- 网络错误 ----------
@property(nonatomic,strong) UIView *networkErroView; // 网络错误视图
@property(nonatomic,strong) UILabel *warnLbl;

// ---------- 搜索bar ----------
@property(nonatomic,strong) UIView *searchbarBoxView;
@property(nonatomic,strong) WKSearchbarView *searchbarView;

// ---------- pc在线 ----------

@property(nonatomic,strong) WKPCOnlineBarView *pcOnlineBarView;
@property(nonatomic,strong,nullable) UIVisualEffectView *pcOnlineGlassView;



@end

@implementation WKConversationListHeaderView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 0.0f)];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    [self addSubview:self.contentView];
    // 搜索在导航栏；header 仅在有网络错误等横幅时占高度，默认零高
    _showEmpty = false;
    [self collapseIfNeeded];
}

- (void)viewConfigChange:(WKViewConfigChangeType)type{
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.networkErroView.backgroundColor = [UIColor colorWithRed:115.0f/255.0f green:46.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
        self.warnLbl.textColor = [UIColor colorWithRed:142.0f/255.0f green:142.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
    }else{
        self.warnLbl.textColor = [UIColor colorWithRed:231.0f/255.0f green:88.0f/255.0f blue:73.0f/255.0f alpha:1.0f];
        self.networkErroView.backgroundColor = [UIColor colorWithRed:251.0f/255.0f green:234.0f/255.0f blue:231.0f/255.0f alpha:1.0f];
    }
    if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
        [self.pcOnlineBarView setBackgroundColor:[UIColor clearColor]];
        self.tableHeaderBottomEmptyView.backgroundColor = [UIColor clearColor];
    } else {
        [self.pcOnlineBarView setBackgroundColor:[WKApp shared].config.backgroundColor];
    }
}

- (void)setShowEmpty:(BOOL)showEmpty {
    if(_showEmpty == showEmpty) {
        return;
    }
    _showEmpty = showEmpty;
    
    [self.tableHeaderBottomEmptyView removeFromSuperview];
    if(showEmpty) {
        [self.contentView addSubview:self.tableHeaderBottomEmptyView];
    }
    [self layoutSubviews];
}

- (void)setShowNetworkError:(BOOL)showNetworkError {
    if(_showNetworkError == showNetworkError) {
        return;
    }
    _showNetworkError = showNetworkError;
    
    [self.networkErroView removeFromSuperview];
    // 不再用空白占位条；无横幅时 header 高度为 0，避免分组 Tab 下出现大块空隙
    self.showEmpty = NO;
    if(showNetworkError) {
        [self.contentView addSubview:self.networkErroView];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            self.networkErroView.backgroundColor = [UIColor colorWithRed:115.0f/255.0f green:46.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
            self.warnLbl.textColor = [UIColor colorWithRed:142.0f/255.0f green:142.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
        }else{
            self.warnLbl.textColor = [UIColor colorWithRed:231.0f/255.0f green:88.0f/255.0f blue:73.0f/255.0f alpha:1.0f];
            self.networkErroView.backgroundColor = [UIColor colorWithRed:251.0f/255.0f green:234.0f/255.0f blue:231.0f/255.0f alpha:1.0f];
        }
    }
    [self layoutSubviews];
}

- (void)setShowPCOnline:(BOOL)showPCOnline {
    // 网页/电脑已登录提示改放到会话列表导航栏左上角，不再占列表顶部独立行
    if (_showPCOnline == showPCOnline) {
        return;
    }
    _showPCOnline = showPCOnline;
    [self.pcOnlineBarView removeFromSuperview];
    self.showEmpty = NO;
    [self layoutSubviews];
}

- (void)collapseIfNeeded {
    [self.pcOnlineBarView removeFromSuperview];
    [self.tableHeaderBottomEmptyView removeFromSuperview];
    if (!self.showNetworkError) {
        [self.networkErroView removeFromSuperview];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 确保旧的 PC 在线条 / 空白占位不会残留
    [self.pcOnlineBarView removeFromSuperview];
    if (!self.showEmpty) {
        [self.tableHeaderBottomEmptyView removeFromSuperview];
    }
    
    NSArray *subviews = self.contentView.subviews;
    
    UIView *preView;
    for (UIView *view in subviews) {
        if(!preView) {
            view.lim_top = 0.0f;
        }else {
            view.lim_top = preView.lim_bottom;
        }
        view.lim_centerX_parent = self.contentView;
        preView = view;
    }
    if (!preView) {
        self.contentView.lim_height = 0.0f;
        self.lim_size = CGSizeMake(WKScreenWidth, 0.0f);
        self.bounds = CGRectMake(0, 0, WKScreenWidth, 0);
        return;
    }
    self.contentView.lim_height = preView.lim_bottom;
    self.lim_size = self.contentView.lim_size;
    self.bounds = CGRectMake(0, 0, self.lim_width, self.lim_height);
}

- (UIView *)networkErroView {
    if(!_networkErroView) {
        _networkErroView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, networkErrorViewHeight)];
        UIImageView *warnIcon = [[UIImageView alloc] initWithFrame:CGRectMake(20.0f, 0.0f, 26.0f, 26.0f)];
        [warnIcon setImage:[self imageName:@"ConversationList/Index/NetworkStatusFail"]];
        warnIcon.lim_top = _networkErroView.lim_height/2.0f - warnIcon.lim_height/2.0f;
        [_networkErroView addSubview:warnIcon];
        
         _warnLbl = [[UILabel alloc] init];
        [_warnLbl setText:LLang(@"当前网络不可用，请检查网络设置")];
        [_warnLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_warnLbl sizeToFit];
        _warnLbl.lim_top = _networkErroView.lim_height/2.0f - _warnLbl.lim_height/2.0f;
        _warnLbl.lim_left = warnIcon.lim_right + 20.0f;
        [_networkErroView addSubview:_warnLbl];
    }
    return _networkErroView;
}

- (WKSearchbarView *)searchbarView {
    if(!_searchbarView) {
        _searchbarView = [[WKSearchbarView alloc] initWithFrame:CGRectMake(15.0f, 0.0f, WKScreenWidth - 30.0f, 36.0f)];
        _searchbarView.placeholder = LLang(@"搜索");
    }
    return _searchbarView;
}

- (UIView *)tableHeaderBottomEmptyView {
    if(!_tableHeaderBottomEmptyView) {
        _tableHeaderBottomEmptyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 6.0f)];
        UIColor *fill = [WKLiquidGlassHelper isLiquidGlassAvailable]
            ? [UIColor clearColor]
            : [UIColor whiteColor];
        [_tableHeaderBottomEmptyView setBackgroundColor:fill];
    }
    return _tableHeaderBottomEmptyView;
   
}

- (UIView *)searchbarBoxView {
    if(!_searchbarBoxView) {
        _searchbarBoxView = [[UIView alloc] init];
        _searchbarBoxView.lim_size = CGSizeMake(self.searchbarView.bounds.size.width, self.searchbarView.bounds.size.height + 10.0f);
    }
    return _searchbarBoxView;
}

- (UIView *)contentView {
    if(!_contentView) {
        _contentView = [[UIView alloc] init];
        _contentView.lim_size = self.lim_size;
    }
    return _contentView;
}

- (WKPCOnlineBarView *)pcOnlineBarView {
    if(!_pcOnlineBarView) {
        _pcOnlineBarView = [[WKPCOnlineBarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 48.0f)];
        if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
            [_pcOnlineBarView setBackgroundColor:[UIColor clearColor]];
            self.pcOnlineGlassView = [WKLiquidGlassHelper installInView:_pcOnlineBarView
                                                          cornerRadius:14
                                                           interactive:YES
                                                            solidColor:nil];
            CGFloat inset = 12.0f;
            self.pcOnlineGlassView.frame = CGRectMake(inset, 4.0f, WKScreenWidth - inset * 2.0f, 40.0f);
        } else {
            [_pcOnlineBarView setBackgroundColor:[WKApp shared].config.backgroundColor];
        }
        _pcOnlineBarView.userInteractionEnabled = YES;
        [_pcOnlineBarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onPCOnlineTap)]];
    }
    return _pcOnlineBarView;
}

-(void) onPCOnlineTap {
    WKPCOnlineVC *vc = [WKPCOnlineVC new];
    vc.mute = WKOnlineStatusManager.shared.muteOfApp;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(UIImage*) imageName:(NSString*)name {
    return LImage(name);
}

@end


@interface WKPCOnlineBarView ()

@property(nonatomic,strong) UIImageView *iconImgView;



@end

@implementation WKPCOnlineBarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.iconImgView];
        [self addSubview:self.tipLbl];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.iconImgView.lim_left = 32.0f;
    self.iconImgView.lim_centerY_parent = self;
    
    self.tipLbl.lim_left = self.iconImgView.lim_right + 28.0f;
    self.tipLbl.lim_centerY_parent = self;
    
    
}

- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
        _iconImgView.image = [self imageName:@"ConversationList/Index/PCOnline"];
    }
    return _iconImgView;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.textColor = [UIColor grayColor];
        _tipLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    }
    return _tipLbl;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
