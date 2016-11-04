//
//  wdViewController.m
//  Alerts
//
//  Created by Benjamin Harrell on 11/20/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdViewController.h"
#import "wdAlertLocation.h"
#import "ASIHTTPRequest.h"
#import "wdBoundingCircle.h"
#import "JSONKit.h"
#import "wdAlertDetailsViewController.h"

// Add at the top of the file
//#import "MBProgressHUD.h"

static NSMutableDictionary* arrPolys;
static NSMutableDictionary* arrPoints;
static NSMutableDictionary* arrPolyCenters;
static NSMutableDictionary* snoozeItems;




#define METERS_PER_MILE 1609.344f
#define METERS_PER_YARD .914f

@interface wdViewController ()

@end

@implementation wdViewController

@synthesize radiusInMiles;

- (NSInteger) radiusInMiles
{
    //get the user pref for radius
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"map_size_miles_preference"];
    if (val == 0)
        return 10;
    else
        return val;
}

@synthesize snoozeLengthInMinutes;

- (NSInteger) snoozeLengthInMinutes
{
    //get the user pref
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"snooze_time_mins_preference"];
    if (val == 0)
        return 10;
    else
        return val;
}


@synthesize detectionDistanceInYards;

- (NSInteger) detectionDistanceInYards
{
    //get the user pref
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"detection_distance_yds_preference"];
    if (val == 0)
        return 10;
    else
        return val;
}


@synthesize batteryMgmtMode;

- (NSString*) batteryMgmtMode
{
    //get the user pref
    NSString * val = [[NSUserDefaults standardUserDefaults] stringForKey:@"battery_mgmt_preference"];
    if (val == nil)
        return @"kCLLocationAccuracyNearestTenMeters";
    else
        return val;
}



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    arrPolys = [[NSMutableDictionary alloc] init];
    arrPoints = [[NSMutableDictionary alloc] init];
    arrPolyCenters = [[NSMutableDictionary alloc] init];
    snoozeItems = [[NSMutableDictionary alloc] init];    
   
    
    [self moveMapToLastKnownLocationOrDefault];
    [self startUserFollowMode:nil];
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
        
        
    // Add right after [request startAsynchronous] in refreshTapped action method
    //MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    //hud.labelText = @"Loading alerts...";
    
    // Add at start of setCompletionBlock and setFailedBlock blocks
    //[MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    
    //currentLocation = userLocation.location;
    
    CLLocationCoordinate2D coord = {.latitude= newLocation.coordinate.latitude, .longitude =  newLocation.coordinate.longitude};
    // 2
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(coord, self.radiusInMiles*METERS_PER_MILE, self.radiusInMiles*METERS_PER_MILE);
    
    
    // 3
    [self.mapView setRegion:viewRegion animated:YES];
    
    
    [self processNewLocation:newLocation];
    
}





-(void) moveMapToLastKnownLocationOrDefault
{
    
    //start in powell or get default
    CLLocationCoordinate2D coord = {.latitude= 36.042159, .longitude =  -83.993568};
    // 2
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(coord, self.radiusInMiles*METERS_PER_MILE, self.radiusInMiles*METERS_PER_MILE);
    
    
    // 3
    [self.mapView setRegion:viewRegion animated:YES];
}

- (void)zoomToUserLocation:(MKUserLocation *)userLocation
{
    if (!userLocation)
        return;
    
    MKCoordinateRegion region;
    region.center = userLocation.location.coordinate;
    region.span = MKCoordinateSpanMake(2.0, 2.0);
    region = [self.mapView regionThatFits:region];
    [self.mapView setRegion:region animated:YES];
}




- (void)processNewLocation:(CLLocation *)newLocation
{   
    
    //first thing check to see if they are near an Alert
    [self checkForAlertProximityToPoints:newLocation];
    
    [self loadAlertTargets:newLocation radius:self.radiusInMiles];
    
}



