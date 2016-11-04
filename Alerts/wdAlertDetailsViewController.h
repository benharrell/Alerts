//
//  wdAlertDetailsViewController.h
//  Carry Alerts
//
//  Created by Benjamin Harrell on 6/13/13.
//  Copyright (c) 2013 Benjamin Harrell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "wdAlertLocation.h"

@protocol wdAlertDetailsChangeDelegate<NSObject>@optional

-(void) didUpdateAlertLabel:(wdAlertLocation * )customAlertItem;
-(void) didRemoveAlert:(wdAlertLocation * )customAlertItem;

@end



@interface wdAlertDetailsViewController : UIViewController
{
    wdAlertLocation * _alertAnnotation;
}

- (IBAction)removeAlert:(id)sender;
- (IBAction)saveDetails:(id)sender;
- (void)setAlert:(wdAlertLocation*)alert;
@property (strong, nonatomic) IBOutlet UITextField *titleTextField;

@property (nonatomic, strong) id <wdAlertDetailsChangeDelegate> delegate;

@end
