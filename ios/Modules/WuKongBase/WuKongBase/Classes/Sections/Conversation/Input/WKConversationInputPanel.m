//
//  WKConversationInputPanel.m
//  Session
//
//  Created by tt on 2018/9/29.
//


#import "WKConversationInputPanel.h"
#import "WKGrowingTextView.h"
#import "WKConversationPanel.h"
#import "UIView+WK.h"
#import "WKConstant.h"
#import "WKCommon.h"
#import "WKSessionPanelProto.h"
#import "WKInputChangeTextRespondProto.h"
#import "WKResource.h"
#import "WKApp.h"
#import "Mp3Recorder.h"
#import "UIView+WKCommon.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKInputMentionCache.h"
#import "WKPanel.h"
#import "WKPanelFuncItemProto.h"
#import "WKFuncItemButton.h"
#import "WuKongBase.h"
#import "WKSendButton.h"
#import "WKFuncGroupView.h"
#import "WKLiquidGlassHelper.h"
#define  WKiPhoneX (WKScreenWidth == 375.f && WKScreenHeight == 812.f ? YES : NO)

#define WKConversationInputHeight 36.0f // 输入框高度
#define WKConversationFuncGroupViewHeight 40.0f // 底部工具条高度
#define WKInputShellVPad 6.0f
#define WKInputShellHPad 10.0f
#define WKInputOuterPad 10.0f
#define WKSendButtonSide 32.0f

@interface WKConversationInputPanel()<WKGrowingTextViewDelegate>{
    BOOL _refreshingMentionStyle;
    //    CGFloat _inputPanelBorder;
    BOOL _noFollowKeyboradHeight; // 不追随键盘高度
}

//@property(nonatomic,assign) CGFloat height;


// 工具栏中间视图
@property(nonatomic,strong) WKFuncGroupView *funcGroupView;
// 消息工具栏
@property(nonatomic,strong) UIView *messageToolBar;

@property(nonatomic,strong) UIView *contentView;

@property(nonatomic) CGFloat messageToolBarMaxHeight; // 消息栏最大高度
// bar 的按钮
//@property(nonatomic,strong) UIView *rightItemContainer; // 右边Button的容器
// 面板相关

@property(nonatomic)  CGFloat panelHeight; // 面板高度（不包含消息输入栏）
@property(nonatomic,strong) NSArray<id<WKInputChangeTextRespondProto>> *inputChangeTextResponds; // 输入框文本改变响应链


@property(nonatomic,assign) CGFloat currentInputHeight; // 当前输入框高度



@property(nonatomic,strong) UIView *inputShellView; // 圆角输入框
@property(nonatomic,strong) WKSendButton *sendButton;

@property(nonatomic,assign) BOOL mentionStart; // 是否开始@
- (void)refreshMentionHighlightInInput;

@property(nonatomic,strong) NSArray<UIView*> *textViewRights;

@property(nonatomic,strong,nullable) UIVisualEffectView *liquidGlassView;
/// Opaque/blur underlay so the home-indicator strip never shows chat wallpaper.
@property(nonatomic,strong,nullable) UIView *chromeUnderlayView;
@property(nonatomic,assign) BOOL usesLiquidGlassChrome;

@end

@implementation WKConversationInputPanel

-(WKConversationInputPanel*) initWithConversationContext:(id<WKConversationContext>)context {
    self = [super init];
    if(!self) return nil;
    self.conversationContext = context;
    [self setupUI];
    
    return self;
}



