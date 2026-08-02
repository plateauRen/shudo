#import "WKShudoOrgManager.h"
#import "WKApp.h"
#import "WKLoginInfo.h"
#import "WKNavigationManager.h"
#import "WKSubChannelsVC.h"
#import "UIView+WKCommon.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

static NSString *const kFoldersCacheKey = @"shudo-folders-cache";
static NSString *const kSubMapCacheKey = @"shudo-subchannel-map";
static NSString *const kTopicsFolderName = @"话题";

@interface WKShudoOrgManager ()
@property(nonatomic, copy, readwrite) NSArray<NSDictionary *> *folders;
@property(nonatomic, copy, readwrite) NSDictionary<NSString *, NSDictionary *> *subChannelMap;
@property(nonatomic, strong) NSMutableArray *folderListeners;
@end

@implementation WKShudoOrgManager

+ (instancetype)shared {
    static WKShudoOrgManager *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [WKShudoOrgManager new];
    });
    return m;
}

+ (NSString *)topicsFolderName {
    return kTopicsFolderName;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _folders = @[];
        _subChannelMap = @{};
        _folderListeners = [NSMutableArray array];
        [self loadCache];
    }
    return self;
}

- (void)emitFoldersChanged {
    NSArray *copy = [self.folderListeners copy];
    for (void (^fn)(void) in copy) {
        if (fn) fn();
    }
}

- (void)addFoldersListener:(void (^)(void))listener {
    if (!listener) return;
    // 不二次 copy，保证 remove 时能按同一 block 指针移除
    if (![self.folderListeners containsObject:listener]) {
        [self.folderListeners addObject:listener];
    }
}

- (void)removeFoldersListener:(void (^)(void))listener {
    if (!listener) return;
    [self.folderListeners removeObject:listener];
}

- (NSString *)baseURL {
    NSString *api = [WKApp shared].config.apiBaseUrl ?: @"";
    NSURL *u = [NSURL URLWithString:api];
    if (!u.host) {
        return @"http://127.0.0.1:8092/v1/shudo";
    }
    NSString *scheme = u.scheme ?: @"http";
    return [NSString stringWithFormat:@"%@://%@:8092/v1/shudo", scheme, u.host];
}

- (NSDictionary *)authHeaders {
    NSString *token = [WKApp shared].loginInfo.token ?: @"";
    NSString *uid = [WKApp shared].loginInfo.uid ?: @"";
    return @{
        @"Content-Type": @"application/json",
        @"token": token,
        @"uid": uid,
    };
}

- (void)loadCache {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    id f = [ud objectForKey:kFoldersCacheKey];
    if ([f isKindOfClass:NSArray.class]) {
        self.folders = f;
    }
    id m = [ud objectForKey:kSubMapCacheKey];
    if ([m isKindOfClass:NSDictionary.class]) {
        self.subChannelMap = m;
    }
}

- (void)saveFoldersCache {
    [NSUserDefaults.standardUserDefaults setObject:self.folders ?: @[] forKey:kFoldersCacheKey];
}

- (void)saveSubMapCache {
    [NSUserDefaults.standardUserDefaults setObject:self.subChannelMap ?: @{} forKey:kSubMapCacheKey];
}

- (void)request:(NSString *)method
           path:(NSString *)path
           body:(id)body
       complete:(void (^)(id _Nullable json, NSError *_Nullable error))complete {
    NSString *url = [[self baseURL] stringByAppendingString:path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    req.HTTPMethod = method;
    [[self authHeaders] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [req setValue:obj forHTTPHeaderField:key];
    }];
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (complete) complete(nil, error); });
            return;
        }
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : @{};
        if (code >= 400) {
            NSString *msg = @"请求失败";
            if ([json isKindOfClass:NSDictionary.class]) {
                msg = json[@"detail"] ?: json[@"msg"] ?: msg;
            }
            NSError *err = [NSError errorWithDomain:@"WKShudoOrg" code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (complete) complete(nil, err); });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (complete) complete(json, nil); });
    }] resume];
}

