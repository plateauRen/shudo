//
//  WKMainTabController.m
//  TangSengDaoDao
//
//  Created by tt on 2019/12/7.
//  Copyright © 2019 xinbida. All rights reserved.
//

#import "WKMainTabController.h"
#import <WuKongBase/WuKongBase.h>
#import <Lottie/Lottie.h>
#import "WKConversationListVC.h"
#import "WKContactsVC.h"
#import "WKMeVC.h"

@interface WKMainTabController ()<UITabBarControllerDelegate>
@property(nonatomic,strong) LOTAnimationView *currentLOTAnimationView;
@end

@implementation WKMainTabController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(brandThemeDidChange)
                                                 name:WKNOTIFY_BRAND_THEME_CHANGE
                                               object:nil];

    if (@available(iOS 26.0, *)) {
        // Let the system Liquid Glass tab bar show; opaque fills fight the material.
        self.tabBar.backgroundColor = nil;
        self.tabBar.barTintColor = nil;
        self.tabBar.translucent = YES;
        self.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorOnScrollDown;
        self.tabBar.standardAppearance = [[UITabBarAppearance alloc] init];
        [self.tabBar.standardAppearance configureWithDefaultBackground];
        self.tabBar.scrollEdgeAppearance = self.tabBar.standardAppearance;
    } else if (@available(iOS 13.0, *)) {
        [self.tabBar setBarTintColor:[UIColor systemBackgroundColor]];
        [self.tabBar setBackgroundColor:[UIColor systemBackgroundColor]];
        [[UITabBar appearance] setShadowImage:[[UIImage alloc] init]];
        [[UITabBar appearance] setBackgroundImage:[[UIImage alloc] init]];
    } else {
        [self.tabBar setBarTintColor:[UIColor whiteColor]];
        [self.tabBar setBackgroundColor:[UIColor whiteColor]];
        [[UITabBar appearance] setShadowImage:[[UIImage alloc] init]];
        [[UITabBar appearance] setBackgroundImage:[[UIImage alloc] init]];
    }

    // Feishu blue selected / gray unselected — no baked-in orange assets.
    self.tabBar.tintColor = [WKApp shared].config.themeColor;
    if (@available(iOS 10.0, *)) {
        self.tabBar.unselectedItemTintColor = [WKApp shared].config.tipColor;
    }

    [self setupChildVC:WKConversationListVC.class
                 title:@""
                symbol:@"message"
        selectedSymbol:@"message.fill"
           fallbackImg:@"HomeTab"
   fallbackSelectedImg:@"HomeTabSelected"];
    [self setupChildVC:WKContactsVC.class
                 title:@""
                symbol:@"person.2"
        selectedSymbol:@"person.2.fill"
           fallbackImg:@"ContactsTab"
   fallbackSelectedImg:@"ContactsTabSelected"];
    [self setupChildVC:WKMeVC.class
                 title:@""
                symbol:@"person.circle"
        selectedSymbol:@"person.circle.fill"
           fallbackImg:@"MeTab"
   fallbackSelectedImg:@"MeTabSelected"];
}

- (UIImage *)templateSymbol:(NSString *)name fallbackAsset:(NSString *)asset {
    if (@available(iOS 13.0, *)) {
        UIImage *sys = [UIImage systemImageNamed:name];
        if (sys) {
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:22
                                                                weight:UIImageSymbolWeightMedium];
            UIImage *img = [sys imageByApplyingSymbolConfiguration:cfg];
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    UIImage *fallback = [UIImage imageNamed:asset];
    return [fallback imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)setupChildVC:(Class)vc
               title:(NSString *)title
              symbol:(NSString *)symbol
      selectedSymbol:(NSString *)selectedSymbol
         fallbackImg:(NSString *)fallbackImg
 fallbackSelectedImg:(NSString *)fallbackSelectedImg {
    UIViewController *vcInstall = [[vc alloc] init];
    vcInstall.tabBarItem.title = title;
    vcInstall.tabBarItem.image = [self templateSymbol:symbol fallbackAsset:fallbackImg];
    vcInstall.tabBarItem.selectedImage = [self templateSymbol:selectedSymbol fallbackAsset:fallbackSelectedImg];
    vcInstall.tabBarItem.imageInsets = UIEdgeInsetsMake(6, 0, -6, 0);
    [self addChildViewController:vcInstall];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (![WKApp shared].config.darkModeWithSystem) return;
        if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            return;
        }
        WKSystemStyle next = (UIScreen.mainScreen.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? WKSystemStyleDark
            : WKSystemStyleLight;
        if ([WKApp shared].config.style != next) {
            [WKApp shared].config.style = next;
        }
        self.tabBar.tintColor = [WKApp shared].config.themeColor;
        self.tabBar.unselectedItemTintColor = [WKApp shared].config.tipColor;
    }
}

- (void)brandThemeDidChange {
    self.tabBar.tintColor = [WKApp shared].config.themeColor;
    if (@available(iOS 10.0, *)) {
        self.tabBar.unselectedItemTintColor = [WKApp shared].config.tipColor;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_BRAND_THEME_CHANGE object:nil];
    WKLogDebug(@"WKMainTabController dealloc");
}

#pragma mark - UITabBarControllerDelegate

static UIImpactFeedbackGenerator *impactFeedBack;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    if (!impactFeedBack) {
        impactFeedBack = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    [impactFeedBack prepare];
    [impactFeedBack impactOccurred];
}

@end