-(void) setupUI {
    
    [self addKeyboardListen]; // 这里也必须添加键盘通知，要不然有草稿的时候键盘弹起不会触发监听事件

   
    self.layer.shadowOffset = CGSizeMake(0.0f, -1.0f);
    if (@available(iOS 13.0, *)) {
        self.usesLiquidGlassChrome = YES;
    } else {
        self.usesLiquidGlassChrome = NO;
    }
    self.layer.shadowOpacity = [WKLiquidGlassHelper isLiquidGlassAvailable] ? 0.0f : (self.usesLiquidGlassChrome ? 0.2f : 0.6f);
    
    self.currentInputHeight = WKConversationInputHeight;
    
     //获取输入框改变响应链
    _inputChangeTextResponds = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_RESPOND param:nil];
    if(_inputChangeTextResponds) {
        [_inputChangeTextResponds enumerateObjectsUsingBlock:^(id<WKInputChangeTextRespondProto>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.conversationContext = self.conversationContext;
        }];
    }
    
    
    _contentViewMinHeight = WKInputOuterPad + (WKConversationInputHeight + WKInputShellVPad * 2.0f) + 2.0f + WKConversationFuncGroupViewHeight + 4.0f;
    
    [self addSubview:self.contentView];
    
    [self.contentView addSubview:self.messageToolBar];

    // Underlay + glass on the full input panel (incl. home-indicator strip).
    // Pure UIGlassEffect alone is too transparent at the empty bottom and shows wallpaper.
    if (self.usesLiquidGlassChrome) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.messageToolBar.backgroundColor = [UIColor clearColor];

        // Glass first (helper inserts at 0), then underlay behind it.
        self.liquidGlassView = [WKLiquidGlassHelper installInView:self
                                                     cornerRadius:20.0f
                                                      interactive:YES
                                                       solidColor:nil];
        if (@available(iOS 26.0, *)) {
            if (self.liquidGlassView) {
                UICornerRadius *top = [UICornerRadius fixedRadius:20.0f];
                UICornerRadius *bottom = [UICornerRadius fixedRadius:0.0f];
                self.liquidGlassView.cornerConfiguration = [UICornerConfiguration configurationWithUniformTopRadius:top uniformBottomRadius:bottom];
            }
        }

        if (@available(iOS 13.0, *)) {
            UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
            UIVisualEffectView *underlay = [[UIVisualEffectView alloc] initWithEffect:blur];
            underlay.userInteractionEnabled = NO;
            underlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self insertSubview:underlay atIndex:0];
            self.chromeUnderlayView = underlay;
        } else {
            UIView *underlay = [[UIView alloc] init];
            underlay.userInteractionEnabled = NO;
            underlay.backgroundColor = [WKApp shared].config.cellBackgroundColor;
            underlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self insertSubview:underlay atIndex:0];
            self.chromeUnderlayView = underlay;
        }
        // Stack: underlay → glass → contentView / panel
        if (self.liquidGlassView && self.chromeUnderlayView) {
            [self insertSubview:self.liquidGlassView aboveSubview:self.chromeUnderlayView];
        }
    }
    
    [self addSubview:self.conversationPanel];
    
    [self.messageToolBar addSubview:self.menusBtn];
    [self.messageToolBar addSubview:self.plusButton];
    [self.messageToolBar addSubview:self.inputShellView];
    [self.inputShellView addSubview:self.textView];
    [self.messageToolBar addSubview:self.funcGroupView];
    [self.messageToolBar addSubview:self.sendButton];
    
    [self reloadInputPanelFrame];
    [self layoutContentView];
}
// 添加和布局文本框右边视图
-(void) updateAndLayoutTextViewRightView {
    self.textViewRights = [[WKApp shared] invokes:WKPOINT_CATEGORY_TEXTVIEW_RIGHTVIEW param:@{@"context":self.conversationContext}];
    [self.textViewRightView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    if(!self.textViewRights || self.textViewRights.count==0) {
        [self.textView setRightView:nil];
        return;
    }
    self.textViewRightView.lim_height = self.textView.lim_height - 4.0f;
    self.textViewRightView.lim_top = 2.0f;
    self.textViewRightView.lim_width = 0.0f;
    UIView *preView;
    for (UIView *rightView in self.textViewRights) {
        rightView.lim_centerY_parent = self.textViewRightView;
        if(preView) {
            rightView.lim_left = preView.lim_right;
        }
        [self.textViewRightView addSubview:rightView];
        preView = rightView;
    }
    if(preView) {
        self.textViewRightView.lim_width = preView.lim_right;
    }
    
    [self.textView setRightView:self.textViewRightView];
    
}

- (UIView *)textViewRightView {
    if(!_textViewRightView) {
        _textViewRightView = [[UIView alloc] init];
    }
    return _textViewRightView;
}


-(void) resetCurrentInputHeight {
    self.textView.internalTextView.lim_size = self.textView.lim_size;
   CGFloat mHeight = [self.textView measureHeight];
    CGFloat currentHeight = MIN(mHeight, self.textView.maxHeight);
    self.currentInputHeight = MAX(WKConversationInputHeight, currentHeight);
}
//
//-(void) resetMoreItemAndTextView{
//    self.moreBtnItem.lim_left = itemSpace;
//    self.textView.lim_left = itemWidth+itemSpace*2;
//}

-(void) resetInputHeight {
   self.currentInputHeight = WKConversationInputHeight;
}
#pragma mark -- 面板相关
-(WKConversationPanel*) conversationPanel {
    if(!_conversationPanel) {
        _conversationPanel = [[WKConversationPanel alloc] init];
    }
    return _conversationPanel;
}


#pragma mark - 布局

CGFloat itemSpace = 10.0f;
-(void) layoutSubviews{
    [super layoutSubviews];
    [self reloadInputPanelFrame];
    [self layoutContentView];

    self.textView.internalTextView.backgroundColor = [UIColor clearColor];
    if (self.usesLiquidGlassChrome && (self.liquidGlassView || self.chromeUnderlayView)) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.messageToolBar.backgroundColor = [UIColor clearColor];
        // Full panel bounds — must cover home-indicator strip under func buttons.
        self.chromeUnderlayView.frame = self.bounds;
        self.liquidGlassView.frame = self.bounds;
        if (self.chromeUnderlayView) {
            [self sendSubviewToBack:self.chromeUnderlayView];
        }
        if (self.liquidGlassView && self.chromeUnderlayView) {
            [self insertSubview:self.liquidGlassView aboveSubview:self.chromeUnderlayView];
        }
        if (@available(iOS 13.0, *)) {
            self.conversationPanel.backgroundColor = [UIColor clearColor];
        }
        if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
            self.layer.shadowOpacity = 0.0f;
        }
        [self.textView setBackgroundColor:[UIColor clearColor]];
        [self styleInputShell];
    } else {
        [self.messageToolBar setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        [self.conversationPanel setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            self.layer.shadowColor = [UIColor colorWithRed:15.0f/255.0f green:15.0f/255.0f blue:15.0f/255.0f alpha:1.0].CGColor;
        }else{
            self.layer.shadowColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0].CGColor;
        }
        [self.textView setBackgroundColor:[UIColor clearColor]];
        [self styleInputShell];
    }
}

