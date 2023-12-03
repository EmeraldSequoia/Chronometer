//
//  ECOptionsLoc.h
//  Chronometer
//
//  Created by Bill Arnett on 9/7/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "ContactsUI/ContactsUI.h"
#import "Constants.h"
#import "ECGeoNames.h"

@interface ECLocationPin : NSObject <MKAnnotation> {
    CLLocationCoordinate2D		coordinate;
    NSString				*title;
    NSString				*subtitle;
}

@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, readwrite, copy) NSString *title;
@property (nonatomic, readwrite, copy) NSString *subtitle;

@end

@interface ECOptionsLoc : UIViewController <UITextFieldDelegate, MKMapViewDelegate> {
    IBOutlet UIView			*backer;
    IBOutlet UIView			*tzbacker;
    IBOutlet UISwitch			*useDeviceLocationSwitch;
    IBOutlet UIActivityIndicatorView	*spinner;
    IBOutlet UILabel			*switchLabel;
    IBOutlet UILabel			*tzlabel;
    IBOutlet UILabel			*cityNameLabel;
    IBOutlet UITextField                *cityNameTextField;  // Used only to trigger instantiation of search controller in separate window
    IBOutlet UILabel			*regionInfoLabel;
    IBOutlet UIView                     *cityNameSearchBarHolder;
    IBOutlet UIButton			*recentsButton;
    IBOutlet UIButton			*setButton;
    IBOutlet UIButton			*mapButton;
    IBOutlet UIButton			*satButton;
    IBOutlet UITextField		*targetLatitude;
    IBOutlet UITextField		*targetLongitude;
    IBOutlet UILabel			*targetLatitudeLabel;
    IBOutlet UILabel			*targetLongitudeLabel;
    IBOutlet UILabel			*latitudeLabel;
    IBOutlet UILabel			*longitudeLabel;
    IBOutlet UILabel			*latitudeLabelLabel;
    IBOutlet UILabel			*longitudeLabelLabel;
    IBOutlet UIImageView		*scaleBar;
    IBOutlet UIImageView		*xHairs;
    IBOutlet UIButton			*scaleUnitsButton;
    IBOutlet UILabel			*tapmapLabel;
    IBOutlet UILabel			*scaleLabel;
    IBOutlet UILabel			*tzNameLabel;
    IBOutlet UILabel			*tzSourceLabel;
    IBOutlet UILabel			*tzInfoLabel;
    IBOutlet UILabel			*timeLabel;
    IBOutlet MKMapView			*mapView;
    IBOutlet UIButton			*oneTouch;			    // above the small map
#ifdef BIGMAPLABELS
    UILabel				*label1;			    // for big map view
    UILabel				*label2;
    UILabel				*label3;
#endif    
    //MKReverseGeocoder			*finder;
    ECGeoNames				*locDB;
    CLLocationCoordinate2D		center;
    CGPoint				cityNameLabelCenter;
    CGRect				regionInfoFrame;
    CGFloat				mainFrameOriginY;
    NSTimer				*timeTimer;
    bool				needLoc;
    bool				searchEditing;
    bool				beginingABSession;
    bool				unfinished;			// we haven't finished initialization yet
    bool                                mapInitialized;
    bool				inSomeLatLongField;		// we're editing either of the lat/long fields
    bool				kbdLockout;			// true means don't allow textField editing just yet
    bool                                firstLayoutSubviewsDone;
    ECLocationPin			*pin;
}

@property (nonatomic, readonly) MKMapView *mapView;
@property (nonatomic, readonly) ECLocationPin *pin;
@property (nonatomic, readonly) UISwitch *useDeviceLocationSwitch;
#ifdef BIGMAPLABELS
@property (nonatomic, readwrite, assign) UILabel *label1;
@property (nonatomic, readwrite, assign) UILabel *label2;
@property (nonatomic, readwrite, assign) UILabel *label3;
- (void)updateLabels;
#endif

- (IBAction) autoLocAction: (id) sender;
- (IBAction) unitsAction: (id) sender;
- (IBAction) bigmapAction: (id) sender;
- (IBAction) recentsAction: (id) sender;

- (ECOptionsLoc *)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil locDB:(ECGeoNames *)db;
- (void)updateToCoordinate:(CLLocationCoordinate2D)newPosition horizontalError:(double)horizontalError;
- (void)useSelectedCity;

@end
