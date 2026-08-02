//
//  WKThemeSettingVM.m
//  WuKongBase
//

#import "WKThemeSettingVM.h"

@implementation WKThemeSettingVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    __weak typeof(self) weakSelf = self;
    return @[
        @{
            @"height": @(0.0f),
            @"remark": LLang(@"选择品牌主题色，将应用于按钮、链接、气泡、Logo 与默认头像"),
            @"items": @[
                @{
                    @"class": WKLabelItemSelectModel.class,
                    @"label": LLang(@"石青"),
                    @"selected": @(WKApp.shared.config.brandTheme == WKBrandThemeShiQing),
                    @"onClick": ^{
                        WKApp.shared.config.brandTheme = WKBrandThemeShiQing;
                        [weakSelf reloadData];
                    }
                },
                @{
                    @"class": WKLabelItemSelectModel.class,
                    @"label": LLang(@"玄青"),
                    @"selected": @(WKApp.shared.config.brandTheme == WKBrandThemeXuanQing),
                    @"onClick": ^{
                        WKApp.shared.config.brandTheme = WKBrandThemeXuanQing;
                        [weakSelf reloadData];
                    }
                },
                @{
                    @"class": WKLabelItemSelectModel.class,
                    @"label": LLang(@"松烟"),
                    @"selected": @(WKApp.shared.config.brandTheme == WKBrandThemeSongYan),
                    @"onClick": ^{
                        WKApp.shared.config.brandTheme = WKBrandThemeSongYan;
                        [weakSelf reloadData];
                    }
                },
                @{
                    @"class": WKLabelItemSelectModel.class,
                    @"label": LLang(@"雾蓝"),
                    @"selected": @(WKApp.shared.config.brandTheme == WKBrandThemeWuLan),
                    @"onClick": ^{
                        WKApp.shared.config.brandTheme = WKBrandThemeWuLan;
                        [weakSelf reloadData];
                    }
                },
            ],
        },
    ];
}

@end
