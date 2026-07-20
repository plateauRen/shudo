//
//  WKTranslateSettingVM.m
//  WuKongBase
//

#import "WKTranslateSettingVM.h"
#import "WKSwitchItemCell.h"
#import "WKTranslateManager.h"

@implementation WKTranslateSettingVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    WKTranslateManager *mgr = [WKTranslateManager shared];
    __weak typeof(self) weakSelf = self;

    NSMutableArray *langItems = [NSMutableArray array];
    for (NSDictionary *lang in mgr.supportedLanguages) {
        NSString *code = lang[@"code"];
        [langItems addObject:@{
            @"class": WKLabelItemSelectModel.class,
            @"label": lang[@"name"] ?: code,
            @"selected": @([mgr.targetLanguage isEqualToString:code]),
            @"onClick": ^{
                mgr.targetLanguage = code;
                [weakSelf reloadData];
            },
        }];
    }

    return @[
        @{
            @"height": @(0.0f),
            @"remark": LLang(@"开启后，会话中收到的文本消息将自动翻译为目标语言，并显示在原文下方。"),
            @"items": @[
                @{
                    @"class": WKSwitchItemModel.class,
                    @"label": LLang(@"自动翻译"),
                    @"on": @(mgr.autoTranslateEnabled),
                    @"onSwitch": ^(BOOL on) {
                        mgr.autoTranslateEnabled = on;
                        [weakSelf reloadData];
                    },
                },
            ],
        },
        @{
            @"height": WKSectionHeight,
            @"remark": LLang(@"选择译文语言"),
            @"items": langItems,
        },
    ];
}

@end
