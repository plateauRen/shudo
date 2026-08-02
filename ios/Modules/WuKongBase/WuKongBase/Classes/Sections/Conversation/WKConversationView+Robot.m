//
//  WKConversationView+Robot.m
//  WuKongBase
//
//  Created by tt on 2022/5/20.
//

#import "WKConversationView+Robot.h"
#import "WuKongBase.h"
#import "WKConversationContextImpl.h"
#import "WKInlineQueryResult.h"
#import "WKInlineQueryManager.h"
#import "WKSlashCommandSuggestView.h"
#import <objc/runtime.h>

static const void *kSlashSuggestViewKey = &kSlashSuggestViewKey;
static const void *kSlashSuggestOnKey = &kSlashSuggestOnKey;

@implementation WKConversationView (Robot)

-(void) initRobot {
    __weak typeof(self) weakSelf = self;
    
    [[WKApp shared] setMethod:WKPOINT_ROBOT_INPUT_TEXT_CHANGE handler:^id _Nullable(id  _Nonnull param) {
        [weakSelf inputTextChange];
        return nil;
    } category:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_CHANGE];
    
    [self.input.menusBtn setOnClick:^(BOOL open) {
        [weakSelf showRobotMenus:open];
    }];
   
}


-(void) inputTextChange {

    [self triggerSlashCommandSuggestIfNeed];
    [self triggerRobotInlineSearchIfNeed];
    
    if(self.robotInlineOn && self.currentRobotInline && self.currentRobotInline.inlineOn) {
        NSString *text = self.input.textView.text;
        NSString *lang = self.input.textView.internalTextView.textInputMode.primaryLanguage;
        if ([lang isEqualToString:@"zh-Hans"]){
            UITextRange *selectedRange = [self.input.textView.internalTextView markedTextRange];
            if (selectedRange) {// 高亮不执行
                return;
            }
        }
        NSArray<NSString*> *splits = [text componentsSeparatedByString:@" "];
        if(splits.count>1) {
            NSString *query = [text substringFromIndex:splits[0].length];
            query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [self requestAndShowRobotInlineQuery:query username:self.currentRobotInline.username offset:@""];
        }
    }
}

#pragma mark - Slash command suggest (/)

-(BOOL) slashSuggestOn {
    return [objc_getAssociatedObject(self, kSlashSuggestOnKey) boolValue];
}

