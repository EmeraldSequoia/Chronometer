//
//  ECGlobals.h
//  Emerald Chronometer
//
//  Created by Steve Pucci in Aug 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#include "Constants.h"

@class EBVirtualMachine, ECErrorReporter;

//  Data requiring fast access

extern NSString *ECbundleDirectory;
extern NSString *ECbundleArchiveDirectory;
extern NSString *ECcacheArchiveDirectory;
#ifdef EC_HENRY
extern NSString *ECTempPngDirectory;
extern NSString *ECbundleXMLDirectory;
extern NSString *ECbundleProductDirectory;
extern NSString *ECbundleProductName;
#else // NOT Henry
extern NSString *ECarchiveVersion;
extern NSString *ECfullArchiveVersion;
#endif
extern NSString *ECDocumentDirectory;
extern NSString *ECDocumentArchiveDirectory;
extern NSFileManager *ECfileManager;
extern ECErrorReporter *ECtheErrorReporter;
extern size_t   ECMaxLoadedTextureSize;
extern const char *ECmodeNames[ECNumWatchDrawModes];
extern int ECCalendarWeekdayStart;	// 0 == Sunday; 1 == Monday; 6 == Saturday

extern bool ECisPre30;

extern bool ECSingleWatchProduct;

extern double EC_fmod(double arg1, double arg2);
extern void ECImportVariables(EBVirtualMachine *vm);

extern double ECVisualZoomFactors[];

#ifndef NDEBUG
extern NSString *nameOfPlanetWithNumber(int planetNumber);
#endif

extern void *readBinaryFileIntoMallocedArray(NSString *relativePath, size_t *bytesRead);
extern void *readBinaryFileIntoMallocedArrayFromDocumentDirectory(NSString *relativePath, size_t *bytesRead);
extern void *readBinaryFileIntoMallocedArrayAtAbsolutePath(NSString *absolutePath, size_t *bytesRead);
extern void readStringsFileIntoNSArray(NSString *relativePath, NSArray **arrayOut, int arraySizeGuess);
extern NSArray *readStringsFileAtAbsolutePathIntoNSArray(NSString *relativePath, int arraySizeGuess);
extern void writeBinaryFileFromMallocedArrayToDocumentDirectory(NSString *relativePath, char *storage, size_t fileSize);
extern unsigned int readSingleUnsignedFromFile(NSString *relativePath);
extern NSString *readSingleStringFromTextFile(NSString *relativePath);

extern NSString *sendCommandToCommandServer(const char *cmdStr);

extern void ESSetFileNotBackedUp(const char *filename);

extern bool isIpad(void);

#if EC_HENRY_ANDROID
static const int androidWatchOutputWidths[]  = {480};
static const int numAndroidWatchOutputWidths = sizeof(androidWatchOutputWidths) / sizeof(int);
#endif

// Hack around bug in iPad simulator
//#if TARGET_IPHONE_SIMULATOR
#if 0
struct stat;
extern int EC_fstat(int filedes, struct stat *buf);
#else
#define EC_fstat(filedes, buf) fstat(filedes, buf)
#endif

@interface ECGlobals : NSObject {
}

+ (void)initGlobals;

@end
