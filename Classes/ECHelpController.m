//
//  ECHelpController.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/7/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "Constants.h"
#import "ECHelpController.h"
#import "ECErrorReporter.h"
#import "ECWatchTime.h"
#import "ECLocationManager.h"
#import "ECGLWatch.h"
#import "ChronometerAppDelegate.h"
#import "ECAppLog.h"
#import "ECTS.h"
#import "ECGlobals.h"
#undef ECTRACE
#import "ECTrace.h"

@interface ECHelpController (ECHelpControllerPrivate)

- (void)checkBackButton;
- (void)checkBackButtonSlowTimerFire:(NSTimer *)timer;
- (void)checkBackButtonFastTimerFire:(NSTimer *)timer;

@end

@implementation ECHelpController

#define ECBackButtonCheckSlowInterval 0.5
#define ECBackButtonCheckFastInterval 0.1

- (id) initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle {
    [super initWithNibName:nibName bundle:bundle];
    lastPage = nil;
    goingBack = false;
    fullyOnScreen = false;
    backButtonCheckTimer = [NSTimer scheduledTimerWithTimeInterval:ECBackButtonCheckSlowInterval target:self selector:@selector(checkBackButtonSlowTimerFire:) userInfo:nil repeats:true];
    backButtonCheckTimerCount = 0;

    tracePrintf("*** ECHelpController init");
    return self;
}

- (void) dealloc {
    tracePrintf("*** ECHelpController dealloc");
    [self.browser stopLoading];  // again; should have happened in helpless:, but we got a weird assert
    assert([NSThread isMainThread]);
    [lastPage release];
    lastPage = nil;
    [backButtonCheckTimer invalidate];
    backButtonCheckTimer = nil;
    self.browser.UIDelegate = nil;
    self.browser.navigationDelegate = nil;
    [super dealloc];
}

- (void)loadView {
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(helpless:)];
//    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(helpBack:)];
//    self.navigationItem.leftBarButtonItem = nil;
//    self.navigationItem.rightBarButtonItem = nil;
    tracePrintf("*** ECHelpController load view");
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 64, 320, 416)];
    //printf("web view bounds at creation are %g x %g\n", webView.bounds.size.width, webView.bounds.size.height);
    lastPage = nil;
    // webView.scalesPageToFit = YES;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    // if ([webView respondsToSelector:@selector(setDataDetectorTypes:)]) {
    //	[webView setDataDetectorTypes:UIDataDetectorTypeNone];
    // }
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    self.browser = webView;
    [self checkBackButton];
}

- (WKWebView *)browser {
    return (WKWebView *)self.view;
}

- (void)setBrowser:(WKWebView *)browser {
    self.view = browser;
}

- (void)helpless:(id)sender {			// This method is called when the Done button is pressed
    tracePrintf("*** ECHelpController helpless");
    assert([NSThread isMainThread]);
    [self.browser stopLoading];
    [ChronometerAppDelegate infoDone:lastPage];
    [lastPage release];
    lastPage = nil;
    [backButtonCheckTimer invalidate];
    backButtonCheckTimer = nil;
}

- (void)helpBack:(id)sender {			// This method is called when the left arrow ("rewind") button is pressed
    tracePrintf("*** ECHelpController helpBack");
    if ([self.browser canGoBack]) {
	[self.browser goBack];
	if (backButtonCheckTimer) {
	    tracePrintf("*** ECHelpController calling goBack, killing timer");
	    [backButtonCheckTimer invalidate]; // in case it's the slow version
	}
	tracePrintf("*** ECHelpController calling goBack, starting fast timer");
	backButtonCheckTimer = [NSTimer scheduledTimerWithTimeInterval:ECBackButtonCheckFastInterval target:self selector:@selector(checkBackButtonFastTimerFire:) userInfo:nil repeats:true];
	backButtonCheckTimerCount = 0;
    }
}

