//
//  ECESVMBridge.h
//
//  Created by Steve Pucci 18 Jan 2016
//  Copyright Emerald Sequoia LLC 2016. All rights reserved.
//

#ifndef _ECESVMBRIDGE_H_
#define _ECESVMBRIDGE_H_

#include "ESPlatform.h"

ES_OPAQUE_CPLUSPLUS(VMErrorReporter);
ES_OPAQUE_CPLUSPLUS(ESVirtualMachine);
ES_OPAQUE_CPLUSPLUS(ESVMInstructionStream);
ES_OPAQUE_CPLUSPLUS(ESChronoVMOwner);
ES_OPAQUE_OBJC(EBVirtualMachine);

/** This class acts as a bridge for ESVMIstructionStream. */
@interface EBVMInstructionStream : NSObject {
@public
    ESVMInstructionStream   *stream;
}

-(id)initWithStream:(ESVMInstructionStream *)stream;
-(void)printToOutputFile:(FILE *)outputFile withIndentLevel:(int)indentLevel fromVirtualMachine:(EBVirtualMachine *)virtualMachine;
-(void)writeInstructionStreamToFile:(FILE *)filePointer forVirtualMachine:(EBVirtualMachine *)virtualMachine;
-(id)initFromFilePointer:(FILE *)filePointer withStreamLength:(int)streamLength forVirtualMachine:(EBVirtualMachine *)virtualMachine pathForDebugMsgs:(NSString *)path;

@end

/** This class acts as a bridge to ESVirtualMachine.
 *  This is useful when generating atlases and archives for
 *  Android or other esvm-based apps.
 */
@interface EBVirtualMachine : NSObject {
    ESVirtualMachine *vm;
    ESChronoVMOwner  *vmOwner;
    VMErrorReporter  *vmErrorReporter;
    id               unusedCocoaOwner;
}

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) ESVirtualMachine *vm;

-(id)initWithOwner:(id)owner name:(NSString *)nam;
-(id)initWithOwner:(id)owner name:(NSString *)nam variableCount:(int)variableCount variableImporter:(EBVMvariableImporter)variableImporter;
-(id)init;
-(id)owner;
-(void)importVariableWithName:(NSString *)name andValue:(double)value;
-(int)numVariables;
-(void)writeVariableNamesToFile:(NSString *)filename;
-(void)readVariableNamesFromFile:(NSString *)filename;
-(void)dumpVariableValues;
-(bool)variableWithIndexIsDefined:(int)indx;
-(double)variableValueForIndex:(int)indx;

// -(EBVMInstructionStream *)streamBeingEvaluated;
-(void)printCurrentStream;

-(NSString *)variableNameForCode:(int)varcode;

-(double)evaluateInstructionStream:(EBVMInstructionStream *)instructionStream errorReporter:(id)errorReporter;
-(EBVMInstructionStream *)compileInstructionStreamFromCExpression:(NSString *)CExpressionString errorReporter:(id)errorReporter;

@end

#endif  // _ECESVMBRIDGE_H_
