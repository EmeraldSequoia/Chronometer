//
//  ECGlobals.m
//  Emerald Chronometer
//
//  Created by Steve Pucci in Aug 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECGlobals.h"
#import "Constants.h"
#import "EBVirtualMachine.h"
#import "ECErrorReporter.h"
#include "ECVariables.h"

#include <sys/stat.h>  // For fstat
#include <fcntl.h>  // For open
#include <unistd.h>  // For read
#include <sys/xattr.h>  // For setxattr

// For socket code to connect to command server:
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>

//  Data requiring fast access
NSString *ECbundleDirectory = nil;
NSString *ECbundleArchiveDirectory = nil;
NSString *ECcacheArchiveDirectory = nil;
#ifdef EC_HENRY
NSString *ECbundleXMLDirectory = nil;
NSString *ECTempPngDirectory = nil;
NSString *ECbundleSandboxDirectory = nil;
NSString *ECbundleProductDirectory = nil;
NSString *ECbundleProductName = nil;
#else // NOT Henry
NSString *ECarchiveVersion;
NSString *ECfullArchiveVersion;
#endif
NSString *ECDocumentDirectory = nil;
NSString *ECDocumentArchiveDirectory = nil;
NSFileManager *ECfileManager = nil;
ECErrorReporter *ECtheErrorReporter = nil;
const char *ECmodeNames[ECNumWatchDrawModes] = { "front", "night", "back"/*, "back night"*/ };
bool ECisPre30 = false;
bool ECSingleWatchProduct = false;

double ECVisualZoomFactors[ECNumVisualZoomFactors];
int ECCalendarWeekdayStart = 0;

bool isIpad(void) {
#if __IPHONE_3_2
    static bool initialized = false;
    static bool isipad = false;
    if (!initialized) {
	if ([UIDevice instancesRespondToSelector:@selector(userInterfaceIdiom)]) {
	    isipad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
	    //printf("sez it's %s\n", isIpad ? "ipad" : "not ipad");
	} else {
	    isipad = false;
	}
        initialized = true;
    }
    return isipad;
#else
    return false;
#endif
}

@implementation ECGlobals