-(void) styleInputShell {
    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    self.inputShellView.backgroundColor = dark
        ? [UIColor colorWithWhite:1.0 alpha:0.06]
        : [UIColor colorWithWhite:1.0 alpha:0.92];
    self.inputShellView.layer.borderColor = (dark
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:0.0 alpha:0.12]).CGColor;
}
-(void) layoutContentView{
    
    CGFloat contentHeight = self.currentContentHeight;
    CGFloat leftSpace = WKInputOuterPad;
    
    self.contentView.lim_width = self.lim_width;
    self.contentView.lim_height = contentHeight;
    
    self.messageToolBar.lim_size = self.contentView.lim_size;
    if(self.topView) {
        self.messageToolBar.lim_top = self.topView.lim_bottom;
    }else {
        self.messageToolBar.lim_top = 0.0f;
    }
    
    if(self.showMenusBtn) {
        self.menusBtn.lim_left = leftSpace;
    }
    
    // Input shell: text only
    CGFloat shellLeft = leftSpace;
    if(self.showMenusBtn) {
        shellLeft = self.menusBtn.lim_right + 8.0f;
    }
    CGFloat shellRightPad = WKInputOuterPad;
    CGFloat shellWidth = self.lim_width - shellLeft - shellRightPad;
    CGFloat shellHeight = self.currentInputHeight + WKInputShellVPad * 2.0f;
    
    self.inputShellView.lim_left = shellLeft;
    self.inputShellView.lim_top = WKInputOuterPad;
    self.inputShellView.lim_width = shellWidth;
    self.inputShellView.lim_height = shellHeight;
    
    self.textView.lim_left = WKInputShellHPad;
    self.textView.lim_width = MAX(80.0f, shellWidth - WKInputShellHPad * 2.0f);
    self.textView.lim_height = self.currentInputHeight;
    self.textView.lim_top = WKInputShellVPad;
    
    if(self.showMenusBtn) {
        self.menusBtn.lim_top = self.inputShellView.lim_top + (shellHeight / 2.0f - self.menusBtn.lim_height / 2.0f);
    }
    
    // Bottom toolbar: [emoji mic image …] ........ [send]
    CGFloat toolsTop;
    if(self.funcGroupView.startScroll) {
        toolsTop = self.inputShellView.lim_bottom + 2.0f - (self.funcGroupView.lim_height - WKConversationFuncGroupViewHeight);
    } else {
        toolsTop = self.inputShellView.lim_bottom + 2.0f;
    }
    CGFloat sendRightPad = WKInputOuterPad;
    CGFloat sendW = WKSendButtonSide;
    self.sendButton.lim_width = sendW;
    self.sendButton.lim_height = sendW;
    self.sendButton.lim_left = self.lim_width - sendRightPad - sendW;
    self.sendButton.lim_top = toolsTop + (WKConversationFuncGroupViewHeight - sendW) / 2.0f;
    
    if(!self.plusButton.hidden) {
        self.plusButton.lim_left = self.sendButton.lim_left - self.plusButton.lim_width - 6.0f;
        self.plusButton.lim_top = self.sendButton.lim_top + (sendW - self.plusButton.lim_height) / 2.0f;
    }
    
    self.funcGroupView.lim_top = toolsTop;
    self.funcGroupView.lim_left = 0;
    CGFloat funcRight = self.sendButton.lim_left;
    if(!self.plusButton.hidden) {
        funcRight = self.plusButton.lim_left;
    }
    self.funcGroupView.lim_width = MAX(0, funcRight - 4.0f);
    
    self.conversationPanel.lim_top = self.contentView.lim_bottom;
}

- (UIEdgeInsets)inputFieldInsets
{
    static UIEdgeInsets insets;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        insets = UIEdgeInsetsMake(5.0f, 0.0f, 5.0f, 0.0f);
    });
    
    return insets;
}

#pragma mark - 消息栏相关

