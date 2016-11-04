//
//  wdLocationManager.m
//  Alerts
//
//  Created by Benjamin Harrell on 12/12/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdAlertsManager.h"
#import "ASIHTTPRequest.h"

#import "Reachability.h"
#import <MapKit/MapKit.h>




#define METERS_PER_MILE 1609.344f
#define METERS_PER_YARD .914f
#define MIN_LOAD_RADIUS_IN_MILES 0.5f
#define MAX_LOAD_RADIUS_IN_MILES 10.0f
#define DEFAULT_LATITUDE -90.0f
#define DEFAULT_LONGITUDE -180.0f
#define MIN_STATE_CHECK_SECONDS 300  //default is 300
#define MIN_LOAD_MULTIPLIER 20    //default is 2

@implementation wdAlertsManager


@synthesize currentAlertItemRows;
@synthesize currentCustomAlertItemRows;
@synthesize currentIgnoreAlertItemRows;
@synthesize currentAPIKeys;
@synthesize delegate;
@synthesize locationManager;
@synthesize locationForLastManualMove ;
@synthesize currentStateForLocation;
@synthesize currentCountryForLocation;
@synthesize isUserFollowMode;
@synthesize activeRequests;



-(id) init
{
    self = [super init];
    
    
    //read these from the cache on initial start...
    self.currentAlertItemRows  = [self getAlertItemsCachePreferenceValue];
    self.currentCustomAlertItemRows = [self getCustomAlertItemsCachePreferenceValue];
    self.currentIgnoreAlertItemRows = [self getIgnoreAlertItemsCachePreferenceValue];
    
    self.currentAPIKeys = [self buildAPIArray];
    
   
   
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(defaultsChanged:)
                   name:NSUserDefaultsDidChangeNotification  
                 object:nil];
    
    
    
    
    return self;

}

-(NSArray *) buildAPIArray
{
    NSArray *list=[[NSArray alloc] initWithObjects:@"Fmjtd%7Cluub21utl9%2Crl%3Do5-96tlga",  //carry alerts main
                   @"Fmjtd%7Cluub21utl9%2Cax%3Do5-96tlg0",  //ben dev
                   @"Fmjtd%7Cluuan90an0%2C2g%3Do5-96r5u0",  //ben prod
                   @"Fmjtd%7Cluub21u1nq%2Cal%3Do5-96txlr",  //ben test
                   @"Fmjtd%7Cluub21u1nq%2C2w%3Do5-96txly",  //carry alerts test
                   @"Fmjtd%7Cluub21u1nq%2Ca2%3Do5-96txlz",  //carry alerts deb
                   @"Fmjtd%7Cluub21u1nq%2Ca0%3Do5-96txlf",  //amino dev
                   @"Fmjtd%7Cluub21u1nq%2Caa%3Do5-96txq6",  //amino test
                   @"Fmjtd%7Cluub21u1nq%2Caa%3Do5-96txqu",nil  //amino prod   |,=
                   ];
    
    return list;
}



- (void)defaultsChanged:(NSNotification *)notification {
   
    // Do something with it
    NSLog(@"user pref change detected");
    
    //start by making sure we have latest....
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //now see what the user pref value is
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"detection_distance_yds_preference"];
    NSInteger filter = [self detectionDistanceInYards] * METERS_PER_YARD;
    
    //if we don't have a location manager then this code won't work so return
    if (self.locationManager == nil)
        return;
    
    //if it has changed either diff value or if no longer -1 but filter is 'none'
    double currentFilter  = self.locationManager.distanceFilter;
    if (currentFilter == kCLDistanceFilterNone)
    {
        //then we have value of -1 but default is 10 so its evaluating wrong
        //need to see what pref really says, if its -1 then keep going
        if (val != -1)
        {
            NSLog(@"filter is none but user pref is not -1, restarting loc mgr");
            
            
            //then it doesnt match what user wants...restart all
            //then restart the loc mgr object with the new values
            [self endBackgroundMode];
            self.locationManager = nil;
            [self startBackgroundMode];
            
        }
        
    }
    else
    {
        //this is the normal case where it should be actual values
        //so see if the normal filter matches the user pref
        if (filter != currentFilter)
        {
            NSLog(@"filter is diff than user pref, restarting loc mgr");
            
            //then restart the loc mgr object with the new values
            [self endBackgroundMode];
            self.locationManager = nil;
            [self startBackgroundMode];
            
        }
    }
    
    
    //we need to find out if the categories changed and clear the cache
    [self checkForInvalidCacheAndReloadCategories];

}

-(void)updateAlertDetails:(wdAlertLocation * )customAlertItem
{
    //find it and set values
    if (customAlertItem.isCustom)
    {
        for (wdAlertLocation * alertItem in self.currentCustomAlertItemRows)
        {
            //see if points are same for now
            if (alertItem.coordinate.latitude == customAlertItem.coordinate.latitude &&
            alertItem.coordinate.longitude == customAlertItem.coordinate.longitude)
            {
                //update and exit
                alertItem.title = customAlertItem.title;
            
                break;
            }
        }
        //tell it to sync just in case
        [self setCustomAlertItemsCachePreferenceValue:self.currentCustomAlertItemRows];
    }
    
    
    
}

-(void) checkForInvalidCacheAndReloadCategories
{
    
    //first see if we are already loading...if so then just wait for now because if not
    //it will create an infinite loop
    
    NSLog(@"checkForInvalidCacheAndReloadCategories called");
    
    if (self.activeRequests > 0)
        return;
    
    
    
    
    //see if current prefs are = to previous value stored
    
    NSMutableArray * enabledCatsCache =  [self getEnabledCatsCachePreferenceValue];
    //if no loaded cats then no cache to invalidate
    if (enabledCatsCache == nil)
    {
        NSLog(@"cats cache is nil reloading...");
        
        
        //no cats are loaded, either it hasn't been called yet or the items were loaded from cache but
        //the cats were not in the cache (upgrade scenario)
        //so we probably should reload but we don't want to hit this again
        //while loading due to other pref changes
        [self reloadAndCheckAlertsForCurrentLocation];
        return;
    }
    
    
    
    NSMutableArray * currPrefCats = [self getEnabledCategories];
    
    //first check for length inequality
    if (currPrefCats.count != enabledCatsCache.count)
    {
        NSLog(@"cats cache count doesn't match reloading...");
        [self reloadAndCheckAlertsForCurrentLocation];
        return;
    }
    
    
    for (int i=0;i<enabledCatsCache.count;i++)
    {
        NSString * cacheValue = [enabledCatsCache objectAtIndex:i];
        
        
        if ([currPrefCats containsObject:cacheValue])
            continue;
        else
        {
            //trigger a reload because something changed
            NSLog(@"cats cache same number but one not matching reloading...");
            [self reloadAndCheckAlertsForCurrentLocation];
        }
    }
    
}


