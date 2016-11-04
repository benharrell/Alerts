//
//  wdViewController.m
//  Alerts
//
//  Created by Benjamin Harrell on 11/20/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdViewController.h"
#import "wdAlertLocation.h"
#import "wdAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "wdBoundingCircle.h"
#import "wdAlertDetailsViewController.h"


#import "YRDropdownView.h"

// Add at the top of the file
//#import "MBProgressHUD.h"
#define METERS_PER_MILE 1609.344f
#define METERS_PER_YARD .914f
#define MIN_LOAD_RADIUS_IN_MILES 0.5f
#define MAX_LOAD_RADIUS_IN_MILES 10.0f
#define DEFAULT_MAP_SIZE_IN_MILES 5


//static NSMutableDictionary* arrPolys;
//static NSMutableDictionary* arrPoints;
//static NSMutableDictionary* arrPolyCenters;


@interface wdViewController ()

@end

@implementation wdViewController


@synthesize HUD;
@synthesize appDelegate;



- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    _initialMapSizeWasSet = false;
    self.appDelegate = (wdAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }
    
    self.appDelegate.alertsManager.delegate = self;
    
    //setup the init stuff
    //arrPolys = [[NSMutableDictionary alloc] init];
    //arrPoints = [[NSMutableDictionary alloc] init];
    //arrPolyCenters = [[NSMutableDictionary alloc] init];
    
    UIPanGestureRecognizer* panRec = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didDragMap:)];
    [panRec setDelegate:self];
    [self.mapView addGestureRecognizer:panRec];
    
    
    UIPinchGestureRecognizer* pinchRec = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(didPinchMap:)];
    [pinchRec setDelegate:self];
    [self.mapView addGestureRecognizer:pinchRec];
    
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressGesture:)];
    [self.mapView addGestureRecognizer:longPressGesture];
 
    
    
    self.mapView.zoomEnabled = true;
    self.mapView.scrollEnabled = true;
    self.mapView.userInteractionEnabled = true;
    //self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    self.mapView.showsUserLocation = true;
    
    
    [self centerMap:nil]; //call this just in case to trigger follow mode
    //display the custom alerts
    [self plotCustomAlertPositions];
    [self sizeMapToDefault];
    
    
    
    
    
                         
    
}

- (void) viewDidAppear:(BOOL)animated
{
    //how do we know if this is first launch, check user pref?
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"hasSeenTutorial"])
        [self displayTutorial];
}

- (void) displayTutorial
{
    //push the tutorial onto the stack modal so user has to view it....
    [self performSegueWithIdentifier: @"showTutorial" sender: self];
}



- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}


-(void) didStartProcessingAlerts:(NSString*)msg
{
    self.HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES  ];
    self.HUD.labelText = @"Scanning Area for Alerts";
    self.HUD.detailsLabelText = msg;
    
            
}

-(void) didEndProcessingAlerts
{
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}


-(void)didResetAlertItems
{
    //NSLog(@"wiping old annotations");
    //wipe all of the alert items except the user pin
    
    NSMutableArray *locs = [[NSMutableArray alloc] init];
    for (id <MKAnnotation> annot in [self.mapView annotations])
    {
        if ( [annot isKindOfClass:[ MKUserLocation class]] ) {
        }
        else {
            [locs addObject:annot];
        }
    }
    [self.mapView removeAnnotations:locs];
    
    
    //wipe the polylines as well
    [self.mapView removeOverlays:self.mapView.overlays];

}

-(void)didUpdateAlertItems:(NSString*)msg
{
    //NSLog(@"didUpdateAlertItems in the UI thread? %d", [NSThread isMainThread]);
    //NSLog(@"did update, got new items to plot");
    
    if (self.HUD && msg.length>0)
    {
        self.HUD.detailsLabelText = msg;
    }
        
    [self plotAlertPositions];
    
    //NSLog(@"did update, calling set region just in case");
    
    //[self.mapView setRegion:self.mapView.region animated:TRUE];
}

-(void)didUpdateCustomAlertItems:(NSString*)msg
{
    //NSLog(@"didUpdateAlertItems in the UI thread? %d", [NSThread isMainThread]);
    //NSLog(@"did update, got new items to plot");
    
    if (self.HUD && msg.length>0)
    {
        self.HUD.detailsLabelText = msg;
    }
    
    [self plotCustomAlertPositions];
    
    //NSLog(@"did update, calling set region just in case");
    
    //[self.mapView setRegion:self.mapView.region animated:TRUE];
}