-(UIView*) messageToolBar {
    if(!_messageToolBar) {
        _messageToolBar = [[UIView alloc] init];
//        _messageToolBar.layer.borderWidth = 0.5;
//        _messageToolBar.layer.borderColor = [UIColor lightGrayColor].CGColor;
    }
    return _messageToolBar;
}

- (UIView *)contentView {
    if(!_contentView) {
        _contentView = [[UIView alloc] init];
    }
    return _contentView;
}

-(WKFuncGroupView*) funcGroupView {
    if(!_funcGroupView) {
        CGFloat scaleZoom = 1.8f;
        _funcGroupView = [[WKFuncGroupView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKConversationFuncGroupViewHeight) inputPanel:self];
        _funcGroupView.scaleZoom = scaleZoom;
        __weak typeof(self) weakSelf = self;
        [_funcGroupView setOnLayout:^{
            [weakSelf layoutContentView];
        }];
    }
    return _funcGroupView;
}

-(CGFloat) contentViewChangeHeight {
    
    return [self currentContentHeight] - _contentViewMinHeight;
}

#pragma mark - Panel draw


- (WKMenusBtn *)menusBtn {
    if(!_menusBtn) {
        _menusBtn = [[WKMenusBtn alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 25.0f)];
//        _menusBtn.backgroundColor = [WKApp shared].config.themeColor;
        _menusBtn.hidden = YES;
        _menusBtn.layer.masksToBounds = YES;
//        _menusBtn.layer.cornerRadius = _menusBtn.lim_height/2.0f;
    }
    return _menusBtn;
}

- (UIButton *)plusButton {
    if(!_plusButton) {
        _plusButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 28.0f, 28.0f)];
        _plusButton.hidden = YES;
        [_plusButton setTitle:@"⋯" forState:UIControlStateNormal];
        _plusButton.titleLabel.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightMedium];
        [_plusButton setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        _plusButton.layer.cornerRadius = 6.0f;
        _plusButton.layer.masksToBounds = YES;
    }
    return _plusButton;
}

- (void)setShowPlusButton:(BOOL)show {
    self.plusButton.hidden = !show;
    [self layoutSubviews];
}

- (BOOL)showPlusButton {
    return !self.plusButton.hidden;
}