- (void)locationManager:(CLLocationManager*)aManager didFailWithError:(NSError*)anError
{
    switch([anError code])
    {
        case kCLErrorLocationUnknown: // location is currently unknown, but CL will keep trying
            //[self fireStatusMessage:@"Determining current location...'"];
            break;
            
        case kCLErrorDenied: // CL access has been denied (eg, user declined location use)
            [self fireErrorMessage:@"Carry Alerts needs to know your location in order to work, please enable Location Services for Carry Alerts in 'Settings'"];
            break;
            
        case kCLErrorNetwork: // general, network-related error
            [self fireErrorMessage:@"Carry Alerts can't find you - please check your network connection or that you are not in airplane mode"];
    }
}



- (void)startUserFollowMode
{
    
    NSLog(@"startUserFollowMode called");
    self.isUserFollowMode = true;
    
    //reset the manual location for the next time its used
    self.locationForLastManualMove = nil;
    
    //reset the current items
    self.currentAlertItemRows = nil;
    //now see if we have any cached
    self.currentAlertItemRows = [self getAlertItemsCachePreferenceValue];

    
    NSLog(@"follow mode started, restoring %u cached alert items", self.currentAlertItemRows.count);
}
- (void)endUserFollowMode
{
    self.isUserFollowMode = false;
    
}


- (void)startBackgroundMode
{
    //only remake if not there...
    if (self.locationManager == nil)
    {
        self.locationManager = [[CLLocationManager alloc] init] ;
        self.locationManager.delegate = self;
        //if ( self.locationManager.deferredLocationUpdatesAvailable == true)
        [self.locationManager disallowDeferredLocationUpdates ];
    }
    
    
    //check one more time just in case
    if (self.locationManager == nil)
    {
        NSLog(@"log mgr still nil, can't start");
        return;
    }
    
    
    //force it off to set our new values...
    [self.locationManager stopUpdatingLocation];
    
    
    
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"detection_distance_yds_preference"];
    NSInteger filter = [self detectionDistanceInYards] * METERS_PER_YARD;
    if (val ==-1)
    {
        self.locationManager.distanceFilter =  kCLDistanceFilterNone;
    }
    else
    {
        self.locationManager.distanceFilter =  filter;
    }
    self.locationManager.desiredAccuracy = [self getBatteryMode];
    [self.locationManager startUpdatingLocation];
    
}

- (void)endBackgroundMode
{
    if (self.locationManager != nil)
        [self.locationManager stopUpdatingLocation];
    
}

- (void)setLocationAndRadiusManually:(CLLocation *)manualLoc
{
    
    self.locationForLastManualMove = manualLoc;
    
    /*
    
    //try to emulate the distance filter to avoid excessive loads
    if (!self.locationForLastManualMove)
    {
        //start with where we are so that we don't jump to a load first thing
        self.locationForLastManualMove = [self getLastLocationPreferenceValue];
    }
    
    
    
    bool needToLoad = false;
    
    if(self.locationForLastManualMove == nil)
        needToLoad = true;
    
    needToLoad = [self isLocationBreakingLoadThreshold:manualLoc lastLoadLocation:self.locationForLastManualMove threshold:[self searchRadiusInMiles]];//manualRadius];
    
    if (needToLoad)
    {
        self.locationForLastManualMove = manualLoc;
        //NSLog(@"manual load alerts with radius %1f", manualRadius);
        //[self loadAlertTargets:manualLoc  shouldCheckAlerts:false];
    }
     
     */
}


//this method will be used by the manual load command it can be called from either mode
//in follow mode it will load
- (void)loadCurrentMapPositionWithoutAlertCheck
{
    if (self.isUserFollowMode)
    {
        //then load but also cache the items
        [self loadAlertTargets:[self getLastLocationPreferenceValue]  shouldCheckAlerts:false];
    }
    else
    {
        //use the map position to load
        [self loadAlertTargets:self.locationForLastManualMove  shouldCheckAlerts:false];
    }
}


//this is called by the refresh arrow but also when category change is detected
//we dont know the user follow mode so we need to be smart about the load and check
-(void)reloadAndCheckAlertsForCurrentLocation
{
    NSLog(@"reload called");
    //we will use this to load the current location so need to know if userfollowmode
    if (self.isUserFollowMode)
    {
        //then load but also cache the items
        [self loadAlertTargets:[self getLastLocationPreferenceValue]  shouldCheckAlerts:true];
    }
    else
    {
        //since they are just dragging around lets just warn them that it changed but make them
        //click refresh manually
        //this will likely happen while the user is in the settings screen so not sure a message will help
        [self fireStatusMessage:@"Categories have been changed while in manual mode, use the 'Reload' button to load with the new settings."];
        //use the map position to load
        //[self loadAlertTargets:self.locationForLastManualMove  shouldCheckAlerts:false];
    }
    
    
    //NSLog(@"reload and check using stored loc %f, %f and radius %1f", self.locationForCurrentLoadedAlerts.coordinate.latitude, self.locationForCurrentLoadedAlerts.coordinate.longitude, [self radiusInMiles]);
    
}


//we need to catch a filter change and restart loc mgr


- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"didUpdateToLocation called");
    
    //check if we are in manual mode
    if (!self.isUserFollowMode)
        return;
    
    if (newLocation == nil)
        return;
    
    if([newLocation horizontalAccuracy] < 0.0f) return;
    
    NSDate* time = newLocation.timestamp;
    NSTimeInterval timePeriod = [time timeIntervalSinceNow];
    //usually it take less than 0.5 sec to get a new location but you can use greater
    if(timePeriod > 2.0 ) {
        // skip the location
        return;
    }
    
    //we have a good locaiton so store the new location no matter what
    [self setLastLocationPreferenceValue:newLocation];
    
    //we need to handle the situation where we get to here for the first location update
    //and the item cache was empty but the last location saved was within the reload threshold
    //so the threshold wont trigger a load we need to force it
    
    bool needToLoad = false;
    
    
    //what happens if we always load when cache is empty?  this would affect places that had no results...
    CLLocation * lastLoadLoc = [self getLastLocationForLoadPreferenceValue];
    if (self.currentAlertItemRows.count ==0||
        lastLoadLoc == nil)
        needToLoad = true;
    else
    {
        //see if we need to load based on size of radius and distance traveled by user
        
        needToLoad = [self isLocationBreakingLoadThreshold:newLocation lastLoadLocation:lastLoadLoc threshold:[self searchRadiusInMiles]];
    }
    
    
    
    
    //we need to load but make sure we are not currently loading
    if (needToLoad &&
        self.activeRequests == 0)
    {
        NSLog(@"reloading alerts basedon threshold and activereqs = 0");
        
        //NSLog(@"locmgr update load alerts with radius %1f", [self radiusInMiles]);
        [self loadAlertTargets:newLocation shouldCheckAlerts:true];
        
        
        
    }
    else{
        
        NSLog(@"didUpdateToLocation just checking alert proximity");
        [self checkAllAlertConditions:newLocation];
    }
    
    
    
    //always push thelocation to the delegate and let them decide what to do with it....
    if([self.delegate respondsToSelector:@selector(didUpdateLocation)])
    {
        //send the delegate function
        [self.delegate didUpdateLocation];
    }
    
    
    
}

