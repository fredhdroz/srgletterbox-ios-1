//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AutoplayTableViewCell.h"

#import "SettingsViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGLetterbox/SRGLetterbox.h>

@interface AutoplayTableViewCell ()

@property (nonatomic) SRGLetterboxController *letterboxController;
@property (nonatomic, weak) id periodicTimeObserver;

@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;
@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@end

@implementation AutoplayTableViewCell

#pragma mark Getters and setters

- (void)setMedia:(SRGMedia *)media withPreferredSubtitleLocalization:(NSString *)preferredSubtitleLocalization
{
    if (media) {
        SRGLetterboxPlaybackSettings *settings = [[SRGLetterboxPlaybackSettings alloc] init];
        settings.standalone = ApplicationSettingIsStandalone();
        
        self.letterboxController.mediaConfigurationBlock = ^(AVPlayerItem * _Nonnull playerItem, AVAsset * _Nonnull asset) {
            AVMediaSelectionGroup *group = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(AVMediaSelectionOption * _Nullable option, NSDictionary<NSString *,id> * _Nullable bindings) {
                return [[option.locale objectForKey:NSLocaleLanguageCode] isEqualToString:preferredSubtitleLocalization];
            }];
            NSArray<AVMediaSelectionOption *> *options = [AVMediaSelectionGroup mediaSelectionOptionsFromArray:group.options withoutMediaCharacteristics:@[AVMediaCharacteristicContainsOnlyForcedSubtitles]];
            AVMediaSelectionOption *option = [options filteredArrayUsingPredicate:predicate].firstObject;
            if (option) {
                [playerItem selectMediaOption:option inMediaSelectionGroup:group];
            }
        };
        
        [self.letterboxController playMedia:media atPosition:nil withPreferredSettings:settings];
    }
    else {
        [self.letterboxController reset];
    }
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.letterboxController = [[SRGLetterboxController alloc] init];
    self.letterboxController.serviceURL = ApplicationSettingServiceURL();
    self.letterboxController.updateInterval = ApplicationSettingUpdateInterval();
    self.letterboxController.globalParameters = ApplicationSettingGlobalParameters();
    self.letterboxController.muted = YES;
    self.letterboxController.resumesAfterRouteBecomesUnavailable = YES;
    self.letterboxView.controller = self.letterboxController;
    
    [self.letterboxView setUserInterfaceHidden:YES animated:NO togglable:NO];
    [self.letterboxView setTimelineAlwaysHidden:YES animated:NO];
    
    [self updateProgressWithTime:kCMTimeZero];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.progressView.hidden = YES;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        @weakify(self)
        self.periodicTimeObserver = [self.letterboxController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
            @strongify(self)
            [self updateProgressWithTime:time];
        }];
    }
    else {
        [self.letterboxController removePeriodicTimeObserver:self.periodicTimeObserver];
    }
}

#pragma UI

- (void)updateProgressWithTime:(CMTime)time
{
    CMTimeRange timeRange = self.letterboxController.timeRange;
    if (SRG_CMTIMERANGE_IS_NOT_EMPTY(timeRange)) {
        self.progressView.progress = CMTimeGetSeconds(CMTimeSubtract(time, timeRange.start)) / CMTimeGetSeconds(timeRange.duration);
        self.progressView.hidden = NO;
    }
    else {
        self.progressView.hidden = YES;
    }
}

@end
