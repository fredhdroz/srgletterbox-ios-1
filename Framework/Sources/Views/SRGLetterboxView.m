//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGLetterboxView.h"

#import "NSBundle+SRGLetterbox.h"
#import "SRGLetterboxError.h"
#import "SRGLetterboxService.h"
#import "UIFont+SRGLetterbox.h"
#import "UIImageView+SRGLetterbox.h"

#import <Masonry/Masonry.h>
#import <libextobjc/libextobjc.h>
#import <FXReachability/FXReachability.h>
#import <ASValueTrackingSlider/ASValueTrackingSlider.h>

static void commonInit(SRGLetterboxView *self);

@interface SRGLetterboxView () <ASValueTrackingSliderDataSource>

// UI
@property (nonatomic, weak) IBOutlet UIView *playerView;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UIView *controlsView;
@property (nonatomic, weak) IBOutlet SRGPlaybackButton *playbackButton;
@property (nonatomic, weak) IBOutlet ASValueTrackingSlider *timeSlider;
@property (nonatomic, weak) IBOutlet UIButton *forwardSeekButton;
@property (nonatomic, weak) IBOutlet UIButton *backwardSeekButton;

@property (nonatomic, weak) UIImageView *loadingImageView;

@property (nonatomic, weak) IBOutlet UIView *errorView;
@property (nonatomic, weak) IBOutlet UILabel *errorLabel;

@property (nonatomic, weak) IBOutlet SRGPictureInPictureButton *pictureInPictureButton;

@property (nonatomic, weak) IBOutlet SRGAirplayView *airplayView;
@property (nonatomic, weak) IBOutlet UILabel *airplayLabel;
@property (nonatomic, weak) IBOutlet SRGAirplayButton *airplayButton;
@property (nonatomic, weak) IBOutlet SRGTracksButton *tracksButton;
@property (nonatomic, weak) IBOutlet UIButton *fullScreenButton;

// Internal
@property (nonatomic) NSTimer *inactivityTimer;
@property (nonatomic, weak) id periodicTimeObserver;

@property (nonatomic, getter=isUserInterfaceHidden) BOOL userInterfaceHidden;
@property (nonatomic, getter=isUserInterfaceTogglable) BOOL userInterfaceTogglable;
@property (nonatomic, getter=isFullScreen) BOOL fullScreen;
@property (nonatomic, getter=isShowingPopup) BOOL showingPopup;

@property (nonatomic, copy) void (^animations)(BOOL hidden);
@property (nonatomic, copy) void (^completion)(BOOL finished);

@end

@implementation SRGLetterboxView {
@private
    BOOL _inWillAnimateUserInterface;
}

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        commonInit(self);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        commonInit(self);
    }
    return self;
}

