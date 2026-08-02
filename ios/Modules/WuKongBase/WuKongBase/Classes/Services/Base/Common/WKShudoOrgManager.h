#import <Foundation/Foundation.h>

@class WKChannel;
@class WKMessage;

NS_ASSUME_NONNULL_BEGIN

/// 叙叨扩展服务客户端（文件夹 + 话题），对接 services/shudo-org :8092
@interface WKShudoOrgManager : NSObject

+ (instancetype)shared;

@property(nonatomic, copy, readonly) NSArray<NSDictionary *> *folders;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, NSDictionary *> *subChannelMap;

- (NSString *)baseURL;
- (void)loadCache;
- (void)refreshFolders:(void (^_Nullable)(NSError *_Nullable error))complete;
- (void)refreshSubChannelMap:(void (^_Nullable)(NSError *_Nullable error))complete;

/// 系统默认「话题」分组名（不可删改）
+ (NSString *)topicsFolderName;

- (void)createFolder:(NSString *)name
            complete:(void (^_Nullable)(NSDictionary *_Nullable folder, NSError *_Nullable error))complete;
- (void)renameFolder:(NSString *)folderId
                name:(NSString *)name
            complete:(void (^_Nullable)(NSError *_Nullable error))complete;
- (void)deleteFolder:(NSString *)folderId
            complete:(void (^_Nullable)(NSError *_Nullable error))complete;
- (void)addChannel:(NSString *)channelId
              type:(NSInteger)channelType
          toFolder:(NSString *)folderId
          complete:(void (^_Nullable)(NSError *_Nullable error))complete;
- (void)removeChannel:(NSString *)channelId
                 type:(NSInteger)channelType
           fromFolder:(NSString *)folderId
             complete:(void (^_Nullable)(NSError *_Nullable error))complete;

- (BOOL)folder:(NSDictionary *)folder containsChannel:(NSString *)channelId type:(NSInteger)channelType;
- (NSArray<NSDictionary *> *)foldersContainingChannel:(NSString *)channelId type:(NSInteger)channelType;

- (void)addFoldersListener:(void (^)(void))listener;
- (void)removeFoldersListener:(void (^)(void))listener;

- (void)createSubChannel:(NSString *)title
               inParent:(NSString *)parentGroupNo
               complete:(void (^_Nullable)(NSDictionary *_Nullable info, NSError *_Nullable error))complete;
/// 群内创建话题（可附带种子消息）
- (void)createSubChannel:(NSString *)title
               inParent:(NSString *)parentGroupNo
            seedPayload:(nullable NSDictionary *)seedPayload
            seedFromUid:(nullable NSString *)seedFromUid
               complete:(void (^_Nullable)(NSDictionary *_Nullable info, NSError *_Nullable error))complete;

/// 从私聊 / bot 会话创建话题（对接 POST /topics/from-person）
- (void)createTopicFromPerson:(NSString *)peerUid
                        title:(NSString *)title
                      fromUid:(nullable NSString *)fromUid
                  seedPayload:(nullable NSDictionary *)seedPayload
                  seedFromUid:(nullable NSString *)seedFromUid
                     complete:(void (^_Nullable)(NSDictionary *_Nullable info, NSError *_Nullable error))complete;

/// 解析私聊对方 uid（支持 `user@robot`）
- (NSString *)resolvePersonPeerUid:(nullable NSString *)channelId fromUid:(nullable NSString *)fromUid;

- (void)listSubChannels:(NSString *)parentGroupNo
               complete:(void (^_Nullable)(NSArray *_Nullable list, NSError *_Nullable error))complete;
/// @param includeArchived 是否包含已归档话题
- (void)listSubChannels:(NSString *)parentGroupNo
       includeArchived:(BOOL)includeArchived
               complete:(void (^_Nullable)(NSArray *_Nullable list, NSError *_Nullable error))complete;
- (void)syncSubChannelMembers:(NSString *)parentGroupNo
                     complete:(void (^_Nullable)(NSError *_Nullable error))complete;

/// 改名话题
- (void)renameSubChannel:(NSString *)subGroupNo
                   title:(NSString *)title
                complete:(void (^_Nullable)(NSDictionary *_Nullable info, NSError *_Nullable error))complete;
/// 归档 / 取消归档
- (void)setSubChannel:(NSString *)subGroupNo
             archived:(BOOL)archived
             complete:(void (^_Nullable)(NSDictionary *_Nullable info, NSError *_Nullable error))complete;
/// 删除话题元数据；默认解散底层群
- (void)deleteSubChannel:(NSString *)subGroupNo
                 disband:(BOOL)disband
                complete:(void (^_Nullable)(NSError *_Nullable error))complete;

- (nullable NSDictionary *)subChannelMeta:(NSString *)groupNo;

/// 话题父键：群用 groupNo；私聊用 dm:{peer}
- (NSString *)parentKeyForChannel:(WKChannel *)channel fromUid:(nullable NSString *)fromUid;
/// 当前会话是否可作为话题父级
- (BOOL)canHostTopicsInChannel:(WKChannel *)channel;

/// 弹出话题名称输入并创建；成功后打开话题会话。
/// @param channel 当前会话（群或私聊）
/// @param seedMessage 可选，用于种子消息与默认标题
- (void)promptCreateTopicFromChannel:(WKChannel *)channel
                         seedMessage:(nullable WKMessage *)seedMessage;

/// 打开话题管理页（父群 / 私聊）
- (void)openManageTopicsForChannel:(WKChannel *)channel;
/// 从话题会话跳回所属群或私聊
- (void)openParentOfTopicChannel:(WKChannel *)channel;
/// 父频道上弹出「创建话题 / 管理话题」；话题内弹出「打开所属群/私聊」
- (void)presentTopicActionsForChannel:(WKChannel *)channel;

@end

NS_ASSUME_NONNULL_END
