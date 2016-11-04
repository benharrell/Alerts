//
//  wdAlertsEventParameters.h
//  Carry Alerts
//
//  Created by Benjamin Harrell on 12/28/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface wdAlertsEventParameters : NSObject
{
    NSInteger alertItemsCount;
    NSString * alertItemsMessage;

}

@property (nonatomic) NSInteger alertItemsCount;
@property (nonatomic) NSString * alertItemsMessage;

- (id)initWithCountAndMessage:(NSInteger)count message:(NSString *)msg;


@end