#pragma mark View lifecycle

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    SRGLetterboxController *letterboxController = [SRGLetterboxService sharedService].controller;
    [self.playerView insertSubview:letterboxController.view aboveSubview:self.imageView];
    [letterboxController.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.playerView);
    }];
    
    self.playbackButton.mediaPlayerController = letterboxController;
    
    // FIXME: Currently added in code, but we should provide a more customizable activity indicator
    //        in the SRG Media Player library soon. Replace when available
    UIImageView *loadingImageView = [UIImageView srg_loadingImageView35WithTintColor:[UIColor whiteColor]];
    loadingImageView.alpha = 0.f;
    [self.playerView insertSubview:loadingImageView aboveSubview:self.playbackButton];
    [loadingImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.playbackButton.mas_top).with.offset(-20.f);
        make.centerX.equalTo(self.playbackButton.mas_centerX);
    }];
    self.loadingImageView = loadingImageView;
    
    self.backwardSeekButton.hidden = YES;
    self.forwardSeekButton.hidden = YES;
    
    self.pictureInPictureButton.mediaPlayerController = letterboxController;
    
    self.airplayView.mediaPlayerController = letterboxController;
    self.airplayView.delegate = self;
    
    self.airplayButton.mediaPlayerController = letterboxController;
    self.tracksButton.mediaPlayerController = letterboxController;
    
    self.timeSlider.mediaPlayerController = letterboxController;
    self.timeSlider.resumingAfterSeek = YES;
    
    self.timeSlider.font = [UIFont srg_regularFontWithSize:14.f];
    self.timeSlider.popUpViewColor = UIColor.whiteColor;
    self.timeSlider.textColor = UIColor.blackColor;
    self.timeSlider.popUpViewWidthPaddingFactor = 1.5f;
    self.timeSlider.popUpViewHeightPaddingFactor = 1.f;
    self.timeSlider.popUpViewCornerRadius = 3.f;
    self.timeSlider.popUpViewArrowLength = 4.f;
    self.timeSlider.dataSource = self;
    
    self.airplayLabel.font = [UIFont srg_regularFontWithTextStyle:UIFontTextStyleFootnote];
    self.errorLabel.font = [UIFont srg_regularFontWithTextStyle:UIFontTextStyleSubheadline];
    
    // Detect all touches on the player view. Other gesture recognizers can be added directly in the storyboard
    // to detect other interactions earlier
    SRGActivityGestureRecognizer *activityGestureRecognizer = [[SRGActivityGestureRecognizer alloc] initWithTarget:self
                                                                                                            action:@selector(resetInactivityTimer:)];
    activityGestureRecognizer.delegate = self;
    [self.playerView addGestureRecognizer:activityGestureRecognizer];
    
    self.fullScreenButton.hidden = [self isFullScreenButtonHidden];
    
    [self reloadData];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    SRGLetterboxController *letterboxController = [SRGLetterboxService sharedService].controller;
    
    if (newWindow) {
        @weakify(self)
        @weakify(letterboxController)
        self.periodicTimeObserver = [letterboxController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
            @strongify(self)
            @strongify(letterboxController)
            
            self.forwardSeekButton.hidden = ![letterboxController canSeekForward];
            self.backwardSeekButton.hidden = ![letterboxController canSeekBackward];
        }];
        
        [self updateInterfaceAnimated:NO];
        [self reloadData];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mediaMetadataDidChange:)
                                                     name:SRGLetterboxServiceMetadataDidChangeNotification
                                                   object:[SRGLetterboxService sharedService]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mediaPlaybackDidFail:)
                                                     name:SRGLetterboxServicePlaybackDidFailNotification
                                                   object:[SRGLetterboxService sharedService]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackStateDidChange:)
                                                     name:SRGMediaPlayerPlaybackStateDidChangeNotification
                                                   object:letterboxController];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(wirelessRouteDidChange:)
                                                     name:SRGMediaPlayerWirelessRouteDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenDidConnect:)
                                                     name:UIScreenDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenDidDisconnect:)
                                                     name:UIScreenDidDisconnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityDidChange:)
                                                     name:FXReachabilityStatusDidChangeNotification
                                                   object:nil];
        
        AVPictureInPictureController *pictureInPictureController = letterboxController.pictureInPictureController;
        if (pictureInPictureController.isPictureInPictureActive) {
            [pictureInPictureController stopPictureInPicture];
        }
    }
    else {
        self.inactivityTimer = nil;                 // Invalidate timer
        [letterboxController removePeriodicTimeObserver:self.periodicTimeObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

#pragma mark Getters and setters

- (void)setDelegate:(id<SRGLetterboxViewDelegate>)delegate
{
    _delegate = delegate;
    self.fullScreenButton.hidden = [self isFullScreenButtonHidden];
}

- (void)setFullScreen:(BOOL)fullScreen
{
    [self setFullScreen:fullScreen animated:NO];
}

- (void)setFullScreen:(BOOL)fullScreen animated:(BOOL)animated
{
    if (_fullScreen == fullScreen) {
        return;
    }
    
    _fullScreen = fullScreen;
    self.fullScreenButton.selected = fullScreen;
    
    if ([self.delegate respondsToSelector:@selector(letterboxView:didToggleFullScreen:animated:)]) {
        [self.delegate letterboxView:self didToggleFullScreen:fullScreen animated:animated];
    }
}

- (void)setInactivityTimer:(NSTimer *)inactivityTimer
{
    [_inactivityTimer invalidate];
    _inactivityTimer = inactivityTimer;
}

#pragma mark UI

- (void)setUserInterfaceHidden:(BOOL)hidden animated:(BOOL)animated togglable:(BOOL)togglable
{
    // Allow to change hide or display
    self.userInterfaceTogglable = YES;
    
    [self setUserInterfaceHidden:hidden animated:animated];
    if (togglable) {
        [self resetInactivityTimer];
    }
    
    // Apply the setting
    self.userInterfaceTogglable = togglable;
}

- (void)setUserInterfaceHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (! self.userInterfaceTogglable) {
        return;
    }
    
    if (self.userInterfaceHidden == hidden) {
        return;
    }
    
    // Cannot toggle UI when an error is displayed
    if (! self.errorView.hidden) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(letterboxViewWillAnimateUserInterface:)]) {
        _inWillAnimateUserInterface = YES;
        [self.delegate letterboxViewWillAnimateUserInterface:self];
        _inWillAnimateUserInterface = NO;
    }
    
    void (^animations)(void) = ^{
        CGFloat alpha = hidden ? 0.f : 1.f;
        self.controlsView.alpha = alpha;
        self.animations ? self.animations(hidden) : nil;
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished) {
            self.userInterfaceHidden = hidden;
        }
        self.completion ? self.completion(finished) : nil;
        
        self.animations = nil;
        self.completion = nil;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:animations completion:completion];
    }
    else {
        animations();
        completion(YES);
    }
}

