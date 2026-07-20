//
//  WKLogicView.m
//  WuKongLogin
//
//  Created by tt on 2019/12/2.
//

#import "WKLoginView.h"
#import <Masonry/Masonry.h>
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WKImageView.h>
#import <WuKongBase/WKButton.h>
#import "WKCountrySelectVC.h"
#import "WKRegisterVC.h"
#import "WKForgetPasswordVC.h"
#import "WKAuthWebViewVC.h"
#import "WKLoginSettingVC.h"
@interface WKLoginView() <UITextFieldDelegate> {
}

@property(nonatomic,strong) UIImageView *bgImgView; // 背景图
@property(nonatomic,strong) UIButton *settingBtn; // 服务器配置
@property(nonatomic,strong) UILabel *welcomeTitleLbl; // 欢迎标题

// ---------- 手机号输入相关 ----------
@property(nonatomic,strong) UIView *mobileBoxView; // 手机号输入的box view
@property(nonatomic,strong) UIButton *countryBtn; // 国家区号
@property(nonatomic,strong) UIImageView *downArrowView; // 向下的小箭头
@property(nonatomic,strong) UIView *countrySpliteLineView; // 分割线
@property(nonatomic,strong) UITextField *mobileTextField; // 手机输入
@property(nonatomic,strong) UIView *mobileBottomLineView; // 手机号底部输入线

// ---------- 密码输入相关 ----------
@property(nonatomic,strong) UIView *passwordBoxView; // 密码输入的box view
@property(nonatomic,strong) UIView *passwordBottomLineView; // 密码底部输入线
@property(nonatomic,strong) UITextField *passwordTextField; // 密码输入
@property(nonatomic,strong) UIButton *eyeBtn; // 眼睛关闭

// ---------- 底部相关 ----------
@property(nonatomic,strong) UIButton *forgetPwdBtn; // 忘记密码
@property(nonatomic,strong) UIButton *loginBtn; // 登录按钮
@property(nonatomic,strong) UILabel *registerTipLbl; // 注册提示
@property(nonatomic,strong) UIButton *registerBtn; // 注册


@end

@implementation WKLoginView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _country = @"86";
    
    [self addSubview:self.bgImgView];
    [self addSubview:self.settingBtn];
    [self addSubview:self.welcomeTitleLbl];
    
    [self addSubview:self.mobileBoxView];
    [self.mobileBoxView addSubview:self.countryBtn];
    [self updateCountryBtnTitle];
    [self.mobileBoxView addSubview:self.downArrowView];
    [self.mobileBoxView addSubview:self.countrySpliteLineView];
    [self.mobileBoxView addSubview:self.mobileTextField];
    [self.mobileBoxView addSubview:self.mobileBottomLineView];
    [self.mobileTextField addTarget:self action:@selector(accountTextChanged:) forControlEvents:UIControlEventEditingChanged];
    
    [self addSubview:self.passwordBoxView];
    [self.passwordBoxView addSubview:self.passwordBottomLineView];
    [self.passwordBoxView addSubview:self.passwordTextField];
    [self.passwordBoxView addSubview:self.eyeBtn];
    
    [self addSubview:self.forgetPwdBtn];
    [self addSubview:self.loginBtn];
    [self addSubview:self.registerTipLbl];
    [self addSubview:self.registerBtn];
    
    [self.mobileTextField addTarget:self action:@selector(accountTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [self refreshAccountInputLayout];
    
    return self;
}

#pragma mark -- 视图初始化

// ---------- 背景图片 ----------
- (UIImageView *)bgImgView {
    if(!_bgImgView) {
        _bgImgView = [[UIImageView alloc] initWithImage:[[WKApp shared] loadImage:@"Background" moduleID:@"WuKongLogin"]];
        _bgImgView.frame = self.bounds;
    }
    return _bgImgView;
}

// ---------- 服务器配置 ----------
- (UIButton *)settingBtn {
    if(!_settingBtn) {
        _settingBtn = [[UIButton alloc] init];
        _settingBtn.lim_size = CGSizeMake(44.0f, 44.0f);
        // 优先系统齿轮（对比度稳定）；模块图作回退
        UIImage *icon = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
            icon = [UIImage systemImageNamed:@"gearshape.fill" withConfiguration:cfg];
        }
        if (!icon) {
            icon = [[WKApp shared] loadImage:@"Setting" moduleID:@"WuKongLogin"];
        }
        [_settingBtn setImage:icon forState:UIControlStateNormal];
        _settingBtn.tintColor = [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0];
        _settingBtn.accessibilityLabel = @"服务器配置";
        _settingBtn.accessibilityIdentifier = @"login.server.settings";
        [_settingBtn addTarget:self action:@selector(settingPressed) forControlEvents:UIControlEventTouchUpInside];
        [self layoutSettingBtn];
    }
    return _settingBtn;
}