-(void) checkAllAlertConditions:(CLLocation *)newLocation
{
    
    //this is where we store the alert items
    NSMutableString* alertItemsNames = [[NSMutableString alloc] init];
    NSInteger alertItemsCount = 0;
    
    /*
    if([self.delegate respondsToSelector:@selector(didStartProcessingAlerts:)])
    {
        //send the delegate function
        [self.delegate didStartProcessingAlerts:[NSString stringWithFormat:@"Checking if %u items in %.1f mile radius are within %u yds of current location",self.currentAlertItemRows.count, [self radiusInMiles], self.detectionDistanceInYards ]];
    }*/
        
    //always check the proximity because user could be traveling inside the load threshold but be close to an alert
    alertItemsCount += [self checkForAlertProximityToPoints:newLocation alertList:alertItemsNames itemsToCheck:self.currentAlertItemRows];
    alertItemsCount += [self checkForAlertProximityToPoints:newLocation alertList:alertItemsNames itemsToCheck:self.currentCustomAlertItemRows];
    
    alertItemsCount += [self checkAllPolys:newLocation alertList:alertItemsNames];
    
    
    
    if (alertItemsCount > 0)
    {
        //[alertItemsNames insertString:[NSString stringWithFormat:@"%u alerts: \r\n", alertItemsCount] atIndex:0];
        wdAlertsEventParameters* params = [[wdAlertsEventParameters alloc] initWithCountAndMessage:alertItemsCount message:alertItemsNames];
        [self fireAlertAndNotification:params];
    }
    
    //get the current STATE for this location to check reciprocity
    //NOTE this runs async so will not be part of the alert list but will do its own alert
    //since this is an expensive reverse GEOCODE then we should only do it once every few minutes
    //so check the timer
    if (_lastStateAndCountryCheckTime == nil)
    {
        NSLog(@"Last state and country check time is nil, checking");
        [self loadAndCheckStateForLocation:newLocation];
    }
    else{
        NSTimeInterval loadDiff = [_lastStateAndCountryCheckTime timeIntervalSinceNow];
        loadDiff = abs(loadDiff);
        if (loadDiff > (MIN_STATE_CHECK_SECONDS ))  //TODO: only check state every 5 mins = 300 secs
        {
            NSLog(@"Last state and country check time is > 5 mins, checking");
            [self loadAndCheckStateForLocation:newLocation];
        }
        else{
            NSLog(@"Last state and country check time is < 5 mins, skipping");
            //hasn't been 5 mins so dont check state
        }
    }
    
    
    //this is where we would check for custom alerts added by the user
    
            
            
}


- (bool)isLocationBreakingLoadThreshold:(CLLocation *)newLocation lastLoadLocation:(CLLocation *)oldLocation threshold:(double)radiusToCheckInMiles
{
    //try to emulate the distance filter to avoid excessive loads
    
    bool needToLoad = false;
    
    //first check if the existing one is bad...if so go straight to load for first time
    if (! oldLocation   ||
        oldLocation.coordinate.latitude == 0||
        oldLocation.coordinate.longitude == 0 ||
        oldLocation.coordinate.latitude == -90.0f||
        oldLocation.coordinate.longitude == -180.f)
    {
        
        needToLoad = true;
    }
    else
    {
        
        //we have loaded before so check how far away it is....
        CLLocationDistance metersFromLastLoad = [newLocation distanceFromLocation:oldLocation];
        NSInteger searchRadiusInMeters = radiusToCheckInMiles * METERS_PER_MILE;
        
        if (metersFromLastLoad >0 &&
            metersFromLastLoad >  (searchRadiusInMeters / 1.25)
            )
        {
            NSLog(@"Location TOO FAR from last load checking load time: %f  >  %f", metersFromLastLoad, (searchRadiusInMeters / 1.25));
            
            
            //now check to see if we have slept for the minimum load interval
            
            NSDate * lastLoad = [self getLastLoadStartTimePreferenceValue];
            NSTimeInterval loadDiff = [lastLoad timeIntervalSinceNow];
            loadDiff = abs(loadDiff);
            if (loadDiff > ([self minLoadIntervalMinutes] * 60 ))
            {
                NSLog(@"Min load time (secs) HAS passed: %f  >  %f", loadDiff, ([self minLoadIntervalMinutes] * 60 ));

                needToLoad = true;
            }
            else{
                
                NSLog(@"Min load time (secs) HAS NOT passed: %f  <  %f", loadDiff, ([self minLoadIntervalMinutes] * 60 ));
                needToLoad = false;
            }
            
        }
        else{
            NSLog(@"Location NOT TOO FAR from last load: %f  <  %f", metersFromLastLoad, (searchRadiusInMeters / 1.25));
        }
        
    }
    
    return needToLoad;
}


- (float) searchRadiusInMiles
{
    //get the user pref for radius
    NSInteger val = [[NSUserDefaults standardUserDefaults] floatForKey:@"search_size_miles_preference"];
    
    if (val == 0)
        return 20;
    else
        return val;
  
}



- (float) minLoadIntervalMinutes
{
    //for now calc based on search radius
    return [self searchRadiusInMiles] / MIN_LOAD_MULTIPLIER;
}


- (NSInteger) detectionDistanceInYards
{
    //get the user pref
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"detection_distance_yds_preference"];
    if (val <= 0)
        return 50;
    else
        return val;
}

- (CLLocationAccuracy) getBatteryMode
{
   
    NSString * val = [[NSUserDefaults standardUserDefaults] stringForKey:@"battery_usage_preference"];
    if (val == nil)
        return kCLLocationAccuracyNearestTenMeters;
    else
        return (CLLocationAccuracy)[self accuracyFromNSString:val];
    
}

-(double) accuracyFromNSString:(NSString *)strAcc
{
    if ([strAcc isEqualToString:@"kCLLocationAccuracyBest"])
        return kCLLocationAccuracyBest;
    if ([strAcc isEqualToString:@"kCLLocationAccuracyBestForNavigation"])
        return kCLLocationAccuracyBestForNavigation;
    if ([strAcc isEqualToString: @"kCLLocationAccuracyHundredMeters"])
        return kCLLocationAccuracyHundredMeters;
    if ([strAcc isEqualToString: @"kCLLocationAccuracyKilometer"])
        return kCLLocationAccuracyKilometer;
    if ([strAcc isEqualToString: @"kCLLocationAccuracyNearestTenMeters"])
        return kCLLocationAccuracyNearestTenMeters;
    else
        return kCLLocationAccuracyNearestTenMeters;
    
}



- (bool) getCategoryPreferenceValue:(NSString *)keyName
{
    NSObject * val = [[NSUserDefaults standardUserDefaults] objectForKey:keyName];
    
    if (val == nil)
    {
        return true;  //this will force all on by default...
    }
    else
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:keyName];
    }
}

- (NSString *) getEnabledCatsCacheFilename
{
    NSArray *cach = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [cach lastObject];
    NSString *filePathCats = [cache stringByAppendingPathComponent:@"enabledCats.plist"];
    return filePathCats;
}