- (void)updateInterfaceAnimated:(BOOL)animated
{
    void (^animations)(void) = ^{
        SRGLetterboxController *letterboxController = [SRGLetterboxService sharedService].controller;
        
        if (letterboxController.playbackState == SRGMediaPlayerPlaybackStatePlaying) {
            // Hide if playing a video in Airplay or if true screen mirroring is used
            SRGMedia *media = [SRGLetterboxService sharedService].media;
            BOOL hidden = (media.mediaType == SRGMediaTypeVideo) && (! [AVAudioSession srg_isAirplayActive] || ([UIScreen srg_isMirroring] && ! letterboxController.player.usesExternalPlaybackWhileExternalScreenIsActive));
            self.imageView.alpha = hidden ? 0.f : 1.f;
            letterboxController.view.alpha = hidden ? 1.f : 0.f;
            
            [self resetInactivityTimer];
            
            if (!self.showingPopup) {
                self.showingPopup = YES;
                [self.timeSlider showPopUpViewAnimated:YES];
            }
        }
        else if (letterboxController.playbackState == SRGMediaPlayerPlaybackStateEnded) {
            self.imageView.alpha = 1.f;
            letterboxController.view.alpha = 0.f;
            
            [self.timeSlider hidePopUpViewAnimated:YES];
            self.showingPopup = NO;
            
            [self setUserInterfaceHidden:NO animated:YES];
        }
        
        self.loadingImageView.alpha = (letterboxController.playbackState == SRGMediaPlayerPlaybackStatePlaying
                                       || letterboxController.playbackState == SRGMediaPlayerPlaybackStatePaused
                                       || letterboxController.playbackState == SRGMediaPlayerPlaybackStateEnded
                                       || letterboxController.playbackState == SRGMediaPlayerPlaybackStateIdle) ? 0.f : 1.f;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:animations];
    }
    else {
        animations();
    }
}

- (void)resetInactivityTimer
{
    self.inactivityTimer = [NSTimer scheduledTimerWithTimeInterval:4. target:self selector:@selector(hideInterface:) userInfo:nil repeats:NO];
}

- (void)animateAlongsideUserInterfaceWithAnimations:(void (^)(BOOL))animations completion:(void (^)(BOOL finished))completion
{
    if (! _inWillAnimateUserInterface) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"-animateAlongsideUserInterfaceWithAnimations:completion: can omnly be called from within the -animateAlongsideUserInterfaceWithAnimations: method of the Letterbox view delegate"
                                     userInfo:nil];
    }
    
    self.animations = animations;
    self.completion = completion;
}

- (BOOL)isFullScreenButtonHidden
{
    return ! self.delegate || ! [self.delegate respondsToSelector:@selector(letterboxView:didToggleFullScreen:animated:)];
}

#pragma mark Gesture recognizers

- (void)resetInactivityTimer:(UIGestureRecognizer *)gestureRecognizer
{
    [self resetInactivityTimer];
    [self setUserInterfaceHidden:NO animated:YES];
}

- (IBAction)hideUserInterfaceVisibility:(UIGestureRecognizer *)gestureRecognizer
{
    [self setUserInterfaceHidden:YES animated:YES];
}

