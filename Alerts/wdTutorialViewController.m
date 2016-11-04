//
//  wdTutorialViewController.m
//  Carry Alerts
//
//  Created by Benjamin Harrell on 3/8/13.
//  Copyright (c) 2013 Benjamin Harrell. All rights reserved.
//

#import "wdTutorialViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface wdTutorialViewController ()

@end

@implementation wdTutorialViewController

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
    /*
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f]; //[UIColor clearColor];
    UIView * v = self.textLabel;
    [v.layer setCornerRadius:30.0f];
    [v.layer setBorderColor:[UIColor lightGrayColor].CGColor];
    [v.layer setBorderWidth:1.5f];
    [v.layer setShadowColor:[UIColor blackColor].CGColor];
    [v.layer setShadowOpacity:0.8];
    [v.layer setShadowRadius:3.0];
    [v.layer setShadowOffset:CGSizeMake(2.0, 2.0)];*/
    
    
    UITapGestureRecognizer* taprec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
        
    [self.view addGestureRecognizer:taprec];

    
    
    
}

-(void)didSwipe:(UITapGestureRecognizer *)recognizer {
    NSLog(@"Swipe received.");
    [self exitPage];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)exitTutorial:(id)sender {
    
    [self exitPage];
}

- (void)exitPage{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasSeenTutorial"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
}
@end
