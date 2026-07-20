//
//  WKHermesAudioBar.m
//  WuKongBase
//

#import "WKHermesAudioBar.h"
#import "WuKongBase.h"
#import "WKLiquidGlassHelper.h"
#import <AVFoundation/AVFoundation.h>

static const CGFloat kBarContentHeight = 56.0f;
static const CGFloat kBarVMargin = 6.0f;
static const CGFloat kBarHInset = 12.0f;
static const CGFloat kGlassCornerRadius = 18.0f;

@interface WKHermesAudioBar ()
@property(nonatomic, strong) UIView *chromeView;
@property(nonatomic, strong, nullable) UIVisualEffectView *glassView;
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UIButton *playBtn;
@property(nonatomic, strong) UIButton *closeBtn;
@property(nonatomic, strong) UISlider *slider;
@property(nonatomic, strong) UILabel *timeLbl;
@property(nonatomic, strong, nullable) AVPlayer *player;
@property(nonatomic, strong, nullable) id timeObserver;
@property(nonatomic, assign) BOOL scrubbing;
@property(nonatomic, assign) BOOL visibleFlag;
@end

@implementation WKHermesAudioBar

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;

        _chromeView = [[UIView alloc] initWithFrame:CGRectZero];
        _chromeView.backgroundColor = [UIColor clearColor];
        [self addSubview:_chromeView];

        _glassView = [WKLiquidGlassHelper installInView:_chromeView
                                           cornerRadius:kGlassCornerRadius
                                            interactive:YES
                                             solidColor:[WKApp shared].config.cellBackgroundColor];
        // Start dematerialized; materialize on show (iOS 26 animation).
        if (@available(iOS 26.0, *)) {
            _glassView.effect = nil;
        }

        _playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_playBtn setImage:[self sfImage:@"play.fill"] forState:UIControlStateNormal];
        _playBtn.tintColor = [WKApp shared].config.themeColor;
        [_playBtn addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
        [_chromeView addSubview:_playBtn];

        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        if (@available(iOS 13.0, *)) {
            _titleLbl.textColor = [UIColor labelColor];
        } else {
            _titleLbl.textColor = [WKApp shared].config.defaultTextColor;
        }
        _titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [_chromeView addSubview:_titleLbl];

        _slider = [[UISlider alloc] init];
        _slider.minimumTrackTintColor = [WKApp shared].config.themeColor;
        [_slider addTarget:self action:@selector(sliderBegin) forControlEvents:UIControlEventTouchDown];
        [_slider addTarget:self action:@selector(sliderEnd) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [_slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
        [_chromeView addSubview:_slider];

        _timeLbl = [[UILabel alloc] init];
        _timeLbl.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        if (@available(iOS 13.0, *)) {
            _timeLbl.textColor = [UIColor secondaryLabelColor];
        } else {
            _timeLbl.textColor = [WKApp shared].config.tipColor;
        }
        _timeLbl.textAlignment = NSTextAlignmentRight;
        _timeLbl.text = @"0:00";
        [_chromeView addSubview:_timeLbl];

        _closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_closeBtn setImage:[self sfImage:@"xmark"] forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            _closeBtn.tintColor = [UIColor secondaryLabelColor];
        } else {
            _closeBtn.tintColor = [WKApp shared].config.tipColor;
        }
        [_closeBtn addTarget:self action:@selector(stopAndHide) forControlEvents:UIControlEventTouchUpInside];
        [_chromeView addSubview:_closeBtn];

        self.hidden = YES;
        _visibleFlag = NO;
    }
    return self;
}

- (UIImage *)sfImage:(NSString *)name {
    if (@available(iOS 13.0, *)) {
        return [UIImage systemImageNamed:name];
    }
    return nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat chromeW = MAX(0, w - kBarHInset * 2.0f);
    CGFloat chromeH = kBarContentHeight;
    CGFloat chromeY = MAX(0, (h - chromeH) / 2.0f);
    self.chromeView.frame = CGRectMake(kBarHInset, chromeY, chromeW, chromeH);
    self.glassView.frame = self.chromeView.bounds;

    CGFloat cw = chromeW;
    CGFloat ch = chromeH;
    self.playBtn.frame = CGRectMake(10, (ch - 32) / 2, 32, 32);
    self.closeBtn.frame = CGRectMake(cw - 40, (ch - 28) / 2, 28, 28);
    self.timeLbl.frame = CGRectMake(cw - 96, 8, 52, 16);
    self.titleLbl.frame = CGRectMake(48, 6, cw - 48 - 100, 18);
    self.slider.frame = CGRectMake(48, 28, cw - 48 - 48, 22);
}

