//
//  EBVirtualMachineOps.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#include <math.h>
#include <stdio.h>
#include <assert.h>

#include "EBVirtualMachineOps.h"

#include "EBVirtualMachine.h"
#include "EBVirtualMachinePvt.h"
#include "EBVirtualMachinePvtObjC.h"

// **************************************************************************
// Builtin operations that appear as functions in C expressions
// Each operation starts with a function name, and is followed by any number of arguments
// The type of all arguments, and the return type, of all operations, are all doubles.
// **************************************************************************
EBVM_OP0(pi)
{
    return M_PI;
}

EBVM_OP1(round, arg)
{
    return (double)(llrint(arg));
}

EBVM_OP1(floor, arg)
{
    return floor(arg);
}

EBVM_OP1(ceil, arg)
{
    return ceil(arg);
}

// **************************************************************************
// C operators that simply operate on doubles
// **************************************************************************
EBVM_OP1_SIMPLE(unaryPlus,  arg, +)
EBVM_OP1_SIMPLE(unaryMinus, arg, -)

EBVM_OP2_SIMPLE(binaryPlus,         arg1, arg2, +)
EBVM_OP2_SIMPLE(binaryMinus,        arg1, arg2, -)
EBVM_OP2_SIMPLE(multiply,           arg1, arg2, *)
EBVM_OP2_SIMPLE(divide,             arg1, arg2, /)
EBVM_OP2_SIMPLE(lessThan,           arg1, arg2, <)
EBVM_OP2_SIMPLE(greaterThan,        arg1, arg2, >)
EBVM_OP2_SIMPLE(lessThanOrEqual,    arg1, arg2, <=)
EBVM_OP2_SIMPLE(greaterThanOrEqual, arg1, arg2, >=)
EBVM_OP2_SIMPLE(equal,    	    arg1, arg2, ==)
EBVM_OP2_SIMPLE(notEqual, 	    arg1, arg2, !=)

// **************************************************************************
// C operators whose arguments must be converted to integers before operating
// **************************************************************************
EBVM_OP1_INTEGER(bitwiseNot, arg, ~)
EBVM_OP1_INTEGER(logicalNot, arg, !)

EBVM_OP2_INTEGER(mod,        arg1, arg2, %)
EBVM_OP2_INTEGER(leftShift,  arg1, arg2, <<)
EBVM_OP2_INTEGER(rightShift, arg1, arg2, >>)
EBVM_OP2_INTEGER(bitwiseAnd, arg1, arg2, &)
EBVM_OP2_INTEGER(bitwiseOr,  arg1, arg2, |)
EBVM_OP2_INTEGER(bitwiseXor, arg1, arg2, ^)

// **************************************************************************
// C assignment operators that operate on doubles; we don't implement integer
// assigns
// **************************************************************************
EBVM_OP2_ASSIGN(assign, lval, arg, =)
EBVM_OP2_ASSIGN(plusAssign, lval, arg, +=)
EBVM_OP2_ASSIGN(minusAssign, lval, arg, -=)
EBVM_OP2_ASSIGN(multiplyAssign, lval, arg, *=)
EBVM_OP2_ASSIGN(divideAssign, lval, arg, /=)

// **************************************************************************
// Operators whose arguments are not evaluated unless needed by C semantics
// **************************************************************************
EBVM_OP3_SPECIAL(questionColon, instructionStream, virtualMachine)
{
    double condition = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
    if (condition > 0.5) {
        double returnValue = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
        EBVMSkipStreamPastExpression(instructionStream, virtualMachine);
        return returnValue;
    } else {
        EBVMSkipStreamPastExpression(instructionStream, virtualMachine);
        return EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
    }
}

EBVM_OP2_SPECIAL(logicalAnd, instructionStream, virtualMachine)
{
    double arg1 = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
    if (arg1 > 0.5) {
	double arg2 = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
	return (double)(arg2 > 0.5);
    } else {
	EBVMSkipStreamPastExpression(instructionStream, virtualMachine);
	return 0.0;
    }
}