- (void)loadAlertTargets:(CLLocation *)newLocation radius:(NSInteger)searchRadiusInMiles
{
    //iterate the preferences and if a category is YES then add to the array
    NSMutableString* searchCategories = [[NSMutableString alloc] init];
    for(NSString * currKey in [NSUserDefaults standardUserDefaults].dictionaryRepresentation.allKeys)
    {
        if ( [currKey hasPrefix:@"category_"])
        {
            //parse the category value
            NSString * catValue = [currKey substringFromIndex:9];
            
            
            [searchCategories appendString:catValue];
        }
    }

    NSString * urlBase = [NSString stringWithFormat:@"http://www.mapquestapi.com/search/v1/search?key=%@&callback=renderAdvancedRadiusResults&shapePoints=%f,%f&mapData=navt,%@&radius=%d", @"Fmjtd%7Cluuan90an0%2C2g%3Do5-96r5u0", newLocation.coordinate.latitude, newLocation.coordinate.longitude, searchCategories, searchRadiusInMiles];
    
    
    // 3
    NSURL *url = [NSURL URLWithString:urlBase];
    
    // 4
    ASIHTTPRequest *_request = [ASIHTTPRequest requestWithURL:url];
    __weak ASIHTTPRequest *request = _request;
    
    request.requestMethod = @"GET";
    //[request addRequestHeader:@"Content-Type" value:@"application/json"];
    //[request appendPostData:[json dataUsingEncoding:NSUTF8StringEncoding]];
    // 5
    [request setDelegate:self];
    [request setCompletionBlock:^{
        //NSString *responseString = [request responseString];
        [self plotAlertPositions:request.rawResponseData];
        //NSLog(@"Response: %@", responseString);
    }];
    [request setFailedBlock:^{
        NSError *error = [request error];
        NSLog(@"Error: %@", error.localizedDescription);
    }];
    
    // 6
    [request startAsynchronous];
    
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



- (CLLocation *)calcPolyCenter:(NSArray*)polyPointsArrayofLocations
{
    double minLat;double maxLat;
    double minLon;double maxLon;
    
    for(CLLocation * currLoc in polyPointsArrayofLocations)
    {
        CLLocationCoordinate2D curr = currLoc.coordinate;
        //now calc the center point
        if(curr.latitude > maxLat)
            maxLat = curr.latitude;
        if(curr.latitude < minLat)
            minLat = curr.latitude;
        if(curr.longitude > maxLon)
            maxLon = curr.longitude;
        if(curr.longitude < minLon)
            minLon = curr.longitude;
     
    }
    
    CLLocationCoordinate2D centerPoint;
    centerPoint.latitude = ((maxLat + 90) - (minLat + 90)/2 );
    centerPoint.longitude = ((maxLon + 180) - (minLon + 180)/2 );
    
    CLLocation *centerLoc = [[CLLocation alloc] initWithLatitude:centerPoint.latitude longitude:centerPoint.longitude];
    return centerLoc;
    
    //get the radius
    //wdBoundingCircle * bc = [[wdBoundingCircle alloc] initWithPoints:arrLocs];
    //coordinate.latitude = bc.XCoordinate;
    //coordinate.longitude = bc.YCoordinate;
    /*CLRegion *currRegion = [[CLRegion alloc]
     initCircularRegionWithCenter:coordinate
     radius:150
     identifier:name];*/

}

// Add new method above refreshTapped
- (void)plotAlertPositions:(NSData *)responseData {
    for (id<MKAnnotation> annotation in _mapView.annotations) {
        [self.mapView removeAnnotation:annotation];
    }

    NSString* rawJSON = [[NSString alloc] initWithData:responseData
                                              encoding:NSUTF8StringEncoding];
    
    
    //NSLog(@"RAW RESPONSE::::%@", rawJSON);
    rawJSON = [rawJSON substringFromIndex:28];
    rawJSON = [rawJSON substringToIndex:[rawJSON length] - 2];
    //NSLog(@"SUBSTRING:::::%@", rawJSON);
    NSDictionary *unserializedData = [rawJSON objectFromJSONString];
    
    NSArray *data = [unserializedData objectForKey: @"searchResults"];
    
    
    for (NSDictionary *row in data) {
        
        NSString *name = row[@"name"];
        NSArray * latlng = row[@"shapePoints"];
        NSInteger arrCount = ([latlng count]/2);
        NSInteger pointsCount = [latlng count];
        
        if (pointsCount < 2)//not enough points bad point
        {
            NSLog(@"Skipping %@ - Not enough points, %d", name, arrCount);
            continue;
        }
        
        
        if (pointsCount % 2 == 1)
        {
            NSLog(@"Skipping %@ - Odd number of points %d", name, arrCount);
            continue;
        }
        
        //NSArray * latlng1 = latlng[0];
        NSString *latitude = latlng[0];
        NSString *longitude = latlng[1];
        NSNumber * nlat = [NSNumber numberWithFloat:[latitude floatValue]];
        NSNumber * nlong = [NSNumber numberWithFloat:[longitude floatValue]];
        //NSString *address = row[@"shapePoints"];
        
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = nlat.doubleValue;
        coordinate.longitude = nlong.doubleValue;
        
        NSArray * arrLocs= [self buildLocationArray:latlng];
        
        
        
        if (arrCount > 2)
        {
            // Add an overlay
            

            MKPolyline *polyLine = [self buildPolyline:arrLocs];
            
            [self.mapView addOverlay:polyLine];
            
            [arrPolys setObject:row forKey:name];
            //[arrPolyCenters setObject:centerPoint forKey:name];
            
            //NSLog(@"Drawing Poly for %@", name);
            wdAlertLocation *annotation = [[wdAlertLocation alloc] initWithName:name coordinate:coordinate] ;
            [self.mapView addAnnotation:annotation];
        }
        else
        {
            //render as circle for now
            if ( [arrPolys objectForKey:name] == nil)
            {
                // Add an overlay
                //MKCircle *circle = [MKCircle circleWithCenterCoordinate:coordinate radius:100];//(bc.Radius*111000)];
                //[_mapView addOverlay:circle];
            
                [arrPoints setObject:row forKey:name];
                //NSLog(@"Drawing Circ for %@", name);
                wdAlertLocation *annotation = [[wdAlertLocation alloc] initWithName:name coordinate:coordinate] ;
                [self.mapView addAnnotation:annotation];
            }
        }
	}
}

- (MKPolyline *) buildPolyline:(NSArray *)allLocations
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
    
    MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:arrLocs count:pointsCount];
    return polyLine;
}