-(void)didUpdateLocation
{
  
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }
    
    //NSLog(@"didUpdateLocation in the UI thread? %d", [NSThread isMainThread]);
    if (!self.appDelegate.alertsManager.isUserFollowMode)
        return;
    
    [self moveMapToUser];
    
    //if the map never got sized then we need to size to default
    //this can happen on first launch because of no stored preference
    if (! _initialMapSizeWasSet)
        [self sizeMapToDefault];
}


-(void) didAlert:(wdAlertsEventParameters*)params
{
    [self showAlert:params.alertItemsMessage numberOfItems:params.alertItemsCount];
    
}

-(void) didStatusMessage:(NSString*)msg
{
    [self showStatusMessage:msg];
}

-(void) didErrorMessage:(NSString*)msg
{
    [self showErrorMessage:msg];

}


- (void)didDragMap:(UIGestureRecognizer*)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded){
        
         if (self.appDelegate.alertsManager.isUserFollowMode)
         {
        
             [self.appDelegate.alertsManager endUserFollowMode];
        
             [self showStatusMessage:@"'Follow Mode' disabled use the 'Reload' button to see items in the new area or click the 'Arrow' button to resume following your current location."];
         }
        
        CLLocation * mapCenterLoc = [[CLLocation alloc]
                                     initWithLatitude:self.mapView.centerCoordinate.latitude
                                     longitude:self.mapView.centerCoordinate.longitude];
        
        
        //not follow mode so get the manually loaded items....
        [self.appDelegate.alertsManager setLocationAndRadiusManually:mapCenterLoc];
    }
}

- (void)didPinchMap:(UIGestureRecognizer*)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded){
        
        if (self.appDelegate.alertsManager == nil)
        {
            [self showErrorMessage:@"Alerts Manager not available"];
            return;
        }
        
        [self.appDelegate.alertsManager setLastMapSizePreferenceValue:[self getRadiusInMilesFromMapView]];
        
        //tell the user about default map size
         [self showStatusMessage:@"Current map size has been saved as default."];
        
    }
}

-(void)didLongPressGesture:(UIGestureRecognizer*)sender {
    // This is important if you only want to receive one tap and hold event
    if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateChanged)
        return;
    // Otherwise continue with add pin method
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        [self.mapView removeGestureRecognizer:sender];
    }
    else
    {
        // Here we get the CGPoint for the touch and convert it to latitude and longitude coordinates to display on the map
        CGPoint point = [sender locationInView:self.mapView];
        CLLocationCoordinate2D locCoord = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
        // Then all you have to do is create the annotation and add it to the map
        //NSArray *
        //NSArray * arrLocs= [self.appDelegate.alertsManager buildLocationArray:latlng];
        wdAlertLocation *dropPin = [[wdAlertLocation alloc] initWithAll:@"custom" coordinate:locCoord type:@"Proximity Check" ref:@"user" points:nil isCust:true] ;
        
        
        //add it to the list which will trigger the render event....
        [self.appDelegate.alertsManager addCustomAlertItem:dropPin];

        
        
    }
}


- (IBAction)displayAlertEditor:(id)sender {
    NSLog(@"edit alert called");
    
    int calloutButtonPressed = ((UIButton *)sender).tag;
    if(calloutButtonPressed < 99999)
    {
        
        UIStoryboard*  sb = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone"
                                                      bundle:nil];
        UIViewController* vc = [sb instantiateViewControllerWithIdentifier:@"wdAlertDetailsViewController"];
        
        //if(self.detailView == nil)
        //{
            //wdTutorialViewController *tmpViewController = [[wdTutorialViewController alloc] initWithNibName:@"DetailViewController" bundle:nil];
            //self.detailView = tmpViewController;
            //[tmpViewController release];
        //}
        
                
        [self.navigationController pushViewController:vc animated:YES];
        
        if (calloutButtonPressed == 0)
        {
            // TRP - I inserted my view atIndex:99999 to ensure that it gets placed in front of all windows
                        [self.view insertSubview:vc.view atIndex:99999];
        }
        //self.detailView.title = @"Title";
    }
    
}

- (IBAction)centerMap:(id)sender {
    
    //NSLog(@"centerMap in the UI thread? %d", [NSThread isMainThread]);
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }

    [self showStatusMessage:@"'Follow Mode' enabled drag the map to manually set the location."];
    if (self.appDelegate.alertsManager.isUserFollowMode)
        return ;
    
    //NSLog(@"center map called");
    
    
    [self.appDelegate.alertsManager startUserFollowMode];
    
    [self clearAlertPositions];
    
    [self moveMapToUser];
    
    [self plotAlertPositions];
    //[self refreshAll:nil];
    //NSLog(@"center map UI thread? %d", [NSThread isMainThread]);
    
    //TODO consider killing all offscreen annotations at this point to save memory if needed
    
}