- (NSString *)rootInfoPath  {				// name of the Help directory root
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Help"];
}

- (NSString *)infoPath:(NSString *)watchName  {				// name of the info file for this watch
    return [[self rootInfoPath] stringByAppendingPathComponent: [watchName stringByAppendingString:@".html"]];
}

- (void)showHelp:(NSString *)topic {			// This method is called when the info button is pressed.
    assert([NSThread isMainThread]);
    if (self.browser) {
	if (!topic) {
	    NSString *watchName = [[ChronometerAppDelegate currentWatch] name];
	    topic = [NSString stringWithFormat:@"%@/%@", watchName, watchName];
	}
        [self.browser loadFileURL:[NSURL fileURLWithPath:[self infoPath:topic]]
                      allowingReadAccessToURL:[NSURL fileURLWithPath:[self rootInfoPath]]];
    }
}

- (void)delayedLoadSessionLog:(NSTimer *)timer {
    assert([NSThread isMainThread]);
    NSURL *url = [NSURL fileURLWithPath:[ECAppLog logFileName]];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    [self.browser loadRequest:req];
}

- (void)putUpBackButton {
    UIImage *img = [UIImage imageNamed:@"iBack.png"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:img style:UIBarButtonItemStylePlain target:self action:@selector(helpBack:)];
}

- (void)takeDownBackButton {
    self.navigationItem.leftBarButtonItem = nil;
}

- (void)checkBackButton {
    if ([self.browser canGoBack]) {
	if (!self.navigationItem.leftBarButtonItem) {
	    [self putUpBackButton];
	}
    } else {
	if (self.navigationItem.leftBarButtonItem) {
	    [self takeDownBackButton];
	}
    }
}

- (void)printCurrentPage {
    WKWebView *webView = self.browser;
    Class uiPrintInteractionControllerClass = NSClassFromString(@"UIPrintInteractionController");
    if (uiPrintInteractionControllerClass && [webView respondsToSelector:@selector(viewPrintFormatter)] && [uiPrintInteractionControllerClass isPrintingAvailable]) {
	UIPrintInteractionController *sharedPrintController = [uiPrintInteractionControllerClass sharedPrintController];
	sharedPrintController.printFormatter = [webView viewPrintFormatter];

	void (^completionHandler)(UIPrintInteractionController *, BOOL, NSError *) =
	    ^(UIPrintInteractionController *pic, BOOL completed, NSError *error) {
	    //self.content = nil;
	    if (!completed && error)
		NSLog(@"FAILED! due to error in domain %@ with error code %ld",
		      error.domain, (long)error.code);
	    [webView reload];
	};
	Class printInfoClass = NSClassFromString(@"UIPrintInfo");
	UIPrintInfo *printInfo = [printInfoClass printInfo];
	printInfo.outputType = UIPrintInfoOutputGeneral;
	printInfo.duplex = UIPrintInfoDuplexLongEdge;
	sharedPrintController.printInfo = printInfo;

	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
	    // Really should present from the button that invoked us but we don't know exactly where that is; most Print links are at the top left, though...
	    [sharedPrintController presentFromRect:CGRectMake(100,45,1,1) inView:webView animated:YES
			       completionHandler:completionHandler];
	} else {
	    [sharedPrintController presentAnimated:YES completionHandler:completionHandler];
	}
    } else {
	[[ECErrorReporter theErrorReporter] reportError:@"Printing is not supported with this version of iOS"];
    }
}

