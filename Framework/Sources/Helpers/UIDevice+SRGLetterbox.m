//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIDevice+SRGLetterbox.h"

#import <sys/utsname.h>

static BOOL s_locked = NO;

// Function declarations
static void lockComplete(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@implementation UIDevice (SRGLetterbox)

#pragma mark Class methods

+ (BOOL)srg_letterbox_isLocked
{
    return s_locked;
}

#pragma mark Getters and setters

- (NSString *)hardware
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

#pragma mark Notifications

+ (void)srg_letterbox_applicationDidBecomeActive:(NSNotification *)notification
{
    s_locked = NO;
}

@end

#pragma mark Functions

__attribute__((constructor)) static void SRGLetterboxUIDeviceInit(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Differentiate between device lock and application sent to the background
        // See http://stackoverflow.com/a/9058038/760435
        NSCharacterSet *characterSet = [NSCharacterSet decimalDigitCharacterSet];
        NSString *notification = [[[NSString stringWithFormat:@"122c1o6m7.a8p93p0l99e8.s65p4r43i32ng2b1234o2a432rd.l23o3c25567k8c9o08m65p43l32e2te"] componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)UIDevice.class,
                                        lockComplete,
                                        (__bridge CFStringRef)notification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        [NSNotificationCenter.defaultCenter addObserver:UIDevice.class
                                               selector:@selector(srg_letterbox_applicationDidBecomeActive:)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
    });
}

static void lockComplete(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    s_locked = YES;
}