- (void)refreshFolders:(void (^)(NSError * _Nullable))complete {
    [self request:@"GET" path:@"/folders" body:nil complete:^(id json, NSError *error) {
        if (!error && [json isKindOfClass:NSDictionary.class]) {
            NSArray *folders = json[@"folders"];
            if ([folders isKindOfClass:NSArray.class]) {
                self.folders = folders;
                [self saveFoldersCache];
                [self emitFoldersChanged];
            }
        }
        if (complete) complete(error);
    }];
}

- (void)refreshSubChannelMap:(void (^)(NSError * _Nullable))complete {
    [self request:@"GET" path:@"/subchannels/map" body:nil complete:^(id json, NSError *error) {
        if (!error && [json isKindOfClass:NSDictionary.class]) {
            NSDictionary *map = json[@"map"];
            if ([map isKindOfClass:NSDictionary.class]) {
                self.subChannelMap = map;
                [self saveSubMapCache];
            }
        }
        if (complete) complete(error);
    }];
}

- (void)createFolder:(NSString *)name complete:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))complete {
    [self request:@"POST" path:@"/folders" body:@{@"name": name ?: @""} complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshFolders:^(NSError *e) { if (complete) complete(json, e ?: error); }];
        } else if (complete) {
            complete(nil, error);
        }
    }];
}

- (void)renameFolder:(NSString *)folderId name:(NSString *)name complete:(void (^)(NSError * _Nullable))complete {
    NSString *path = [NSString stringWithFormat:@"/folders/%@", folderId];
    [self request:@"PUT" path:path body:@{@"name": name ?: @""} complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshFolders:complete];
        } else if (complete) {
            complete(error);
        }
    }];
}

- (void)deleteFolder:(NSString *)folderId complete:(void (^)(NSError * _Nullable))complete {
    NSString *path = [NSString stringWithFormat:@"/folders/%@", folderId];
    [self request:@"DELETE" path:path body:nil complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshFolders:complete];
        } else if (complete) {
            complete(error);
        }
    }];
}

- (BOOL)folder:(NSDictionary *)folder containsChannel:(NSString *)channelId type:(NSInteger)channelType {
    if (![folder isKindOfClass:NSDictionary.class] || !channelId.length) return NO;
    for (NSDictionary *it in folder[@"items"] ?: @[]) {
        if (![it isKindOfClass:NSDictionary.class]) continue;
        if ([it[@"channel_id"] isEqualToString:channelId] && [it[@"channel_type"] integerValue] == channelType) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSDictionary *> *)foldersContainingChannel:(NSString *)channelId type:(NSInteger)channelType {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *f in self.folders) {
        if ([self folder:f containsChannel:channelId type:channelType]) {
            [out addObject:f];
        }
    }
    return out;
}

- (void)addChannel:(NSString *)channelId
              type:(NSInteger)channelType
          toFolder:(NSString *)folderId
          complete:(void (^)(NSError * _Nullable))complete {
    NSDictionary *folder = nil;
    for (NSDictionary *f in self.folders) {
        if ([f[@"folder_id"] isEqualToString:folderId]) {
            folder = f;
            break;
        }
    }
    NSMutableArray *items = [NSMutableArray arrayWithArray:folder[@"items"] ?: @[]];
    for (NSDictionary *it in items) {
        if ([it[@"channel_id"] isEqualToString:channelId] && [it[@"channel_type"] integerValue] == channelType) {
            if (complete) complete(nil);
            return;
        }
    }
    [items addObject:@{@"channel_id": channelId ?: @"", @"channel_type": @(channelType)}];
    NSString *path = [NSString stringWithFormat:@"/folders/%@/items", folderId];
    [self request:@"PUT" path:path body:@{@"items": items} complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshFolders:complete];
        } else if (complete) {
            complete(error);
        }
    }];
}

- (void)removeChannel:(NSString *)channelId
                 type:(NSInteger)channelType
           fromFolder:(NSString *)folderId
             complete:(void (^)(NSError * _Nullable))complete {
    NSDictionary *folder = nil;
    for (NSDictionary *f in self.folders) {
        if ([f[@"folder_id"] isEqualToString:folderId]) {
            folder = f;
            break;
        }
    }
    if (!folder) {
        if (complete) complete(nil);
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *it in folder[@"items"] ?: @[]) {
        if ([it[@"channel_id"] isEqualToString:channelId] && [it[@"channel_type"] integerValue] == channelType) {
            continue;
        }
        [items addObject:it];
    }
    NSString *path = [NSString stringWithFormat:@"/folders/%@/items", folderId];
    [self request:@"PUT" path:path body:@{@"items": items} complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshFolders:complete];
        } else if (complete) {
            complete(error);
        }
    }];
}

