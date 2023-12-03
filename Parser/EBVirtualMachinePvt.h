//
//  EBVirtualMachinePvt.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

extern const char *EBEncodeIntegerConstant(const char *integerConstant);
extern const char *EBEncodeDoubleConstant(const char *doubleConstant);
extern const char *EBEncodeDoubleEConstant(const char *doubleEConstant);
extern const char *EBConcatenateArgumentList(const char *priorList, const char *newArgument);
extern const char *EBEncodeOpcodeWithVariableValue(const char *identifierName);
extern const char *EBEncodeOpcodeWithFunctionWithNoArgs(const char *identifierName);
extern const char *EBEncodeOpcodeWithFunctionWithArgs(const char *identifierName, const char *encodedArguments);
extern const char *EBEncodeOpcodeWithAssignmentOperator(const char *opcodeString, const char *variableName, const char *value);
extern const char *EBEncodeOpcodeWithUnaryOperator(const char *opcodeString, const char *parameter);
extern const char *EBEncodeOpcodeWithBinaryOperator(const char *opcodeString, const char *parameter1, const char *parameter2);
extern const char *EBEncodeOpcodeWithTrinaryOperator(const char *opcodeString, const char *parameter1, const char *parameter2, const char *parameter3);
extern void EBSetRootExpression(const char *expression);
extern void EBReportYaccError(const char *string, int column);

extern double EBVMReadDoubleAndAdvanceStream(const char **instructionStream);
extern void EBVMSkipStreamPastDouble(const char **instructionStream);
extern int EBVMSkipPastAndReturnInt(const char **instructionStream);
extern void EBVMSkipPastVariableReference(const char **instructionStream);

extern void EBAddOpcodeToDictionary(int opcode, const char *opcodeName);

// Implemented in c.l:
extern void EBSetInputString(const char *);
