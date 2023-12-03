//
//  ECHelpController.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/7/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@interface ECHelpController : UIViewController <WKUIDelegate, WKNavigationDelegate> {
    NSString	*lastPage;			// path of last page viewed
    NSTimer     *backButtonCheckTimer;
    int         backButtonCheckTimerCount;
    bool goingBack;
    bool fullyOnScreen;
}

@property(nonatomic, assign) WKWebView *browser;

- (void)showHelp:(NSString *)topic;
- (void)allUp;
- (void)helpless:(id)sender;
@end
