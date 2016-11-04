//
//  wdAlertLocation.m
//  Alerts
//
//  Created by Benjamin Harrell on 11/22/12.
//  Copyright (c) 2012 Benjamin Harrell. All rights reserved.
//

#import "wdAlertLocation.h"
#import <AddressBook/AddressBook.h>




@implementation wdAlertLocation
@synthesize title = _title;
@synthesize type = _type;
@synthesize coordinate = _coordinate;
@synthesize reference = _reference;
@synthesize shapePoints = _shapePoints;
@synthesize hasAlerted = _hasAlerted;
@synthesize isCustom = _isCustom;

@synthesize originalAnnotationView = _origAnnoView;

- (id)initWithAll:(NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(NSString*)typeValue ref:(NSString *)reference points:(NSArray *)shapePoints isCust:(bool)isCustom {
    if ((self = [super init])) {
        _title = [title copy];
        _type = [typeValue copy];
        _coordinate = coordinate;
        _reference = reference;
        _shapePoints = shapePoints;
        _isCustom = isCustom;
        
    }
    return self;
}

- (void)updateDetails:(NSString*)title type:(NSString*)typeValue
{
    _title = [title copy];
    _type = [typeValue copy];
}

/*
- (NSString *)title {
    if ([_name isKindOfClass:[NSNull class]])
        return @"[empty]";
    else
        return _name;
}
*/
- (NSString *)subtitle {
    if ([_type isKindOfClass:[NSNull class]])
        return @"Detection Type: <blank>";
    else
        return [NSString stringWithFormat:@"Detection Type: %@",_type];
}



- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _title = [decoder decodeObjectForKey:@"name"];
        _type = [decoder decodeObjectForKey:@"title"];
        _reference = [decoder decodeObjectForKey:@"reference"];
        _shapePoints= [decoder decodeObjectForKey:@"shapePoints"];
        float lat = [decoder decodeFloatForKey:@"coordinate_latitude"];
        float lon = [decoder decodeFloatForKey:@"coordinate_longitude"];
        
        if ( [decoder containsValueForKey:@"isCustom"])
            _isCustom = [decoder decodeBoolForKey:@"isCustom"];
        else
            _isCustom = false;
        
        
        
        CLLocationCoordinate2D coord;
        coord.latitude = lat;
        coord.longitude = lon;
        _coordinate = coord;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_title forKey:@"name"];
    [encoder encodeObject:_type forKey:@"title"];
    [encoder encodeObject:_reference forKey:@"reference"];
    [encoder encodeObject:_shapePoints forKey:@"shapePoints"];
    [encoder encodeFloat:_coordinate.latitude forKey:@"coordinate_latitude"];
    [encoder encodeFloat:_coordinate.longitude forKey:@"coordinate_longitude"];
    [encoder encodeBool:_isCustom forKey:@"isCustom"];
}




@end


