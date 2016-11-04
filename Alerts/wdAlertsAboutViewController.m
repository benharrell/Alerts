//
//  wdAlertDetailsViewController.m
//  Alerts
//
//  Created by Benjamin Harrell on 12/4/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdAlertsAboutViewController.h"


@interface wdAlertsAboutViewController ()

@end

@implementation wdAlertsAboutViewController
@synthesize nameLabel;
@synthesize alertObject;
@synthesize tweetLabel;

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
    
    //UIImage * bg = [UIImage imageNamed:@"background.png"];
    ////if (bg != nil)
    //    self.view.backgroundColor = [UIColor colorWithPatternImage:bg];
    
    if (alertObject != nil)
        self.navigationItem.title =  alertObject.title;
    
}

// Implement loadView to create a view hierarchy programmatically.
- (void)loadView {
    
    CGRect applicationFrame = [[UIScreen mainScreen] applicationFrame];
	//applicationFrame.origin = CGPointZero;
    
	UIView *contentView = [[UIView alloc] initWithFrame:applicationFrame];
    
	[contentView setBackgroundColor:[UIColor orangeColor]];

    
    self.tweetLabel = [[IFTweetLabel alloc] initWithFrame:CGRectMake(10.0f, 50.0f, applicationFrame.size.width - 20.0f, applicationFrame.size.height - 50.0f - 40.0f)];
	[self.tweetLabel setFont:[UIFont boldSystemFontOfSize:18.0f]];
	[self.tweetLabel setTextColor:[UIColor whiteColor]];
	[self.tweetLabel setBackgroundColor:[UIColor clearColor]];
	[self.tweetLabel setNumberOfLines:0];
	[self.tweetLabel setText:@"This is a #test of regular expressions with http://example.com links as used in @Twitterrific. HTTP://CHOCKLOCK.COM APPROVED OF COURSE."];
	[self.tweetLabel setLinksEnabled:true];
	[contentView addSubview:self.tweetLabel];
    
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
