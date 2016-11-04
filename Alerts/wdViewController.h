//
//  wdViewController.h
//  Alerts
//
//  Created by Benjamin Harrell on 11/20/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "wdAlertsManager.h"
#import "wdAppDelegate.h"
#import "MBProgressHUD.h"
#import "wdAlertDetailsViewController.h"


@interface wdViewController : UIViewController<MKMapViewDelegate, wdAlertsManagerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, wdAlertDetailsChangeDelegate>
{
    MBProgressHUD *_HUD;
    
    wdAppDelegate *_appDelegate;
    //setup the init stuff
    bool _initialMapSizeWasSet;
    
}


@property (nonatomic, retain) IBOutlet MKMapView *mapView;
@property (nonatomic, retain) IBOutlet UIToolbar *mapToolbar;
@property (nonatomic, retain) MBProgressHUD* HUD;
@property (nonatomic, assign) wdAppDelegate* appDelegate;


- (IBAction)centerMap:(id)sender;
- (IBAction)refreshAll:(id)sender;
- (void) displayTutorial;

- (MKPolyline *) buildPolyline:(NSArray *)allLocations;
- (void) moveMapToUser;
- (void) sizeMapToDefault;
- (void) plotAlertPositions;
- (void) plotCustomAlertPositions;
- (void) clearAlertPositions;
- (float) getRadiusInMilesFromMapView;
- (void) showStatusMessage:(NSString *)msg;
- (void) showAlert:(NSString *)msg numberOfItems:(NSInteger)count;
- (void) showErrorMessage:(NSString *)msg;

@end
