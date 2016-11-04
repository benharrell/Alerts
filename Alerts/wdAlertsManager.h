//
//  wdLocationManager.h
//  Alerts
//
//  Created by Benjamin Harrell on 12/12/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "wdAlertsEventParameters.h"
#import "wdAlertLocation.h"

@protocol wdAlertsManagerDelegate<NSObject>
@optional
-(void)didUpdateLocation;
-(void) didUpdateAlertItems:(NSString*)msg;
-(void) didUpdateCustomAlertItems:(NSString*)msg;
-(void) didResetAlertItems;
-(void) didAlert:(wdAlertsEventParameters*)params;
-(void) didStatusMessage:(NSString*)msg;
-(void) didErrorMessage:(NSString*)msg;
-(void) didStartProcessingAlerts:(NSString*)msg;
-(void) didEndProcessingAlerts;
-(void) didUpdateProcessingAlerts:(NSString*)msg;

@end

@interface wdAlertsManager : NSObject<CLLocationManagerDelegate>
{
    CLLocationManager * _locationManager;
    CLLocation		* _locationForLastManualMove ;
    NSMutableArray * _currentAlertItemRows;
    NSMutableArray * _currentCustomAlertItemRows;
    NSMutableArray * _currentIgnoreAlertItemRows;
    NSArray * _currentAPIKeys;
    NSString * _currentStateForLocation;
    NSString * _currentCountryForLocation;
    bool _isUserFollowMode;
    NSInteger _activeRequests;
    NSDate * _lastStateAndCountryCheckTime;
}

@property (nonatomic, retain) NSMutableArray * currentAlertItemRows;
@property (nonatomic, retain) NSMutableArray * currentCustomAlertItemRows;
@property (nonatomic, retain) NSMutableArray * currentIgnoreAlertItemRows;
@property (nonatomic, retain) NSArray * currentAPIKeys;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) CLLocation * locationForLastManualMove ;
@property (nonatomic, retain) NSString * currentStateForLocation;
@property (nonatomic, retain) NSString * currentCountryForLocation;
@property (nonatomic, assign) bool isUserFollowMode;
@property (atomic, assign) NSInteger activeRequests;

- (bool) shouldIgnoreAlertItem:(wdAlertLocation *)alertItem;
- (void) addIgnoreAlertItem:(wdAlertLocation *)newItem;
- (void) removeIgnoreAlertItem:(wdAlertLocation *)alertItem;
- (void) removeCustomAlertItem:(wdAlertLocation *)alertItem;
- (void) addCustomAlertItem:(wdAlertLocation *)newItem;
-(void)updateAlertDetails:(wdAlertLocation * )customAlertItem;
- (NSString *) getIgnoreAlertItemsCacheFilename;
- (NSString *) getCustomAlertItemsCacheFilename;
- (NSString *) getAlertItemsCacheFilename;
- (NSString *) getEnabledCatsCacheFilename;
- (NSMutableArray *)buildLocationArray:(NSArray *)latlng;
- (NSArray *) buildAPIArray;
- (void)loadAlertTargets:(CLLocation *)newLocation shouldCheckAlerts:(bool)checkAlerts;
-(void)loadAlertCategory:(CLLocation *)newLocation shouldCheckAlerts:(bool)checkAlerts filter:(NSString*)filterVal hostedCats:(NSString*)hostedVal keyIndex:(int)keyToUse;
- (CLLocation *) getLastLocationPreferenceValue;
- (CLLocation *) getLastLocationForLoadPreferenceValue;
- (NSMutableArray *) getEnabledCatsCachePreferenceValue;
- (void)setLastLocationPreferenceValue:(CLLocation *)loc;
- (void)setLastLocationForLoadPreferenceValue:(CLLocation *)loc;
- (float) getLastMapSizePreferenceValue;
- (void)setLastMapSizePreferenceValue:(float)obj;
- (NSMutableArray *) getAlertItemsCachePreferenceValue;
- (void)setAlertItemsAndEnabledCatsCachePreferenceValue:(NSMutableArray *) items  cats:(NSMutableArray *)enabledCats;

- (void)setLastLoadStartTimePreferenceValue:(NSDate *)last;
- (bool) getCategoryPreferenceValue:(NSString *)keyName;
- (NSInteger) detectionDistanceInYards;
- (NSMutableArray *) getEnabledCategories;
- (float) searchRadiusInMiles;
- (float) minLoadIntervalMinutes;
- (void) checkForInvalidCacheAndReloadCategories;
- (bool)isLocationBreakingLoadThreshold:(CLLocation *)newLocation lastLoadLocation:(CLLocation *)oldLocation threshold:(double)radiusToCheckInMiles;

- (int)checkForAlertProximityToPoints:(CLLocation * )userLocation alertList:(NSMutableString *)alertItemsNames itemsToCheck:(NSMutableArray *)alertItemsTocheck ;

- (void)startBackgroundMode;
- (void)endBackgroundMode;
- (void)startUserFollowMode;
- (void)endUserFollowMode;
- (void)loadAndCheckStateForLocation:(CLLocation *)newLocation;
- (void)processAlerts:(NSData *)responseData;
- (void)setLocationAndRadiusManually:(CLLocation *)manualLoc;
- (void)loadCurrentMapPositionWithoutAlertCheck;
- (void)reloadAndCheckAlertsForCurrentLocation;
- (void)fireErrorMessage:(NSString *)msg;
- (void)fireStatusMessage:(NSString *)msg;
- (void)fireAlertAndNotification:(wdAlertsEventParameters*)params;
- (bool)isInternetAvailable;
- (void)handlePostLoad:(CLLocation *)newLocation check:(bool)checkAlerts radius:(float)searchRadiusInMiles;
- (NSString *)getFieldFromDetails:(NSData *)responseData valName:(NSString *)fieldName;

- (NSMutableArray *)buildCLLocationArrayFromLatLngArray:(NSArray *)latlng;



@property (nonatomic, strong) id <wdAlertsManagerDelegate> delegate;



@end



