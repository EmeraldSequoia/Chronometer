//
//  ECOptionsDim.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 8/18/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#ifdef ECDIMMER

#import "ECOptionsDim.h"
#import "ChronometerAppDelegate.h"
#import "Constants.h"


@implementation ECOptionsDim

- (id)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)quitMe:(id)sender {
    [ChronometerAppDelegate optionDone];
}

#if 0
- (void)setMovingLabel:(double)val {
    CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
    CGRect labelFrame = CGRectMake(screenRect.size.width*0.1 + screenRect.size.width*0.8*val - 25, screenRect.size.height/2 - kLabelHeight, 50, kLabelHeight);
    [label setFrame:labelFrame];
    label.text = [NSString stringWithFormat:@"%d %%", (int)round(val*100)];
}
#endif

- (void)sliderAction:(UISlider*)sender {
    double val = sender.value;
    double updatedVal = [ChronometerAppDelegate setDimmer:val];
    if (val != updatedVal) {
	mySlider.value = updatedVal;
    }
}

- (void)loadView {		
    [[UIApplication sharedApplication] setStatusBarHidden:YES animated:YES];		// too bright!
    
    CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
    double val = [ChronometerAppDelegate dimmerValue];
    [ChronometerAppDelegate setDimmer:val];	// just to get the label to show
    
    // setup our parent content view and embed it to your view controller
    UIView *contentView = [[UIView alloc] initWithFrame:screenRect];
    contentView.backgroundColor = [UIColor clearColor];
    contentView.autoresizesSubviews = YES;
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    self.view = contentView;
    [contentView release];
    
#if 0
    // label
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [UIFont systemFontOfSize: 16];
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    [self setLabel:val];
    [self.view addSubview:label];
    [label release];
#endif
    
    // slider
    mySlider = [[UISlider alloc] initWithFrame:CGRectMake(screenRect.size.width*0.1, screenRect.size.height/2, screenRect.size.width*0.8, kSliderHeight)];
    [mySlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchDragInside|UIControlEventTouchDragOutside];
    mySlider.minimumValue = 0;
    mySlider.value = val;
    [self.view addSubview:mySlider];
    
    //
    self.title = NSLocalizedString(@"Brightness", @"brightness setting screen title");
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitMe:)] autorelease];
}

- (void)dealloc {
    [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
    [mySlider release];
#if DIMMERLABEL
    [ChronometerAppDelegate clearDimmerLabel];
#endif
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait) || isIpad();
}

@end

#endif
