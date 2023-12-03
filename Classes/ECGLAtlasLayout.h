//
//  ECGLAtlasLayout.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@class EBVirtualMachine;

@interface ECGLAtlasLayout : NSObject {
}

+ (void)mergeWatchAtlasesFromArchive:(NSString *)fromArchivePath
			   toArchive:(NSString *)toArchivePath
		 usingVirtualMachine:(EBVirtualMachine *)vm
			   watchName:(NSString *)watchName
		  inArchiveDirectory:(NSString *)archiveDirectory
		usingPngsInDirectory:(NSString *)partPngDirectory
		   isBackgroundWatch:(bool)isBackgroundWatch
                      forDeviceWidth:(int)deviceWidth
                   deviceWidthSuffix:(NSString *)deviceWidthSuffix
	     expectingFrontAtlasSize:(CGSize)expectedFrontAtlasSize
	      expectingBackAtlasSize:(CGSize)expectedBackAtlasSize
	     expectingNightAtlasSize:(CGSize)expectedNightAtlasSize;

@end
