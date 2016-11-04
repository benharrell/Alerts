//
//  wdBoundingCircle.m
//  Alerts
//
//  Created by Benjamin Harrell on 11/23/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdBoundingCircle.h"
#import <CoreLocation/CoreLocation.h>

@implementation wdBoundingCircle

-  (double) XCoordinate
{
    return self->centerX;
}

-  (double) YCoordinate
{
    return self->centerY;
}
-  (double) Radius{
    return self->radius;
}

    /**
     * simple 'bounding-box style' approx.
     */
-  (id) initWithPoints:(NSArray*)points
{
    self = [super init];
    if (points.count ==0)return self;
    
    if (points.count == 1)
    {
        CLLocation *def = points[0];
        self->centerX = def.coordinate.latitude;
        self->centerY = def.coordinate.longitude;
        self->radius = 15/111000;
        return self;
    }
    
    CLLocation *firstLoc = points[0];
    //NSNumber * nlt = [NSNumber numberWithFloat:[latlng[i] floatValue]];
    //NSNumber * nlg = [NSNumber numberWithFloat:[latlng[i+1] floatValue]];
    //CLLocation *locCurr = [[CLLocation alloc] initWithLatitude:nlt.doubleValue longitude:nlg.doubleValue];
    //CLLocationDistance dist = [locOrig distanceFromLocation:locCurr];
    //if (dist>maxDist) maxDist = dist;
    
    
    double vx = [NSNumber numberWithDouble:firstLoc.coordinate.latitude].doubleValue;
    double vy = [NSNumber numberWithDouble:firstLoc.coordinate.longitude].doubleValue;
    
    double xmin = vx;
    double ymin = vy;
    double xmax = vx;
    double ymax = vy;
    
    int i;
    for (i = 0; i < [points count]; i++)
    {
        
        CLLocation *v = points[i];
        vx = [NSNumber numberWithDouble:v.coordinate.latitude].doubleValue;
        vy = [NSNumber numberWithDouble:v.coordinate.longitude].doubleValue;
                
            if (vx < xmin) xmin = vx;
            if (vy < ymin) ymin = vy;	
            if (vx > xmax) xmax = vx;
            if (vy > ymax) ymax = vy;
        
    }
    
        self->centerX = (xmin + xmax) /2;
        self->centerY = (ymin + ymax) /2;
        double  tx = (xmax - xmin) /2;;
        double  ty = (ymax - ymin) /2;        
        
        self->radius = tx + ty - (MIN(tx, ty) /2);
    return self;
    
}

   @end