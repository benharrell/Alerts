//
//  wdTutorialViewController.h
//  Carry Alerts
//
//  Created by Benjamin Harrell on 3/8/13.
//  Copyright (c) 2013 Benjamin Harrell. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface wdTutorialViewController : UIViewController
- (IBAction)exitTutorial:(id)sender;
- (void)exitPage;
@property (weak, nonatomic) IBOutlet UILabel *textLabel;

@end