- (IBAction)refreshAll:(id)sender {
    
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }
    
    //NSLog(@"refreshAll in the UI thread? %d", [NSThread isMainThread]);
    //tell it to load and check prox
    
        [self.appDelegate.alertsManager loadCurrentMapPositionWithoutAlertCheck];
    
}

- (float) getRadiusInMilesFromMapView
{
    
    /*
     
     CLLocationCoordinate2D bottomLeftCoord =
     [self.mapView convertPoint:CGPointMake(0, self.mapView.frame.size.height)
     toCoordinateFromView:self.mapView];
     
     CLLocationCoordinate2D topRightCoord =
     [self.mapView convertPoint:CGPointMake(self.mapView.frame.size.width, 0)
     toCoordinateFromView:self.mapView];
     
     
     CLLocation * bottomLeftLocation = [[CLLocation alloc]
     initWithLatitude:bottomLeftCoord.latitude
     longitude:bottomLeftCoord.longitude];
     CLLocation * bottomRightLocation = [[CLLocation alloc]
     initWithLatitude:bottomLeftCoord.latitude
     longitude:topRightCoord.longitude];
     
     CLLocationDistance distanceInMeters = [bottomLeftLocation distanceFromLocation:bottomRightLocation];*/
    
    MKMapRect mRect = self.mapView.visibleMapRect;
    MKMapPoint eastMapPoint = MKMapPointMake(MKMapRectGetMinX(mRect), MKMapRectGetMidY(mRect));
    MKMapPoint westMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), MKMapRectGetMidY(mRect));
    
    CLLocationDistance distanceInMeters = MKMetersBetweenMapPoints(eastMapPoint, westMapPoint);
    
    
    
    
    float distanceInMiles = round(distanceInMeters / METERS_PER_MILE) ;
    
    //should we divide by 2 since this is diameter and want search radius from center?
    distanceInMiles = distanceInMiles / 2;
    
    if (distanceInMiles < MIN_LOAD_RADIUS_IN_MILES)
        distanceInMiles = MIN_LOAD_RADIUS_IN_MILES;
    
    
    if (distanceInMiles > MAX_LOAD_RADIUS_IN_MILES)
        distanceInMiles = MAX_LOAD_RADIUS_IN_MILES;
    
    return distanceInMiles;
}


-(void) sizeMapToDefault
{
    
    CLLocation * loc = [self.appDelegate.alertsManager getLastLocationPreferenceValue];
    if (loc == nil)
        return;
    
    CLLocationCoordinate2D coord = loc.coordinate;
    CLLocationDistance span = [self.appDelegate.alertsManager getLastMapSizePreferenceValue] *METERS_PER_MILE;
    MKCoordinateRegion viewRegion = [self.mapView regionThatFits:MKCoordinateRegionMakeWithDistance(coord, span,span)];
    if (viewRegion.span.latitudeDelta==0
        || viewRegion.span.longitudeDelta == 0
        ||isnan(viewRegion.span.latitudeDelta)
        || isnan(viewRegion.span.longitudeDelta))
    {
        //if that span is messed up then dont let the map adjust it
        viewRegion = MKCoordinateRegionMakeWithDistance(coord, span,span);
    }
    
    //NSLog(@"move map to user:using radius pref (region that fits) %f, %f", viewRegion.span.latitudeDelta, viewRegion.span.longitudeDelta);
    [self.mapView setRegion:viewRegion animated:NO];
    
    _initialMapSizeWasSet = true;
    
}

//this will help if they scroll around, etc
-(void) moveMapToUser
{
    CLLocation * loc = [self.appDelegate.alertsManager getLastLocationPreferenceValue];
    if (loc == nil)
        return;
    
    //see if its valid before setting it
    //NSLog(@"move map to user using getLastLocationPreferenceValue  %f, %f",loc.coordinate.latitude, loc.coordinate.longitude);
    self.mapView.centerCoordinate = loc.coordinate;
}



//this happens after a drag event and is our chance to get info about the new location and size
- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView{
    
    
    /*
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }
    
    if (self.appDelegate.alertsManager.isUserFollowMode)
        return;
        
    CLLocation * mapCenterLoc = [[CLLocation alloc]
                                 initWithLatitude:mapView.centerCoordinate.latitude
                                 longitude:mapView.centerCoordinate.longitude];
    
    
    //not follow mode so get the manually loaded items....
    [self.appDelegate.alertsManager setLocationAndRadiusManually:mapCenterLoc];
*/
}