EBVM_OP2_SPECIAL(logicalOr, instructionStream, virtualMachine)
{
    double arg1 = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
    if (arg1 > 0.5) {
	EBVMSkipStreamPastExpression(instructionStream, virtualMachine);
	return 1.0;
    } else {
	double arg2 = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
	return (double)(arg2 > 0.5);
    }
}

EBVM_OPX_SPECIAL(constant, instructionStream, virtualMachine)
{
    double retVal = EBVMReadDoubleAndAdvanceStream(instructionStream);
    return retVal;
}

void EB_constant_skip(const char **instructionStream,
		      EBVirtualMachine *virtualMachine)
{
    EBVMSkipStreamPastDouble(instructionStream);
}

void EB_constant_print(FILE             *outputFile,
		       const char **instructionStream,
		       EBVirtualMachine *virtualMachine,
		       int          indentLevel)
{
    int i;
    for (i = 0; i < indentLevel; i++) {
        fprintf(outputFile, "  ");
    }
    fprintf(outputFile, "constant\n");
    double value = EBVMReadDoubleAndAdvanceStream(instructionStream);
    for (i = 0; i < indentLevel + 1; i++) {
        fprintf(outputFile, "  ");
    }
    fprintf(outputFile, "%g\n", value);
}

EBVM_OPX_SPECIAL(variable, instructionStream, virtualMachine)
{
    double *variableReference = EBVMEvaluateVariableReferenceAndAdvanceStream(instructionStream, virtualMachine, false);
    return *variableReference;
}

void EB_variable_skip(const char **instructionStream,
		      EBVirtualMachine *virtualMachine)
{
    EBVMSkipPastAndReturnInt(instructionStream);
}

void EB_variable_print(FILE             *outputFile,
		       const char       **instructionStream,
		       EBVirtualMachine *virtualMachine,
		       int              indentLevel)
{
    int i;
    for (i = 0; i < indentLevel; i++) {
        fprintf(outputFile, "  ");
    }
    fprintf(outputFile, "variable\n");
    int varcode = EBVMSkipPastAndReturnInt(instructionStream);
    for (i = 0; i < indentLevel + 1; i++) {
        fprintf(outputFile, "  ");
    }
    NSString *variableNameString = [virtualMachine variableNameForCode:varcode];
    NSString *variableValue = nil;
    if ([virtualMachine variableWithIndexIsDefined:varcode]) {
	variableValue = [NSString stringWithFormat:@"%.4f", [virtualMachine variableValueForIndex:varcode]];
    } else {
	variableValue = @"undefined";
    }
    fprintf(outputFile, "%d (%s) %s\n", varcode, [variableNameString UTF8String], [variableValue UTF8String]);
}

EBVM_OPX_SPECIAL(expressionList, instructionStream, virtualMachine)
{
    int numArguments = EBVMSkipPastAndReturnInt(instructionStream);
    int i;
    double arg = 0;
    for (i = 0; i < numArguments; i++) {
	arg = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
    }
    return arg;
}

void EB_expressionList_skip(const char **instructionStream,
			    EBVirtualMachine *virtualMachine)
{
    int numArguments = EBVMSkipPastAndReturnInt(instructionStream);
    int i;
    for (i = 0; i < numArguments; i++) {
	EBVMSkipStreamPastExpression(instructionStream, virtualMachine);
    }
}

void EB_expressionList_print(FILE *outputFile,
			     const char **instructionStream,
			     EBVirtualMachine *virtualMachine,
			     int       indentLevel)
{
    int numArguments = EBVMSkipPastAndReturnInt(instructionStream);
    int i;
    for (i = 0; i < indentLevel; i++) {
        fprintf(outputFile, "  ");
    }
    fprintf(outputFile, "list of %d expression%s\n", numArguments, (numArguments == 1) ? "" : "s");
    for (i = 0; i < numArguments; i++) {
	EBVMPrintInstructionStreamPvt(outputFile, instructionStream, virtualMachine, indentLevel + 1);
    }
}
