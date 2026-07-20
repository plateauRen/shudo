//
//  WKMeVM.h
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKBaseTableVM.h"
#import "WKFormSection.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMeVM : WKBaseTableVM

/// Invalidate cached me-menu sections (call on module/lang/login change).
- (void)invalidateSectionCache;

@end

NS_ASSUME_NONNULL_END
