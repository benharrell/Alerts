//
//  wdAppDelegate.m
//  Alerts
//
//  Created by Benjamin Harrell on 11/20/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdAppDelegate.h"


@implementation wdAppDelegate

@synthesize alertsManager;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    // Override point for customization after application launch.
    
    // Load  defaults
    //[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
    
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithInt:50] , @"detection_distance_yds_preference",                            [NSNumber numberWithInt:20] , @"search_size_miles_preference",
                                 [NSNumber numberWithInt:5] , @"last_map_size_preference",
                                 @"kCLLocationAccuracyNearestTenMeters", @"battery_usage_preference",  
                                 [NSNumber numberWithBool:YES], @"background_mode_preference",
                                 //national
                                 
                                 [NSNumber numberWithBool:YES], @"category_1734",
                                 [NSNumber numberWithBool:YES], @"category_1729,1590,1550,1050",
                                 [NSNumber numberWithBool:YES], @"category_1707,1727,1728,1730,1731,1754,1735,1075,1072,1071,1070,1069,1064,1058",
                                 [NSNumber numberWithBool:YES], @"category_1612,1613,1614,1615,1616,1617",
                                 [NSNumber numberWithBool:YES], @"category_1587,1547,1078,1047,T=3010",
                                 [NSNumber numberWithBool:YES], @"category_1055,1711",
                                 [NSNumber numberWithBool:YES], @"category_1054",
                                 [NSNumber numberWithBool:YES], @"category_1073,1725",
                                 [NSNumber numberWithBool:YES], @"category_1589,1549,1049",
                                 [NSNumber numberWithBool:YES], @"category_1756",
                                 [NSNumber numberWithBool:YES], @"category_1753,1061,T=3043",
                                 [NSNumber numberWithBool:YES], @"category_1726",
                                 [NSNumber numberWithBool:YES], @"category_1706,1062",
                                 [NSNumber numberWithBool:YES], @"category_1703",
                                 [NSNumber numberWithBool:YES], @"category_1700,1063",
                                 [NSNumber numberWithBool:YES], @"category_1606,1607,1608,1609,1610,1611",
                                 [NSNumber numberWithBool:YES], @"category_1708",
                                 [NSNumber numberWithBool:YES], @"category_1060",
                                 [NSNumber numberWithBool:YES], @"category_1059,T=3003",
                                 [NSNumber numberWithBool:YES], @"category_1057,T=3040",
                                 [NSNumber numberWithBool:YES], @"category_1053",
                                 
                                 [NSNumber numberWithBool:YES], @"category_1761,T=3046",
                                 
                                 [NSNumber numberWithBool:YES], @"category_1765,T=3030",
                                 [NSNumber numberWithBool:YES], @"category_1774",
                                 [NSNumber numberWithBool:YES], @"category_1712,1713,1714",
                                 [NSNumber numberWithBool:YES], @"category_1758,T=3038",
                                 [NSNumber numberWithBool:YES], @"category_1757,T=3036",
                                 [NSNumber numberWithBool:YES], @"category_1718",
                                 [NSNumber numberWithBool:YES], @"category_1548,1588,1048",
                                 [NSNumber numberWithBool:YES], @"category_1704",
                                 [NSNumber numberWithBool:YES], @"category_1732",
                                 [NSNumber numberWithBool:YES], @"category_1733,T=3051",
                                 [NSNumber numberWithBool:YES], @"category_1750,1751,1755,1759,T=3004,T=3005,T=3007",
                                 [NSNumber numberWithBool:YES], @"category_1752,T=3044,T=3045",
                                 [NSNumber numberWithBool:YES], @"category_T=3047",
                                 [NSNumber numberWithBool:YES], @"category_1763,T=3049",
                                 [NSNumber numberWithBool:YES], @"category_1764",    //,T=3050
                                 [NSNumber numberWithBool:YES], @"category_1770,T=3039", //lose the 3042?
                                 [NSNumber numberWithBool:YES], @"category_1775",
                                 [NSNumber numberWithBool:YES], @"category_1709",

                                 nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
  
    
    if (self.alertsManager == nil)
    {
        self.alertsManager = [[wdAlertsManager alloc] init];
        
        
    }
        
    
    //always call this incase of changed user settings
    [self.alertsManager startBackgroundMode];
    
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(defaultsChanged:)
                   name:NSUserDefaultsDidChangeNotification
                 object:nil];
    
    
    self.window.rootViewController.modalPresentationStyle = UIModalPresentationCurrentContext;
    
    
    return YES;
}





