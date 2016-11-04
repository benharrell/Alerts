//
//  wdAlertDetailsViewController.h
//  Alerts
//
//  Created by Benjamin Harrell on 12/4/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "wdalertLocation.h"
#import "IFTweetLabel.h"

@interface wdAlertsAboutViewController : UIViewController
{
    
	
	IFTweetLabel *tweetLabel;
	
}


@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) wdAlertLocation *alertObject;
@property (nonatomic, retain) IFTweetLabel *tweetLabel;

@end