- (void)createSubChannel:(NSString *)title
               inParent:(NSString *)parentGroupNo
               complete:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))complete {
    [self createSubChannel:title inParent:parentGroupNo seedPayload:nil seedFromUid:nil complete:complete];
}

- (void)createSubChannel:(NSString *)title
               inParent:(NSString *)parentGroupNo
            seedPayload:(NSDictionary *)seedPayload
            seedFromUid:(NSString *)seedFromUid
               complete:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))complete {
    NSString *path = [NSString stringWithFormat:@"/groups/%@/subchannels", parentGroupNo];
    NSMutableDictionary *body = [@{@"title": title ?: @""} mutableCopy];
    if ([seedPayload isKindOfClass:NSDictionary.class] && seedPayload.count) {
        body[@"seed_payload"] = seedPayload;
        if (seedFromUid.length) body[@"seed_from_uid"] = seedFromUid;
    }
    [self request:@"POST" path:path body:body complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshSubChannelMap:^(NSError *e) {
                [self refreshFolders:^(NSError *fe) {
                    if (complete) complete(json, e ?: fe ?: error);
                }];
            }];
        } else if (complete) {
            complete(nil, error);
        }
    }];
}

- (NSString *)resolvePersonPeerUid:(NSString *)channelId fromUid:(NSString *)fromUid {
    NSString *me = [WKApp shared].loginInfo.uid ?: @"";
    NSString *(^normalize)(NSString *) = ^NSString *(NSString *raw) {
        NSString *idStr = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!idStr.length) return @"";
        if ([idStr containsString:@"@"]) {
            NSArray *parts = [idStr componentsSeparatedByString:@"@"];
            NSString *left = parts.firstObject ?: @"";
            NSString *right = parts.count > 1 ? parts[1] : @"";
            if (right.length && ![right isEqualToString:me]) return right;
            if (left.length && ![left isEqualToString:me]) return left;
            return right.length ? right : left;
        }
        return ![idStr isEqualToString:me] ? idStr : @"";
    };
    for (NSString *cand in @[channelId ?: @"", fromUid ?: @""]) {
        NSString *peer = normalize(cand);
        if (peer.length) return peer;
    }
    return @"";
}

