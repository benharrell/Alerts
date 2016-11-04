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

// Add at the top of the file
//#import "MBProgressHUD.h"

static NSMutableDictionary* arrPolys;
static NSMutableDictionary* arrPoints;
static NSMutableDictionary* arrPolyCenters;




#define METERS_PER_MILE 1609.344

@interface wdViewController ()

@end

@implementation wdViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    arrPolys = [[NSMutableDictionary alloc] init];
    arrPoints = [[NSMutableDictionary alloc] init];
    arrPolyCenters = [[NSMutableDictionary alloc] init];
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = kCLDistanceFilterNone; // whenever we move
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters; // 10 m user should be able to change
    [locationManager startUpdatingLocation];
    //TODO:  this is where the user can say no and ruin it all :)
    
    
    // Add right after [request startAsynchronous] in refreshTapped action method
    //MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    //hud.labelText = @"Loading alerts...";
    
    // Add at start of setCompletionBlock and setFailedBlock blocks
    //[MBProgressHUD hideHUDForView:self.view animated:YES];
    
    //start in powell
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:36.042159 longitude:-83.993568];
    
    [self changeUserLocation:loc];
    
    




}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    [self changeUserLocation:newLocation];
    
}

- (void)loadAlertTargets:(CLLocation *)newLocation
{
    /*if user has gone past bounds
     http://www.mapquestapi.com/search/v1/search?key=Fmjtd%7Cluuan90an0%2C2g%3Do5-96r5u0&callback=renderAdvancedRadiusResults&shapePoints=36.042159,-83.993568&mapData=navt,1049,0548,0549,0550,1047,1048,1049,1050,1055,1061,1064,1547,1548,1549,1550,1587,1588,1589,1590,1733,1734,1752,1753,1763,1764,1707,1708,1709,1711&radius=3*/
    
    
    NSString * urlBase = [NSString stringWithFormat:@"http://www.mapquestapi.com/search/v1/search?key=%@&callback=renderAdvancedRadiusResults&shapePoints=%f,%f&mapData=navt,1049,1047,1048,1049,1050,1055,1061,1064,1547,1548,1549,1550,1587,1588,1589,1590,1606,1607,1608,1609,1610,1611,1727,1728,1729,1731,1732,1733,1734,1752,1753,1756,1757,1758,1763,1764,1765,1707,1708,1709,1711&radius=10", @"Fmjtd%7Cluuan90an0%2C2g%3Do5-96r5u0", newLocation.coordinate.latitude, newLocation.coordinate.longitude];
    
    
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
        [_mapView removeAnnotation:annotation];
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
            
            [_mapView addOverlay:polyLine];
            
            [arrPolys setObject:row forKey:name];
            //[arrPolyCenters setObject:centerPoint forKey:name];
            
            //NSLog(@"Drawing Poly for %@", name);
            wdAlertLocation *annotation = [[wdAlertLocation alloc] initWithName:name coordinate:coordinate] ;
            [_mapView addAnnotation:annotation];
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
                [_mapView addAnnotation:annotation];
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

- (void)changeUserLocation:(CLLocation *)newLocation
{
    CLLocationCoordinate2D zoomLocation;
    zoomLocation.latitude = newLocation.coordinate.latitude;
    zoomLocation.longitude= newLocation.coordinate.longitude;
    
    //first thing check to see if they are near an Alert
    [self checkForAlertProximityToPoints:newLocation];
    
    
    // 2
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(zoomLocation, .5*METERS_PER_MILE, .5*METERS_PER_MILE);
    
    // 3
    [_mapView setRegion:viewRegion animated:YES];
    
    [self loadAlertTargets:newLocation];
    
}


- (void)checkForAlertProximityToPoints:(CLLocation * )userLocation
{
    
    NSSet * nearbySet = [self.mapView annotationsInMapRect:self.mapView.visibleMapRect];
    
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
            
            if (meters< (50))
            {
                //fire an alert!
                UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Gun Alert!"
                                                              message:[NSString stringWithFormat:@"%@",annotation.title]
                                                             delegate:nil
                                                    cancelButtonTitle:@"OK"
                                                    otherButtonTitles:@"Snooze", @"Details", nil];
                [message show];
            }
        
        }
        //NSLog(@"found some");
        return;
    }
}


- (void) oldAlerts:(CLLocation * )userLocation
{
    //iterate all of the points to see if we have a hit
    
    for(NSDictionary* currPoint in [arrPoints allValues])
    {
        NSString *name = currPoint[@"name"];
        NSArray * latlng = currPoint[@"shapePoints"];
        //NSArray * latlng1 = latlng[0];
        NSString * latitude = latlng[0];
        NSString * longitude = latlng[1];
        NSNumber * nlat = [NSNumber numberWithFloat:[latitude floatValue]];
        NSNumber * nlong = [NSNumber numberWithFloat:[longitude floatValue]];
        //NSString *address = row[@"shapePoints"];
        
        
        CLLocation * currLoc = [[CLLocation alloc] initWithLatitude:nlat.doubleValue longitude:nlong.doubleValue];
        
                
        CLLocationDistance meters = [currLoc distanceFromLocation:userLocation];
        NSLog(@"Point Alert Distance: %f", meters);
        if (meters< (50))
        {
            //fire an alert!
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Gun Alert Point!"
                                                              message:[NSString stringWithFormat:@"%@",name]
                                                             delegate:nil
                                                    cancelButtonTitle:@"OK"
                                                        otherButtonTitles:nil];
            [message show];

        }
    }
    
    for(NSDictionary* currPoly in [arrPolys allValues])
    {
        NSString *name = currPoly[@"name"];
        NSArray * latlng = currPoly[@"shapePoints"];
        NSArray * arrLocs= [self buildLocationArray:latlng];
                
        CLLocation * centerLoc = [self calcPolyCenter:arrLocs];
        
        CLLocationDistance meters = [centerLoc distanceFromLocation:userLocation];
        NSLog(@"Poly Alert Distance: %f", meters);
        if (meters< (50))
        {
            //fire an alert!
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Gun Alert Poly!"
                                                              message:[NSString stringWithFormat:@"%@",name]
                                                             delegate:nil
                                                    cancelButtonTitle:@"OK"
                                                    otherButtonTitles:nil];
            [message show];            
        }
    }
    
    
}


- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender
{
	[self dismissModalViewControllerAnimated:YES];
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
        //add to snooze list
        
    }
    else if(buttonIndex==2) //details
    {
        //launch details screen
        [self showDetails];
        
    }
}

- (void) showDetails
{
    
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
