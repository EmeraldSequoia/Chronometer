//
//  ECAddressKey.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#include "ECAddressKey.h"

@implementation ECAddressKey

-(id)initWithAddress:(id)addr {
    [super init];
    address = [addr retain];
    return self;
}

-(void)dealloc {
    [address release];
    [super dealloc];
}

+(ECAddressKey *)keyForAddress:(id)address {
    return [[[ECAddressKey alloc] initWithAddress:address] autorelease];
}

-(id)getID {
    return address;
}

// Methods necessary for keys
-(id)copyWithZone:(NSZone *)zone {
    return [[ECAddressKey allocWithZone:zone] initWithAddress:address];
}

-(NSUInteger)hash {
    return (NSUInteger)address;
}

-(BOOL)isEqual:(id)other {
    return address == ((ECAddressKey *)other)->address;
}

@end