- (void)createTopicFromPerson:(NSString *)peerUid
                        title:(NSString *)title
                      fromUid:(NSString *)fromUid
                  seedPayload:(NSDictionary *)seedPayload
                  seedFromUid:(NSString *)seedFromUid
                     complete:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))complete {
    NSString *me = [WKApp shared].loginInfo.uid ?: @"";
    NSString *peer = [peerUid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *from = [fromUid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ((!peer.length || [peer isEqualToString:me]) && from.length && ![from isEqualToString:me]) {
        peer = from;
    }
    if ([peer containsString:@"@"]) {
        peer = [self resolvePersonPeerUid:peer fromUid:from];
    }
    if (!peer.length || [peer isEqualToString:me]) {
        NSError *err = [NSError errorWithDomain:@"WKShudoOrg" code:400 userInfo:@{NSLocalizedDescriptionKey: @"无效的会话对象"}];
        if (complete) complete(nil, err);
        return;
    }
    NSMutableDictionary *body = [@{
        @"title": title ?: @"",
        @"peer_uid": peer,
    } mutableCopy];
    if (from.length) body[@"from_uid"] = from;
    if ([seedPayload isKindOfClass:NSDictionary.class] && seedPayload.count) {
        body[@"seed_payload"] = seedPayload;
        NSString *seedFrom = seedFromUid.length ? seedFromUid : from;
        if (seedFrom.length) body[@"seed_from_uid"] = seedFrom;
    }
    [self request:@"POST" path:@"/topics/from-person" body:body complete:^(id json, NSError *error) {
        if (!error) {
            [self refreshSubChannelMap:^(NSError *e) {
                [self refreshFolders:^(NSError *fe) {
                    if (complete) complete(json, e ?: fe ?: error);
                }];
            }];
        } else if (complete) {
            complete(nil, error);
        }
    }];
}

- (void)listSubChannels:(NSString *)parentGroupNo
               complete:(void (^)(NSArray * _Nullable, NSError * _Nullable))complete {
    [self listSubChannels:parentGroupNo includeArchived:NO complete:complete];
}

- (void)listSubChannels:(NSString *)parentGroupNo
       includeArchived:(BOOL)includeArchived
               complete:(void (^)(NSArray * _Nullable, NSError * _Nullable))complete {
    NSString *path = [NSString stringWithFormat:@"/groups/%@/subchannels%@",
                      parentGroupNo, includeArchived ? @"?include_archived=1" : @""];
    [self request:@"GET" path:path body:nil complete:^(id json, NSError *error) {
        NSArray *list = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            list = json[@"subchannels"];
        }
        if (complete) complete(list, error);
    }];
}

- (void)syncSubChannelMembers:(NSString *)parentGroupNo
                     complete:(void (^)(NSError * _Nullable))complete {
    NSString *path = [NSString stringWithFormat:@"/groups/%@/subchannels/sync-members", parentGroupNo];
    [self request:@"POST" path:path body:@{} complete:^(id json, NSError *error) {
        if (complete) complete(error);
    }];
}

- (void)renameSubChannel:(NSString *)subGroupNo
                   title:(NSString *)title
                complete:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))complete {
    if (!subGroupNo.length) {
        if (complete) complete(nil, [NSError errorWithDomain:@"shudo" code:400 userInfo:@{NSLocalizedDescriptionKey:@"无效话题"}]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/subchannels/%@", subGroupNo];
    [self request:@"PATCH" path:path body:@{@"title": title ?: @""} complete:^(id json, NSError *error) {
        if (error) {
            if (complete) complete(nil, error);
            return;
        }
        [self refreshSubChannelMap:^(NSError *e) {
            if (complete) complete([json isKindOfClass:NSDictionary.class] ? json : nil, e ?: error);
        }];
    }];
}

- (void)setSubChannel:(NSString *)subGroupNo
             archived:(BOOL)archived
             complete:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))complete {
    if (!subGroupNo.length) {
        if (complete) complete(nil, [NSError errorWithDomain:@"shudo" code:400 userInfo:@{NSLocalizedDescriptionKey:@"无效话题"}]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/subchannels/%@", subGroupNo];
    [self request:@"PATCH" path:path body:@{@"archived": @(archived)} complete:^(id json, NSError *error) {
        if (error) {
            if (complete) complete(nil, error);
            return;
        }
        [self refreshSubChannelMap:^(NSError *e1) {
            [self refreshFolders:^(NSError *e2) {
                if (complete) complete([json isKindOfClass:NSDictionary.class] ? json : nil, e1 ?: e2);
            }];
        }];
    }];
}

- (void)deleteSubChannel:(NSString *)subGroupNo
                 disband:(BOOL)disband
                complete:(void (^)(NSError * _Nullable))complete {
    if (!subGroupNo.length) {
        if (complete) complete([NSError errorWithDomain:@"shudo" code:400 userInfo:@{NSLocalizedDescriptionKey:@"无效话题"}]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/subchannels/%@?disband=%d", subGroupNo, disband ? 1 : 0];
    [self request:@"DELETE" path:path body:nil complete:^(id json, NSError *error) {
        if (error) {
            if (complete) complete(error);
            return;
        }
        [self refreshSubChannelMap:^(NSError *e1) {
            [self refreshFolders:^(NSError *e2) {
                if (complete) complete(e1 ?: e2);
            }];
        }];
    }];
}

- (NSDictionary *)subChannelMeta:(NSString *)groupNo {
    if (!groupNo.length) return nil;
    return self.subChannelMap[groupNo];
}

- (NSString *)parentKeyForChannel:(WKChannel *)channel fromUid:(NSString *)fromUid {
    if (!channel) return @"";
    if (channel.channelType == WK_PERSON) {
        NSString *peer = [self resolvePersonPeerUid:channel.channelId fromUid:fromUid];
        if (!peer.length) peer = channel.channelId ?: @"";
        NSString *key = [NSString stringWithFormat:@"dm:%@", peer ?: @""];
        if (key.length > 40) key = [key substringToIndex:40];
        return key;
    }
    if (channel.channelType == WK_GROUP) {
        return channel.channelId ?: @"";
    }
    return @"";
}

- (BOOL)canHostTopicsInChannel:(WKChannel *)channel {
    if (!channel) return NO;
    if (channel.channelType == WK_PERSON) return YES;
    if (channel.channelType != WK_GROUP) return NO;
    return [self subChannelMeta:channel.channelId] == nil;
}

- (void)openManageTopicsForChannel:(WKChannel *)channel {
    if (![self canHostTopicsInChannel:channel]) return;
    WKSubChannelsVC *vc = [WKSubChannelsVC new];
    vc.parentChannel = channel;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)openParentOfTopicChannel:(WKChannel *)channel {
    if (!channel || channel.channelType != WK_GROUP) return;
    NSDictionary *meta = [self subChannelMeta:channel.channelId];
    NSString *parentNo = meta[@"parent_group_no"] ?: @"";
    if (!parentNo.length) return;
    if ([parentNo hasPrefix:@"dm:"]) {
        NSString *peer = [parentNo substringFromIndex:3];
        if (peer.length) {
            [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:peer channelType:WK_PERSON]];
        }
    } else {
        [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:parentNo channelType:WK_GROUP]];
    }
}

- (void)presentTopicActionsForChannel:(WKChannel *)channel {
    if (!channel) return;
    UIViewController *top = [WKNavigationManager shared].topViewController;
    if (!top) return;
    if ([self canHostTopicsInChannel:channel]) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"话题"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        __weak typeof(self) weakSelf = self;
        [sheet addAction:[UIAlertAction actionWithTitle:@"创建话题" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf promptCreateTopicFromChannel:channel seedMessage:nil];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"管理话题" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf openManageTopicsForChannel:channel];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [top presentViewController:sheet animated:YES completion:nil];
        return;
    }
    if (channel.channelType == WK_GROUP && [self subChannelMeta:channel.channelId]) {
        NSDictionary *meta = [self subChannelMeta:channel.channelId];
        NSString *parentNo = meta[@"parent_group_no"] ?: @"";
        NSString *title = [parentNo hasPrefix:@"dm:"] ? @"打开私聊" : @"打开所属群";
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"话题"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        __weak typeof(self) weakSelf = self;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf openParentOfTopicChannel:channel];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [top presentViewController:sheet animated:YES completion:nil];
    }
}