+ (CGFloat)preferredHeight {
    return kBarContentHeight + kBarVMargin * 2.0f;
}

- (BOOL)isVisible {
    return self.visibleFlag;
}

- (void)playURL:(NSString *)url title:(NSString *)title durationMs:(NSInteger)durationMs {
    if (!url.length) return;
    [self teardownPlayer];

    self.titleLbl.text = title.length ? title : LLang(@"Hermes 音频");
    self.slider.value = 0;
    if (durationMs > 0) {
        self.slider.maximumValue = durationMs / 1000.0f;
        self.timeLbl.text = [self formatTime:0 total:self.slider.maximumValue];
    } else {
        self.slider.maximumValue = 1;
        self.timeLbl.text = @"0:00";
    }

    NSURL *nsurl = [NSURL URLWithString:url];
    if (!nsurl) {
        nsurl = [NSURL fileURLWithPath:url];
    }
    self.player = [AVPlayer playerWithURL:nsurl];
    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                                  queue:dispatch_get_main_queue()
                                                             usingBlock:^(CMTime time) {
        [weakSelf onTick:time];
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];

    [self showBar];
    [self.player play];
    [self.playBtn setImage:[self sfImage:@"pause.fill"] forState:UIControlStateNormal];
}

- (void)showBar {
    if (self.visibleFlag) {
        if (self.onVisibilityChange) self.onVisibilityChange(YES, [WKHermesAudioBar preferredHeight]);
        return;
    }
    self.hidden = NO;
    self.visibleFlag = YES;
    if (self.onVisibilityChange) self.onVisibilityChange(YES, [WKHermesAudioBar preferredHeight]);
    [WKLiquidGlassHelper materializeEffectView:self.glassView interactive:YES animated:YES completion:nil];
}

- (void)stopAndHide {
    [self teardownPlayer];
    __weak typeof(self) weakSelf = self;
    void (^finish)(void) = ^{
        weakSelf.hidden = YES;
        weakSelf.visibleFlag = NO;
        if (weakSelf.onVisibilityChange) weakSelf.onVisibilityChange(NO, 0);
    };
    if ([WKLiquidGlassHelper isLiquidGlassAvailable]) {
        [WKLiquidGlassHelper dematerializeEffectView:self.glassView animated:YES completion:finish];
    } else {
        finish();
    }
}

- (void)teardownPlayer {
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
    }
    self.timeObserver = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [self.player pause];
    self.player = nil;
    [self.playBtn setImage:[self sfImage:@"play.fill"] forState:UIControlStateNormal];
}

- (void)togglePlay {
    if (!self.player) return;
    if (self.player.rate > 0.01) {
        [self.player pause];
        [self.playBtn setImage:[self sfImage:@"play.fill"] forState:UIControlStateNormal];
    } else {
        [self.player play];
        [self.playBtn setImage:[self sfImage:@"pause.fill"] forState:UIControlStateNormal];
    }
}

- (void)sliderBegin {
    self.scrubbing = YES;
}

- (void)sliderEnd {
    self.scrubbing = NO;
    if (!self.player) return;
    CMTime t = CMTimeMakeWithSeconds(self.slider.value, NSEC_PER_SEC);
    [self.player seekToTime:t toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)sliderChanged {
    if (!self.scrubbing) return;
    self.timeLbl.text = [self formatTime:self.slider.value total:self.slider.maximumValue];
}

- (void)onTick:(CMTime)time {
    if (self.scrubbing || !self.player) return;
    Float64 sec = CMTimeGetSeconds(time);
    AVPlayerItem *item = self.player.currentItem;
    Float64 dur = CMTimeGetSeconds(item.duration);
    if (isfinite(dur) && dur > 0) {
        self.slider.maximumValue = (float)dur;
    }
    if (isfinite(sec)) {
        self.slider.value = (float)sec;
        self.timeLbl.text = [self formatTime:sec total:self.slider.maximumValue];
    }
}

- (void)itemDidEnd:(NSNotification *)n {
    [self.player seekToTime:kCMTimeZero];
    [self.player pause];
    [self.playBtn setImage:[self sfImage:@"play.fill"] forState:UIControlStateNormal];
    self.slider.value = 0;
}

- (NSString *)formatTime:(Float64)cur total:(Float64)total {
    int c = (int)MAX(0, cur);
    int t = (int)MAX(0, total);
    return [NSString stringWithFormat:@"%d:%02d / %d:%02d", c / 60, c % 60, t / 60, t % 60];
}

- (void)dealloc {
    [self teardownPlayer];
}

@end
