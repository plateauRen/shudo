//
//  WKTranslateSettingVC.m
//  WuKongBase
//

#import "WKTranslateSettingVC.h"

@implementation WKTranslateSettingVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.viewModel = [WKTranslateSettingVM new];
    }
    return self;
}

- (NSString *)langTitle {
    return LLang(@"翻译");
}

@end