- (void)promptCreateTopicFromChannel:(WKChannel *)channel
                         seedMessage:(WKMessage *)seedMessage {
    if (![self canHostTopicsInChannel:channel]) return;
    NSString *hint = @"";
    if (seedMessage) {
        hint = [[seedMessage.content conversationDigest] ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (hint.length > 20) hint = [hint substringToIndex:20];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"创建话题" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"话题名称";
        if (hint.length) textField.text = hint;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *title = alert.textFields.firstObject.text ?: @"";
        title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!title.length) return;
        NSDictionary *seedPayload = nil;
        NSString *seedFrom = seedMessage.fromUid;
        if (seedMessage.content) {
            [seedMessage.content encode];
            if ([seedMessage.content.contentDict isKindOfClass:NSDictionary.class] && seedMessage.content.contentDict.count) {
                seedPayload = seedMessage.content.contentDict;
            }
        }
        void (^onDone)(NSDictionary *, NSError *) = ^(NSDictionary *info, NSError *error) {
            if (error) {
                [[WKNavigationManager shared].topViewController.view showHUDWithHide:error.localizedDescription ?: @"创建话题失败"];
                return;
            }
            NSString *subNo = info[@"sub_group_no"];
            if (subNo.length) {
                [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:subNo channelType:WK_GROUP]];
            }
        };
        if (channel.channelType == WK_GROUP) {
            [self createSubChannel:title
                          inParent:channel.channelId
                       seedPayload:seedPayload
                       seedFromUid:seedFrom
                          complete:onDone];
        } else {
            NSString *peer = [self resolvePersonPeerUid:channel.channelId fromUid:seedFrom];
            if (!peer.length) peer = channel.channelId;
            [self createTopicFromPerson:peer
                                  title:title
                                fromUid:seedFrom
                            seedPayload:seedPayload
                            seedFromUid:seedFrom
                               complete:onDone];
        }
    }]];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

@end