- (NSString *) getAlertItemsCacheFilename
{
    NSArray *cach = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [cach lastObject];
    NSString *filePath = [cache stringByAppendingPathComponent:@"alertItems.plist"];
    return filePath;
}

- (NSString *) getCustomAlertItemsCacheFilename
{
    NSArray *cach = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [cach lastObject];
    NSString *filePath = [cache stringByAppendingPathComponent:@"customalertItems.plist"];
    return filePath;
}

- (NSString *) getIgnoreAlertItemsCacheFilename
{
    NSArray *cach = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [cach lastObject];
    NSString *filePath = [cache stringByAppendingPathComponent:@"ignorealertItems.plist"];
    return filePath;
}



-(void)setAlertItemsAndEnabledCatsCachePreferenceValue:(NSMutableArray *) items  cats:(NSMutableArray *)enabledCats
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *myEncodedObject2 = [NSKeyedArchiver archivedDataWithRootObject:enabledCats];
    [defaults setObject:myEncodedObject2 forKey:@"enabled_categories_cache_preference"];
    
    
    NSData *myEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:items];
    //[defaults setObject:myEncodedObject forKey:@"alert_items_cache_preference"];
    //lets write this instead to the library \ cache
    
    
    //NSString * filePathCats = [self getEnabledCatsCacheFilename];
    //[enabledCats writeToFile:filePathCats atomically:YES];
    
    NSString * filePathAlerts = [self getAlertItemsCacheFilename];
    [myEncodedObject writeToFile:filePathAlerts atomically:YES];
    
    
}
 


-(void)setCustomAlertItemsCachePreferenceValue:(NSMutableArray *) items 
{
    NSData *myEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:items];    
    NSString * filePathAlerts = [self getCustomAlertItemsCacheFilename];
    [myEncodedObject writeToFile:filePathAlerts atomically:YES];
    NSLog(@"Custom Alerts saved to preference name: %@ total of %d items", filePathAlerts, items.count);
}

-(void)setIgnoreAlertItemsCachePreferenceValue:(NSMutableArray *) items
{
    NSData *myEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:items];
    NSString * filePathAlerts = [self getIgnoreAlertItemsCacheFilename];
    [myEncodedObject writeToFile:filePathAlerts atomically:YES];
    NSLog(@"Ignore Alerts saved to preference name: %@ total of %d items", filePathAlerts, items.count);
}

- (NSMutableArray *) getEnabledCatsCachePreferenceValue
{
    //NSString * filePathCats = [self getEnabledCatsCacheFilename];
    //NSMutableArray *loadedCats = [NSMutableArray arrayWithContentsOfFile:filePathCats];
    
    NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"enabled_categories_cache_preference"];
    
    //if (loadedCats == nil)
    if (myEncodedObject == nil)
    {
        return nil;
    }
    else
    {
        NSMutableArray *obj = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        return obj;
        //return loadedCats;
    }
    
    
}

- (NSMutableArray *) getCustomAlertItemsCachePreferenceValue
{
    
    NSString * filePath = [self getCustomAlertItemsCacheFilename];
    NSData *myEncodedObject = [NSData dataWithContentsOfFile:filePath];
    
    //NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"alert_items_cache_preference"];
    
    
    if (myEncodedObject == nil)
    {
        NSLog(@"Custom Alerts not found in preference: %@ returning new array", filePath);
        return [[NSMutableArray alloc] init];
    }
    else
    {
        NSMutableArray *obj = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        NSLog(@"Custom Alerts found in preference name: %@ total of %d items", filePath, obj.count);
        return obj;
        //return [[NSMutableArray alloc]  initWithArray:loadedAlerts];
    }
}

- (NSMutableArray *) getIgnoreAlertItemsCachePreferenceValue
{
    
    NSString * filePath = [self getIgnoreAlertItemsCacheFilename];
    NSData *myEncodedObject = [NSData dataWithContentsOfFile:filePath];
    
    //NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"alert_items_cache_preference"];
    
    
    if (myEncodedObject == nil)
    {
        NSLog(@"Ignore Alerts not found in preference: %@ returning new array", filePath);
        return [[NSMutableArray alloc] init];
    }
    else
    {
        NSMutableArray *obj = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        NSLog(@"Ignore Alerts found in preference name: %@ total of %d items", filePath, obj.count);
        return obj;
        //return [[NSMutableArray alloc]  initWithArray:loadedAlerts];
    }
}

- (NSMutableArray *) getAlertItemsCachePreferenceValue
{
    
    NSString * filePath = [self getAlertItemsCacheFilename];
    NSData *myEncodedObject = [NSData dataWithContentsOfFile:filePath];
    
    //NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"alert_items_cache_preference"];
    
    if (myEncodedObject == nil)
    {
        return [[NSMutableArray alloc] init];
    }
    else
    {
        NSMutableArray *obj = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        return obj;
        //return [[NSMutableArray alloc]  initWithArray:loadedAlerts];
    }
}

- (float) getLastMapSizePreferenceValue
{
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"last_map_size_preference"];
    if (val <= 0)
        return 5;
    else
        return val;
}

- (void)setLastMapSizePreferenceValue:(float)val
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults  setFloat:val forKey:@"last_map_size_preference"];
}

- (void)setLastLocationForLoadPreferenceValue:(CLLocation *)obj {
    NSData *myEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:obj];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:myEncodedObject forKey:@"last_location_for_load_preference"];
}

- (CLLocation *) getLastLocationForLoadPreferenceValue
{
    NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"last_location_for_load_preference"];
    
    if (myEncodedObject == nil)
    {
        //NSLog(@"No location pref stored, returning nil");
        return nil;
        //CLLocation *centerLoc = [[CLLocation alloc] initWithLatitude:DEFAULT_LATITUDE longitude:DEFAULT_LONGITUDE];
        //return centerLoc;
    }
    else
    {
        CLLocation *obj = (CLLocation *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        return obj;
    }
}


- (void)setLastLocationPreferenceValue:(CLLocation *)obj {
    NSData *myEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:obj];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:myEncodedObject forKey:@"last_location_preference"];
}

- (void)setLastLoadStartTimePreferenceValue:(NSDate *)last{
    NSData *myEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:last];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:myEncodedObject forKey:@"last_load_start_time_preference"];
}

- (NSDate *) getLastLoadStartTimePreferenceValue
{
    NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"last_load_start_time_preference"];
    
    if (myEncodedObject == nil)
    {
        return nil;
    }
    else
    {
        NSDate *obj = (NSDate *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        return obj;
    }
}


- (CLLocation *) getLastLocationPreferenceValue
{
    NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"last_location_preference"];
    
    if (myEncodedObject == nil)
    {
        //NSLog(@"No location pref stored, returning nil");
        return nil;
        //CLLocation *centerLoc = [[CLLocation alloc] initWithLatitude:DEFAULT_LATITUDE longitude:DEFAULT_LONGITUDE];
        //return centerLoc;
    }
    else
    {
        CLLocation *obj = (CLLocation *)[NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        return obj;
    }
}

