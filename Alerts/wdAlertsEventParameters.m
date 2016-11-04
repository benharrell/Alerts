//
//  wdAlertsEventParameters.m
//  Carry Alerts
//
//  Created by Benjamin Harrell on 12/28/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdAlertsEventParameters.h"

@implementation wdAlertsEventParameters


@synthesize alertItemsCount;
@synthesize alertItemsMessage;



- (id)initWithCountAndMessage:(NSInteger)count message:(NSString *)msg {
    if ((self = [super init])) {
        self.alertItemsCount = count;
        self.alertItemsMessage  = msg;
    }
    return self;
}




@end