- (WKSendButton *)sendButton {
    if(!_sendButton) {
        CGSize size = CGSizeMake(WKSendButtonSide, WKSendButtonSide);
        _sendButton = [[WKSendButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
        __weak typeof(self) weakSelf = self;
        [_sendButton setOnSend:^{
            [weakSelf inputSendFinished];
        }];
    }
    return _sendButton;
}

- (void)setShowMenusBtn:(BOOL)showMenusBtn {
    _showMenusBtn = showMenusBtn;
    self.menusBtn.hidden = !showMenusBtn;
    
    [self layoutSubviews];
}

-(UIView *)inputShellView {
    if (!_inputShellView) {
        _inputShellView = [[UIView alloc] init];
        _inputShellView.layer.masksToBounds = YES;
        _inputShellView.layer.cornerRadius = 10.0f;
        _inputShellView.layer.borderWidth = 1.0f / UIScreen.mainScreen.scale;
    }
    return _inputShellView;
}

-(WKGrowingTextView*) textView {
    if(!_textView) {
        _textView = [[WKGrowingTextView alloc] init];
        _textView.lim_height =WKConversationInputHeight;
        _textView.layer.masksToBounds = YES;
        _textView.layer.cornerRadius = 0;
        _textView.tag = 99;
        _textView.delegate = self;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.internalTextView.returnKeyType = UIReturnKeyDefault;
    }
    return _textView;
}

// 切换更多面板
-(void) switchPanel:(NSString*)pointId{
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(switchPanel:pointID:)]) {
        [self.delegate switchPanel:self pointID:pointId];
    }
    
    if(![self keyboardIsUp]&&self.panelHeight>0){
        if(pointId && [pointId isEqualToString:[self.conversationPanel currentPanelPointId]]) { // 如果是点击相同的按钮才会弹起键盘
            [self.textView becomeFirstResponder];
            return;
        }
    }
    _noFollowKeyboradHeight = true;
    if(self.conversationPanel){
        self.conversationPanel.conversationContext = self.conversationContext;
    }
    
    if([self.conversationPanel switchPanel:nil pointId:pointId]){
        if(![self messageToolBarIsUp]){ // 如果输入栏没弹起 就先调整大小 这样面板出现的时候感觉像一个整体
            [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
        }
        
        self.panelHeight = [self.conversationPanel currentPanelHeight];
        [WKCommon commonAnimation:^{
            [self.textView endEditing:YES];
            [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
            [self reloadInputPanelFrame];
            [self inputPanelUpOrDown];
        }];
    }
    
}

-(BOOL) becomeFirstResponder {
   return [self.textView becomeFirstResponder];
}

-(void) endEditing {
    if(self.panelHeight>0){
        self.panelHeight = 0;
        [self keyboardAnimation:^{
            [self.textView endEditing:YES];
            [self reloadInputPanelFrame];
            [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
            [self inputPanelUpOrDown];
        }];
        
    }else if([self keyboardIsUp]){
        [self.textView endEditing:YES];
    }
}

#pragma mark - 消息栏位置计算
-(void) reloadInputPanelFrame {
    self.lim_size = CGSizeMake(WKScreenWidth, [self currentContentHeight]+[self currentPanelHeight]);
    if(!self.disableAutoTop) {
        self.lim_top =  [self currentMessageToolBarY];
    }
   
    
    if(self.panelHeight<=0) {
        [self unSelectedFuncItems];
    }else if([self keyboardIsUp]) {
         [self unSelectedFuncItems];
    }

}

// 当前输入栏的Y坐标
-(CGFloat) currentMessageToolBarY{
//    CGRect statusRect = [[UIApplication sharedApplication] statusBarFrame];
//    CGFloat navHeight = self.lim_viewController.navigationController.navigationBar.frame.size.height;
//    CGFloat y =  WKScreenHeight -navHeight - statusRect.size.height -[self currentInputPanelHeight];
     CGFloat y =  WKScreenHeight -[self currentInputPanelHeight];
    
    return y;
}

// 当前整个输入面板的高度
-(CGFloat) currentInputPanelHeight{
    return [self currentPanelHeight]+[self currentContentHeight]-[self bottomAdjustOffset];
}

// 当前消息栏高度：圆角输入框 + 下方工具条（含发送）
-(CGFloat) currentContentHeight{
    CGFloat topViewBottom = 0.0f;
    if(self.topView) {
        topViewBottom = self.topView.lim_bottom;
    }
    CGFloat shellH = self.currentInputHeight + WKInputShellVPad * 2.0f;
    CGFloat height = WKInputOuterPad + shellH + 2.0f + WKConversationFuncGroupViewHeight + 4.0f;
    height = MAX(height, _contentViewMinHeight);
    return height+topViewBottom;
}
// 当前面板的高度
-(CGFloat) currentPanelHeight{
    if([self keyboardIsUp]) {
        return self.keyboardHeight+[self bottomAdjustOffset];
    }
    
    return self.panelHeight+[self bottomOffset];
}

// 底部偏移距离
-(CGFloat) bottomOffset{
    
    return [self safeBottom]+[self bottomAdjustOffset];
}

// 人为调整的大小
-(CGFloat) bottomAdjustOffset{
    return WKiPhoneX? 0.0f:0.0f;
}

#pragma mark - keyboard (键盘相关)

// 键盘是否弹起
-(BOOL) keyboardIsUp {
    return self.keyboardHeight>0;
}

-(void) setHidden:(BOOL)hidden animation:(BOOL)animation animationBlock:(void(^)(void))animationBlock{
    __weak typeof(self) weakSelf = self;
    if(hidden) {
        [self animateInputWithBlock:^{
            if(!weakSelf.disableAutoTop) {
                weakSelf.lim_top = WKScreenHeight;
            }
            
            weakSelf.hidden = YES;
            if(animationBlock) {
                animationBlock();
            }
        }];
    }else{
        weakSelf.hidden = NO;
        [self animateInputWithBlock:^{
            [weakSelf reloadInputPanelFrame];
            if(animationBlock) {
                animationBlock();
            }
        }];
    }
    
}
// 消息工具栏弹起
-(BOOL) messageToolBarIsUp{
    if([self keyboardIsUp]){
        return true;
    }
    if(self.panelHeight>0){
        return true;
    }
    return false;
}

-(void) keyboardAnimation:(void(^)(void)) block{
    
    [WKCommon commonAnimation:^{
        if(block){
            block();
        }
    }];
}

- (void)configureWithKeyboardNotification:(NSNotification *)notification {
    CGRect keyboardBeginFrame = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect keyboardBeginFrameInView = [self.superview convertRect:keyboardBeginFrame fromView:nil];
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardEndFrameInView = [self.superview convertRect:keyboardEndFrame fromView:nil];
    CGRect keyboardEndFrameIntersectingView = CGRectIntersection(self.superview.bounds, keyboardEndFrameInView);
    
    CGFloat keyboardHeight = CGRectGetHeight(keyboardEndFrameIntersectingView);
    
    self.keyboardHeight =keyboardHeight;
    if(!_noFollowKeyboradHeight) {
        self.panelHeight = self.keyboardHeight;
    }else{
        _noFollowKeyboradHeight = false;
    }
    
    // Workaround for collection view cell sizes changing/animating when view is first pushed onscreen on iOS 8.
    if (CGRectEqualToRect(keyboardBeginFrameInView, keyboardEndFrameInView)) {
        [UIView performWithoutAnimation:^{
            NSLog(@"configureWithKeyboardNotification---->1");
//            [self reloadInputPanelFrame];
//            [self inputPanelUpOrDown];
        }];
        return;
    }
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [self reloadInputPanelFrame];
    if(self.keyboardHeight>0){
        NSLog(@"configureWithKeyboardNotification---->3 ->%0.2f -->%0.2f",self.panelHeight,self.keyboardHeight);
        [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
    }
    [self inputPanelUpOrDown];
    [UIView commitAnimations];
    NSLog(@"configureWithKeyboardNotification---->2");
   

}


// 取消所有被选中的功能item
-(void) unSelectedFuncItems {
    [self.funcGroupView unSelectedItems];
}



// 键盘隐藏
- (void)keyboardWillHide:(NSNotification *)notification{
    [self configureWithKeyboardNotification:notification];
}

// 键盘显示
- (void)keyboardWillShow:(NSNotification *)notification{
    [self  unSelectedFuncItems];
    [self configureWithKeyboardNotification:notification];
}


//添加监听键盘
-(void)addKeyboardListen{
    [self removeKeyboardListen];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}
//移除监听
-(void)removeKeyboardListen{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}

- (int)convertToByte:(NSString*)str {
    int strlength = 0;
    char* p = (char*)[str cStringUsingEncoding:NSUnicodeStringEncoding];
    for (int i=0 ; i<[str lengthOfBytesUsingEncoding:NSUnicodeStringEncoding] ;i++) {
        if (*p) {
            p++;
            strlength++;
        }
        else {
            p++;
        }
    }
    return (strlength+1)/2;
}

-(void) inputSendFinished {
    NSString *content = self.textView.text;
    if([WKApp shared].config.messageTextMaxBytes !=0) {
        if(content && [self convertToByte:content]>[WKApp shared].config.messageTextMaxBytes) {
            [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送的内容太长！")];
            return;
        }
    }
    
    self.textView.text = @"";
    self.sendButton.show = NO;
    [self resetInputHeight];
    [self animateInputPanelChange:^{
        if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelSend:text:)]) {
            [self.delegate inputPanelSend:self text:content];
        }
    }];
   
}

#pragma mark - UITextViewDelegate
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    if ([text isEqualToString:@"\n"]) {
        return YES; // 移动端回车换行，点击发送按钮发送
    }
    if ([self isMention:text]) { // @功能
        [self triggerMentionStartIfNeed];
        
        return YES;
    } else  if ([text isEqualToString:@""] && range.length == 1 ) { // 删除
        NSString *willDeleteStr =  [self.textView.text substringWithRange:range];
        if([willDeleteStr isEqualToString:WKInputAtStartChar]) { /// @被删除了 说明@结束了
            [self triggerMentionEndIfNeed];
            return YES;
        }
         NSRange rangeForMention = [self delRangeForMention];
        if(rangeForMention.length>1) {
            [self triggerMentionEndIfNeed];
            if([self.delegate respondsToSelector:@selector(inputPanel:delMention:)]) {
                [self.delegate inputPanel:self delMention:rangeForMention];
            }
            [self inputDeleteText:rangeForMention];
            return NO;
        }
    }else if([text isEqualToString:@" "]) { // 空格 如果有@需要结束
        [self triggerMentionEndIfNeed];
    }
    
    if(_inputChangeTextResponds && _inputChangeTextResponds.count>0){
        BOOL allowChange = true;
        for(id<WKInputChangeTextRespondProto> inputChangeTextRespond in _inputChangeTextResponds){
            id<WKInputChangeRespondResult> result =  [inputChangeTextRespond shouldChangeTextInRange:range replacementText:text];
            if(result && !result.changeText) {
                allowChange = false;
            }
            if(result&&!result.next) {
                break;
            }
        }
        return allowChange;
    }
    return YES;
}

-(void) triggerMentionStartIfNeed {
    if(self.mentionStart) {
        return;
    }
    self.mentionStart = true;
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelMentionStart:)]) {
        [self.delegate inputPanelMentionStart:self];
    }
}
-(void) triggerMentionEndIfNeed {
    if(!self.mentionStart) {
        return;
    }
    self.mentionStart = false;
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelMentionEnd:)]) {
        [self.delegate inputPanelMentionEnd:self];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    if (_refreshingMentionStyle) return;
    [self handleTextViewContentDidChange];
   
}