-(bool)isInternetAvailable
{
    //check for inet status first
    Reachability *internetReachable = [Reachability reachabilityForInternetConnection];
    if (internetReachable.currentReachabilityStatus == NotReachable)
    {
        return false;
    }
    else{
        return true;
    }
}

- (NSMutableArray *) getEnabledCategories
{
    
    NSMutableArray * enabledCats = [[NSMutableArray alloc] init];
    
    //iterate the preferences and if a category is YES then add to the array
    for(NSString * currKey in [NSUserDefaults standardUserDefaults].dictionaryRepresentation.allKeys)
    {
        if ( [currKey hasPrefix:@"category_"])
        {
            bool val = [self getCategoryPreferenceValue:currKey];
            if (!val)
                continue;
            
            [enabledCats addObject:currKey];
            
        }
    }
    
    return enabledCats;
}

-(void)loadAlertTargets:(CLLocation *)newLocation  shouldCheckAlerts:(bool)checkAlerts
{
    if (![self isInternetAvailable])
    {
        NSLog(@"Internet connection not available...skipping load");
        [self fireStatusMessage:@"Internet unavailable, Current Alerts will be scanned and new Alerts will load when connection is re-established."];
        return;
    }
    
    if (! newLocation   ||
        newLocation.coordinate.latitude == 0||
        newLocation.coordinate.longitude == 0||
        newLocation.coordinate.latitude == -90.0f||
        newLocation.coordinate.longitude == -180.0f)
    {
        NSLog(@"bad coordinates...skipping load");
        return;
    }
    
    //NSLog(@"resetting alert items...");
    [self.currentAlertItemRows removeAllObjects];
    //NSLog(@"item count after %u", self.currentAlertItemRows.count );
    
    
    //about to load so store the start time so we dont trigger another when moving too fast!!!
    
    
    
    if([self.delegate respondsToSelector:@selector(didResetAlertItems)])
    {
        //send the delegate function
        [self.delegate didResetAlertItems];
    }
    
    
    //iterate the cats and make a call for each
    //set to 0 just in case....
    NSLog(@"resetting activeRequests to 0");
    self.activeRequests = 0;
    
    int numCats = 0;
    
    //iterate the preferences and if a category is YES then add to the array
    NSMutableString* searchCategories = [[NSMutableString alloc] init];
    NSMutableString* hostedCategories = [[NSMutableString alloc] init];
    for(NSString * currKey in [NSUserDefaults standardUserDefaults].dictionaryRepresentation.allKeys)
    {
        if ( [currKey hasPrefix:@"category_"])
        {
            bool val = [self getCategoryPreferenceValue:currKey];
            
            //parse the category value
            NSString * catValue = [currKey substringFromIndex:9] ;
            if (val)
            {
                numCats++;
                //we have to split these based on , and then put in the correct place
                NSArray * splitValues = [[NSArray alloc] init];
                splitValues = [catValue componentsSeparatedByString:@","];
                for (NSString * cat in splitValues)
                {
                    if([cat hasPrefix:@"T"])//check if begins with T
                    {
                        //handle the hostedData types here  hostedData=MQA.NTPois,T=3045 OR T=XXXX  (%20 for spaces)
                        [hostedCategories appendString:cat];
                        [hostedCategories appendString:@" OR "];
                        
                    }
                    else//else handle the numeric
                    {
                        [searchCategories appendString:cat];
                        [searchCategories appendString:@","];
                        
                    }
                }
                
            }
            
            
        }
        
        
    }
    
    //[searchCategories appendString:@"123123123,123,123,123,213,"];

    
    if (searchCategories.length == 0 && hostedCategories.length == 0)
    {
        [self fireStatusMessage:@"No categories found, check that categories are enabled in 'Settings'"];
        
        return;  //no need to query
    }
    else{
        //[self fireStatusMessage:[NSString stringWithFormat:@"Loading %u categories within %u mile radius",numOfCats, searchRadiusInMiles]];
        //remove last comma
        if (searchCategories.length > 1)
            [searchCategories deleteCharactersInRange:NSMakeRange([searchCategories length]-1, 1)];
        if (hostedCategories.length > 1)
            [hostedCategories deleteCharactersInRange:NSMakeRange([hostedCategories length]-4, 4)];
    }
    
    //for stress testing and failure use the loop...so far no errors using it though
    //for(int i=0; i<5005;i++)
    //{
        [self loadAlertCategory:newLocation shouldCheckAlerts:checkAlerts filter:searchCategories hostedCats:hostedCategories keyIndex:0];
    //    NSLog(@"FORCELOAD::::::::::::::::%u", i);
    //}
    
    self.activeRequests = 1;//numCats;
    
    if (self.activeRequests > 0)
    {
        
        //start the progress indicator
        if([self.delegate respondsToSelector:@selector(didStartProcessingAlerts:)])
        {
            //send the delegate function
            [self.delegate didStartProcessingAlerts:[NSString stringWithFormat:@"Loading %u categories within %.1f mile radius", numCats, [self searchRadiusInMiles]]];
        }
    }
    else{
        //TODO: in a multi request scenario we might do more here, like update progress...
        [self fireStatusMessage:@"No categories found, check that categories are enabled in 'Settings'"];
        return;
    }
    
    
    
    //no matter if cats or not we still dont want to try to load every second while traveling fast
    //so set this to "snooze" the loading
    [self setLastLoadStartTimePreferenceValue:[NSDate date]];
    
    //also set the last load location so that we won't load every loc update we can check distance
    [self setLastLocationForLoadPreferenceValue:newLocation];
    
    NSLog(@"setting last load time and last load location");
    
        
}