- (void)showAlert:(wdAlertLocation *)anno
{
    
    NSString * msg = [NSString stringWithFormat:@"%@ \r\n id: %d",anno.title, anno.hash];
    


    //fire an alert!
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Gun Alert!"
                                                      message:msg
                                                     delegate:anno
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:@"Snooze", @"Details", nil];
    
    [message show];
}


- (void)checkForAlertProximityToPoints:(CLLocation * )userLocation
{
    
    NSSet * nearbySet = [self.mapView annotationsInMapRect:self.mapView.visibleMapRect];
    if (nearbySet == nil)
        return;
    
    
    if (nearbySet.count > 0)
    {
        for (wdAlertLocation *annotation in [nearbySet allObjects])
        {
            CLLocation * currLoc = [[CLLocation alloc] initWithCoordinate:annotation.coordinate
                                                                                          altitude:1
                                                                                horizontalAccuracy:1 
                                                                                  verticalAccuracy:-1
                                                                                         timestamp:[NSDate date]];
            
            CLLocationDistance meters = [currLoc distanceFromLocation:userLocation];
            if (currLoc.horizontalAccuracy <0)
                continue;
            
            if (userLocation.horizontalAccuracy <0)
                continue;
            
            if (meters< (detectionDistanceInYards*METERS_PER_YARD))
            {
                NSString * msg = [NSString stringWithFormat:@"%@ \r\n id: %d",annotation.title, annotation.hash];
                
                
                NSDate * snzValue = [snoozeItems objectForKey:msg];
                //check if its a sn
                if ( snzValue != nil)
                {
                   //check if still inside snooze time...
                    NSDate * snzDiff =  [NSDate dateWithTimeIntervalSinceNow:(snoozeLengthInMinutes*60)];
                    if (snzValue < snzDiff)  //then snooze value for ex is 5 mins and its been 7mins so alert it
                    {
                        //snooze lapsed so remove the object and set the alert!
                        [snoozeItems removeObjectForKey:msg];
                        [self showAlert:annotation];
                    }
                    else{
                       //snooze still valid so skip it
                        continue;
                    }
                }
                else{

                    [self showAlert:annotation];
                }
            }
        
        }
        //NSLog(@"found some");
        return;
    }
}


- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender
{
	//[self dismissModalViewControllerAnimated:YES];
	[self reconfigure];
}

-(void)reconfigure
{
    
}

