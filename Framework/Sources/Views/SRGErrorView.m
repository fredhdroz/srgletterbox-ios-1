//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGErrorView.h"

#import "NSBundle+SRGLetterbox.h"
#import "SRGLetterboxView+Private.h"
#import "UIImage+SRGLetterbox.h"

#import <SRGAppearance/SRGAppearance.h>

@interface SRGErrorView ()

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;
@property (nonatomic, weak) IBOutlet UILabel *instructionsLabel;

@end

@implementation SRGErrorView

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.messageLabel.numberOfLines = 3;
    self.instructionsLabel.accessibilityTraits = UIAccessibilityTraitButton;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self reloadData];
}

- (void)contentSizeCategoryDidChange
{
    [super contentSizeCategoryDidChange];
    
    self.messageLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.instructionsLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
}

- (void)reloadData
{
    [super reloadData];
    
    NSError *error =  SRGLetterboxViewErrorForController(self.controller);
    UIImage *image = [UIImage srg_letterboxImageForError:error];
    self.imageView.image = image;
    self.messageLabel.text = error.localizedDescription;
    self.instructionsLabel.text = self.controller.URN ? SRGLetterboxLocalizedString(@"Tap to retry", @"Message displayed when an error has occurred and the ability to retry") : nil;
    
    self.messageLabel.hidden = NO;
    self.instructionsLabel.hidden = (image == nil);     // Hide if empty so that the stack view wrapper can adjust its layout properly
    
    CGFloat height = CGRectGetHeight(self.frame);
    if (height < 170.f) {
        self.instructionsLabel.hidden = YES;
    }
    if (height < 140.f) {
        self.messageLabel.hidden = YES;
    }
}

#pragma mark Actions

- (IBAction)retry:(id)sender
{
    [self.controller restart];
}

@end