-(void)loadAlertCategory:(CLLocation *)newLocation shouldCheckAlerts:(bool)checkAlerts filter:(NSString*)filterVal hostedCats:(NSString*)hostedVal keyIndex:(int)keyToUse
{
    
    float searchRadiusInMiles = [self searchRadiusInMiles];
    //double searchRadiusInMeters = searchRadiusInMiles * METERS_PER_MILE;
    
    //MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(newLocation.coordinate, searchRadiusInMeters, searchRadiusInMeters);
    NSMutableString * hostedCombined = [[NSMutableString alloc] init];
    if (hostedVal.length > 0)
    {
        [hostedCombined appendString:@"&hostedData=MQA.NTPois,"];
        [hostedCombined appendString:hostedVal];
    }
    
    NSString * currKey = [self.currentAPIKeys[keyToUse] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString * urlBase = [NSString stringWithFormat:@"http://www.mapquestapi.com/search/v1/search?key=%@&maxMatches=5000&shapePoints=%f,%f&mapData=navt,%@%@&radius=%1f", currKey, newLocation.coordinate.latitude, newLocation.coordinate.longitude, filterVal, hostedCombined, searchRadiusInMiles];
        
        // 3
    
    NSString* webStringURL = [urlBase stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:webStringURL];
    
    NSLog(@"calling service %@", webStringURL);
    
    // 4
    ASIHTTPRequest *_request = [ASIHTTPRequest requestWithURL:url];
    __weak ASIHTTPRequest *request = _request;
    request.timeOutSeconds = 60;
    request.requestMethod = @"GET";
    [request setAllowCompressedResponse:NO];
    //[request addRequestHeader:@"Content-Type" value:@"application/json"];
    //[request appendPostData:[json dataUsingEncoding:NSUTF8StringEncoding]];
    // 5
    [request setDelegate:self];        
    [request setCompletionBlock:^{
        
        self.activeRequests--;
        NSLog(@"Good response: active reqs %i", self.activeRequests);
        //return;
        [self processAlerts:request.rawResponseData];
        
        if (checkAlerts)//manual location changes shouldn't scan
        {
            //NSLog(@"checking proximity using loc %f, %f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
            //just loaded new alert items so go ahead and scan for alerts just in case
            
            [self checkAllAlertConditions:newLocation];
        }        //this will check active reqs and fire the plot delegate
        [self handlePostLoad:newLocation check:checkAlerts radius:searchRadiusInMiles];
                
    }];
    [request setFailedBlock:^{
        
        self.activeRequests--;
        
        //check the http status..if OK then prob over limit
       
        NSLog(@"Error: %@", [request error].localizedDescription);
        
        //TODO: try other keys
        //first thing try to make a query again until we run out of keys then its really an error
        
        if (keyToUse +1  < self.currentAPIKeys.count)
        {
            [self loadAlertCategory:newLocation shouldCheckAlerts:checkAlerts filter:filterVal hostedCats:hostedVal keyIndex:keyToUse+1];
        }
        else
        {
            //this will turn off this request and kill the loading screen even for an error
            [self handlePostLoad:newLocation check:checkAlerts radius:searchRadiusInMiles];
        
            [self fireStatusMessage:[request error].localizedDescription];
        }
    }];
    
    // 6
    [request startAsynchronous];
    
}


-(void)handlePostLoad:(CLLocation *)newLocation check:(bool)checkAlerts radius:(float)searchRadiusInMiles
{
    //make sure everyone done first....
    //NSLog(@"check if delegate can fire: %u", self.activeRequests);
    
    if([self.delegate respondsToSelector:@selector(didUpdateAlertItems:)])
    {
        //send the delegate function with the amount entered by the user
        //[self.delegate didUpdateAlertItems:[NSString stringWithFormat:@"Loading %u categories within %.1f mile radius",self.activeRequests, searchRadiusInMiles]];
        
        [self.delegate didUpdateAlertItems:@""];
    }
     
        
    
    NSLog(@"handle post load: active requests: %i", self.activeRequests);
    if (self.activeRequests > 0)
        return;
    
    
        
        
    //start the progress indicator
    if([self.delegate respondsToSelector:@selector(didEndProcessingAlerts)])
    {
        //send the delegate function
        [self.delegate didEndProcessingAlerts];
    }
    
    //if tracking user then cache the results since all requests are done
    if (self.isUserFollowMode)
    {
        NSLog(@"Caching %u items", self.currentAlertItemRows.count);
        NSMutableArray * enabledCats = [self getEnabledCategories];
        [self setAlertItemsAndEnabledCatsCachePreferenceValue:self.currentAlertItemRows cats:enabledCats];
    }
    
}

-(void)processAlerts:(NSData *)responseData
{
 
    NSMutableArray * dicItems = [[NSMutableArray alloc] init];
 
    /*NSString* rawJSON = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    rawJSON = [rawJSON substringFromIndex:28];
    rawJSON = [rawJSON substringToIndex:[rawJSON length] - 2];
    
    NSDictionary *unserializedData = [rawJSON objectFromJSONString];
    NSArray *data = [unserializedData objectForKey: @"searchResults"];
     */
    //NSLog(@"RAW RESPONSE:::::%@", rawJSON);
    
    //google approach
    
    NSString* rawJSON = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSLog(@"RAW RESPONSE:::::%@", rawJSON);
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:responseData
                          
                          options:kNilOptions
                          error:&error];
    
    //The results from Google will be an array obtained from the NSDictionary object with the key "results".
    NSArray* data = [json objectForKey:@"searchResults"];
        
    for (NSDictionary * row in data)
    {
        
        //get the values we need
        NSString *name = row[@"name"];
        NSString *gefID = row[@"gefId"];
        NSArray * latlng = row[@"shapePoints"];
        
        NSInteger pointsCount = [latlng count];
        
        if (pointsCount < 2)//not enough points bad point
        {
            NSLog(@"Skipping %@ - Not enough points, %d", name, pointsCount);
            continue;
        }
        
        
        if (pointsCount % 2 == 1)
        {
            NSLog(@"Skipping %@ - Odd number of points %d", name, pointsCount);
            continue;
        }
        
        
        NSString *latitude = latlng[0];
        NSString *longitude = latlng[1];
        NSNumber * nlat = [NSNumber numberWithFloat:[latitude floatValue]];
        NSNumber * nlong = [NSNumber numberWithFloat:[longitude floatValue]];
         
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = nlat.doubleValue;
        coordinate.longitude = nlong.doubleValue;
         
        NSArray * arrLocs= [self buildLocationArray:latlng];
        NSString * typeVal;
        if (pointsCount > 2)
            typeVal = @"Boundary Check";
        else
            typeVal = @"Proximity Check";
         
        //at this point we should have all we need so create an alert obj and store it
        wdAlertLocation *annotation = [[wdAlertLocation alloc] initWithAll:name coordinate:coordinate type:typeVal ref:gefID points:arrLocs isCust:false] ;
        
        [dicItems addObject:annotation];
        
    }
    
    
    [currentAlertItemRows addObjectsFromArray:dicItems];
    NSLog(@"DB alerts count: %u", currentAlertItemRows.count);
    
    
    
}

- (void)addCustomAlertItem:(id)newItem
{
    [currentCustomAlertItemRows addObject:newItem];
    NSLog(@"custom alerts count: %u", currentCustomAlertItemRows.count);
    //now sync it to the prefs to remember it
    [self setCustomAlertItemsCachePreferenceValue:currentCustomAlertItemRows];
    
    if([self.delegate respondsToSelector:@selector(didUpdateCustomAlertItems:)])
    {
        //send the delegate function with the amount entered by the user
        //[self.delegate didUpdateAlertItems:[NSString stringWithFormat:@"Loading %u categories within %.1f mile radius",self.activeRequests, searchRadiusInMiles]];
        
        [self.delegate didUpdateCustomAlertItems:@""];
    }

}

- (void)removeCustomAlertItem:(wdAlertLocation *)alertItem
{
    NSUInteger idx = -1;
    for (wdAlertLocation * currItem in currentCustomAlertItemRows)
    {
        idx ++;
        if (currItem.coordinate.latitude == alertItem.coordinate.latitude &&
            currItem.coordinate.longitude == alertItem.coordinate.longitude )
        {
            //then remove it
            [currentCustomAlertItemRows removeObjectAtIndex:idx];
        }
    }
    
}

