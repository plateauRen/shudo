//
//  M80AttributedLabel+NIMKit
//  NIM
//
//  Created by chris.
//  Copyright (c) 2015 Netease. All rights reserved.
//

#import "M80AttributedLabel+WK.h"
#import "WKEmoticonService.h"
#import "WKMentionService.h"
#import "WKApp.h"


@implementation M80AttributedLabel (WK)


- (void)lim_setText:(NSString *)text mentionInfo:(WKMentionedInfo*)mentionInfo {
    [self setText:@""];
    if(!text || [text isEqualToString:@""]) {
        return;
    }

    UIColor *mentionColor = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
    NSArray<id<WKMatchToken>> *tokens = [ [WKEmoticonService shared] parseEmotion:text];
    for(id<WKMatchToken> token in tokens){
           if (token.type == WKatchTokenTypeEmoji){
               WKEmotionToken *emojiToken = (WKEmotionToken*)token;
               UIImage *image = [[WKEmoticonService shared] emojiImageNamed:emojiToken.imageName];
               if(image){
                   [self appendImage:image maxSize:CGSizeMake(24.0f, 24.0f)];
               }
           }else{
               NSString *partText = token.text;
               NSArray<id<WKMatchToken>> *mentions = [[WKMentionService shared] parseMention:partText mentionInfo:mentionInfo];
               if(mentions && mentions.count>0) {
                   for(id<WKMatchToken> mtoken in mentions) {
                       if(mtoken.type == WKatchTokenTypeMetion) {
                           WKMetionToken *mentionToken = (WKMetionToken*)mtoken;
                           NSRange range = NSMakeRange(self.attributedText.length, mentionToken.text.length);
                           [self appendText:mentionToken.text];
                           [self addCustomLink:mentionToken forRange:range linkColor:mentionColor];
                       }else{
                           [self appendText:mtoken.text];
                       }
                   }
               } else {
                    [self appendText:partText];
               }
           }
       }
}

- (void)lim_setText:(NSString *)text
{
    [self lim_setText:text mentionInfo:nil];
   
}

@end
