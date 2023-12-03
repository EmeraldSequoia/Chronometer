//
//  EBVirtualMachine.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <stdio.h>  // For FILE *

#ifndef NDEBUG
#define VM_READABLE_STRING
#endif

@class EBVirtualMachine;

@protocol EBVirtualMachineErrorDelegate
-(void)reportError:(NSString *)errorDescription;
@end

@interface EBStdoutErrorReporter : NSObject<EBVirtualMachineErrorDelegate> {
}

-(void)reportError:(NSString *)errorDescription;
+(EBStdoutErrorReporter *)theErrorReporter;

@end

typedef void (*EBVMvariableImporter)(EBVirtualMachine *vm);

#ifdef EC_HENRY_ANDROID
#define ESVM_BRIDGE
#endif // EC_HENRY_ANDROID

#ifdef ESVM_BRIDGE
#include "ECESVMBridge.h"

#else  // !ESVM_BRIDGE

@interface EBVMInstructionStream : NSObject {
    const char *instructionStream;
#ifdef VM_READABLE_STRING
    NSString *readableString;
#endif
}

-(id)initWithRawStream:(const char *)str;
#ifdef VM_READABLE_STRING
-(void)setReadableString:(NSString *)string;
#endif
-(void)dealloc;

-(void)printToOutputFile:(FILE *)outputFile withIndentLevel:(int)indentLevel fromVirtualMachine:(EBVirtualMachine *)virtualMachine;
-(void)writeInstructionStreamToFile:(FILE *)filePointer forVirtualMachine:(EBVirtualMachine *)virtualMachine;
-(id)initFromFilePointer:(FILE *)filePointer withStreamLength:(int)streamLength forVirtualMachine:(EBVirtualMachine *)virtualMachine pathForDebugMsgs:(NSString *)path;

-(const char *)rawStream;

@end

@interface EBVirtualMachine : NSObject {
@public
    id           	errorDelegate;
@protected
    NSMutableDictionary *opcodesByName;
    NSMutableDictionary *variableCodesByName;
    NSMutableDictionary *variableNamesByCode;
    const char     	*instructionStreamReturn;
    int                 numVariables;
    double              *variableValues;
    bool                *variableInitializationDone;
    int                 variableArraySize;
    id                  owner;
    NSString		*name;
}

@property (readonly, nonatomic) NSString *name;

-(id)initWithOwner:(id)owner name:(NSString *)nam;
-(id)initWithOwner:(id)owner name:(NSString *)nam variableCount:(int)variableCount variableImporter:(EBVMvariableImporter)variableImporter;
-(id)init;  // deprecated; do not use
-(id)owner;
-(void)importVariableWithName:(NSString *)name andValue:(double)value;
-(int)numVariables;
#ifdef EC_HENRY
-(void)writeVariableNamesToFile:(NSString *)filename;
-(void)readVariableNamesFromFile:(NSString *)filename;
#endif
-(void)dumpVariableValues;
-(bool)variableWithIndexIsDefined:(int)indx;
-(double)variableValueForIndex:(int)indx;

-(EBVMInstructionStream *)streamBeingEvaluated;
-(void)printCurrentStream;

-(NSString *)variableNameForCode:(int)varcode;

-(double)evaluateInstructionStream:(EBVMInstructionStream *)instructionStream errorReporter:(id)errorReporter;
-(EBVMInstructionStream *)compileInstructionStreamFromCExpression:(NSString *)CExpressionString errorReporter:(id)errorReporter;

+(EBVirtualMachine *)theMachine;

@end

#endif // !ESVM_BRIDGE