- (void)printAllPages {
    WKWebView *webView = self.browser;
    Class uiPrintInteractionControllerClass = NSClassFromString(@"UIPrintInteractionController");
    if (uiPrintInteractionControllerClass && [webView respondsToSelector:@selector(viewPrintFormatter)] && [uiPrintInteractionControllerClass isPrintingAvailable]) {
	[[ECErrorReporter theErrorReporter] reportError:@"Printing all pages not yet implemented"];
	return;
	UIPrintInteractionController *sharedPrintController = [uiPrintInteractionControllerClass sharedPrintController];
	sharedPrintController.printFormatter = [webView viewPrintFormatter];

	void (^completionHandler)(UIPrintInteractionController *, BOOL, NSError *) =
	    ^(UIPrintInteractionController *pic, BOOL completed, NSError *error) {
	    //self.content = nil;
	    if (!completed && error)
		NSLog(@"FAILED! due to error in domain %@ with error code %ld",
		      error.domain, (long)error.code);
	    [webView reload];
	};
	Class printInfoClass = NSClassFromString(@"UIPrintInfo");
	UIPrintInfo *printInfo = [printInfoClass printInfo];
	printInfo.outputType = UIPrintInfoOutputGeneral;
	printInfo.duplex = UIPrintInfoDuplexLongEdge;
	sharedPrintController.printInfo = printInfo;

	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
	    assert(false);  // Really should present from the button that invoked us
	    [sharedPrintController presentFromRect:CGRectMake(0,0,1,1) inView:webView animated:YES
			       completionHandler:completionHandler];
	} else {
	    [sharedPrintController presentAnimated:YES completionHandler:completionHandler];
	}
    } else {
	[[ECErrorReporter theErrorReporter] reportError:@"Printing is not supported with this version of iOS"];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction* )navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    assert([NSThread isMainThread]);
    NSURL *url = [navigationAction.request URL];
    if (![ChronometerAppDelegate helping]) {
	tracePrintf("Skipping startLoad when not helping\n");
        decisionHandler(WKNavigationActionPolicyCancel);
	return; // work around apparent bug where web view points at controller after controller has been destroyed
    }
    assert([ChronometerAppDelegate helping]);
    [self checkBackButton];
    if (backButtonCheckTimer) {
	tracePrintf("*** ECHelpController shouldStartLoad, killing timer");
	[backButtonCheckTimer invalidate];  // in case it's the slow one
    }
    tracePrintf("*** ECHelpController shouldStartLoad, starting fast timer");
    backButtonCheckTimer = [NSTimer scheduledTimerWithTimeInterval:ECBackButtonCheckFastInterval target:self selector:@selector(checkBackButtonFastTimerFire:) userInfo:nil repeats:true];
    backButtonCheckTimerCount = 0;
    if ([url isFileURL]) {
	NSString *title = [[[[url relativeString] lastPathComponent] stringByReplacingOccurrencesOfString:@".html" withString:@""] stringByReplacingOccurrencesOfString:@"%20" withString:@" "];
	tracePrintf2("shouldStartLoadWithRequest: '%@' => '%@'",[url relativeString], title);
	if ([title hasPrefix:@"version"] || [title hasPrefix:@"header"]) {
	    // do nothing
	} else 	if ([title caseInsensitiveCompare:@"PrintMe"] == NSOrderedSame) {
	    [self printCurrentPage];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
	} else 	if ([title caseInsensitiveCompare:@"PrintAllOfUs"] == NSOrderedSame) {
	    [self printAllPages];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
	} else 	if ([title caseInsensitiveCompare:@"ClearAppLog"] == NSOrderedSame) {
	    [ECAppLog clear];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
	} else 	if ([title caseInsensitiveCompare:@"MailAppLog"] == NSOrderedSame) {
	    [ECAppLog mail];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
	} else 	if ([title caseInsensitiveCompare:@"LogFileLink"] == NSOrderedSame) {
	    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(delayedLoadSessionLog:) userInfo:nil repeats:false];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
	}
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
	[self.browser stopLoading];
	lastPage = nil;
	//[self helpless:nil];  // We're quitting anyway, why do this?  If we do it, our user defaults will be wrong.
        [[UIApplication sharedApplication] openURL:[navigationAction.request URL] options:@{} completionHandler:nil];
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)webView:(WKWebView *)webView didFailLoadWithError:(NSError *)error {
    tracePrintf1("didFailLoadWithError:  %s\n", [[error description] UTF8String]);
    goingBack = false;
    NSURL *url = [NSURL fileURLWithPath:[self infoPath:@"Help Contents"]];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    [self.browser loadRequest:req];
}

