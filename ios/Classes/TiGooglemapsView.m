/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-Present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiGooglemapsView.h"
#import "TiGooglemapsViewProxy.h"
#import "TiGooglemapsAnnotationProxy.h"
#import "TiGooglemapsCircleProxy.h"
#import "TiGooglemapsPolygonProxy.h"
#import "TiGooglemapsPolylineProxy.h"
#import "TiGooglemapsConstants.h"
#import "TiClusterIconGenerator.h"
#import "TiClusterRenderer.h"
#import "TiPOIItem.h"

@implementation TiGooglemapsView

#define DEPRECATED(from, to, in) \
NSLog(@"[WARN] Ti.GoogleMaps: %@ is deprecated since %@ in favor of %@", from, to, in);\

-(GMSMapView *)mapView
{
    if (_mapView == nil) {

        _mapView = [[GMSMapView alloc] initWithFrame:[self bounds]];
        [_mapView setDelegate:self];
        [_mapView setMyLocationEnabled:[TiUtils boolValue:[self.proxy valueForKey:@"myLocationEnabled"] def:YES]];
        [_mapView setUserInteractionEnabled:[TiUtils boolValue:[self.proxy valueForKey:@"userInteractionEnabled"] def:YES]];
        [_mapView setAutoresizingMask:UIViewAutoresizingNone];

        [self addSubview:_mapView];
    }

    return _mapView;
}

-(GMUClusterManager *)clusterManager
{
    if (_clusterManager == nil) {
        // Set up the cluster manager with default icon generator and renderer.
        id<GMUClusterAlgorithm> algorithm = [[GMUNonHierarchicalDistanceBasedAlgorithm alloc] init];
        
        TiClusterIconGenerator *iconGenerator = [self createIconGenerator];
        
        TiClusterRenderer *renderer = [[TiClusterRenderer alloc] initWithMapView:_mapView clusterIconGenerator:iconGenerator];
        renderer.delegate = self;
        
        _clusterManager = [[GMUClusterManager alloc] initWithMap:[self mapView] algorithm:algorithm renderer:renderer];
        [_clusterManager setDelegate:self mapDelegate:self];
    }
    
    return _clusterManager;
}

- (void)renderer:(id<GMUClusterRenderer>)renderer willRenderMarker:(GMSMarker *)marker
{
    if ([[marker userData] isKindOfClass:[TiPOIItem class]]) {
        TiPOIItem *item = (TiPOIItem *)[marker userData];
        
        [marker setTitle:item.name];
    }
}

- (TiClusterIconGenerator *)createIconGenerator
{
    id clusterRanges = [[self proxy] valueForKey:@"clusterRanges"];
    id clusterBackgrounds = [[self proxy] valueForKey:@"clusterBackgrounds"];
    
    if (clusterRanges && clusterBackgrounds) {
        NSMutableArray *backgrounds = [NSMutableArray array];
        
        for (id background in clusterBackgrounds) {
            ENSURE_TYPE(background, NSString);
            [backgrounds addObject:[TiUtils image:background proxy:self.proxy]];
        }
        
        return [[TiClusterIconGenerator alloc] initWithBuckets:clusterRanges backgroundImages:backgrounds];
    } else if (clusterRanges) {
        return [[TiClusterIconGenerator alloc] initWithBuckets:clusterRanges];
    }
    
    return [[TiClusterIconGenerator alloc] init];
}

-(void)dealloc
{
    RELEASE_TO_NIL(_mapView);
    [super dealloc];
}

-(TiGooglemapsViewProxy *)mapViewProxy
{
    return (TiGooglemapsViewProxy *)[self proxy];
}

