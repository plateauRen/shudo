//
//  WKMeVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKMeVM.h"
#import "WKTableSectionUtil.h"
#import "WKMeItemCell.h"
#import "WKMePushSettingVC.h"
#import "WKCommonSettingVC.h"
#import "WKMeItem.h"
#import "WKApp.h"

@interface WKMeVM ()
@property(nonatomic,strong) NSArray<NSDictionary *> *cachedSectionMaps;
@end

@implementation WKMeVM

- (void)invalidateSectionCache {
    self.cachedSectionMaps = nil;
}

- (NSArray<NSDictionary *> *)tableSectionMaps {
    if (self.cachedSectionMaps) {
        return self.cachedSectionMaps;
    }
    NSArray<WKMeItem*> *itemModels = [[WKApp shared] invokes:WKPOINT_CATEGORY_ME param:nil];
    if(!itemModels || itemModels.count<=0) {
        return @[];
    }
    NSMutableArray *items = [NSMutableArray array];
    WKMeItem *preMeItem;
    for (WKMeItem *meItem in itemModels) {
       [items addObject:@{
           @"height":@(meItem.sectionHeight + (preMeItem?preMeItem.nextSectionHeight:0)),
            @"items":@[@{
                           @"class":WKMeItemModel.class,
                           @"title":meItem.title?:@"",
                           @"icon": meItem.icon,
                           @"bottomLeftSpace":@(0.0f),
                           @"showBottomLine":@(NO),
                           @"showTopLine":@(NO),
                           @"onClick":^(BOOL on){
                               if(meItem.onClick) {
                                   meItem.onClick();
                               }
                           }
                       }]
       }];
        preMeItem = meItem;
        
    }
    self.cachedSectionMaps = items;
    return items;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end
