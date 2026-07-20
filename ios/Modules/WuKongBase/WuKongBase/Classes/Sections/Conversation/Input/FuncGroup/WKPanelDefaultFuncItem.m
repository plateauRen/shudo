//
//  WKPanelDefaultFuncItem.m
//  WuKongBase
//
//  Created by tt on 2020/2/23.
//

#import "WKPanelDefaultFuncItem.h"
#import "WKResource.h"
#import "WKConstant.h"
#import "WKMoreItemClickEvent.h"
#import "WKFuncItemButton.h"
#import "WuKongBase.h"
#import "WKConversationContext.h"
#import "WKCardContent.h"
#import "WKFuncGroupEditVC.h"
#import "WKRichComposerVC.h"
#import "WKRichEditorPool.h"
#import "WKNavigationManager.h"

@interface WKPanelDefaultFuncItem ()
@end

@implementation WKPanelDefaultFuncItem

/// WeChat / Feishu style: monochrome line SF Symbol, theme-tinted.
+ (UIImage *)symbolIcon:(NSString *)systemName fallbackAsset:(NSString *)assetName {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:22
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleMedium];
        UIImage *img = [UIImage systemImageNamed:systemName withConfiguration:cfg];
        if (img) {
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    UIImage *fallback = [WKApp.shared loadImage:assetName moduleID:@"WuKongBase"];
    return [fallback imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIColor *)toolbarIconTint {
    // Align with Feishu secondary icon gray
    if ([WKApp shared].config.style == WKSystemStyleDark) {
        return [UIColor colorWithRed:0x8F/255.0f green:0x95/255.0f blue:0x9E/255.0f alpha:1.0f];
    }
    return [UIColor colorWithRed:0x64/255.0f green:0x6A/255.0f blue:0x73/255.0f alpha:1.0f]; // #646A73
}

-(NSString*) sid {
    return @"";
}

- (nonnull WKFuncItemButton *)itemButton:(WKConversationInputPanel*)inputPanel {
    self.inputPanel = inputPanel;
    WKFuncItemButton *btn = [[WKFuncItemButton alloc] init];
    UIImage *icon = [self itemIcon];
    [btn setImage:icon forState:UIControlStateNormal];
    [btn setImage:icon forState:UIControlStateHighlighted];
    btn.tintColor = [WKPanelDefaultFuncItem toolbarIconTint];
    btn.adjustsImageWhenHighlighted = YES;
    [btn addTarget:self action:@selector(onPressed:) forControlEvents:UIControlEventTouchUpInside];
    [btn setTitle:[self title] forState:UIControlStateNormal];
    // Keep title for a11y / edit UI; hide label on the compact toolbar chrome.
    btn.titleLabel.alpha = 0;
    return btn;
}

-(void) onPressed:(WKFuncItemButton*)btn {
    [self.inputPanel switchPanel:[self panelID]];
}

-(NSString*) title {
    return @"";
}

-(UIImage*) itemIcon {
    return nil;
}

-(NSString*) panelID {
    return @"";
}

- (BOOL)support:(id<WKConversationContext>)context {
    return true;
}

-(BOOL) allowEdit {
    return true;
}

-(UIImage*) getImageNameForBase:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end

@implementation WKPanelEmojiFuncItem

-(BOOL) allowEdit {
    return false;
}
- (NSString *)sid {
    return @"apm.wukong.emoji";
}

- (UIImage *)itemIcon {
    return [WKPanelDefaultFuncItem symbolIcon:@"face.smiling"
                                fallbackAsset:@"Conversation/Toolbar/FaceNormal"];
}

- (NSString *)panelID {
    return WKPOINT_PANEL_EMOJI;
}

- (NSString *)title {
    return LLang(@"表情");
}

@end

@interface WKPanelMentionFuncItem ()
@end
@implementation WKPanelMentionFuncItem

- (NSString *)sid {
    return @"apm.wukong.mention";
}
- (UIImage *)itemIcon {
    return [WKPanelDefaultFuncItem symbolIcon:@"at"
                                fallbackAsset:@"Conversation/Toolbar/MentionNormal"];
}

- (BOOL)support:(id<WKConversationContext>)context {
    return context.channel.channelType != WK_PERSON;
}

-(void) onPressed:(UIButton*)btn {
    [self.inputPanel inputInsertText:@"@"];
    [self.inputPanel.conversationContext showMentionUsers];
}
- (NSString *)title {
    return LLang(@"@");
}

@end

@interface WKPanelVoiceFuncItem ()
@end
@implementation WKPanelVoiceFuncItem

-(BOOL) allowEdit {
    return false;
}

- (NSString *)sid {
    return @"apm.wukong.voice";
}

- (UIImage *)itemIcon {
    // Mic reads clearer than waveform for “voice” in chat toolbars.
    return [WKPanelDefaultFuncItem symbolIcon:@"mic"
                                fallbackAsset:@"Conversation/Toolbar/VoiceNormal"];
}

- (NSString *)panelID {
    return WKPOINT_PANEL_VOICE;
}
- (NSString *)title {
    return LLang(@"语音");
}
@end

@interface WKPanelImageFuncItem ()
@end
@implementation WKPanelImageFuncItem

-(BOOL) allowEdit {
    return false;
}

- (NSString *)sid {
    return @"apm.wukong.image";
}

- (UIImage *)itemIcon {
    return [WKPanelDefaultFuncItem symbolIcon:@"photo"
                                fallbackAsset:@"Conversation/Toolbar/ImageNormal"];
}

-(void) onPressed:(UIButton*)btn {
    [[WKMoreItemClickEvent shared] onPhotoItemPressed:self.inputPanel.conversationContext];
}
- (NSString *)title {
    return LLang(@"图片");
}

@end

@implementation WKPanelMoreFuncItem

- (NSString *)sid {
    return @"apm.wukong.more";
}

- (UIImage *)itemIcon {
    // WeChat-style “+” for more tools
    return [WKPanelDefaultFuncItem symbolIcon:@"plus"
                                fallbackAsset:@"Conversation/Toolbar/MoreNormal"];
}

- (void)onPressed:(UIButton *)btn {
    WKFuncGroupEditVC *vc = [[WKFuncGroupEditVC alloc] init];
    vc.conversationContext = self.inputPanel.conversationContext;
    vc.modalPresentationStyle = UIModalPresentationPopover;
    [[WKNavigationManager shared].topViewController presentViewController:vc animated:YES completion:nil];
}
- (NSString *)title {
    return LLang(@"更多");
}

- (WKFuncGroupEditItemType)type {
    return WKFuncGroupEditItemTypeMore;
}
@end

@implementation WKPanelCardFuncItem

- (NSString *)sid {
    return @"apm.wukong.card";
}

- (UIImage *)itemIcon {
    NSString *name = @"person.text.rectangle";
    if (@available(iOS 14.0, *)) {
        name = @"person.text.rectangle";
    } else {
        name = @"person.crop.rectangle";
    }
    return [WKPanelDefaultFuncItem symbolIcon:name
                                fallbackAsset:@"Conversation/Toolbar/CardNormal"];
}

- (void)onPressed:(UIButton *)btn {
    id<WKConversationContext> conversationContext =  self.inputPanel.conversationContext;
    NSMutableArray<NSString*> *hiddenUsers = [NSMutableArray array];
    if(conversationContext.channel.channelType == WK_PERSON) {
        [hiddenUsers addObject:conversationContext.channel.channelId];
    }
    
    [[WKApp shared] invoke:WKPOINT_CONTACTS_SELECT param:@{@"mode":@"single",@"on_finished":^(NSArray<NSString*>*uids){
        if(uids && [uids count]<=0) {
            return;
        }
        NSString *uid = uids[0];
        WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:uid channelType:WK_PERSON]];
        if(!channelInfo) {
            WKLogDebug(@"没有查到频道信息！");
            return;
        }
        __weak typeof(self) weakSelf = self;
        id<WKConversationContext> context = self.inputPanel.conversationContext;
        
        [WKAlertUtil alert:[NSString stringWithFormat:LLangW(@"发送%@的名片到当前聊天",weakSelf),channelInfo.displayName] buttonsStatement:@[LLangW(@"取消",weakSelf),LLangW(@"确定",weakSelf)] chooseBlock:^(NSInteger buttonIdx) {
            btn.selected = false;
            if(buttonIdx == 1) {
                [[WKNavigationManager shared] popViewControllerAnimated:YES];
                
                [context sendMessage:[WKCardContent cardContent:[channelInfo extraValueForKey:WKChannelExtraKeyVercode] uid:uid name:channelInfo.name avatar:channelInfo.logo]];
            }
        }];
       
       
    },@"on_cancel":^{
        btn.selected = false;
    },@"hidden_users":hiddenUsers}];
}

- (NSString *)title {
    return LLang(@"名片");
}

@end

@implementation WKPanelRichFuncItem

- (NSString *)sid {
    return @"apm.wukong.rich";
}

- (UIImage *)itemIcon {
    return [WKPanelDefaultFuncItem symbolIcon:@"doc.richtext"
                                fallbackAsset:@"Conversation/Toolbar/CardNormal"];
}

- (BOOL)allowEdit {
    return YES;
}

- (void)onPressed:(UIButton *)btn {
    id<WKConversationContext> context = self.inputPanel.conversationContext;
    [self.inputPanel endEditing];
    [[WKRichEditorPool shared] prewarm];
    WKRichComposerVC *vc = [WKRichComposerVC new];
    if ([context conformsToProtocol:@protocol(WKRichComposerDelegate)]) {
        vc.delegate = (id<WKRichComposerDelegate>)context;
    }
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    UIViewController *top = [WKNavigationManager shared].topViewController;
    [top presentViewController:nav animated:YES completion:nil];
}

- (NSString *)title {
    return LLang(@"富文本");
}

@end
