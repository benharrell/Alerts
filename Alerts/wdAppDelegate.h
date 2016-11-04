//
//  wdAppDelegate.h
//  Alerts
//
//  Created by Benjamin Harrell on 11/20/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "wdAlertsManager.h"

@interface wdAppDelegate : UIResponder <UIApplicationDelegate>
{

 wdAlertsManager * alertsManager;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, retain) wdAlertsManager *alertsManager;

-(bool)checkForAlertsShutdown;

@end