- (void)layoutSettingBtn {
    if (!_settingBtn) { return; }
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.safeAreaInsets.top;
    }
    if (safeTop < 1.0f) {
        safeTop = WKApp.shared.config.visibleEdgeInsets.top;
    }
    if (safeTop < 44.0f) { safeTop = 47.0f; }
    CGFloat width = self.bounds.size.width > 1 ? self.bounds.size.width : WKScreenWidth;
    _settingBtn.frame = CGRectMake(width - 44.0f - 16.0f, safeTop + 4.0f, 44.0f, 44.0f);
    [self bringSubviewToFront:_settingBtn];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutSettingBtn];
}

-(void) settingPressed {
    WKLoginSettingVC *vc = [WKLoginSettingVC new];
    [WKNavigationManager.shared pushViewController:vc animated:YES];
}

// ---------- 欢迎标题 ----------
- (UILabel *)welcomeTitleLbl {
    if(!_welcomeTitleLbl) {
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:LLang(@"欢迎登录%@"),[WKApp shared].config.appName] attributes: @{NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Semibold" size: 32],NSForegroundColorAttributeName: [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0]}];
        _welcomeTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, 93, WKScreenWidth-60, 50)];
        _welcomeTitleLbl.attributedText = string;
        _welcomeTitleLbl.textAlignment = NSTextAlignmentLeft;
    }
    return _welcomeTitleLbl;
}

// ---------- 手机号输入 ----------

- (UIView *)mobileBoxView {
    if(!_mobileBoxView) {
        _mobileBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, 240.0f, WKScreenWidth, 40.0f)];
        //[_mobileBoxView setBackgroundColor:[UIColor redColor]];
        _mobileBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }
    return _mobileBoxView;
}
- (UIButton *)countryBtn {
    if(!_countryBtn) {
        _countryBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, self.mobileBoxView.lim_height/2.0f - 10.0f, 70.0f, 20.0f)];
        
        [[_countryBtn titleLabel] setFont:WKApp.shared.config.defaultFont];
        [_countryBtn setTitleColor:WKApp.shared.config.defaultTextColor forState:UIControlStateNormal];
        [_countryBtn addTarget:self action:@selector(countryBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _countryBtn;
}
-(void) updateCountryBtnTitle {
    [self.countryBtn setTitle:[NSString stringWithFormat:@"+ %@",_country] forState:UIControlStateNormal];
}
- (UIImageView *)downArrowView {
    if(!_downArrowView) {
        _downArrowView = [[UIImageView alloc] initWithFrame:CGRectMake(self.countryBtn.lim_right-12.0f, self.mobileBoxView.lim_height/2.0f - 6.0f, 12.0f, 12.0f)];
        [_downArrowView setImage:[[WKApp shared] loadImage:@"ArrowDown" moduleID:@"WuKongLogin"]];
    }
    return _downArrowView;
}
- (UIView *)countrySpliteLineView {
    if(!_countrySpliteLineView) {
        _countrySpliteLineView = [[UIView alloc] initWithFrame:CGRectMake(self.countryBtn.lim_right+10.0f,self.mobileBoxView.lim_height/2.0f - 5.0f,1,10)];
        _countrySpliteLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
       
    }
    return _countrySpliteLineView;
}

-(UITextField*) mobileTextField {
    if(!_mobileTextField) {
        CGFloat left =self.countrySpliteLineView.lim_right+20.0f;
        _mobileTextField = [[UITextField alloc] initWithFrame:CGRectMake(left, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth - left - 20.0f, 40.0f)];
        _mobileTextField.placeholder = LLang(@"请输入手机号或邮箱");
        _mobileTextField.keyboardType = UIKeyboardTypeEmailAddress;
        _mobileTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _mobileTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        _mobileTextField.textContentType = UITextContentTypeUsername;
        _mobileTextField.returnKeyType = UIReturnKeyNext;
        _mobileTextField.delegate = self;
    }
    return _mobileTextField;
}

- (UIView *)mobileBottomLineView {
    if(!_mobileBottomLineView) {
        _mobileBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _mobileBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;

    }
    return _mobileBottomLineView;
}

// ---------- 密码输入 ----------

- (UIView *)passwordBoxView {
    if(!_passwordBoxView) {
        _passwordBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.mobileBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
       // [_passwordBoxView setBackgroundColor:[UIColor grayColor]];
        _passwordBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }
    return _passwordBoxView;
}
- (UIView *)passwordBottomLineView {
    if(!_passwordBottomLineView) {
        _passwordBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _passwordBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _passwordBottomLineView;
}

- (UITextField *)passwordTextField {
    if(!_passwordTextField) {
        _passwordTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2 - 32.0f, 40.0f)];
        [_passwordTextField setPlaceholder:LLang(@"请输入登录密码")];
        _passwordTextField.returnKeyType = UIReturnKeyDone;
        _passwordTextField.secureTextEntry = YES;
        _passwordTextField.delegate = self;
        
    }
    return _passwordTextField;
}
- (UIButton *)eyeBtn {
    if(!_eyeBtn) {
        CGFloat width = 32.0f;
        CGFloat height = 32.0f;
        _eyeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.lim_width - 20.0f - width, self.passwordBoxView.lim_height/2.0f - (height)/2.0f, width, height)];
        [_eyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOff" moduleID:@"WuKongLogin"] forState:UIControlStateNormal];
        [_eyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOn" moduleID:@"WuKongLogin"] forState:UIControlStateSelected];
        _eyeBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_eyeBtn setImageEdgeInsets:UIEdgeInsetsMake(height/4.0f, width, height/4.0f,  width)];
        [_eyeBtn addTarget:self action:@selector(passwordLookPressed:) forControlEvents:UIControlEventTouchUpInside];
       // [_eyeBtn setBackgroundColor:[UIColor redColor]];
    }
    return _eyeBtn;
}

