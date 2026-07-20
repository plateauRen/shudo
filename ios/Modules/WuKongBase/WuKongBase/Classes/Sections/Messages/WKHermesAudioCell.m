//
//  WKHermesAudioCell.m
//  WuKongBase
//
//  Lightweight card — playback is handled by the conversation top bar.
//

#import "WKHermesAudioCell.h"
#import "WKHermesAudioContent.h"
#import "WuKongBase.h"

NSNotificationName const WKHermesAudioPlayNotification = @"WKHermesAudioPlayNotification";

static const CGFloat kW = 260.0f;
static const CGFloat kPad = 12.0f;

@interface WKHermesAudioCell ()
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UILabel *hintLbl;
@property(nonatomic, strong) UIButton *playBtn;
@end

@implementation WKHermesAudioCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    return CGSizeMake(kW, 72.0f);
}

- (void)initUI {
    [super initUI];
    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 8.0f;

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [UIFont boldSystemFontOfSize:15];
    self.titleLbl.numberOfLines = 2;
    [self.messageContentView addSubview:self.titleLbl];

    self.hintLbl = [[UILabel alloc] init];
    self.hintLbl.font = [UIFont systemFontOfSize:12];
    self.hintLbl.text = LLang(@"点击在顶栏播放");
    [self.messageContentView addSubview:self.hintLbl];

    self.playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.playBtn setTitle:LLang(@"播放") forState:UIControlStateNormal];
    self.playBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [self.playBtn addTarget:self action:@selector(onPlay) forControlEvents:UIControlEventTouchUpInside];
    [self.messageContentView addSubview:self.playBtn];
    self.messageContentView.userInteractionEnabled = YES;
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKHermesAudioContent *c = (WKHermesAudioContent *)model.content;
    self.messageContentView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.hintLbl.textColor = [WKApp shared].config.tipColor;
    self.playBtn.tintColor = [WKApp shared].config.themeColor;
    self.titleLbl.text = c.title.length ? c.title : (c.contentText.length ? c.contentText : LLang(@"Hermes 音频"));
    if (c.durationMs > 0) {
        NSInteger sec = (c.durationMs + 500) / 1000;
        self.hintLbl.text = [NSString stringWithFormat:LLang(@"点击在顶栏播放 · %ld秒"), (long)sec];
    } else {
        self.hintLbl.text = LLang(@"点击在顶栏播放");
    }
    if ([WKApp shared].config.style != WKSystemStyleDark) {
        self.trailingView.timeLbl.textColor = [WKApp shared].config.tipColor;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inner = kW - kPad * 2 - 64;
    self.titleLbl.frame = CGRectMake(kPad, kPad, inner, 36);
    self.hintLbl.frame = CGRectMake(kPad, 44, inner, 18);
    self.playBtn.frame = CGRectMake(kW - 60, 20, 52, 32);
}

- (void)onPlay {
    WKHermesAudioContent *c = (WKHermesAudioContent *)self.messageModel.content;
    if (!c.url.length) {
        [self.contentView showHUDWithHide:LLang(@"无音频地址")];
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:WKHermesAudioPlayNotification
                                                        object:nil
                                                      userInfo:@{
                                                          @"url": c.url ?: @"",
                                                          @"title": c.title.length ? c.title : (c.contentText ?: @"音频"),
                                                          @"duration_ms": @(c.durationMs),
                                                      }];
}

- (void)onTap {
    [self onPlay];
}

@end