-(void) setSlashSuggestOn:(BOOL)on {
    objc_setAssociatedObject(self, kSlashSuggestOnKey, @(on), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(WKSlashCommandSuggestView *)slashSuggestView {
    WKSlashCommandSuggestView *view = objc_getAssociatedObject(self, kSlashSuggestViewKey);
    if (!view) {
        view = [[WKSlashCommandSuggestView alloc] initWithFrame:CGRectMake(0, 0, self.lim_width, 0)];
        __weak typeof(self) weakSelf = self;
        view.onSelect = ^(WKSlashCommandItem *item) {
            [weakSelf applySlashCommand:item];
        };
        objc_setAssociatedObject(self, kSlashSuggestViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

/// Hermes / 机器人常用斜杠指令（中文说明兜底）
-(NSArray<WKSlashCommandItem *> *)defaultHermesSlashCommandsWithRobotID:(NSString *)robotID {
    NSArray *pairs = @[
        @[@"/new", @"开始新对话"],
        @[@"/reset", @"重置会话（同 /new）"],
        @[@"/model", @"切换 AI 模型"],
        @[@"/personality", @"设置人格"],
        @[@"/retry", @"重试上一轮回复"],
        @[@"/undo", @"撤销上一轮"],
        @[@"/compress", @"压缩上下文"],
        @[@"/usage", @"查看用量"],
        @[@"/insights", @"用量洞察"],
        @[@"/skills", @"浏览技能列表"],
        @[@"/stop", @"中断当前任务"],
        @[@"/status", @"查看平台状态"],
        @[@"/help", @"显示帮助"],
        @[@"/approve", @"批准待确认操作"],
        @[@"/deny", @"拒绝待确认操作"],
    ];
    NSMutableArray<WKSlashCommandItem *> *items = [NSMutableArray array];
    for (NSArray *p in pairs) {
        [items addObject:[WKSlashCommandItem cmd:p[0] remark:p[1] robotID:robotID]];
    }
    return items;
}

-(NSString *)preferredRobotIDForSlash {
    if (self.robotMenus.count > 0) {
        WKRobotMenus *m = self.robotMenus.firstObject;
        if (m.robotID.length > 0) return m.robotID;
    }
    if (self.channel.channelType == WK_PERSON) {
        return self.channel.channelId;
    }
    return nil;
}

-(NSDictionary<NSString *, NSString *> *)chineseRemarkLookup {
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"/new": @"开始新对话",
            @"/reset": @"重置会话（同 /new）",
            @"/model": @"切换 AI 模型",
            @"/personality": @"设置人格",
            @"/retry": @"重试上一轮回复",
            @"/undo": @"撤销上一轮",
            @"/compress": @"压缩上下文",
            @"/usage": @"查看用量",
            @"/insights": @"用量洞察",
            @"/skills": @"浏览技能列表",
            @"/stop": @"中断当前任务",
            @"/status": @"查看平台状态",
            @"/help": @"显示帮助",
            @"/approve": @"批准待确认操作",
            @"/deny": @"拒绝待确认操作",
        };
    });
    return map;
}

-(NSArray<WKSlashCommandItem *> *)slashCommandSourceItems {
    NSString *robotID = [self preferredRobotIDForSlash];
    NSMutableArray<WKSlashCommandItem *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSDictionary *zh = [self chineseRemarkLookup];

    if (self.robotMenus.count > 0) {
        for (WKRobotMenus *m in self.robotMenus) {
            NSString *cmd = m.cmd ?: @"";
            if (cmd.length == 0) continue;
            if (![cmd hasPrefix:@"/"]) {
                cmd = [@"/" stringByAppendingString:cmd];
            }
            NSString *key = cmd.lowercaseString;
            if ([seen containsObject:key]) continue;
            [seen addObject:key];
            NSString *remark = m.remark ?: @"";
            // 服务端无说明或非中文时，用本地中文补全
            BOOL hasCJK = [remark rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0x4E00, 0x9FFF)]].location != NSNotFound;
            if (remark.length == 0 || !hasCJK) {
                NSString *local = zh[key] ?: zh[cmd];
                if (local.length > 0) remark = local;
            }
            if (remark.length == 0) remark = @"执行指令";
            [items addObject:[WKSlashCommandItem cmd:cmd remark:remark robotID:m.robotID.length ? m.robotID : robotID]];
        }
    }

    // API 无 menus 时用 Hermes 中文兜底；有 menus 时也把未覆盖的常用指令补上
    for (WKSlashCommandItem *fb in [self defaultHermesSlashCommandsWithRobotID:robotID]) {
        NSString *key = fb.cmd.lowercaseString;
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [items addObject:fb];
    }
    return items;
}

-(void) triggerSlashCommandSuggestIfNeed {
    NSString *text = self.input.textView.text ?: @"";
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // 高亮输入中不弹
    NSString *lang = self.input.textView.internalTextView.textInputMode.primaryLanguage;
    if ([lang isEqualToString:@"zh-Hans"]) {
        UITextRange *selectedRange = [self.input.textView.internalTextView markedTextRange];
        if (selectedRange) {
            return;
        }
    }

    if (![text hasPrefix:@"/"]) {
        [self hideSlashCommandSuggest];
        return;
    }

    // 仅在机器人会话或已有 menus 时启用（个人频道视为对方可能是机器人）
    BOOL canSuggest = (self.robotMenus.count > 0)
        || (self.channel.channelType == WK_PERSON)
        || self.input.showMenusBtn;
    if (!canSuggest) {
        [self hideSlashCommandSuggest];
        return;
    }

    NSArray *parts = [text componentsSeparatedByString:@" "];
    NSString *token = parts.firstObject ?: text;
    NSString *tokenLower = token.lowercaseString;

    NSArray<WKSlashCommandItem *> *source = [self slashCommandSourceItems];
    NSMutableArray<WKSlashCommandItem *> *matched = [NSMutableArray array];
    // 1) 指令前缀：/ 或 /ne → 匹配 /new
    for (WKSlashCommandItem *item in source) {
        if ([item.cmd.lowercaseString hasPrefix:tokenLower]) {
            [matched addObject:item];
        }
    }
    // 2) 中文说明模糊：/帮助、/新对话
    if (matched.count == 0 && token.length > 1) {
        NSString *q = [token substringFromIndex:1];
        for (WKSlashCommandItem *item in source) {
            if (q.length > 0 &&
                ([item.remark containsString:q] ||
                 [item.cmd.lowercaseString containsString:q.lowercaseString])) {
                [matched addObject:item];
            }
        }
    }

    if (matched.count == 0) {
        [self hideSlashCommandSuggest];
        return;
    }

    self.slashSuggestOn = YES;
    WKSlashCommandSuggestView *panel = self.slashSuggestView;
    panel.lim_width = self.lim_width;
    [panel reloadItems:matched];
    [self.conversationContext setInputTopView:panel];
}