- (void)clearAlertPositions
{
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
}



// Add new method above refreshTapped
- (void)plotAlertPositions
{
    
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }
    
    if (self.appDelegate.alertsManager.currentAlertItemRows == nil)
        return;
    
    NSMutableArray *annotationsToAdd = [[NSMutableArray alloc] init];
    
    NSLog(@"creating annotations for %u items", self.appDelegate.alertsManager.currentAlertItemRows.count);
        
    for (wdAlertLocation * alertItem in self.appDelegate.alertsManager.currentAlertItemRows)
    {
        //see if it doesn't exist and add it if not
        if ([self.mapView.annotations containsObject:alertItem])
            continue;
        
        if (alertItem.shapePoints == nil)
            continue;
        
        if (alertItem.shapePoints.count > 2)
        {
             // Add an overlay
         
             MKPolyline *polyLine = [self buildPolyline:alertItem.shapePoints];
         
             [self.mapView addOverlay:polyLine];         
        }
         
        [annotationsToAdd addObject:alertItem];        
	}
    
    if (annotationsToAdd.count>0)
        [self.mapView addAnnotations:annotationsToAdd];
        
}



-(void)plotCustomAlertPositions
{
    if (self.appDelegate.alertsManager == nil)
    {
        [self showErrorMessage:@"Alerts Manager not available"];
        return;
    }
    
    if (self.appDelegate.alertsManager.currentCustomAlertItemRows == nil)
        return;
    
    NSMutableArray *annotationsToAdd = [[NSMutableArray alloc] init];
    
    NSLog(@"creating customannotations for %u items", self.appDelegate.alertsManager.currentCustomAlertItemRows.count);
    
    for (wdAlertLocation * alertItem in self.appDelegate.alertsManager.currentCustomAlertItemRows)
    {
        //see if it doesn't exist and add it if not
        if ([self.mapView.annotations containsObject:alertItem])
            continue;
        
        
        if (alertItem.coordinate.latitude == 0||
            alertItem.coordinate.longitude == 0)
            continue;
        
        [annotationsToAdd addObject:alertItem];
	}
    
    if (annotationsToAdd.count>0)
        [self.mapView addAnnotations:annotationsToAdd];
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




- (void)showStatusMessage:(NSString *)msg
{
    
     
    UIImage *img = [UIImage imageNamed:@"bg-gray123.png"];
    UIImage *acc = [UIImage imageNamed:@"Icon-Small"];
    
    [YRDropdownView showDropdownInView:self.view
                                 title:@"Carry Alerts Message"
                                detail:msg
                                 image:acc
                       backgroundImage:img
                              animated:YES
                             hideAfter:10
     ];
    
    
}

- (void)showErrorMessage:(NSString *)msg
{
    
    
    UIImage *img = [UIImage imageNamed:@"bg-red.png"];
    UIImage *acc = [UIImage imageNamed:@"Icon-Small"];
    
    [YRDropdownView showDropdownInView:self.view
                                 title:@"Carry Alerts ERROR!"
                                detail:msg
                                 image:acc
                       backgroundImage:img
                              animated:YES
                             hideAfter:30
     ];
    
    
}




- (void)showAlert:(NSString *)msg numberOfItems:(NSInteger)count
{
    
    UIImage *img = [UIImage imageNamed:@"bg-yellow.png"];
    UIImage *acc = [UIImage imageNamed:@"Icon-Small"];
    
    NSString * title;
    if (count == 1)
        title = @"Carry Alert!";
    else
        title = [NSString stringWithFormat:@"%u Carry Alerts!", count];
    
    [YRDropdownView showDropdownInView:self.view
                                 title:title
                                detail:msg
                                 image:acc
                                 backgroundImage:img
                              animated:YES
                             hideAfter:15
                            ];
    
    
    
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




- (void)setAnnotationDetails:(NSString *)title
{
    wdAlertLocation * al = (wdAlertLocation*)self.mapView.selectedAnnotations[0];
    if(al)
    {
        [al updateDetails:title type:@"type"];
        
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"Source Controller = %@", [segue sourceViewController]);
    NSLog(@"Destination Controller = %@", [segue destinationViewController]);
    NSLog(@"Segue Identifier = %@", [segue identifier]);
    
    if ([segue.identifier isEqualToString:@"showDetails"])
    {
        NSLog(@"showing details ");
        
        //SecondViewController *loginViewController = (SecondViewController *)segue.destinationViewController;
        
        //SecondViewController *navigationController = [[UINavigationController alloc]init];
        
        //[self presentModalViewController:loginViewController animated:YES];
        
        wdAlertLocation * al = (wdAlertLocation *)sender;
        wdAlertDetailsViewController *destViewController = segue.destinationViewController;
        [destViewController setAlert:al];
        destViewController.delegate = self;
        //double x = view.frame.origin.x + view.frame.size.width;
        //double y = view.frame.origin.y + view.frame.size.height;
        //[destViewController.view setFrame:CGRectMake(25,25,250,60)];
        
    }
    
}


- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    wdAlertLocation * al = (wdAlertLocation *)view.annotation;
    if (al.isCustom)
    {   
        wdAlertLocation * al = (wdAlertLocation *)view.annotation;
    
        al.originalAnnotationView = view;
        
        [mapView deselectAnnotation:view.annotation animated:YES];
    
        //UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:nil];
    
        //wdAlertDetailsViewController * detailsPopupViewController = [storyboard instantiateViewControllerWithIdentifier:@"wdAlertDetailsViewController"];
        
        //[detailsPopupViewController setAlert:al];
        
        //[self presentModalViewController:detailsPopupViewController animated:YES];
        
        
        //push the tutorial onto the stack modal so user has to view it....
        [self performSegueWithIdentifier: @"showDetails" sender: al];
        
        //[self addChildViewController:detailsPopupViewController];                 // 1
        
        //[self.view addSubview:self.currentClientView];
         //[ detailsPopupViewController didMoveToParentViewController:self];     // 3
        //double x = view.frame.origin.x + view.frame.size.width;
        //double y = view.frame.origin.y + view.frame.size.height;
        //[detailsPopupViewController.view setFrame:CGRectMake(x,y,250,60)];
        
    }

}

-(void)didUpdateAlertLabel:(id)customAlertItem {
    [self dismissViewControllerAnimated:YES completion:nil];
    //update the item on the manager, then call sync
    //[self.appDelegate.alertsManager.currentCustomAlertItemRows objec]
    
    //tell it to sync just in case
    [self.appDelegate.alertsManager setAlertItemsAndEnabledCatsCachePreferenceValue:self.appDelegate.alertsManager.currentAlertItemRows cats:self.appDelegate.alertsManager.getEnabledCategories];
    
}


- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    
    
    static NSString *identifier = @"wdAlertLocation";
    if ([annotation isKindOfClass:[wdAlertLocation class]]) {
        
        MKAnnotationView *annotationView = (MKAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        
        if (annotationView == nil) {
            
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            annotationView.enabled = YES;
            annotationView.canShowCallout = YES;
                        
            //image
            UIImage* flagImage = [UIImage imageNamed:@"mapmarker3-16"];
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:flagImage] ;
            [annotationView addSubview:imageView];
            
            annotationView.frame = CGRectMake(0, 0, 51, 85);
            //annotationView.contentScaleFactor = 1;
            //annotationView.image = flagImage;
            annotationView.contentMode = UIViewContentModeCenter;
            annotationView.centerOffset = CGPointMake(15, 5);
            annotationView.calloutOffset = CGPointMake(-13,0);
            
                        
            /*
            
            if ([al.title isEqualToString:@"[empty]"] )
            {
             
            
                UIImage *origimage = [UIImage imageWithData: [NSData dataWithContentsOfFile:@"loading.gif"]];
            
                UIGraphicsBeginImageContext(CGSizeMake(32.0f, 32.0f));
            
                [origimage drawInRect:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
            
                UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            
                UIGraphicsEndImageContext();
            
                annotationView.leftCalloutAccessoryView = [[UIImageView alloc] initWithImage:img];
            }
             */

           
    
        } else {
            annotationView.annotation = annotation;
            wdAlertLocation * al = (wdAlertLocation *)annotation;
            if (! [al.title isEqualToString:@"[empty]"] )
            {
                annotationView.leftCalloutAccessoryView = nil;
            }

        }
        
        wdAlertLocation * al = (wdAlertLocation *)annotation;
        if (al.isCustom)
        {
            //UIButton* butt = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            //[butt addTarget:self action:@selector(displayAlertEditor:) forControlEvents:UIControlEventTouchUpInside];
            annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        }
        

        
//        UIImageView *leftCalloutView = [[UIImageView alloc]
//                                        initWithImage:((NeighborMapAnnotation *)annotation).image];
//        pinView.leftCalloutAccessoryView = leftCalloutView;
//        [leftCalloutView release];
        
        
        
        [annotationView setNeedsDisplay];
        
        return annotationView;
    }
    
    return nil;    
        
      
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



-(void)dealloc
{
    self.HUD = nil;
    self.appDelegate = nil;
}



@end
