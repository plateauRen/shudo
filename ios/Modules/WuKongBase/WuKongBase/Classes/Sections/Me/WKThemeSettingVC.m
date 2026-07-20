//
//  WKThemeSettingVC.m
//  WuKongBase
//

#import "WKThemeSettingVC.h"

@implementation WKThemeSettingVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.viewModel = [WKThemeSettingVM new];
    }
    return self;
}

- (NSString *)langTitle {
    return LLang(@"主题设置");
}

@end