-(void) hideSlashCommandSuggest {
    if (!self.slashSuggestOn && self.conversationContext.inputTopView != self.slashSuggestView) {
        return;
    }
    self.slashSuggestOn = NO;
    if (self.conversationContext.inputTopView == self.slashSuggestView) {
        [self.conversationContext setInputTopView:nil];
    }
}

-(void) applySlashCommand:(WKSlashCommandItem *)item {
    if (!item.cmd.length) return;
    NSString *robotID = item.robotID ?: [self preferredRobotIDForSlash];
    [self.conversationContext inputSetText:@""];
    [self hideSlashCommandSuggest];
    [self.conversationContext sendTextMessage:item.cmd
                                     entities:@[[WKMessageEntity type:WKEntityTypeRobotCommand range:NSMakeRange(0, item.cmd.length)]]
                                      robotID:robotID];
}


-(void) requestAndShowRobotInlineQuery:(NSString*)query username:(NSString*)username offset:(NSString*)offset{
    __weak typeof(self) weakSelf = self;
    
    [self requestInlineQuery:query username:username offset:offset].then(^(WKInlineQueryResult *result){
        [weakSelf showInlineQueryView:result query:query username:username];
    }).catch(^(NSError *error){
        WKLogError(@"提交robot查询数据失败！->%@",error);
    });
}

-(AnyPromise*) requestInlineQuery:(NSString*)query username:(NSString*)username offset:(NSString*)offset {
    return [[WKAPIClient sharedClient] POST:@"robot/inline_query" parameters:@{
        @"username":username,
        @"query": query,
        @"offset":offset?:@"",
        @"channel_id": self.channel.channelId,
        @"channel_type": @(self.channel.channelType),
    } model:WKInlineQueryResult.class];
}

-(void) showInlineQueryView:(WKInlineQueryResult*)result query:(NSString*)query username:(NSString*)username{
    if(!self.robotInlineOn) {
        return;
    }
    if(result.results && result.results.count>0) {
        __weak typeof(self) weakSelf = self;
        WKResultPanel *panel = [[WKInlineQueryManager shared] createResultPanel:result context:self.conversationContext];
        [panel setLoadMore:^(NSString *nextOffset,WKLoadMoreCallback callback) {
            [weakSelf requestInlineQuery:query username:username offset:nextOffset].then(^(WKInlineQueryResult *result){
                callback(result,nil);
            }).catch(^(NSError *error){
                callback(nil,error);
            });
        }];
        [self.conversationContext setInputTopView:panel];
    }else {
        [self.conversationContext setInputTopView:nil];
    }
   
}

-(void) cancelInlineQuery {
    [self.conversationContext setInputTopView:nil];
}

-(void) triggerRobotInlineSearchIfNeed {

    if(![self canTriggerSearch]) {
        if(self.robotInlineOn) {
            self.robotInlineOn = false;
            [self cancelInlineQuery];
        }
        
        return;
    }

    // 斜杠联想优先，不与 @inline 抢 topView
    if (self.slashSuggestOn) {
        return;
    }
    
    if(self.robotInlineOn) {
        return;
    }
    
    self.robotInlineOn = true;
   
   NSString *text = self.input.textView.text;
    NSArray *splits = [text componentsSeparatedByString:@" "];
  
    NSString *robotUsername = [splits[0] substringFromIndex:1];
    __weak typeof(self) weakSelf = self;
   WKRobot *robot = [[WKRobotManager shared] getRobotWithUsername:robotUsername];
    if(!robot) {
        [[WKRobotManager shared] syncWithUsernames:@[robotUsername] complete:^(BOOL hasData, NSError * _Nonnull error) {
            if(error) {
                WKLogError(@"同步机器人[%@]数据失败！->%@",robotUsername,error);
                return;
            }
            if(hasData) {
                WKRobot *robot = [[WKRobotManager shared] getRobotWithUsername:robotUsername];
                weakSelf.currentRobotInline = robot;
            }
        }];
    }else{
        self.currentRobotInline = robot;
    }
}


