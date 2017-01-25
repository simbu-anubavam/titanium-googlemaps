/**
 * Ti.GoogleMaps
 * Copyright (c) 2015-Present by Hans Knoechel, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiUIView.h"
#import <GoogleMaps/GoogleMaps.h>

@interface TiGooglemapsMapView : TiUIView<GMSMapViewDelegate>

@property(nonatomic,retain) GMSMapView *mapView;

@end
