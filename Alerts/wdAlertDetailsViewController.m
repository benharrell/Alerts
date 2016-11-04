//
//  wdAlertDetailsViewController.m
//  Carry Alerts
//
//  Created by Benjamin Harrell on 6/13/13.
//  Copyright (c) 2013 Benjamin Harrell. All rights reserved.
//

#import "wdAlertDetailsViewController.h"
#import <MapKit/MapKit.h>

@interface wdAlertDetailsViewController ()

@end

@implementation wdAlertDetailsViewController


@synthesize delegate;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    if (_alertAnnotation!= nil)
        self.titleTextField.text = _alertAnnotation.title   ;
    

}

-(void)viewDidAppear:(BOOL)animated
{
    [self.view setFrame:CGRectMake(25, 25, 250, 120)];
    self.view.center = self.view.superview.center;
    
    
}

- (void)setAlert:(wdAlertLocation*)alert
{
    _alertAnnotation = alert;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)removeAlert:(id)sender
{
    //always push thelocation to the delegate and let them decide what to do with it....
    if (self.delegate != nil)
    {
        [self.delegate didRemoveAlert:_alertAnnotation];
    }

}

- (IBAction)saveDetails:(id)sender {
    
    //at this point we will set the name and save it
    
    //[self willMoveToParentViewController:nil];  // 1
    //[self.view removeFromSuperview];            // 2
    //[self removeFromParentViewController];      // 3
    
    if (_alertAnnotation != nil)
        _alertAnnotation.title = self.titleTextField.text;
    
    
    
    //always push thelocation to the delegate and let them decide what to do with it....
    if (self.delegate != nil)
    {
        [self.delegate didUpdateAlertLabel:_alertAnnotation];
    }


    
    
}

@end