-(BOOL) canTriggerSearch {
    NSString *text = self.input.textView.text;
    if(![text hasPrefix:@"@"]) {
        return false;
    }
//    if(self.mentionCache.itemCount>0) { // 有被选中@的人则不响应机器人
//        return false;
//    }
    if(![text containsString:@" "]) {
        return false;
    }
    return true;
}


-(void) syncRobot:(NSArray<NSString*>*) robotIDs {
    if(!robotIDs || robotIDs.count ==0) {
        return;
    }
    [self initRobotMenus:robotIDs];
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].robotManager sync:robotIDs complete:^(BOOL hasData,NSError * _Nonnull error) {
        if(error) {
            return;
        }
        if(hasData) {
            [weakSelf initRobotMenus:robotIDs];
        }
    }];
}

-(void) initRobotMenus:(NSArray<NSString*>*) robotIDs {
    NSArray<WKRobot*> *robots = [[WKRobotDB shared] queryRobots:robotIDs];
    NSMutableArray *menus = [NSMutableArray array];
    for (WKRobot *robot in robots) {
        if(robot.menus && robot.menus.count>0) {
            [menus addObjectsFromArray:robot.menus];
        }
    }
    self.robotMenus = menus;
    
    self.robotMenusModalView =  [self newRobotMenusModalView];
    
    if(menus && menus.count>0) {
        self.input.showMenusBtn = true;
    }
   
}

- (WKRobotMenusListView *)newRobotMenusModalView {
    WKRobotMenusListView *robotMenusModalView = [WKRobotMenusListView initItems:[self getRobotMenus]];
    robotMenusModalView.targetView = self.input;
    return robotMenusModalView;
}

-(NSArray<WKRobotMenusItem*>*) getRobotMenus {
    
    NSMutableArray *items = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    if(self.robotMenus) {
        for (WKRobotMenus *m in self.robotMenus) {
            NSString *cmd = m.cmd ?: @"";
            NSString *remark = m.remark ?: @"";
            NSDictionary *zh = [self chineseRemarkLookup];
            NSString *cmdKey = cmd;
            if (cmdKey.length && ![cmdKey hasPrefix:@"/"]) {
                cmdKey = [@"/" stringByAppendingString:cmdKey];
            }
            BOOL hasCJK = [remark rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0x4E00, 0x9FFF)]].location != NSNotFound;
            if (remark.length == 0 || !hasCJK) {
                NSString *local = zh[cmdKey.lowercaseString] ?: zh[cmdKey];
                if (local.length > 0) remark = local;
            }
            [items addObject:[WKRobotMenusItem cmd:cmd iconURL:[WKAvatarUtil getAvatar:m.robotID] remark:remark onClick:^{
                [weakSelf.conversationContext sendTextMessage:m.cmd entities:@[[WKMessageEntity type:WKEntityTypeRobotCommand range:NSMakeRange(0, m.cmd.length)]] robotID:m.robotID];
                [weakSelf dismissRobotMenus];
            }]];
        }
        
    }
    
    return items;
}

-(void) dismissRobotMenus {
    [self showRobotMenus:NO];
    self.input.menusBtn.openMenus = NO;
    [self.input.menusBtn changeStatus];
}


// 是否显示机器人菜单
#define robotMenusMinTop 120.0f
-(void) showRobotMenus:(BOOL) show {
    if(show) {
        self.robotMenusModalView.lim_top = self.input.lim_top;
        [self addSubview:self.robotMenusModalView];
        [self bringSubviewToFront:self.input];
        
        [UIView animateWithDuration:0.25f animations:^{
            self.robotMenusModalView.lim_top = self.input.lim_top - robotMenusMinTop;
        }];
    }else{
        [UIView animateWithDuration:0.25f animations:^{
            self.robotMenusModalView.lim_top = self.input.lim_top;
            [self.robotMenusModalView reset];
        } completion:^(BOOL finished) {
            [self.robotMenusModalView removeFromSuperview];
        }];
    }
}


-(void) adjustRobotMenusIfNeed {
    if(self.robotMenusModalView.superview) {
        self.robotMenusModalView.lim_top = self.input.lim_top - robotMenusMinTop;
    }
}


@end
