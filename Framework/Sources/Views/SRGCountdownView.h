//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  A simple view displaying a remaining time (in seconds) as a fancy countdown.
 */
IB_DESIGNABLE
@interface SRGCountdownView : UIView

/**
 *  The remaining time to be displayed (in seconds).
 */
@property (nonatomic) NSTimeInterval remainingTimeInterval;

@end

NS_ASSUME_NONNULL_END
