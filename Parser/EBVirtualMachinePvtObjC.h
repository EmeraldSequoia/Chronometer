//
//  EBVirtualMachinePvtObjC.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@class EBVirtualMachine;

double EBVMEvaluateAndAdvanceStream(const char **instructionStream, EBVirtualMachine *virtualMachine);
double EBVMEvaluateAndAdvanceStream(const char       **instructionStream,
				    EBVirtualMachine *virtualMachine);
double *EBVMEvaluateVariableReferenceAndAdvanceStream(const char       **instructionStream,
						      EBVirtualMachine *virtualMachine,
						      bool             initializing);
void EBVMSkipStreamPastExpression(const char       **instructionStream,
				  EBVirtualMachine *virtualMachine);
int EBVMStreamLengthInBytes(const char *instructionStream,
			    EBVirtualMachine *virtualMachine);
void EBVMPrintInstructionStreamRaw(FILE *outputFile, const char *instructionStream, EBVirtualMachine *vm, int indentLevel);
void EBVMPrintInstructionStreamPvt(FILE *outputFile, const char **instructionStream, EBVirtualMachine *vm, int indentLevel);
const char *EBVMCopyInstructionStream(const char *instructionStream, EBVirtualMachine *vm);