+ (void)initGlobals {
    NSBundle *mainBundle = [NSBundle mainBundle];
    ECbundleDirectory = [[mainBundle resourcePath] retain];
    NSDictionary *dict = [mainBundle infoDictionary];
    assert(dict);

    ECfileManager = [[NSFileManager defaultManager] retain];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    ECDocumentDirectory = [paths objectAtIndex:0];
    [ECDocumentDirectory retain];
    ECDocumentArchiveDirectory = [[ECDocumentDirectory stringByAppendingPathComponent:@"archive"] retain];
    // printf("Document archive directory %s\n", [ECDocumentArchiveDirectory UTF8String]);
    if (![ECfileManager fileExistsAtPath:ECDocumentArchiveDirectory]) {
        //printf("... doesn't exist\n");
	NSError *error;
	BOOL createOK = [ECfileManager createDirectoryAtPath:ECDocumentArchiveDirectory withIntermediateDirectories:YES attributes:nil error:&error];
	if (!createOK) {
#ifndef NDEBUG
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error creating cache directory: %@", [error description]]];
#endif
	}
    }
    ESSetFileNotBackedUp([ECDocumentArchiveDirectory UTF8String]);  // yust in case
#ifdef EC_HENRY
    ECbundleProductName = [dict objectForKey:@"CFBundleDisplayName"];
    // printf("Product name %s\n", [ECbundleProductName UTF8String]);
    assert(ECbundleProductName);
    ECbundleXMLDirectory = [[[mainBundle resourcePath] stringByAppendingPathComponent:@"Watches"] retain];
    ECTempPngDirectory = [[ECDocumentDirectory stringByAppendingString:@"/archivePartPngs"] retain];
    ECbundleProductDirectory = [[NSString stringWithFormat:@"%@/products/%@", [mainBundle resourcePath], ECbundleProductName] retain];
    // printf("Product directory %s\n", [ECbundleProductDirectory UTF8String]);
#else // NOT Henry
    NSString *bundleVersion = [dict objectForKey:@"CFBundleVersion"];
    ECarchiveVersion = [readSingleStringFromTextFile(@"/archive/archiveVersion.txt") retain];
    //printf("Found archive version %s\n", [ECarchiveVersion UTF8String]);
    ECfullArchiveVersion = [[NSString stringWithFormat:@"%@_r%@", bundleVersion, ECarchiveVersion] retain];
    //printf("Constructed full archive version %s\n", [ECfullArchiveVersion UTF8String]);
#endif
    ECtheErrorReporter = [ECErrorReporter theErrorReporter];

#ifdef EC_HENRY
    ECbundleArchiveDirectory = [[ECDocumentDirectory stringByAppendingPathComponent:@"archive"] retain];
    ECcacheArchiveDirectory = [[ECDocumentArchiveDirectory stringByReplacingOccurrencesOfString:@"/archive" withString:@"/archiveSpecial"] retain];
#else
    ECbundleArchiveDirectory = [[ECbundleDirectory stringByAppendingPathComponent:@"/archive"] retain];
    ECcacheArchiveDirectory = [ECDocumentArchiveDirectory retain];
#endif

#if ECZoomMinPower2 < 0
    double z = 1.0/(1 << (-ECZoomMinPower2));
#else
    double z = 1 << ECZoomMinPower2;
#endif
    double * const zpl = ECVisualZoomFactors + ECNumVisualZoomFactors;
    for (double *zp = &ECVisualZoomFactors[0]; zp < zpl; z *= 2) {
	*zp++ = z;
    }
    UIDevice *dev = [UIDevice currentDevice];
    ECisPre30 = ![dev respondsToSelector:@selector(batteryLevel)];
}

// Tested with negative numbers, works:
double
EC_fmod(double arg1,
	double arg2)
{
    return (arg1 - floor(arg1/arg2)*arg2);
}

void ECImportVariables(EBVirtualMachine *vm) {
    for (int i = 0; i < ECNumPredefinedVariables; i++) {
        struct ECPredefinedVariable *var = ECPredefinedVariables + i;
        [vm importVariableWithName:[NSString stringWithUTF8String:var->name] 
                          andValue:var->value];
    }
    [vm importVariableWithName:@"body" andValue:[[NSUserDefaults standardUserDefaults] doubleForKey:[vm.name stringByAppendingString:@"-body"]]];
}

#ifndef NDEBUG
NSString *nameOfPlanetWithNumber(int planetNumber) {
    switch(planetNumber) {
      case ECPlanetSun:
	return @"Sun";
      case ECPlanetMoon:
	return @"Moon";
      case ECPlanetMercury:
	return @"Mercury";
      case ECPlanetVenus:
	return @"Venus";
      case ECPlanetEarth:
	return @"Earth";
      case ECPlanetMars:
	return @"Mars";
      case ECPlanetJupiter:
	return @"Jupiter";
      case ECPlanetSaturn:
	return @"Saturn";
      case ECPlanetUranus:
	return @"Uranus";
      case ECPlanetNeptune:
	return @"Neptune";
      case ECPlanetPluto:
	return @"Pluto";
      default:
	return [NSString stringWithFormat:@"Unknown planet number %d", planetNumber];
    }
    
}
#endif

#if 0
#if TARGET_IPHONE_SIMULATOR
int EC_fstat(int filedes, struct stat *buf) {
    // hack for iPad simulator
    extern int fstat64(int fildes, struct stat *buf);
    return fstat64(filedes, buf);
}
#endif
#endif