-(void) handleTextViewContentDidChange {
    NSString *text = self.textView.text;
    if([[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
        self.sendButton.show = false;
    }else {
        self.sendButton.show = true;
    }
    [self animateInputPanelChange];
    [self refreshMentionHighlightInInput];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelTyping:)]) {
        [self.delegate inputPanelTyping:self];
    }
    
    if([text hasSuffix:WKInputAtStartChar]) {
        [self triggerMentionStartIfNeed];
    }
   
    if(![text containsString:@"@"]) {
        [self triggerMentionEndIfNeed];
    }else if(text.length>0){
        if([text hasSuffix:WKInputAtEndChar]) {
            [self triggerMentionEndIfNeed];
        }
    }
    if(self.mentionStart) {
        [self textChangeMentionCandidateIfNeeded];
    }
    
    [[WKApp shared] invokes:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_CHANGE param:@{@"input":self}];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanel:textChange:)]) {
        [self.delegate inputPanel:self textChange:text];
    }
    
    
}

/// 输入框内 @人名 主题色标注（与气泡消息一致）
- (void)refreshMentionHighlightInInput {
    if (_refreshingMentionStyle) return;
    UITextView *tv = self.textView.internalTextView;
    if (!tv) return;
    NSString *text = tv.text ?: @"";
    UIFont *font = tv.font ?: [UIFont systemFontOfSize:16];
    UIColor *normalColor = [WKApp shared].config.defaultTextColor;
    if (!normalColor) {
        if (@available(iOS 13.0, *)) {
            normalColor = [UIColor labelColor];
        } else {
            normalColor = [UIColor blackColor];
        }
    }
    UIColor *mentionColor = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
    UIFont *mentionFont = [UIFont systemFontOfSize:font.pointSize weight:UIFontWeightSemibold] ?: font;

    NSDictionary *baseAttrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: normalColor,
    };
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text attributes:baseAttrs];
    if (text.length > 0) {
        // \S 不含结束符 \u2004，正好只高亮 @Hermes
        NSError *reErr = nil;
        NSRegularExpression *re =
            [NSRegularExpression regularExpressionWithPattern:@"@\\S+" options:0 error:&reErr];
        if (re && !reErr) {
            [re enumerateMatchesInString:text
                                 options:0
                                   range:NSMakeRange(0, text.length)
                              usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                if (!result || result.range.location == NSNotFound) return;
                [attr addAttributes:@{
                    NSForegroundColorAttributeName: mentionColor,
                    NSFontAttributeName: mentionFont,
                } range:result.range];
            }];
        }
    }

    NSRange selected = tv.selectedRange;
    _refreshingMentionStyle = YES;
    tv.allowsEditingTextAttributes = YES;
    // 清掉 textColor，避免覆盖 attributedText 的分片颜色
    tv.textColor = nil;
    tv.attributedText = attr;
    tv.typingAttributes = baseAttrs;
    if (selected.location != NSNotFound && NSMaxRange(selected) <= attr.length) {
        tv.selectedRange = selected;
    }
    _refreshingMentionStyle = NO;
}