#pragma mark Timers

- (void)hideInterface:(NSTimer *)timer
{
    // Only auto-hide the UI when it makes sense (e.g. not when the player is paused or loading). When the state
    // of the player returns to playing, the inactivity timer will be reset (see -playbackStateDidChange:)
    SRGLetterboxController *letterboxController = [SRGLetterboxService sharedService].controller;
    if (letterboxController.playbackState == SRGMediaPlayerPlaybackStatePlaying
            || letterboxController.playbackState == SRGMediaPlayerPlaybackStateSeeking
            || letterboxController.playbackState == SRGMediaPlayerPlaybackStateStalled) {
        [self setUserInterfaceHidden:YES animated:YES];
    }
}

#pragma mark Actions

- (IBAction)seekBackward:(id)sender
{
    [[SRGLetterboxService sharedService].controller seekBackwardWithCompletionHandler:nil];
}

- (IBAction)seekForward:(id)sender
{
    [[SRGLetterboxService sharedService].controller seekForwardWithCompletionHandler:nil];
}

- (IBAction)toggleFullScreen:(id)sender
{
    [self setFullScreen:!self.isFullScreen animated:YES];
}

#pragma mark Data display

- (void)reloadData
{
    SRGMedia *media = [SRGLetterboxService sharedService].media;
    NSError *error = [SRGLetterboxService sharedService].error;
    
    if (error) {
        self.errorView.hidden = NO;
        self.errorLabel.text = error.localizedDescription;
    }
    else if (media) {
        self.errorView.hidden = YES;
        [self.imageView srg_requestImageForObject:media withScale:SRGImageScaleLarge placeholderImageName:@"placeholder_media-180"];
    }
    else if ([SRGLetterboxService sharedService].URN) {
        self.errorView.hidden = YES;
    }
    else {
        NSError *error = [NSError errorWithDomain:SRGLetterboxErrorDomain
                                             code:SRGLetterboxErrorCodeNotFound
                                         userInfo:@{ NSLocalizedDescriptionKey : SRGLetterboxLocalizedString(@"No media", @"Text displayed when no media is available for playback") }];
        self.errorView.hidden = NO;
        self.errorLabel.text = error.localizedDescription;
    }
}

#pragma mark ASValueTrackingSliderDataSource protocol

- (NSString *)slider:(ASValueTrackingSlider *)slider stringForValue:(float)value;
{
    SRGMedia *media = [SRGLetterboxService sharedService].media;
    if (media.contentType == SRGContentTypeLivestream) {
        return (self.timeSlider.isLive) ? NSLocalizedString(@"Live", nil) : self.timeSlider.valueString;
    }
    else {
        return self.timeSlider.valueString ?: @"--:--";
    }
}

#pragma mark SRGAirplayViewDelegate protocol

- (void)airplayView:(SRGAirplayView *)airplayView didShowWithAirplayRouteName:(NSString *)routeName
{
    self.airplayLabel.text = SRGAirplayRouteDescription();
}

#pragma mark UIGestureRecognizerDelegate protocol

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark Notifications

- (void)mediaMetadataDidChange:(NSNotification *)notification
{
    [self reloadData];
    
    if (! self.errorView.hidden) {
        self.errorView.hidden = YES;
        [self resetInactivityTimer];
    }
}

- (void)mediaPlaybackDidFail:(NSNotification *)notification
{
    [self reloadData];
}

- (void)playbackStateDidChange:(NSNotification *)notification
{
    [self updateInterfaceAnimated:YES];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self setUserInterfaceHidden:NO animated:YES];
    [self updateInterfaceAnimated:YES];
}

- (void)wirelessRouteDidChange:(NSNotification *)notification
{
    [self updateInterfaceAnimated:YES];
}

- (void)screenDidConnect:(NSNotification *)notification
{
    [self updateInterfaceAnimated:YES];
}

- (void)screenDidDisconnect:(NSNotification *)notification
{
    [self updateInterfaceAnimated:YES];
}

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self reloadData];
    }
}

@end

static void commonInit(SRGLetterboxView *self)
{
    UIView *view = [[[NSBundle srg_letterboxBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil] firstObject];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    self.userInterfaceHidden = NO;
    self.userInterfaceTogglable = YES;
}