- (void)addIgnoreAlertItem:(id)newItem
{

    [currentIgnoreAlertItemRows addObject:newItem];
    NSLog(@"ignore alerts count: %u", currentIgnoreAlertItemRows.count);
    //now sync it to the prefs to remember it
    [self setIgnoreAlertItemsCachePreferenceValue:currentIgnoreAlertItemRows];
    
    //TODO: do we need to send a delegate event?
    
}

- (void)removeIgnoreAlertItem:(wdAlertLocation *)alertItem
{
    NSUInteger idx = -1;
    for (wdAlertLocation * currItem in currentIgnoreAlertItemRows)
    {
        if (currItem.coordinate.latitude == alertItem.coordinate.latitude &&
            currItem.coordinate.longitude == alertItem.coordinate.longitude )
        {
            
            idx = [currentIgnoreAlertItemRows indexOfObject:currItem];
            break;
        }
    }
    
    if (idx != -1)
        [currentIgnoreAlertItemRows removeObjectAtIndex:idx];
    
}

- (bool) shouldIgnoreAlertItem:(wdAlertLocation *)alertItem
{
    //TODO: iterate the list and return if exists in list
    for (wdAlertLocation * currItem in currentIgnoreAlertItemRows)
    {
        if (currItem.coordinate.latitude == alertItem.coordinate.latitude &&
            currItem.coordinate.longitude == alertItem.coordinate.longitude )
        {
            return true;
        }
    }
    return false;
}


- (NSMutableArray *)buildLocationArray:(NSArray *)latlng {
    
    NSInteger pointsCount = [latlng count];
    int i;
    NSMutableArray* arrLocs = [[NSMutableArray alloc] init];
    for (i = 0; i < pointsCount; i=i+2)
    {
        NSNumber * nlt = [NSNumber numberWithFloat:[latlng[i] floatValue]];
        NSNumber * nlg = [NSNumber numberWithFloat:[latlng[i+1] floatValue]];
        CLLocation *locCurr = [[CLLocation alloc] initWithLatitude:nlt.doubleValue longitude:nlg.doubleValue];
        [arrLocs addObject:locCurr];
    }
    return arrLocs;
}





-(NSString *)getFieldFromDetails:(NSData *)responseData valName:(NSString *)fieldName
{
    
        
    //google approach
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:responseData
                          
                          options:kNilOptions
                          error:&error];
    
    //The results from Google will be an array obtained from the NSDictionary object with the key "results".
    NSDictionary* data = [json objectForKey:@"result"];
    if (!data)
        return @"Details Unavailable";
    
        NSString *name=[data objectForKey:@"name"];
    
        NSDictionary* allTypes = [data objectForKey:@"types"];
    
        NSString *amenity = [[NSString alloc] init];
        for (NSString * type in allTypes)
        {
            amenity = [amenity stringByAppendingString:type];
            amenity = [amenity stringByAppendingString:@","];
        }
    
        if ([fieldName isEqualToString:@"name"])
            return name;
        else if ([fieldName isEqualToString:@"types"])
            return amenity;
        else
            return @"";
    
    
}


- (int)checkForAlertProximityToPoints:(CLLocation * )userLocation alertList:(NSMutableString *)alertItemsNames itemsToCheck:(NSMutableArray *)alertItemsTocheck {
    
    int alertItemsCount = 0;
    
    if (alertItemsTocheck.count > 0)
    {
                
        for (wdAlertLocation * alertItem in alertItemsTocheck)
        {
                   
            //make sure its not a polygon
            if (alertItem.shapePoints.count > 2)
                continue;
            
            if ([self shouldIgnoreAlertItem:alertItem])
                continue;
            
            //only alert once for now
            
            //TODO: potential bug here when user changes det dist on the fly and we dont reset
            //items that are in the det dist but after the change they move out of it but we
            //will rely ont he next loc update to reset those items...chance is small and not worth
            //coding currently....
            if (alertItem.hasAlerted)
                continue;
            
            CLLocation * currLoc = [[CLLocation alloc] initWithCoordinate:alertItem.coordinate
                                                                 altitude:1
                                                       horizontalAccuracy:1
                                                         verticalAccuracy:-1
                                                                timestamp:[NSDate date]];
            
            CLLocationDistance meters = [currLoc distanceFromLocation:userLocation];
            //NSLog(@"%f meters", meters);
            
            
            //[self fireAlertAndNotification:@"chking curr and user to find dist"];
            if (currLoc.horizontalAccuracy <0)
                continue;
            
            if (userLocation.horizontalAccuracy <0)
                continue;
            
            //NSLog(@"%f meters %f dist", meters, (self.detectionDistanceInYards*METERS_PER_YARD));
            
            if (meters< (self.detectionDistanceInYards*METERS_PER_YARD))
            {
                [alertItemsNames appendString:@"Proximity: "];
                [alertItemsNames appendString:alertItem.title];
                [alertItemsNames appendString:@"\r\n"];
                alertItemsCount++;
                
                //we are going to alert so turn it on
                alertItem.hasAlerted = true;
            }
            else{
                //not alerted or left so turn it back off
                alertItem.hasAlerted = false;
            }
            
        }
        
                
        return alertItemsCount;
    }
    
    return 0;
}


- (void)loadAndCheckStateForLocation:(CLLocation *)newLocation
{
    
    if (![self isInternetAvailable])
    {
        NSLog(@"Inernet connection not available...skipping load and check state");
        [self fireStatusMessage:@"Internet unavailable, Current Alerts will be scanned and new Alerts will load when connection is re-established."];
        return;
    }
    
    
    
    CLGeocoder * geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error)
     {
         //NSLog(@"Checking State values");
         //just use the first placemark or ignore if none returned
         if (placemarks != nil)
         {
             CLPlacemark * placemark = [placemarks objectAtIndex:0];
             if (placemark == nil)
             {
                 NSLog(@"placemark object is null but array is not");
                 return;
             }
             
             NSLog(@"Comparing current state %@ with new value: %@", self.currentStateForLocation, placemark.administrativeArea);
             
             NSMutableString * borderAlerts = [[NSMutableString alloc] init];
             
             //first check the country
             if (self.currentCountryForLocation != nil &&
                 ![self.currentCountryForLocation isEqualToString:placemark.country])
             {
                 
                 
                 [borderAlerts  appendFormat:@"Border Alert! Be sure that %@ recognizes your permit.", placemark.country];
                 
             }
             
             
             //now check the state/province
             if (self.currentStateForLocation != nil &&
                 ![self.currentStateForLocation isEqualToString:placemark.administrativeArea])
             {
                 if (borderAlerts != nil &&
                     borderAlerts.length > 0)
                     [borderAlerts appendString:@"\r\n"];  //add a new line since country hit also
                 
                [borderAlerts  appendFormat:@"Border Alert! Be sure that %@ recognizes your permit.", placemark.administrativeArea];
                 
             }
             
             
             if (borderAlerts != nil &&
                 borderAlerts.length > 0)
             {
                 wdAlertsEventParameters* params = [[wdAlertsEventParameters alloc] initWithCountAndMessage:1 message:borderAlerts];
                 [self fireAlertAndNotification:params];
             }
             self.currentStateForLocation = placemark.administrativeArea;
             self.currentCountryForLocation = placemark.country;
             _lastStateAndCountryCheckTime = [NSDate date];
         }
         
         
     }
     ];
}