// 是否提及
-(BOOL) isMention:(NSString*)text {
    return [text isEqualToString:WKInputAtStartChar];
}

// 是否删除提及
- (NSRange)delRangeForMention {
    NSRange range = [self rangeForPrefix:WKInputAtStartChar suffix:WKInputAtEndChar];
    return range;
}


- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSString *text = self.textView.text;
    NSRange range = [self inputSelectedRange];
    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        //往前搜最多20个字符，一般来讲是够了...
        NSInteger p = 20;
        for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}

// 获取输入中的@和后面的关键字
-(NSRange) inputingMentionRange {
    NSString *text = self.textView.text;
    NSRange range = [self inputSelectedRange];
//    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    
    NSInteger index = -1;
    //往前搜最多20个字符，一般来讲是够了...
    NSInteger p = 20;
    for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--) {
        NSRange subRange = NSMakeRange(i - 1, 1);
        NSString *subString = [text substringWithRange:subRange];
        if([subString compare:WKInputAtEndChar] == NSOrderedSame) {
            return NSMakeRange(NSNotFound, 0);
        }
        if ([subString compare:WKInputAtStartChar] == NSOrderedSame) {
            index = i - 1;
            break;
        }
    }
    return index == -1? NSMakeRange(NSNotFound, 0) : NSMakeRange(index, endLocation - index);
}

// 替换正在输入中的@内容
-(BOOL) replaceInputingMention:(NSString*)value {
   NSRange mentionRange = [self inputingMentionRange];
    if(mentionRange.location == NSNotFound) {
        return false;
    }
    self.textView.text  = [self.textView.text stringByReplacingCharactersInRange:mentionRange withString:value];
    [self handleTextViewContentDidChange];
    return YES;
}

-(void) textChangeMentionCandidateIfNeeded {
   NSRange range = [self inputingMentionRange];
    if(range.location == NSNotFound) {
        return;
    }
    if([self.delegate respondsToSelector:@selector(inputPanel:mentionSearch:)]) {
        NSRange keywordRange = NSMakeRange(range.location + 1, range.length - 1);
        NSString *text = [self.textView.text substringWithRange:keywordRange];
        [self.delegate inputPanel:self mentionSearch:text];
    }
}

#pragma mark - WKGrowingTextViewDelegate


