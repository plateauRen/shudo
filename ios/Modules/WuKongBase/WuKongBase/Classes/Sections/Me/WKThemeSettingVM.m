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
            @"remark": LLang(@"选择品牌主题色，将应用于按钮、链接、气泡与图标强调色"),
            @"items": @[
                @{
                    @"class": WKLabelItemSelectModel.class,
                    @"label": LLang(@"荧光橙"),
                    @"selected": @(WKApp.shared.config.brandTheme == WKBrandThemeOrange),
                    @"onClick": ^{
                        WKApp.shared.config.brandTheme = WKBrandThemeOrange;
                        [weakSelf reloadData];
                    }
                },
                @{
                    @"class": WKLabelItemSelectModel.class,
                    @"label": LLang(@"荧光蓝"),
                    @"selected": @(WKApp.shared.config.brandTheme == WKBrandThemeBlue),
                    @"onClick": ^{
                        WKApp.shared.config.brandTheme = WKBrandThemeBlue;
                        [weakSelf reloadData];
                    }
                },
            ],
        },
    ];
}

@end
