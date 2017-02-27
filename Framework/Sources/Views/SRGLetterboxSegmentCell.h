//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreMedia/CoreMedia.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRGLetterboxSegmentCell : UICollectionViewCell

@property (nonatomic, nullable) SRGSegment *segment;

- (void)updateAppearanceWithTime:(NSTimeInterval)timeInSeconds selectedSegment:(SRGSegment *)selectedSegment;

@end

NS_ASSUME_NONNULL_END