- (void)growingTextView:(WKGrowingTextView *)growingTextView willChangeHeight:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve{
//    UIEdgeInsets inputFieldInsets = [self inputFieldInsets];
//    CGFloat inputContainerHeight = MAX(_messageToolBarMinHeight, height);
    if(height < WKConversationInputHeight) {
        height = WKConversationInputHeight;
    }
    CGFloat currentHeight = MIN(height, self.textView.maxHeight);
    if(height!=self.currentInputHeight) {
//        self.currentMessageToolBarHeight +=( currentHeight - self.currentInputHeight);
        self.currentInputHeight = currentHeight;
        [self animateInputPanelChange];
        [self triggerInputPanelChangeEvent];
    }
    
}

#pragma mark - WKInputProto

- (void)sendMessage:(WKMessageContent *)content {
    [self.delegate inputPanel:self sendMessage:content];
}

/**
 往输入框插入文本
 */
-(void) inputInsertText:(NSString *)text{
    [self.textView insertText:text];
    
    [self handleTextViewContentDidChange];
}

-(void) inputSetText:(NSString *)text {
    [self.textView setText:text];
    [self resetInputHeight];
    [self handleTextViewContentDidChange];
}


/**
 删除范围内的文本
 
 @param range <#range description#>
 */
-(void) inputDeleteText:(NSRange)range{
    
    [self.textView deleteText:range];
    [self handleTextViewContentDidChange];
}


/**
 获取当前输入框的文本
 
 @return <#return value description#>
 */
-(NSString*) inputText{
    
    return self.textView.text;
}

-(NSRange) inputSelectedRange{
    
    return self.textView.selectedRange;
}


#pragma mark - 公开方法



-(void) adjustInput:(BOOL)animation{
    if(animation) {
        [self animateInputWithBlock:^{
            [self reloadInputPanelFrame];
        }];
    }else{
        [self reloadInputPanelFrame];
    }
}



- (void)setTopView:(UIView *)topView {
    [self setTopView:topView animateBlock:nil];
}

- (void)setTopView:(UIView *)topView animateBlock:(void(^)(void))animateBlock{
    if(_topView) {
        [_topView removeFromSuperview];
    }
    _topView = topView;
    if(_topView) {
        [self.contentView addSubview:_topView];
        [self.contentView sendSubviewToBack:_topView];
    }
    __weak typeof(self) weakSelf = self;
    [self animateInputWithBlock:^{
        [weakSelf layoutSubviews];
        if(animateBlock) {
            animateBlock();
        }
    }];
    
}


#pragma mark - 私有方法

// 输入框面板收缩
-(void) inputPanelUpOrDown {
    if( [self delegate]&&[self.delegate respondsToSelector:@selector(inputPanelUpOrDown:up:)]){
        [self.delegate inputPanelUpOrDown:self up:self.keyboardHeight>0];
    }
}

-(void) animateInputWithBlock:(void(^)(void)) block{
    [UIView animateWithDuration:SessionInputAnimateDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        block();
    } completion:nil];
}
-(void) animateInputPanelChange {
    [self animateInputWithBlock:^{
//        [self adjustInput:NO];
        [self layoutSubviews]; // 加了这句textView才有向上增长的效果，而不是向上移动（很重要）
        [self.textView layoutSubviews];
    }];
}

-(void) animateInputPanelChange:(void(^)(void))block {
    [self animateInputWithBlock:^{
//        [self adjustInput:NO];
        [self layoutSubviews]; // 加了这句textView才有向上增长的效果，而不是向上移动（很重要）
        [self.textView layoutSubviews];
        block();
    }];
}

-(UIImage*) imageName:(NSString*)name {
//    return [currentModule ImageForResource:name];
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//   return  [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}


// 输入面板发送改变
-(void) triggerInputPanelChangeEvent {
    if(_delegate&&[_delegate respondsToSelector:@selector(inputPanelWillChangeHeight:height:duration:animationCurve:)]) {
        [_delegate inputPanelWillChangeHeight:self height:self.currentContentHeight duration:SessionInputAnimateDuration animationCurve:0];
    }
}

-(void) stopFuncGroupZoom {
    [self.funcGroupView stopZoom];
}

-(BOOL) isFuncGroupZooming {
    return [self.funcGroupView isZooming];
}

-(void) dealloc{
    [self removeKeyboardListen];
}

// iphoneX安全距离（keyWindow 在 Scene 下常为 nil，需多路回退）
- (CGFloat) safeBottom {
    if (@available(iOS 11.0, *)) {
        if (self.safeAreaInsets.bottom > 0.5f) {
            return self.safeAreaInsets.bottom;
        }
        if (self.superview.safeAreaInsets.bottom > 0.5f) {
            return self.superview.safeAreaInsets.bottom;
        }
        UIWindow *window = self.window;
        if (!window) {
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    for (UIWindow *w in ws.windows) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                    if (!window) window = ws.windows.firstObject;
                    if (window) break;
                }
            }
            if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
            }
        }
        if (window.safeAreaInsets.bottom > 0.5f) {
            return window.safeAreaInsets.bottom;
        }
    }
    return 0;
}


@end