- (void)checkBackButtonFastTimerFire:(NSTimer *)timer {
    if (++backButtonCheckTimerCount > 30) { // about 3 seconds
	[backButtonCheckTimer invalidate];
	// Revert to slow check, in case an intra-page link doesn't require a load
	backButtonCheckTimer = [NSTimer scheduledTimerWithTimeInterval:ECBackButtonCheckSlowInterval target:self selector:@selector(checkBackButtonSlowTimerFire:) userInfo:nil repeats:true];
	tracePrintf("*** ECHelpController reverting to slow timer, timed out");
    }
    [self checkBackButton];
}

- (void)checkBackButtonSlowTimerFire:(NSTimer *)timer {
    [self checkBackButton];
}

- (void)allUp {
    if (!self.navigationItem.rightBarButtonItem) {
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(helpless:)];
    }
}

- (void)possiblyTurnOnPrintLinksInWebView:(WKWebView *)webView {
    Class uiPrintInteractionControllerClass = NSClassFromString(@"UIPrintInteractionController");
    if (uiPrintInteractionControllerClass && [webView respondsToSelector:@selector(viewPrintFormatter)] && [uiPrintInteractionControllerClass isPrintingAvailable]) {
	NSString *javaScript = @"document.getElementById('printLink1').style.visibility = 'visible';document.getElementById('printLink2').style.visibility = 'visible';";
	//printf("Executing JavaScript:\n%s\n", [javaScript UTF8String]);
	//NSString *returnString =
        [webView evaluateJavaScript:javaScript completionHandler:nil];
	//printf("...got %s\n", [returnString UTF8String]);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    tracePrintf("webView didFinishNavigation");
    //printf("web view bounds when finished loading are %g x %g\n", webView.bounds.size.width, webView.bounds.size.height);
    [self checkBackButton];
    goingBack = false;
    NSString *title = [[[[[self.browser URL] relativeString] lastPathComponent] stringByReplacingOccurrencesOfString:@".html" withString:@""] stringByReplacingOccurrencesOfString:@"%20" withString:@" "];
    NSRange tagRange = [title rangeOfString:@"#"];
    if (tagRange.location != NSNotFound) {
	title = [title substringToIndex:tagRange.location];
    }
    if ([title caseInsensitiveCompare:@"ReleaseNotesGen"] == NSOrderedSame) {
	title = @"Release Notes";
    }
    self.title = title;
    [lastPage release];
    lastPage = [title retain];

    [self possiblyTurnOnPrintLinksInWebView:webView];

    // at first we just animated up the nav bar itself, now do the rest
    if (!fullyOnScreen) {
	[ChronometerAppDelegate infoSlideUp:0 notify:false];
	fullyOnScreen = true;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)didReceiveMemoryWarning {
    tracePrintf("*** ECHelpController got memory warning !!");
//    [super didReceiveMemoryWarning];  // Don't do this; it will destroy the web view, and thus lose our history
}


#ifdef ECTRACE
- (void)viewWillAppear:(BOOL)animated {
    tracePrintf("*** ECHelpController view will appear");
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    tracePrintf("*** ECHelpController view did appear");
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    tracePrintf("*** ECHelpController view will disappear");
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    tracePrintf("*** ECHelpController view did disappear");
    [super viewDidDisappear:animated];
}

- (void)viewDidLoad {
    tracePrintf("*** ECHelpController view did load");
    [super viewDidLoad];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
}

- (void)viewDidUnload {
    tracePrintf("*** ECHelpController view did unload");
    [super viewDidUnload];
}

#endif

@end
