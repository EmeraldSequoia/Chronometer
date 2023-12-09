//
//  ECAppLog.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 7/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#include <stdio.h>
#include <sys/stat.h>

#import "ECGlobals.h"
#import "ECAppLog.h"
#import "ECWatchTime.h"
#import "ECErrorReporter.h"
#import "TSTime.h"

#include "ESCalendar.h"

#include <unistd.h>  // for ftruncate, unlink

static NSString *logFile = nil;

@implementation ECAppLog

static void initLogName(void) {
    assert(ECDocumentDirectory);   // Don't try to log before [ECGlobals initGlobals]
    logFile = [[ECDocumentDirectory stringByAppendingString:@"/ECAppLog.html"] retain];
}

static void writeButtonDivs(FILE *fp) {
    fprintf(fp, "<div width='100%%'><div style='float:left'><form method=POST action='javascript:window.location.reload()'><input type=submit value='Refresh'></form></div>\n");
    fprintf(fp, "<div style='float:right'><form method=POST action='javascript:clear();location.replace(\"ClearAppLog.html\")'><input type=submit value='Clear'></form></div>\n");
    fprintf(fp, "<div style='text-align:center'><form method=POST action='javascript:location.replace(\"MailAppLog.html\")'><input type=submit value='Mail To Developers'></form></div></div>\n");
}

static void writeLogHeader(FILE *fp) {
    fprintf(fp, "<!-- Content ends at %-20ld -->\n", 0L);
    fprintf(fp, "<html><head><meta name=\"viewport\" content=\"width=320\"/></head>\n");
    fprintf(fp, "<script type=\"text/javascript\" language=\"javascript\">\n");
    fprintf(fp, "  function clear() {\n");
    fprintf(fp, "     document.getElementById(\"logContent\").innerHTML = \"\";\n");
    fprintf(fp, "  }\n");
    fprintf(fp, "</script></head><body onLoad=\"self.scrollTo(0,1000000)\">");
    writeButtonDivs(fp);
    fprintf(fp, "<div width='100%%'><hr width='175'><p><div id='logContent'><pre>\n");
}

static void rewriteLogHeader(FILE *fp, size_t contentEndOffset) {
    fseek(fp, 0, SEEK_SET);
    fprintf(fp, "<!-- Content ends at %-20ld -->\n", contentEndOffset);
}

static size_t readContentEndFromHeader(FILE *fp) {
    fseek(fp, 0, SEEK_SET);
    size_t contentEndOffset = 0;
    int ntok = fscanf(fp, "<!-- Content ends at %ld\n", &contentEndOffset);
    if (ntok != 1) {
	contentEndOffset = 0;
    }
    return contentEndOffset;
}

size_t lastContentOffset = 0;

+(void)log:(NSString *)string creatingNewFile:(bool)creatingNewFile firstLineOfSession:(bool)firstLineOfSession {
    if (!logFile) {
	initLogName();
    }
    FILE * fp = fopen([logFile UTF8String], creatingNewFile ? "w+" : "r+");
    if (!fp) {
	perror([logFile UTF8String]);
    }
    assert(fp);
    if (!fp) {
	return;
    }
    if (lastContentOffset == 0 && !creatingNewFile) {  // First time, go get it
	lastContentOffset = readContentEndFromHeader(fp);
    }
    fseek(fp, lastContentOffset, SEEK_SET);
    if (lastContentOffset == 0) {
	writeLogHeader(fp);
    } else {
	fseek(fp, lastContentOffset, SEEK_SET);
    }
    ESTimeZone *estz = ESCalendar_localTimeZone();
    NSTimeInterval dt = [TSTime currentTime];
    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, estz, &ltcs);
    int second = floor(ltcs.seconds);
    int tenthseconds = floor((ltcs.seconds - second) / 10);
    if (!creatingNewFile && firstLineOfSession) {
	fprintf(fp, "\n");
    }
    fprintf(fp, "%2d %02d:%02d:%02d.%01d %s\n",
	    ltcs.day, ltcs.hour, ltcs.minute, second, tenthseconds, [string UTF8String]);
    lastContentOffset = (size_t)ftell(fp);
    if (lastContentOffset > 1100) {
	fprintf(fp, "</pre><hr width='175'>\n");
	writeButtonDivs(fp);
    } else {
	fflush(fp);
	ftruncate(fileno(fp), lastContentOffset);
    }
    rewriteLogHeader(fp, lastContentOffset);
    fclose(fp);
    if (firstLineOfSession) {
        ESSetFileNotBackedUp([logFile UTF8String]);
    }
}

