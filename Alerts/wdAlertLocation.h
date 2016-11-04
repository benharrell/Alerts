//
//  wdAlertLocation.h
//  Alerts
//
//  Created by Benjamin Harrell on 11/22/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface wdAlertLocation : NSObject <MKAnnotation,NSCoding>
{
    NSString *_title;
    NSString *_type;
    NSString *_reference;
    CLLocationCoordinate2D _coordinate;
    NSArray * _shapePoints;
    bool _hasAlerted;
    bool _isCustom;
    MKAnnotationView * _origAnnoView;
}


@property (copy) NSString *title;
@property (copy) NSString *type;
@property (copy) NSString *reference;
@property (assign) bool hasAlerted;
@property (assign) bool isCustom;
@property (nonatomic, retain) MKAnnotationView * originalAnnotationView;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, retain) NSArray * shapePoints;

- (id)initWithAll:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(NSString*)typeValue ref:(NSString *)reference points:(NSArray *)shapePoints isCust:(bool)isCustom;

- (void)updateDetails:(NSString*)title type:(NSString*)typeValue;
@end