void *readBinaryFileIntoMallocedArrayAtAbsolutePath(NSString *absolutePath, size_t *bytesRead) {
    int fd = open([absolutePath UTF8String], O_RDONLY);
    if (fd < 0) {
	return nil;
//	perror([[NSString stringWithFormat:@"Error opening binary file %@", absolutePath] UTF8String]);
//	exit(1);
    }
    struct stat buf;
    int st = EC_fstat(fd, &buf);
    if (st != 0) {
	perror([[NSString stringWithFormat:@"Error running fstat on file %@", absolutePath] UTF8String]);
	exit(1);
    }
    size_t fileSize = buf.st_size;
    if (fileSize <= 0) {
	perror([[NSString stringWithFormat:@"Apparently empty file %@", absolutePath] UTF8String]);
	exit(1);
    }
    char *storage = (char *)malloc(fileSize + 1);
    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"GeoNames binary start: reading %@", absolutePath] UTF8String]];
    *bytesRead = read(fd, storage, fileSize);
    if (*bytesRead != fileSize) {
	perror([[NSString stringWithFormat:@"Failed to read entire file %@", absolutePath] UTF8String]);
	exit(1);
    }
    close(fd);
    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"GeoNames binary finish: read %d bytes", fileSize] UTF8String]];
    return storage;
}

void writeBinaryFileFromMallocedArrayAtAbsolutePath(NSString *absolutePath, char *storage, size_t fileSize) {
    int fd = open([absolutePath UTF8String], O_CREAT|O_TRUNC|O_RDWR, 0x777);
    if (fd < 0) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error opening binary file %@ for write: %s", absolutePath, strerror(errno)]];
	return;
    }
    ssize_t bytesWritten = write(fd, storage, fileSize);
    if (bytesWritten != fileSize) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Failed to write entire file %@: %s", absolutePath, strerror(errno)]];
	return;
    }
    close(fd);
}

void *readBinaryFileIntoMallocedArray(NSString *relativePath, size_t *bytesRead) {
    NSString *absolutePath = [ECbundleDirectory stringByAppendingString:relativePath];
    // printf("Opening application binary file at %s\n", [[NSString stringWithFormat:@"GeoNames binary open %@", absolutePath] UTF8String]);
    return readBinaryFileIntoMallocedArrayAtAbsolutePath(absolutePath, bytesRead);
}

void *readBinaryFileIntoMallocedArrayFromDocumentDirectory(NSString *relativePath, size_t *bytesRead) {
    NSString *absolutePath = [ECDocumentDirectory stringByAppendingString:relativePath];
    // printf("Opening document binary file at %s\n", [[NSString stringWithFormat:@"GeoNames binary open %@", absolutePath] UTF8String]);
    return readBinaryFileIntoMallocedArrayAtAbsolutePath(absolutePath, bytesRead);
    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"GeoNames binary open %@", absolutePath] UTF8String]];
}

void writeBinaryFileFromMallocedArrayToDocumentDirectory(NSString *relativePath, char *storage, size_t fileSize) {
    NSString *absolutePath = [ECDocumentDirectory stringByAppendingString:relativePath];
    writeBinaryFileFromMallocedArrayAtAbsolutePath(absolutePath, storage, fileSize);
}

NSArray *readStringsFileAtAbsolutePathIntoNSArray(NSString *absolutePath, int arraySizeGuess) {
    NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:arraySizeGuess];
    size_t bytesRead;
    char *names = (char *)readBinaryFileIntoMallocedArrayAtAbsolutePath(absolutePath, &bytesRead);
    char *ptr = names;
    char *end = names + bytesRead;
    while (ptr < end) {
	char *adv = ptr;
	while (*adv++)
	    ;  // empty
	[arr addObject:[NSString stringWithUTF8String:ptr]];
	assert(adv <= end);
	ptr = adv;
    }
    free(names);
    return arr;
}