+(void)log:(NSString *)string {
    [self log:string creatingNewFile:false firstLineOfSession:false];
}

+(void)logDeviceInfoCreatingNewFile:(bool)creatingNewFile firstLineOfSession:(bool)firstLineOfSession {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    UIDevice *dev = [UIDevice currentDevice];
    [self log:[NSString stringWithFormat:@"EC %@ %@", version, [dev model]] creatingNewFile:creatingNewFile firstLineOfSession:firstLineOfSession];
    [self log:[NSString stringWithFormat:@"%@ %@", [dev systemName], [dev systemVersion]] creatingNewFile:false firstLineOfSession:false];
}

+(void)newSession {
    if (![logFile UTF8String]) {
	initLogName();
    }
    struct stat s;
    int st = stat([logFile UTF8String], &s);
    bool creatingNewFile;
    if (st == 0) {
	if (s.st_size > 200000) {  // If the old file is > 200k, get rid of it to save space on the device
	    unlink([logFile UTF8String]);
	    creatingNewFile = true;
	    lastContentOffset = 0;
	} else {
	    creatingNewFile = false;
	}
    } else {
	creatingNewFile = true;
    }
    [self logDeviceInfoCreatingNewFile:creatingNewFile firstLineOfSession:true];
}

+(void)clear {
    if (!logFile) {
	initLogName();
    }
    //unlink([logFile UTF8String]);
    FILE *fp = fopen([logFile UTF8String], "w");
    if (!fp) {
	perror([logFile UTF8String]);
    }
    assert(fp);
    writeLogHeader(fp);
    lastContentOffset = (size_t)ftell(fp);
    fclose(fp);
}

-(BOOL)canOpenURL:(NSURL *)url {  // Fake out compiler
    return NO;
}

+(void)mail {
    [self logDeviceInfoCreatingNewFile:false firstLineOfSession:false];
    NSString *logFileContents = [NSString stringWithContentsOfFile:logFile encoding:NSUTF8StringEncoding error:NULL];
    NSRange preRange = [logFileContents rangeOfString:@"<pre>\n"];
    if (preRange.length == 0) {
	return;  // Nothing to do
    }
    NSUInteger contentStart = preRange.location + preRange.length;
    NSRange contentRange;
    contentRange.location = contentStart;
    if (contentStart > lastContentOffset) {
	return;  // Nothing to do
    }
    contentRange.length = lastContentOffset - contentStart;
    logFileContents = [NSString stringWithFormat:@"%@\n%@", [[NSDate date] description], [logFileContents substringWithRange:contentRange]];
    NSString *urlString = [NSString stringWithFormat:@"mailto:essupport@emeraldsequoia.com?subject=Emerald%%20Chronometer%%20Session%%20Log&body=%@",
				    [logFileContents stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet]];
    id app = [UIApplication sharedApplication];
    NSURL *url = [NSURL URLWithString:urlString];
    if ([app respondsToSelector:@selector(canOpenURL:)] &&
	![app canOpenURL:url]) {
	[[ECErrorReporter theErrorReporter] reportError:@"No mail application on this device"];
	return;
    }
    [app openURL:url options:@{} completionHandler:nil];
}

+(NSString *)logFileName {
    if (![logFile UTF8String]) {
	initLogName();
    }
    return logFile;
}

@end
