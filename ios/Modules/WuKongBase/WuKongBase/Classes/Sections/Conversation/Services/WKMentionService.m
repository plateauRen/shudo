//
//  WKMentionService.m
//  WuKongBase
//
//  Created by tt on 2020/7/16.
//

#import "WKMentionService.h"



@implementation WKMentionService
static WKMentionService *_instance;
+ (WKMentionService *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

-(NSArray<id<WKMatchToken>>*)parseMention:(NSString *)str mentionInfo:(WKMentionedInfo *)mentionInfo{
    static NSRegularExpression *atExp; // @正则表达式
    if(!atExp) {
        // 不用 \\b：中文昵称在 NSRegularExpression 里常被当成非 word，\\b 会导致匹配失败
        atExp = [NSRegularExpression regularExpressionWithPattern:@"@[^\\s@]+"
        options:NSRegularExpressionCaseInsensitive
          error:nil];
    }
     __block NSInteger index = 0;
     __block NSInteger mentionIndex = 0;
      NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];
    [atExp enumerateMatchesInString:str
       options:0
         range:NSMakeRange(0, [str length])
    usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.range.location > index){
            NSRange rawRange = NSMakeRange(index, result.range.location - index);
            NSString *rawText = [str substringWithRange:rawRange];
            
            [tokens addObject:[WKDefaultToken text:rawText range:rawRange type:WKatchTokenTypeText]];
        }
        NSString *atUID = @"";
        if(mentionInfo && mentionInfo.uids && mentionInfo.uids.count>mentionIndex) {
            atUID = mentionInfo.uids[mentionIndex] ?: @"";
            mentionIndex++;
        }
        NSString *rangeText = [str substringWithRange:result.range];
        // 始终按 mention token 输出，保证 @人名有主题色标注（即使缺少 uid）
        WKMetionToken *token = [WKMetionToken new];
        token.text = rangeText;
        token.range = result.range;
        token.index = mentionIndex > 0 ? mentionIndex - 1 : 0;
        token.uid = atUID;
        [tokens addObject:token];
      
        index = result.range.location + result.range.length;
    }];
    if (index < [str length])
    {
        NSRange range = NSMakeRange(index, [str length] - index);
        NSString *rawText = [str substringWithRange:range];
        [tokens addObject:[WKDefaultToken text:rawText range:range type:WKatchTokenTypeText]];
    }
    return tokens;
}
@end
