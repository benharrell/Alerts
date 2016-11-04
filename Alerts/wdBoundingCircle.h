//
//  wdBoundingCircle.h
//  Alerts
//
//  Created by Benjamin Harrell on 11/23/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface wdBoundingCircle : NSObject
{
    double centerX;
    double centerY;
    double radius;
}
-  (id) initWithPoints:(NSArray*)points;
-  (double) XCoordinate;
-  (double) YCoordinate;
-  (double) Radius;


@end