-(void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:    (NSInteger)buttonIndex
{
    if(buttonIndex==0)
    {
        //Code that will run after you press ok button
        
    }
    else if(buttonIndex==1)  //snooze
    {
        //add to snooze list ,store the anno object?, store the id?
        
        [snoozeItems setObject:[NSDate date] forKey:alertView.message];
        
    }
    else if(buttonIndex==2) //details
    {
        //launch details screen
        //do the segue to the details
        //get the annotation from the ID hash?
        
        wdAlertLocation *selectedLoc = (wdAlertLocation *)alertView.delegate;
        //now go to the details screen
        [self performSegueWithIdentifier:@"AlertDetails" sender:selectedLoc];
    }
}


- (MKOverlayView *)mapView:(MKMapView *)map viewForOverlay:(id <MKOverlay>)overlay {
   
    
    //NSLog(@"circling");
    
    if ([overlay isKindOfClass:[MKCircle class]])
        
    {
        MKCircleView *circleView = [[MKCircleView alloc] initWithCircle:overlay];
        circleView.lineWidth = .5;
        circleView.strokeColor = [UIColor redColor];
        
        return circleView;
    }
    if ([overlay isKindOfClass:[MKPolyline class]])
        
    {
        MKPolylineView *pView = [[MKPolylineView alloc] initWithOverlay:overlay];
        pView.LineWidth = .5;
        pView.StrokeColor = [UIColor redColor];
        return pView;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    wdAlertLocation *selectedLoc = (wdAlertLocation *)view.annotation;
    //now go to the details screen
    [self performSegueWithIdentifier:@"AlertDetails" sender:selectedLoc];
}
                                       

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    static NSString *identifier = @"wdAlertLocation";
    if ([annotation isKindOfClass:[wdAlertLocation class]]) {
        
        MKAnnotationView *annotationView = (MKAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        if (annotationView == nil) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            annotationView.enabled = YES;
            annotationView.canShowCallout = YES;            annotationView.image = [UIImage imageNamed:@"noguns.png"];//here we use a nice image instead of the default pins
        } else {
            annotationView.annotation = annotation;
        }
        
        return annotationView;
    }
    
    return nil;
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView{
    //map moved so as it loads we also need to show the items...
    
    //load all the alerts for this map rect
    
    CLLocationCoordinate2D bottomLeftCoord =
    [mapView convertPoint:CGPointMake(0, mapView.frame.size.height)
       toCoordinateFromView:mapView];
    
    CLLocationCoordinate2D topRightCoord =
    [mapView convertPoint:CGPointMake(mapView.frame.size.width, 0)
       toCoordinateFromView:mapView];
    
    
    CLLocation * bottomLeftLocation = [[CLLocation alloc]
                                       initWithLatitude:bottomLeftCoord.latitude
                                       longitude:bottomLeftCoord.longitude];
    CLLocation * bottomRightLocation = [[CLLocation alloc]
                                   initWithLatitude:bottomLeftCoord.latitude
                                   longitude:topRightCoord.longitude];
    
    CLLocationDistance distanceInMeters = [bottomLeftLocation distanceFromLocation:bottomRightLocation];
    
    float distanceInMiles = distanceInMeters / METERS_PER_MILE ;
    
    CLLocation * mapCenterLoc = [[CLLocation alloc]
                                       initWithLatitude:mapView.centerCoordinate.latitude
                                       longitude:mapView.centerCoordinate.longitude];
    
    [self loadAlertTargets:mapCenterLoc radius:distanceInMiles];
}


-(bool)pointInsideOverlay:(CLLocationCoordinate2D )checkPoint overPoly:(id <MKOverlay>)polygonOverlay {
    bool isInside = FALSE;
    
    MKPolygonView *polygonView = (MKPolygonView *)[_mapView viewForOverlay:polygonOverlay];
    
    MKMapPoint mapPoint = MKMapPointForCoordinate(checkPoint);
    
    CGPoint polygonViewPoint = [polygonView pointForMapPoint:mapPoint];
    
    BOOL mapCoordinateIsInPolygon = CGPathContainsPoint(polygonView.path, NULL, polygonViewPoint, NO);
    
    if ( !mapCoordinateIsInPolygon )
        
        //we are finding points that are inside the overlay
    {
        isInside = TRUE;
        
    }
    return isInside;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AlertDetails"]) {
        
        wdAlertDetailsViewController *destViewController = segue.destinationViewController;
        destViewController.alertObject = sender;
    }
}



- (IBAction)startUserFollowMode:(id)sender {
    
    
    //TODO: need to set the size of the view rect so the zoom in wont happen????    
    self.mapView.zoomEnabled = false;
    self.mapView.scrollEnabled = false;
    self.mapView.userInteractionEnabled = false;
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    self.mapView.showsUserLocation = false;
    
    //get from user pref
    locationManager.distanceFilter = kCLDistanceFilterNone; // whenever we move
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters; // 10 m user should be able to change
    [locationManager startUpdatingLocation];
    //TODO:  this is where the user can say no and ruin it all :)

    
    
    //self.mapView.accur
    
}

- (IBAction)manualMap:(id)sender {
    
    [locationManager stopUpdatingLocation];
    self.mapView.delegate = self;
    self.mapView.zoomEnabled = true;
    self.mapView.scrollEnabled = true;
    self.mapView.userInteractionEnabled = true;
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
    self.mapView.showsUserLocation = false;
    [self.mapView setUserTrackingMode:MKUserTrackingModeNone animated:false];
}


- (void)viewWillAppear:(BOOL)animated {
    // 1
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc
{
    //[arrPolys release];
    //[arrPoints release];
}



@end