- (void)defaultsChanged:(NSNotification *)notification {
    
    // Do something with it
    //NSLog(@"user pref change detected");
    
    //if we are running in the background then check for shutdown flag
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground )
    {
    
        [self checkForAlertsShutdown];
    }
}



void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif == nil)
        return;
    localNotif.fireDate = nil;	// Notification details
    
    NSString * msg = [NSString stringWithFormat:@"Carry Alerts received an error, please restart and contact support if the problem continues.  Details: %@", exception.reason];
    
    localNotif.alertBody =  msg;
	localNotif.alertAction = @"View";
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
    // Internal error reporting
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    
    //UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    //if (localNotif == nil)
     //   return;
    //localNotif.fireDate = nil;	// Notification details
    //localNotif.alertBody = @"Carry Alerts received WillResignActive event...something interrupted app, save state.";
	//localNotif.alertAction = @"View";
    //[[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return YES;
}
- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    return YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    


    if (application.applicationState == UIApplicationStateInactive ) {
        //The application received the notification from an inactive state, i.e. the user tapped the "View" button for the alert.
        //If the visible view controller in your view controller stack isn't the one you need then show the right one.
        
    }
    
    if(application.applicationState == UIApplicationStateActive ) {
        //The application received a notification in the active state, so you can display an alert view or do something appropriate.
        [UIApplication sharedApplication].applicationIconBadgeNumber=0;
    }
    
    
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    
    
    
    
    
    //force a save
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    bool runInBack = [self checkForAlertsShutdown ];
    if (runInBack)
    {
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        if (localNotif == nil)
            return;
        localNotif.fireDate = nil;	// Notification details
        localNotif.alertBody = @"Carry Alerts is now running in the background, you will continue to receive alerts.";
        localNotif.alertAction = @"View";
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
    }
    
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
        
}

-(bool)checkForAlertsShutdown
{
    
    
    //check the disable button disable_background_mode_preference
    //if YES then turn everything off
    NSObject * val = [[NSUserDefaults standardUserDefaults] objectForKey:@"background_mode_preference"];
    bool runInBack = [[NSUserDefaults standardUserDefaults] boolForKey:@"background_mode_preference"];
    if (val != nil &&
        runInBack ==false)
    {
        NSLog(@"user turned off background mode, stopping loc mgr updates");
        [self.alertsManager endBackgroundMode];
    }
    return runInBack;
     
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    
    //This is called when it is running in backgroun and moves to foreground only
    
    //UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    //if (localNotif == nil)
        return;
    //localNotif.fireDate = nil;	// Notification details
    //localNotif.alertBody = @"Carry Alerts received WillEnterForeground event...something caused to launch.";
	//localNotif.alertAction = @"View";
    //[[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
    
    
    
    
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    //this might be a good time to do any handoff of alerts?
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif == nil)
        return;
    localNotif.fireDate = nil;	// Notification details
    localNotif.alertBody = @"Carry Alerts is being shutdown by your device, please relaunch to continue receiving alerts.";
	localNotif.alertAction = @"View";
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    //force an update in case settings changed
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //this is called when first launched AND when moving to foreground from background
    //so this is when we need to synchronize AND set the loc mgr preferences before doing anything
    
    if (self.alertsManager == nil)
    {
        self.alertsManager = [[wdAlertsManager alloc] init];
        
        
    }
    //always call this incase of changed user settings
    [self.alertsManager startBackgroundMode];
     
    
    //this is our chance to remind the user that they had an alert in the background and might want to do something
    if ([UIApplication sharedApplication].applicationIconBadgeNumber > 0)
    {
        
        [self.alertsManager fireStatusMessage:@"One or more alerts were received while running in the background.  To see these alerts use the Notifications Pull Down screen." ];
        
        //wipe all notifcations on open...
        [UIApplication sharedApplication].applicationIconBadgeNumber=0;
    }
    
    
}


-(void)dealloc
{
    self.alertsManager = nil;
}

@end
