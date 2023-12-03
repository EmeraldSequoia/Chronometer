//
//  ECAddressKey.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

// This class is to support using arbitrary objects as keys in dictionaries without copying them
@interface ECAddressKey : NSObject<NSCopying> {
    id   address;
}

+(ECAddressKey *)keyForAddress:(id)address;

-(id)initWithAddress:(id)address;
-(void)dealloc;

-(id)getID;

// Methods necessary for keys
-(id)copyWithZone:(NSZone *)zone;
-(NSUInteger)hash;
-(BOOL)isEqual:(id)other;

@end