void readStringsFileIntoNSArray(NSString *relativePath, NSArray **arrayOut, int arraySizeGuess) {
    NSString *absolutePath = [ECbundleDirectory stringByAppendingString:relativePath];
    *arrayOut = readStringsFileAtAbsolutePathIntoNSArray(absolutePath, arraySizeGuess);
}

unsigned int readSingleUnsignedFromFile(NSString *relativePath) {
    NSString *absolutePath = [ECbundleDirectory stringByAppendingString:relativePath];
    int fd = open([absolutePath UTF8String], O_RDONLY);
    if (fd < 0) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error opening binary file %@: %s", absolutePath, strerror(errno)]];
	return 0;
    }
    unsigned int storage;
    size_t bytesRead = read(fd, &storage, sizeof(unsigned int));
    if (bytesRead != sizeof(unsigned int)) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error reading binary file %@: %s", absolutePath, strerror(errno)]];
	return 0;
    }
    close(fd);
    return storage;
}

NSString *readSingleStringFromTextFile(NSString *relativePath) {
    NSString *absolutePath = [ECbundleDirectory stringByAppendingString:relativePath];
    FILE *fp = fopen([absolutePath UTF8String], "r");
    if (!fp) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error opening text file %@: %s", absolutePath, strerror(errno)]];
	return nil;
    }
    char buf[32];
    int itemsRead = fscanf(fp, "%31s", buf);
    if (itemsRead != 1) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error reading text file %@: %s", absolutePath, strerror(errno)]];
	return nil;
    }
    fclose(fp);
    return [NSString stringWithUTF8String:buf];
}

void ESSetFileNotBackedUp(const char *filename) {
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
 
    int result = setxattr(filename, attrName, &attrValue, sizeof(attrValue), 0, 0);
    if (result == 0) {
        //printf("Set attribute successfully on %s\n", filename);
    } else {
        printf("Set attribute FAILED on %s\n", filename);
        perror("mobile backup attribute set via setxattr");
    }
}

NSString *
sendCommandToCommandServer(const char *cmdStr) {
    static char *host = "127.0.0.1";
    static int port = 7890;
    
    struct sockaddr_storage addr;
    struct sockaddr_in *sockp = (struct sockaddr_in *)&addr;
    int family = PF_INET;
    int addrlen = sizeof(struct sockaddr_in);
    int socktype = SOCK_STREAM;
    int protocol = 6; // TCP
    sockp->sin_len = sizeof(struct sockaddr_in);
    sockp->sin_family = AF_INET;
    sockp->sin_port = htons(port);
    int st = inet_pton(AF_INET, host, &sockp->sin_addr);
    if (st != 1) {
        perror("inet_pton from command server connection");
        assert(false);
        return @"";
    }
    int fd = socket(family, socktype, protocol);
    if (fd < 0) {
        perror("socket() call from command server connection");
        assert(false);
        return @"";
    }
    st = connect(fd, (struct sockaddr *)&addr, addrlen);
    if (st != 0) {
        perror("socket() call from command server connection");
        printf("Run (in a terminal window) the command 'scripts/commandServer.pl' from the top level of the sandbox\n");
        printf("... and leave it running while ChronometerWithHenry{,HD} completes\n");
        assert(false);
        return @"";
    }
    int length = strlen(cmdStr) + 1;
    ssize_t sz = send(fd, cmdStr, length, 0);
    if (sz == ((size_t)-1)) {
        perror("send() call from command server connection");
        assert(false);
        return @"";
    }
    // Now wait for command server to finish command
    NSString *s = @"";
    ssize_t len;
    do {
        char answer[1024];
        len = recv(fd, answer, sizeof(answer)-1, 0);
        if (len > 0) {
            assert(len < 1024);
            answer[len] = '\0';
            // printf("Command output: %s\n", answer);
            s = [s stringByAppendingString:[NSString stringWithUTF8String:answer]];
        }
    } while (len > 0);
    if (len < 0) {
        perror("recv() call from command server connection");
        assert(false);
        return @"";
    }
    return s;
}

@end