- (int) checkAllPolys:(CLLocation *)newLocation alertList:(NSMutableString *)alertItemsNames
{
    
    
    
    int alertItemsCount = 0;
    
    
    

    if (self.currentAlertItemRows == nil)
        return 0;
        
    for (wdAlertLocation * alertItem in self.currentAlertItemRows) {
        
                
        //make sure its a valid polygon, which requires 3 points....
        if (alertItem.shapePoints.count < 3)
            continue;
        
        if ([self shouldIgnoreAlertItem:alertItem])
            continue;
        
        //only alert once for now
        if (alertItem.hasAlerted)
            continue;
                
        float vertexXCoords[alertItem.shapePoints.count];
        float vertexYCoords[alertItem.shapePoints.count];

        //first we need to build the array for the params...
        int i=0;
        for (CLLocation * currLoc in alertItem.shapePoints)
        {
            vertexXCoords[i] = currLoc.coordinate.latitude;
            vertexYCoords[i] = currLoc.coordinate.longitude;
            i++;
        }
        
        //NSLog(@"Testing Point In Poly %@", alertItem.title);

        
        BOOL testPointIsInPoly = pnpoly(alertItem.shapePoints.count, vertexXCoords, vertexYCoords, newLocation.coordinate.latitude, newLocation.coordinate.longitude);
        //[self isPointInPoly:numberOfPoints vertx:vertexXCoords verty:vertexYCoords testx:newLocation.coordinate.latitude testy:newLocation.coordinate.longitude];
        
        //NSLog(@"poly check for location %u", testPointIsInPoly);
        
        if (testPointIsInPoly)
        {
            [alertItemsNames appendString:@"Boundary: "];
            [alertItemsNames appendString:alertItem.title];
            [alertItemsNames appendString:@"\r\n"];
            alertItemsCount++;
            //we are going to alert so turn it on
            alertItem.hasAlerted = true;
        }
        else{
            //not alerted or left so turn it back off
            alertItem.hasAlerted = false;
        }
        
        
        
    }
    
    
    
    return alertItemsCount;
}


-(void)fireStatusMessage:(NSString *)msg
{
    
    if([self.delegate respondsToSelector:@selector(didStatusMessage:)])
    {
        //send the delegate function with the amount entered by the user
        [self.delegate didStatusMessage:msg];
    }
}



-(void)fireErrorMessage:(NSString *)msg
{
    
    if([self.delegate respondsToSelector:@selector(didErrorMessage:)])
    {
        //send the delegate function with the amount entered by the user
        [self.delegate didErrorMessage:msg];
    }
}



-(void)fireAlertAndNotification:(wdAlertsEventParameters*)params
{
    
    if([self.delegate respondsToSelector:@selector(didAlert:)])
    {
        //send the delegate function with the amount entered by the user
        [self.delegate didAlert:params];
    }
    
    
    
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif == nil)
        return;
    localNotif.fireDate = nil;
    //localNotif.timeZone = [NSTimeZone defaultTimeZone];
    
	// Notification details
    localNotif.alertBody = params.alertItemsMessage;
	// Set the action button
    localNotif.alertAction = @"View";
    
    localNotif.soundName = UILocalNotificationDefaultSoundName;
    localNotif.applicationIconBadgeNumber = [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
    
    
	// Specify custom data for the notification
    //NSDictionary *infoDict = [NSDictionary dictionaryWithObject:@"someValue" forKey:@"someKey"];
    //localNotif.userInfo = infoDict;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
    
    
}




- (NSArray *) buildPolylineArrayForCheck:(NSArray *)allLocations
{
    NSInteger pointsCount = [allLocations count];
    
    int pos=0;
    CLLocationCoordinate2D arrLocs[pointsCount];
    for (CLLocation * curr in allLocations)
    {
        
        CLLocationCoordinate2D locCurr;
        locCurr.latitude = curr.coordinate.latitude;
        locCurr.longitude = curr.coordinate.longitude;
        arrLocs[pos] = locCurr;
        pos++;
    }
    return nil;
}

- (NSMutableArray *)buildCLLocationArrayFromLatLngArray:(NSArray *)latlng {
    
    NSInteger pointsCount = [latlng count];
    int i;
    NSMutableArray* arrLocs = [[NSMutableArray alloc] init];
    for (i = 0; i < pointsCount; i=i+2)
    {
        NSNumber * nlt = [NSNumber numberWithFloat:[latlng[i] floatValue]];
        NSNumber * nlg = [NSNumber numberWithFloat:[latlng[i+1] floatValue]];
        CLLocation *locCurr = [[CLLocation alloc] initWithLatitude:nlt.doubleValue longitude:nlg.doubleValue];
        [arrLocs addObject:locCurr];
    }
    return arrLocs;
}



/*
 int nCoords = 4;
 float vertexXCoords[n] = {0.0, 0.0, 20.0, 20.0};
 float vertexYCoords[n] = {0.0, 20.0, 20.0, 0.0};
 NSPoint testPoint = NSMakePoint(5, 10);
 */
- (int) isPointInPoly:(int)numOfVertices vertx:(float*)vertx verty:(float*)verty testx:(float)testx testy:(float)testy
{
        
        int i, j, c = 0;
        for (i = 0, j = numOfVertices-1; i < numOfVertices; j = i++) {
            if ( ((verty[i]>testy) != (verty[j]>testy)) &&
                (testx < (vertx[j]-vertx[i]) * (testy-verty[i]) / (verty[j]-verty[i]) + vertx[i]) )
                c = !c;
        }
        return c;
}


int pnpoly(int nvert, float *vertx, float *verty, float testx, float testy)
{
    int i, j, c = 0;
    for (i = 0, j = nvert-1; i < nvert; j = i++) {
        //NSLog(@"pnpoly %f > %f  != %f > %f", verty[i], testy, verty[j], testy);
        
        if ( ((verty[i]>testy) != (verty[j]>testy)) &&
            (testx < (vertx[j]-vertx[i]) * (testy-verty[i]) / (verty[j]-verty[i]) + vertx[i]) )
            c = !c;
    }
    return c;
}


-(void)dealloc
{
    NSLog(@"dealloc called");
    
    //TODO: is this what kills the list in memory?

    self.currentAlertItemRows = nil;
    self.currentCustomAlertItemRows = nil;
    self.currentIgnoreAlertItemRows = nil;
    self.delegate = nil;
    self.locationManager = nil;
    self.locationForLastManualMove  = nil;
    self.currentStateForLocation = nil;
    self.currentCountryForLocation = nil;
    self.isUserFollowMode = nil;
    self.activeRequests = nil;
}


@end



