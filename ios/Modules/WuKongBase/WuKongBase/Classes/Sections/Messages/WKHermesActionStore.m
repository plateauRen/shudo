//
//  WKHermesActionStore.m
//  WuKongBase
//

#import "WKHermesActionStore.h"

static NSString * const kHermesActionStoreKey = @"wk.hermes.action.store.v1";
static const NSInteger kHermesActionStoreMax = 200;

@implementation WKHermesActionStore

+ (NSMutableDictionary *)mutableStore {
    NSDictionary *raw = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kHermesActionStoreKey];
    return raw ? [raw mutableCopy] : [NSMutableDictionary dictionary];
}

+ (void)saveStore:(NSDictionary *)store {
    [[NSUserDefaults standardUserDefaults] setObject:store forKey:kHermesActionStoreKey];
}

+ (void)markActedForCardId:(NSString *)cardId
                    action:(NSString *)action
                     label:(NSString *)label {
    if (!cardId.length || !action.length) {
        return;
    }
    NSMutableDictionary *store = [self mutableStore];
    store[cardId] = @{
        @"action": action,
        @"label": label.length ? label : action,
        @"ts": @([[NSDate date] timeIntervalSince1970]),
    };
    // Cap size: drop oldest by ts
    if (store.count > kHermesActionStoreMax) {
        NSArray *sorted = [store keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            double ta = [a[@"ts"] doubleValue];
            double tb = [b[@"ts"] doubleValue];
            if (ta < tb) return NSOrderedAscending;
            if (ta > tb) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        NSInteger drop = (NSInteger)store.count - kHermesActionStoreMax;
        for (NSInteger i = 0; i < drop && i < (NSInteger)sorted.count; i++) {
            [store removeObjectForKey:sorted[i]];
        }
    }
    [self saveStore:store];
}

+ (BOOL)isActed:(NSString *)cardId {
    return [self infoForCardId:cardId] != nil;
}

+ (NSDictionary *)infoForCardId:(NSString *)cardId {
    if (!cardId.length) {
        return nil;
    }
    id info = [self mutableStore][cardId];
    return [info isKindOfClass:[NSDictionary class]] ? info : nil;
}

@end