// ---------- 底部相关 ----------

// 忘记密码
- (UIButton *)forgetPwdBtn {
    if(!_forgetPwdBtn) {
        _forgetPwdBtn = [[UIButton alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_bottom+15.0f, 60.0f, 17.0f)];
        [_forgetPwdBtn setTitle:LLang(@"忘记密码?") forState:UIControlStateNormal];
        [_forgetPwdBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_forgetPwdBtn titleLabel] setFont:[UIFont systemFontOfSize:12.0f]];
        [_forgetPwdBtn addTarget:self action:@selector(forgetPwdPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _forgetPwdBtn;
}

-(void) forgetPwdPressed {
    WKForgetPasswordVC *vc = [WKForgetPasswordVC new];
    vc.country = self.country;
    vc.mobile = self.mobileTextField.text;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

// 登录
- (UIButton *)loginBtn {
    if(!_loginBtn) {
        _loginBtn = [[UIButton alloc] initWithFrame:CGRectMake(30.0f, self.passwordBoxView.lim_bottom+82.0f, WKScreenWidth - 60.0f, 40.0f)];
//        [_loginBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_loginBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_loginBtn setTitle:LLang(@"登录") forState:UIControlStateNormal];
        [_loginBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _loginBtn.layer.masksToBounds = YES;
        _loginBtn.layer.cornerRadius = 4.0f;
        [_loginBtn addTarget:self action:@selector(loginBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        
        [WKApp.shared.config setThemeStyleButton:_loginBtn];
        
    }
    return _loginBtn;
}

-(UILabel*) registerTipLbl {
    if(!_registerTipLbl) {
        _registerTipLbl = [[UILabel alloc] init];
        [_registerTipLbl setText:LLang(@"新用户？请")];
        [_registerTipLbl setFont:[UIFont systemFontOfSize:16.0f]];
        [_registerTipLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0]];
        [_registerTipLbl sizeToFit];
        _registerTipLbl.lim_top = self.loginBtn.lim_bottom + 25.0f;
        _registerTipLbl.lim_left = self.lim_width/2.0f - _registerTipLbl.lim_width/2.0f - 20.0f;
    }
    return _registerTipLbl;
}

- (UIButton *)registerBtn {
    if(!_registerBtn) {
        _registerBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.registerTipLbl.lim_right, self.registerTipLbl.lim_top-7.2f, 20.0f, 22.0f)];
        [_registerBtn setTitle:LLang(@"注册") forState:UIControlStateNormal];
        [_registerBtn sizeToFit];
        [_registerBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_registerBtn titleLabel] setFont:[UIFont systemFontOfSize:16.0f]];
        [_registerBtn addTarget:self action:@selector(toRegisterPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _registerBtn;
}


#pragma mark -- 公用方法

- (void)setCountry:(NSString *)country {
    _country = [country copy];
    [self updateCountryBtnTitle];
}

- (void)setMobile:(NSString *)mobile {
    _mobile = [mobile copy];
    self.mobileTextField.text = mobile;
    [self refreshAccountInputLayout];
}

- (BOOL)isEmailAccount:(NSString *)text {
    return text.length > 0 && [text containsString:@"@"];
}

- (void)accountTextChanged:(UITextField *)textField {
    [self refreshAccountInputLayout];
}

/// Hide country code when typing an email; restore for phone.
- (void)refreshAccountInputLayout {
    BOOL emailMode = [self isEmailAccount:self.mobileTextField.text];
    self.countryBtn.hidden = emailMode;
    self.downArrowView.hidden = emailMode;
    self.countrySpliteLineView.hidden = emailMode;
    CGFloat left = emailMode ? 20.0f : (self.countrySpliteLineView.lim_right + 20.0f);
    self.mobileTextField.lim_left = left;
    self.mobileTextField.lim_width = WKScreenWidth - left - 20.0f;
}

#pragma mark -- 事件
// 跳到注册页面
-(void) toRegisterPressed{
    [[WKNavigationManager shared] pushViewController:[WKRegisterVC new] animated:YES];
}

// 密码那个小眼睛点击
-(void) passwordLookPressed:(UIButton*)btn {
    btn.selected = !btn.selected;
    _passwordTextField.secureTextEntry = !btn.selected;
}
// 国家点击
-(void) countryBtnPressed {
    WKCountrySelectVC *vc = [WKCountrySelectVC new];
    vc.onFinished = ^(NSDictionary *data) {
        self->_country = [data[@"code"] stringByReplacingCharactersInRange:NSMakeRange(0, 2) withString:@""];
        NSString *account = self.mobileTextField.text ?: @"";
        if (![account containsString:@"@"] && account.length > 11) {
            self.mobileTextField.text = [account substringToIndex:11];
        }
        [self updateCountryBtnTitle];
        [self refreshAccountInputLayout];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [[[WKNavigationManager shared] topViewController] presentViewController:nav animated:YES completion:nil];
}

// 登录按钮点击
-(void) loginBtnPressed{
    if(self.onLogin) {
        NSString *account = [self.mobileTextField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *zone = [self isEmailAccount:account] ? @"" : [NSString stringWithFormat:@"00%@", _country ?: @"86"];
        self.onLogin(account, self.passwordTextField.text, zone);
    }
}

-(void) giteeLoginPressed {
    __weak typeof(self) weakself = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authcode" parameters:nil].then(^(NSDictionary *resultDict){
        NSString *authcode = resultDict[@"authcode"];
        if(authcode) {
            WKAuthWebViewVC *vc = [[WKAuthWebViewVC alloc] init];
            vc.authcode = authcode;
            vc.url = [NSURL URLWithString:[NSString stringWithFormat:@"%@user/gitee?authcode=%@",WKAPIClient.sharedClient.config.baseUrl,authcode]];
            [WKNavigationManager.shared pushViewController:vc animated:YES];
        }
    }).catch(^(NSError *error){
        [weakself showHUDWithHide:error.domain];
    });
   
}

-(void) githubLoginPressed {
    __weak typeof(self) weakself = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authcode" parameters:nil].then(^(NSDictionary *resultDict){
        NSString *authcode = resultDict[@"authcode"];
        if(authcode) {
            WKAuthWebViewVC *vc = [[WKAuthWebViewVC alloc] init];
            vc.authcode = authcode;
            vc.url = [NSURL URLWithString:[NSString stringWithFormat:@"%@user/github?authcode=%@",WKAPIClient.sharedClient.config.baseUrl,authcode]];
            [WKNavigationManager.shared pushViewController:vc animated:YES];
        }
    }).catch(^(NSError *error){
        [weakself showHUDWithHide:error.domain];
    });
}


#pragma mark -- 委托
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    
    if(textField == self.mobileTextField) {
        NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string ?: @""];
        // Allow email freely; keep CN phone length cap only for pure digit phone input.
        if ([self isEmailAccount:next] || [string containsString:@"@"]) {
            return YES;
        }
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        BOOL digitsOnly = [next rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
        if (digitsOnly && [_country isEqualToString:@"86"]) {
            return (next.length <= 11);
        }
    }
    return true;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(_passwordTextField == textField) {
        [self loginBtnPressed];
    }
    return YES;
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    self.mobileBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.passwordBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.passwordBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    self.countrySpliteLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    self.mobileBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
}


-(UIImage*) image:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongLogin"];
}

@end