- (void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds
{
    [TiUtils setView:_mapView positionRect:bounds];
    [super frameSizeChanged:frame bounds:bounds];
}

#pragma mark Cluster Delegates

- (void)clusterManager:(GMUClusterManager *)clusterManager didTapCluster:(id<GMUCluster>)cluster
{
    if ([[self proxy] _hasListeners:@"clusterclick"]) {
        [[self proxy] fireEvent:@"clusterclick" withObject:@{
            @"latitude": NUMDOUBLE(cluster.position.latitude),
            @"longitude": NUMDOUBLE(cluster.position.longitude),
            @"count": NUMUINTEGER(cluster.count)
        }];
    }
    
    GMSCameraPosition *newCamera = [GMSCameraPosition cameraWithTarget:cluster.position zoom:_mapView.camera.zoom + 1];
    [_mapView moveCamera:[GMSCameraUpdate setCamera:newCamera]];
}

- (void)clusterManager:(GMUClusterManager *)clusterManager didTapClusterItem:(id<GMUClusterItem>)clusterItem
{
    if ([[self proxy] _hasListeners:@"clusteritemclick"]) {
        [[self proxy] fireEvent:@"clusteritemclick" withObject:@{
            @"latitude": NUMDOUBLE(clusterItem.position.latitude),
            @"longitude": NUMDOUBLE(clusterItem.position.longitude),
        }];
    }
}

#pragma mark Map View Delegates

- (void)mapView:(GMSMapView *)mapView willMove:(BOOL)gesture
{
    if ([[self proxy] _hasListeners:@"willmove"]) {
        DEPRECATED(@"Event.willmove", @"Event.regionwillchange", @"2.2.0");
        [[self proxy] fireEvent:@"willmove" withObject:@{@"gesture" : NUMBOOL(gesture)}];
    }
    if ([[self proxy] _hasListeners:@"regionwillchange"]) {
        [[self proxy] fireEvent:@"regionwillchange" withObject:@{
            @"map" : [self proxy],
            @"latitude" : NUMDOUBLE(mapView.camera.target.latitude),
            @"longitude" : NUMDOUBLE(mapView.camera.target.longitude),
            @"gesture" : NUMBOOL(gesture)
        }];
    }
}

- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position
{
    if ([[self proxy] _hasListeners:@"camerachange"]) {
        DEPRECATED(@"Event.camerachange", @"Event.regionchanged", @"2.2.0");
        [[self proxy] fireEvent:@"camerachange" withObject:[self dictionaryFromCameraPosition:position]];
    }
    if ([[self proxy] _hasListeners:@"regionchanged"]) {
        [[self proxy] fireEvent:@"regionchanged" withObject:@{
            @"map" : [self proxy],
            @"latitude" : NUMDOUBLE(position.target.latitude),
            @"longitude" : NUMDOUBLE(position.target.longitude),
        }];
    }
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position
{
    if ([[self proxy] _hasListeners:@"idle"]) {
        [[self proxy] fireEvent:@"idle" withObject:[self dictionaryFromCameraPosition:position]];
    }
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate
{
    if ([[self proxy] _hasListeners:@"click"]) {
        [[self proxy] fireEvent:@"click" withObject:@{
            @"clicksource": @"map",
            @"map": [self proxy],
            @"latitude": NUMDOUBLE(coordinate.latitude),
            @"longitude": NUMDOUBLE(coordinate.longitude)
        }];
    }
}

- (void)mapView:(GMSMapView *)mapView didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate
{
    if ([[self proxy] _hasListeners:@"longpress"]) {
        DEPRECATED(@"Event.longpress", @"Event.longclick", @"2.2.0");
        [[self proxy] fireEvent:@"longpress" withObject:[self dictionaryFromCoordinate:coordinate]];
    }
    if ([[self proxy] _hasListeners:@"longclick"]) {
        [[self proxy] fireEvent:@"longclick" withObject:@{
            @"map": [self proxy],
            @"latitude": NUMDOUBLE(coordinate.latitude),
            @"longitude": NUMDOUBLE(coordinate.longitude)
        }];
    }
}

- (BOOL)mapView:(GMSMapView *)mapView didTapMarker:(GMSMarker *)marker
{
    if ([[self proxy] _hasListeners:@"markerclick"]) {
        DEPRECATED(@"Event.markerclick", @"Event.click", @"2.2.0");
        NSDictionary *event = @{
            @"marker" : [self annotationProxyFromMarker:marker]
        };
        [[self proxy] fireEvent:@"markerclick" withObject:event];
    }
    if ([[self proxy] _hasListeners:@"click"]) {
        [[self proxy] fireEvent:@"click" withObject:@{
            @"clicksource": @"pin",
            @"annotation": [self annotationProxyFromMarker:marker],
            @"map": [self proxy],
            @"latitude": NUMDOUBLE(marker.position.latitude),
            @"longitude": NUMDOUBLE(marker.position.longitude)
        }];
    }
}

- (void)mapView:(GMSMapView *)mapView didTapInfoWindowOfMarker:(GMSMarker *)marker
{
    if ([[self proxy] _hasListeners:@"markerinfoclick"]) {
        DEPRECATED(@"Event.markerinfoclick", @"Event.click", @"2.2.0");
        NSDictionary *event = @{
            @"marker" : [self annotationProxyFromMarker:marker]
        };
        [[self proxy] fireEvent:@"markerinfoclick" withObject:event];
    }
    if ([[self proxy] _hasListeners:@"click"]) {
        [[self proxy] fireEvent:@"click" withObject:@{
            @"clicksource": @"infoWindow",
            @"annotation": [self annotationProxyFromMarker:marker],
            @"map": [self proxy],
            @"latitude": NUMDOUBLE(marker.position.latitude),
            @"longitude": NUMDOUBLE(marker.position.longitude)
        }];
    }
}

- (void)mapView:(GMSMapView *)mapView didTapOverlay:(GMSOverlay *)overlay
{
    if ([[self proxy] _hasListeners:@"overlayclick"]) {
        [[self proxy] fireEvent:@"overlayclick" withObject:@{
            @"overlay": NUMINT([self overlayProxyFromOverlay:overlay])
        }];
    }
    if ([[self proxy] _hasListeners:@"click"]) {
        [[self proxy] fireEvent:@"click" withObject:@{
            @"clicksource": [self overlayTypeFromOverlay:overlay],
            @"map": [self proxy],
            @"overlay": [self overlayProxyFromOverlay:overlay]
        }];
    }
}

- (void)mapView:(GMSMapView *)mapView didBeginDraggingMarker:(GMSMarker *)marker
{
    if ([[self proxy] _hasListeners:@"dragstart"]) {
        TiGooglemapsAnnotationProxy *annotationProxy = [self annotationProxyFromMarker:marker];
        NSDictionary *event = @{
            @"marker" : annotationProxy, // Deprecated
            @"annotation" : annotationProxy
        };
        [[self proxy] fireEvent:@"dragstart" withObject:event];
    }
}

- (void)mapView:(GMSMapView *)mapView didEndDraggingMarker:(GMSMarker *)marker
{
    if ([[self proxy] _hasListeners:@"dragend"]) {
        TiGooglemapsAnnotationProxy *annotationProxy = [self annotationProxyFromMarker:marker];

        NSDictionary *event = @{
            @"marker" : annotationProxy, // Deprecated
            @"annotation" : annotationProxy
        };
      [[self proxy] fireEvent:@"dragend" withObject:event];
    }
}

- (void)mapView:(GMSMapView *)mapView didDragMarker:(GMSMarker *)marker
{
    if ([[self proxy] _hasListeners:@"dragmove"]) {
        TiGooglemapsAnnotationProxy *annotationProxy = [self annotationProxyFromMarker:marker];
        NSDictionary *event = @{
            @"marker" : annotationProxy, // Deprecated
            @"annotation" : annotationProxy
        };
        [[self proxy] fireEvent:@"dragmove" withObject:event];
    }
}

- (BOOL)didTapMyLocationButtonForMapView:(GMSMapView *)mapView
{
    if ([[self proxy] _hasListeners:@"locationclick"]) {
        NSDictionary *event = @{
            @"map" : [self proxy]
        };
        [[self proxy] fireEvent:@"locationclick" withObject:event];
    }
}

- (void)mapViewDidFinishTileRendering:(GMSMapView *)mapView
{
    if ([[self proxy] _hasListeners:@"complete"]) {
        [[self proxy] fireEvent:@"complete"];
    }
}

#pragma mark Helper

-(NSDictionary *)dictionaryFromCameraPosition:(GMSCameraPosition *)position
{
    if (position == nil) {
        return @{};
    }

    return @{
       @"latitude" : NUMDOUBLE(position.target.latitude),
       @"longitude" : NUMDOUBLE(position.target.longitude),
       @"zoom" : NUMFLOAT(position.zoom),
       @"viewingAngle" : NUMDOUBLE(position.viewingAngle),
       @"bearing" : NUMDOUBLE([position bearing])
    };
}

-(NSDictionary *)dictionaryFromCoordinate:(CLLocationCoordinate2D)coordinate
{
    return @{
        @"latitude": NUMDOUBLE(coordinate.latitude),
        @"longitude": NUMDOUBLE(coordinate.longitude)
    };
}

-(id)overlayTypeFromOverlay:(GMSOverlay *)overlay
{
    ENSURE_UI_THREAD(overlayTypeFromOverlay, overlay);

    if([overlay isKindOfClass:[GMSPolygon class]]) {
        return NUMINTEGER(TiGooglemapsOverlayTypePolygon);
    } else if([overlay isKindOfClass:[GMSPolyline class]]) {
        return NUMINTEGER(TiGooglemapsOverlayTypePolyline);
    } else if([overlay isKindOfClass:[GMSCircle class]]) {
        return NUMINTEGER(TiGooglemapsOverlayTypeCircle);
    }
    
    NSLog(@"[ERROR] Unknown overlay provided: %@", [overlay class])
    
    return NUMINTEGER(TiGooglemapsOverlayTypeUnknown);
}

-(id)annotationProxyFromMarker:(GMSMarker *)marker
{
    for (NSUInteger i = 0; i < [[[self mapViewProxy] markers] count]; i++) {
        TiGooglemapsAnnotationProxy *annotationProxy = [[[[self mapViewProxy] markers] objectAtIndex:i] retain];
        
        if ([[[[annotationProxy marker] userData] valueForKey:@"uuid"] isEqualToString:[[marker userData] valueForKey:@"uuid"]]) {
            // Replace the location attributes in the array of annotation-proxies
            TiGooglemapsAnnotationProxy *newAnnotation = [annotationProxy retain];
            [annotationProxy release];
            [newAnnotation updateLocation:@{
                @"latitude": NUMDOUBLE([marker position].latitude),
                @"longitude": NUMDOUBLE([marker position].longitude)
            }];
            [[[self mapViewProxy] markers] replaceObjectAtIndex:i withObject:newAnnotation];
            
            return [newAnnotation autorelease];
        }
    }

    return [NSNull null];
}

-(id)overlayProxyFromOverlay:(GMSOverlay *)overlay
{
    for (TiProxy *overlayProxy in [[self mapViewProxy] overlays]) {
        // Check for polygons
        if ([overlay isKindOfClass:[GMSPolygon class]] && [overlayProxy isKindOfClass:[TiGooglemapsPolygonProxy class]]) {
            if ([(TiGooglemapsPolygonProxy *)overlayProxy polygon] == overlay) {
                return (TiGooglemapsPolygonProxy *)overlayProxy;
            }

        // Check for polylines
        } else if ([overlay isKindOfClass:[GMSPolyline class]] && [overlayProxy isKindOfClass:[TiGooglemapsPolylineProxy class]]) {
            if ([(TiGooglemapsPolylineProxy *)overlayProxy polyline] == overlay) {
                return (TiGooglemapsPolylineProxy *)overlayProxy;
            }

        // Check for circles
        } else if ([overlay isKindOfClass:[GMSCircle class]] && [overlayProxy isKindOfClass:[TiGooglemapsCircleProxy class]]) {
            if ([(TiGooglemapsCircleProxy *)overlayProxy circle] == overlay) {
                return (TiGooglemapsCircleProxy *)overlayProxy;
            }
        }
    }

    return [NSNull null];
}

#pragma mark Constants

MAKE_SYSTEM_PROP(OVERLAY_TYPE_POLYGON, TiGooglemapsOverlayTypePolygon);
MAKE_SYSTEM_PROP(OVERLAY_TYPE_POLYLINE, TiGooglemapsOverlayTypePolyline);
MAKE_SYSTEM_PROP(OVERLAY_TYPE_CIRCLE, TiGooglemapsOverlayTypeCircle);

@end
