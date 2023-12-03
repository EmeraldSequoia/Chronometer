//
//  EBVirtualMachine.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#include <pthread.h>

#import "EBVirtualMachine.h"

#include "EBVirtualMachinePvt.h"
#include "EBVirtualMachinePvtObjC.h"
#include "EBVirtualMachine_gen.h"

#import <Foundation/Foundation.h>

#define EBVM_THROW {@throw [NSException exceptionWithName:@"EBVirtualMachine exception" reason:@"The tea is too hot" userInfo:nil]; }

// Extern declaration
extern int yyparse(void);

// Forward declarations

			    

// The following global is to be used only for compilation, not for evaluation
// During evaluation we can have multiple virtual machines running at once
static EBVirtualMachine *theVirtualMachineForCompilation = NULL;

// The following global is to be used in the static method theMachine, for use by clients
// that only want or need one VM
static EBVirtualMachine *theVirtualMachineForClients = NULL;

@implementation EBStdoutErrorReporter

-(void)reportError:(NSString *)errorDescription
{
    printf("ERROR: %s\n", [errorDescription UTF8String]);
    fflush(stdout);
}

EBStdoutErrorReporter *theErrorReporter = nil;

+(EBStdoutErrorReporter *)theErrorReporter
{
    if (!theErrorReporter) {
	theErrorReporter = [[EBStdoutErrorReporter alloc] init];
    }
    return theErrorReporter;
}


@end

@implementation EBVMInstructionStream

-(id)initWithRawStream:(const char *)str
{
    [super init];
    instructionStream = str;
#ifdef VM_READABLE_STRING
    readableString = nil;
#endif
    return self;
}

-(void)dealloc
{
    if (instructionStream) {
	free((char *)instructionStream);
    }
#ifdef VM_READABLE_STRING
    [readableString release];
#endif
    [super dealloc];
}

#ifdef VM_READABLE_STRING
-(void)setReadableString:(NSString *)str {
    readableString = [str retain];
}

-(NSString *)readableString {
    return readableString;
}
#endif

-(const char *)rawStream
{
    return instructionStream;
}

-(void)printToOutputFile:(FILE *)outputFile withIndentLevel:(int)indentLevel fromVirtualMachine:(EBVirtualMachine *)virtualMachine
{
#ifdef VM_READABLE_STRING
    fprintf(outputFile, "%s\n", [readableString UTF8String]);
#endif
    EBVMPrintInstructionStreamRaw(outputFile, [self rawStream], virtualMachine, indentLevel);
}

-(void)writeInstructionStreamToFile:(FILE *)filePointer forVirtualMachine:(EBVirtualMachine *)virtualMachine {
    int length = EBVMStreamLengthInBytes(instructionStream, virtualMachine);
    // First write size of stream
    size_t objectsWritten = fwrite(&length, sizeof(int), 1, filePointer);
    if (objectsWritten != 1) {
	assert(virtualMachine->errorDelegate);
	[virtualMachine->errorDelegate reportError:[NSString stringWithFormat:@"Error writing int to archive: %s", strerror(errno)]];
    }
    // Now write stream
    objectsWritten = fwrite(instructionStream, length, 1, filePointer);
    if (objectsWritten != 1) {
	assert(virtualMachine->errorDelegate);
	[virtualMachine->errorDelegate reportError:[NSString stringWithFormat:@"Error writing to archive: %s", strerror(errno)]];
    }
}

-(id)initFromFilePointer:(FILE *)filePointer withStreamLength:(int)streamLength forVirtualMachine:(EBVirtualMachine *)virtualMachine pathForDebugMsgs:(NSString *)path {
    [super init];
    instructionStream = (char *)malloc(streamLength);
    int objectsRead = fread((char *)instructionStream, streamLength, 1, filePointer);
    if (objectsRead != 1) {
	assert(virtualMachine->errorDelegate);
	[virtualMachine->errorDelegate reportError:[NSString stringWithFormat:@"Error reading instruction stream from archive: %s", strerror(errno)]];
    }
    int length = EBVMStreamLengthInBytes(instructionStream, virtualMachine);
    if (length != streamLength) {
	assert(virtualMachine->errorDelegate);
	[virtualMachine->errorDelegate reportError:[NSString stringWithFormat:@"Length of instruction stream from archive (%d) doesn't match expected length (%d) [%@]", length, streamLength, path]];
    }
    return self;
}

@end

@implementation EBVirtualMachine

@synthesize name;

#ifndef NDEBUG
static pthread_key_t currentEvaluatingStream;
static bool currentEvaluatingStreamInitialized;
#endif

-(id)initWithOwner:(id)own name:(NSString *)nam 
{
    [super init];
#ifndef NDEBUG
    if (!currentEvaluatingStreamInitialized) {
	pthread_key_create(&currentEvaluatingStream, NULL);
	currentEvaluatingStreamInitialized = true;
    }
#endif
    assert(nam);
    name = [nam retain];
    opcodesByName = [[NSMutableDictionary alloc] initWithCapacity:numEBVMDispatchFunctions];
    theVirtualMachineForCompilation = self;
    EBCallBackWithOpcodeStrings();
    variableCodesByName = [[NSMutableDictionary alloc] initWithCapacity:10];
    variableNamesByCode = [[NSMutableDictionary alloc] initWithCapacity:10];
    variableArraySize = 4;  // enough to store 4 variables without realloc'ing
    variableValues = (double *)malloc(variableArraySize * sizeof(double));
    variableInitializationDone = (bool *)malloc(variableArraySize * sizeof(bool));
    numVariables = 0;  // number actually defined
    theVirtualMachineForCompilation = nil;
    owner = own;
    return self;
}

-(id)initWithOwner:(id)own name:(NSString *)nam variableCount:(int)variableCount variableImporter:(EBVMvariableImporter)variableImporter {
    [super init];
#ifndef NDEBUG
    if (!currentEvaluatingStreamInitialized) {
	pthread_key_create(&currentEvaluatingStream, NULL);
	currentEvaluatingStreamInitialized = true;
    }
#endif
    assert(nam);
    name = [nam retain];
    opcodesByName = [[NSMutableDictionary alloc] initWithCapacity:numEBVMDispatchFunctions];
    theVirtualMachineForCompilation = self;
#ifndef NDEBUG
    EBCallBackWithOpcodeStrings();
    variableCodesByName = [[NSMutableDictionary alloc] initWithCapacity:variableCount];
    variableNamesByCode = [[NSMutableDictionary alloc] initWithCapacity:variableCount];
#endif
    variableArraySize = variableCount;  // enough to store 4 variables without realloc'ing
    variableValues = (double *)malloc(variableArraySize * sizeof(double));
    variableInitializationDone = (bool *)malloc(variableArraySize * sizeof(bool));
    for (int i = 0; i < variableCount; i++) {
	variableValues[i] = 0;
	variableInitializationDone[i] = false;
    }
    owner = own;
    (*variableImporter)(self);
    numVariables = variableCount;  // number actually defined
    theVirtualMachineForCompilation = nil;
    return self;
}

-(id)init
{
    assert(false);  // don't use this
    return [self initWithOwner:nil name:nil];
}

-(id)owner
{
    return owner;
}

-(void)dealloc
{
    [opcodesByName release];
    [variableCodesByName release];
    [variableNamesByCode release];
    [name release];
    free(variableValues);
    free(variableInitializationDone);
    [super dealloc];
}

-(int)numVariables {
    return numVariables;
}

-(bool)variableWithIndexIsDefined:(int)indx {
    if (indx >= 0 && indx < numVariables) {
	return variableInitializationDone[indx];
    }
    return false;
}
-(double)variableValueForIndex:(int)indx {
    if (indx >= 0 && indx < numVariables) {
	return variableValues[indx];
    }
    return 0;
}

-(EBVMInstructionStream *)streamBeingEvaluated {
#ifndef NDEBUG
    if (currentEvaluatingStreamInitialized) {
	return (EBVMInstructionStream *)pthread_getspecific(currentEvaluatingStream);
    }
#endif
    return nil;
}

-(void)printCurrentStream {
    EBVMInstructionStream *stream = [self streamBeingEvaluated];
    if (!stream) {
	printf("Stream is nil\n");
    } else {
	[stream printToOutputFile:stdout withIndentLevel:0 fromVirtualMachine:self];
    }
}

// evaluateInstructionStream is intended to be thread-safe.  No globals should be used.
-(double)evaluateInstructionStream:(EBVMInstructionStream *)instructionStream errorReporter:(id)errorReporter
{
    const char *stream = [instructionStream rawStream];
    if (!stream) {
	[errorReporter reportError:[NSString stringWithFormat:@"%@: Instruction stream invalid", name]];
	return 0;
    }
#ifndef NDEBUG
    assert(currentEvaluatingStreamInitialized);
    pthread_setspecific(currentEvaluatingStream, instructionStream);
#endif
    errorDelegate = errorReporter;
    double val = 0.0;
    @try {
	val = EBVMEvaluateAndAdvanceStream(&stream, self);
    }
    @catch(NSException *exception) {
	[errorDelegate reportError:[NSString stringWithFormat:@"%@: Instruction stream evaluation cancelled", name]];
    }
    @finally {
    }
    errorDelegate = NULL;
#ifndef NDEBUG
    pthread_setspecific(currentEvaluatingStream, NULL);
#endif
    return val;
}

// compileInstructionStreamFromCExpression is not thread-safe.  It uses theVirtualMachineForCompilation as a global, and the lex and yacc
// that underly it also make use of global and static variables.
-(EBVMInstructionStream *)compileInstructionStreamFromCExpression:(NSString *)CExpressionString errorReporter:(id)errorReporter
{
    if (CExpressionString == nil) {
	return nil;
    }
    
    theVirtualMachineForCompilation = self;
    errorDelegate = errorReporter;
    instructionStreamReturn = NULL;
    
    EBSetInputString([[CExpressionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] UTF8String]);
    @try {
	int st = yyparse();
	if (st != 0) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"%@: Expression parser returned an error; compilation cancelled", name]];
	    instructionStreamReturn = NULL;
	}
    }
    @catch(NSException *exception) {
	[errorDelegate reportError:[NSString stringWithFormat:@"%@: Instruction stream compilation cancelled", name]];
	instructionStreamReturn = NULL;
    }
    @finally {
    }
    theVirtualMachineForCompilation = nil;  // protect against accidental incorrect use
    if (instructionStreamReturn) {
	EBVMInstructionStream *strm = [[[EBVMInstructionStream alloc] initWithRawStream:instructionStreamReturn] autorelease];
#ifdef VM_READABLE_STRING	
	[strm setReadableString:CExpressionString];
#endif
	return strm;
    } else {
	return nil;
    }
}

-(void)setInstructionStreamReturn:(const char *)instStream
{
    instructionStreamReturn = EBVMCopyInstructionStream(instStream, self);
}

-(void)reportYaccError:(const char *)error atColumn:(int)column
{
    [errorDelegate reportError:[NSString stringWithFormat:@"%@: Expression compilation error at column %d: %s", name, column, error]];
}

-(void)reportGeneralError:(NSString *)errorString
{
    [errorDelegate reportError:[NSString stringWithFormat:@"%@: %@", name, errorString]];
}

-(int)opcodeForIdentifier:(const char *)identifierName
{
    assert(identifierName != 0);
    NSNumber *num = [opcodesByName objectForKey:[NSString stringWithUTF8String:identifierName]];
    if (num) {
	return [num intValue];
    } else {
	[errorDelegate reportError:[NSString stringWithFormat:@"%@: Unrecognized function '%s'", name, identifierName]];
	EBVM_THROW
    }
}

-(void)addOpcodeToDictionary:(int)opcode withName:(const char *)opcodeName
{
    [opcodesByName setObject:[NSNumber numberWithInt:opcode] forKey:[NSString stringWithUTF8String:opcodeName]];
}

// Variable codes, unlike functions, are automatically assigned the first time the corresponding identifier is encountered
// Note that this correspondence is thus both dynamic (won't necessarily be the same for different runs of the executable)
// and specific to this particular virtual machine instance
-(int)variableCodeForIdentifier:(const char *)identifierName
{
    assert(identifierName != 0);
    NSString *identifierString = [NSString stringWithUTF8String:identifierName];
    assert(variableCodesByName);
    NSNumber *num = [variableCodesByName objectForKey:identifierString];
    if (num) {
	return [num intValue];
    } else {
	// Assign a new index, and make sure there is a slot in the array available for that index
	int newIndex = numVariables++;
	NSNumber *number = [NSNumber numberWithInt:newIndex];
	[variableCodesByName setObject:number forKey:identifierString];
	[variableNamesByCode setObject:identifierString forKey:number];

	if (newIndex >= variableArraySize) {
	    variableArraySize *= 2;  // Double the array each time it is resized
	    variableValues = (double *)realloc(variableValues, variableArraySize * sizeof(double));
	    variableInitializationDone = (bool *)realloc(variableInitializationDone, variableArraySize * sizeof(bool));
	}
	variableValues[newIndex] = 0.0;  // Variables are always initialized to zero
	variableInitializationDone[newIndex] = false;
	return newIndex;
    }
}

-(NSString *)variableNameForCode:(int)varcode
{
    return [variableNamesByCode objectForKey:[NSNumber numberWithInt:varcode]];
}

-(void)importVariableWithName:(NSString *)nam andValue:(double)value
{
    assert(![variableCodesByName objectForKey:nam]);  // Don't try to import the same variable twice
    int varcode = [self variableCodeForIdentifier:[nam UTF8String]];
    variableValues[varcode] = value;
    variableInitializationDone[varcode] = true;
}

-(double *)variableReferenceForIndex:(int)indx initializing:(bool)initializing
{
    if (indx < 0) {
	[errorDelegate reportError:[NSString stringWithFormat:@"%@: Variable index '%d' is negative", name, indx]];
	EBVM_THROW
    }
    if (indx >= numVariables) {
	[errorDelegate reportError:[NSString stringWithFormat:@"%@: Variable index (%d) is >= than the number of variables (%d) -- are you using the right VM?", name, indx, numVariables]];
	EBVM_THROW
    }
    if (indx >= variableArraySize) {
	printf("About to crash with indx %d and variableArraySize %d\n",indx, variableArraySize);
    }
    assert(indx < variableArraySize);
    if (initializing) {
	variableInitializationDone[indx] = true;
    } else {
	if (!variableInitializationDone[indx]) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"%@: Variable index %d, corresponding to '%@' in this VM, is uninitialized", name, indx, [self variableNameForCode:indx]]];
	    // Don't throw -- it returns a well-defined value (zero)
	}
    }
    return &variableValues[indx];
}

+(EBVirtualMachine *)theMachine
{
    if (!theVirtualMachineForClients) {
	theVirtualMachineForClients = [[EBVirtualMachine alloc] init];
    }
    return theVirtualMachineForClients;
}

#ifdef EC_HENRY
-(void)writeVariableNamesToFile:(NSString *)path {
    FILE *file = fopen([path UTF8String], "w");
    if (!file) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Error creating variable-name file %@: %s", path, strerror(errno)]];
    }
    for (int i = 0; i < numVariables; i++) {
	NSString *varname = [variableNamesByCode objectForKey:[NSNumber numberWithInt:i]];
	fprintf(file, "%s\n", [varname UTF8String]);
    }
    fclose(file);
}



-(void)readVariableNamesFromFile:(NSString *)path {
    FILE *file = fopen([path UTF8String], "r");
    if (!file) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Error reading variable-name file %@: %s", path, strerror(errno)]];
    }
    int i = 0;
    while (!feof(file)) {
	char buf[512];
	char *bufptr = buf;
	int c = '\0';
	while (!feof(file) && (c=getc(file)) && c != '\n' && c != EOF) {
	    *bufptr++ = c;
	}
	if (c != '\n') {
	    break;
	}
	*bufptr = '\0';
	[variableNamesByCode setObject:[[[NSString alloc] initWithUTF8String:buf] autorelease] forKey:[NSNumber numberWithInt:i]];
	i++;
    }
    fclose(file);
}

#endif

-(void)dumpVariableValues {
    printf("Dumping %d variable values\n", numVariables);
    for (int i = 0; i < numVariables; i++) {
#ifndef NDEBUG
	NSString *varname = [NSString stringWithFormat:@"Variable %d (%@)", i, [variableNamesByCode objectForKey:[NSNumber numberWithInt:i]]];
#else
	NSString *varname = [NSString stringWithFormat:@"Variable %d", i];
#endif
	double value = variableValues[i];
	printf("%30s => %20.4f", [varname UTF8String], value);
	if (fabs(value) > 10000) {
	    printf(" == 0x%8x", (unsigned int)value);
	}
	printf("\n");
    }
}

@end

//  ************************
//  LEX/YACC utility methods
//  ************************
static char *encodeIntAndAdvance(char *buffer,
				 int  i)
{
    *((int *)buffer) = i;
    return buffer + sizeof(int);
}

static char *encodeDoubleAndAdvance(char   *buffer,
				    double d)
{
    *((double *)buffer) = d;
    return buffer + sizeof(double);
}

static char *encodeParameterAndAdvance(char       *buffer,
				       const char *parameter,
				       int        paramLength)
{
    bcopy(parameter, buffer, paramLength);
    free((char *)parameter);
    return buffer + paramLength;
}

static char *encodeParameterAndAdvanceWithoutFree(char       *buffer,
						  const char *parameter,
						  int        paramLength)
{
    bcopy(parameter, buffer, paramLength);
    return buffer + paramLength;
}

static char *allocateBufAndEncodeOpcode(int  totalBufferSize,
					int  opcode)
{
    char *chunk = (char *)malloc(totalBufferSize);
    encodeIntAndAdvance(chunk, opcode);
    return chunk;
}

static char *allocateBufAndEncodeOpcodeWithReturn(int  totalBufferSize,
						  int  opcode,
						  char **nextPosition)
{
    char *chunk = (char *)malloc(totalBufferSize);
    *nextPosition = encodeIntAndAdvance(chunk, opcode);
    return chunk;
}

static void
checkInternalOpcode(int        opcode,
		    const char *identifierName)
{
    if (opcode == EB_constant_opcode || opcode == EB_expressionList_opcode || opcode == EB_variable_opcode) {
	[theVirtualMachineForCompilation reportGeneralError:[NSString stringWithFormat:@"improper call to internal opcode '%s'",
								      identifierName]];
	EBVM_THROW
    }
}

const char *
EBEncodeOpcodeWithVariableValue(const char *identifierName)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:"variable"];
    int varcode = [theVirtualMachineForCompilation variableCodeForIdentifier:identifierName];
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + sizeof(varcode), opcode, &ptr);
    encodeIntAndAdvance(ptr, varcode);
    free((char *)identifierName);
    return chunk;
}

void
EBVMSkipPastVariableReference(const char **instructionStream)
{
    *instructionStream += sizeof(int);
}

const char *
EBEncodeOpcodeWithAssignmentOperator(const char *opcodeString,
				     const char *variableName,
				     const char *value)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:opcodeString];
    int varcode = [theVirtualMachineForCompilation variableCodeForIdentifier:variableName];
    int valueLength = EBVMStreamLengthInBytes(value, theVirtualMachineForCompilation);
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + sizeof(varcode) + valueLength, opcode, &ptr);
    ptr = encodeIntAndAdvance(ptr, varcode);
    encodeParameterAndAdvance(ptr, value, valueLength);
    free((char *)variableName);
    return chunk;
}

int
EBVMStreamLengthInBytes(const char       *instructionStream,
			EBVirtualMachine *virtualMachine)
{
    const char *ptr = instructionStream;
    EBVMSkipStreamPastExpression(&ptr, virtualMachine);
    return ptr - instructionStream;
}

static double
convertIntegerToString(const char *str) {
    double dValue;
    int tokensScanned;
    if (str[0] == '0') {
	unsigned int value;
	if (str[1] == 'x' || str[1] == 'X') {
	    // hex
	    tokensScanned = sscanf(str+2, "%x", &value);
	    dValue = (double) value;
	} else if (str[1] == '\0') {
	    return 0.0;
	} else {
	    // octal -- we don't support this to avoid confusing anyone
            printf("Octal detected in '%s'\n", str);
	    [theVirtualMachineForCompilation reportGeneralError:[NSString stringWithFormat:@"Leading 0 in %s rejected; octal constants not supported (use hex or decimal)",
									  str]];
	    EBVM_THROW
	}
    } else {
	// decimal
	int value;
	tokensScanned = sscanf(str, "%d", &value);
	dValue = (double) value;
    }
    if (tokensScanned != 1) {
	[theVirtualMachineForCompilation reportGeneralError:[NSString stringWithFormat:@"Internal parsing error parsing integer %s",
								      str]];
	EBVM_THROW
    }
    return dValue;
}

const char *
EBEncodeIntegerConstant(const char *integerConstant)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:"constant"];
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + sizeof(double), opcode, &ptr);
    encodeDoubleAndAdvance(ptr, convertIntegerToString(integerConstant));
    free((char *)integerConstant);
    return chunk;
}

const char *
EBEncodeDoubleConstant(const char *doubleConstant)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:"constant"];
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + sizeof(double), opcode, &ptr);
    double value = atof(doubleConstant);
    encodeDoubleAndAdvance(ptr, value);
    free((char *)doubleConstant);
    return chunk;
}

const char *
EBEncodeDoubleEConstant(const char *doubleConstant)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:"constant"];
    char *ptr;
    int chunkLength = sizeof(opcode) + sizeof(double);
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(chunkLength, opcode, &ptr);
    double value = atof(doubleConstant);
    encodeDoubleAndAdvance(ptr, value);
    free((char *)doubleConstant);
    return chunk;
}

const char *
EBEncodeOpcodeWithUnaryOperator(const char *opcodeString,
				const char *parameter)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:opcodeString];
    int paramLength = EBVMStreamLengthInBytes(parameter, theVirtualMachineForCompilation);
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + paramLength, opcode, &ptr);
    encodeParameterAndAdvance(ptr, parameter, paramLength);
    return chunk;
}

const char *
EBEncodeOpcodeWithBinaryOperator(const char *opcodeString,
				 const char *parameter1,
				 const char *parameter2)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:opcodeString];
    int param1Length = EBVMStreamLengthInBytes(parameter1, theVirtualMachineForCompilation);
    int param2Length = EBVMStreamLengthInBytes(parameter2, theVirtualMachineForCompilation);
    int chunkLength = sizeof(opcode) + param1Length + param2Length;
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(chunkLength, opcode, &ptr);
    ptr = encodeParameterAndAdvance(ptr, parameter1, param1Length);
    encodeParameterAndAdvance(ptr, parameter2, param2Length);
    return chunk;
}

const char *
EBEncodeOpcodeWithTrinaryOperator(const char *opcodeString,
				  const char *parameter1,
				  const char *parameter2,
				  const char *parameter3)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:opcodeString];
    int param1Length = EBVMStreamLengthInBytes(parameter1, theVirtualMachineForCompilation);
    int param2Length = EBVMStreamLengthInBytes(parameter2, theVirtualMachineForCompilation);
    int param3Length = EBVMStreamLengthInBytes(parameter3, theVirtualMachineForCompilation);
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + param1Length + param2Length + param3Length, opcode, &ptr);
    ptr = encodeParameterAndAdvance(ptr, parameter1, param1Length);
    ptr = encodeParameterAndAdvance(ptr, parameter2, param2Length);
    encodeParameterAndAdvance(ptr, parameter3, param3Length);
    return chunk;
}

const char *
EBConcatenateArgumentList(const char *priorList,
			  const char *newArgument)
{
    // This is tricky.  When we eventually reduce to the function call, we need to
    // be able to check at that time how many arguments were passed.  Simply
    // concatenating the arguments wouldn't tell us that.  Furthermore, this function
    // can't do its job properly without knowing how many arguments are in the "priorList".
    //
    // We could just prepend an int to the stream, but that would make us unable to distinguish
    // a priorList which is simply a single argument from a prior concatenation of arguments.
    //
    // So an "argument list" opcode is a special instruction whose first argument is
    // an inline int with the number of arguments in the list, and the second argument
    // is the concatenated list of arguments that will be actually used.
    // This opcode, along with the count, will be stripped out of the stream when we
    // process the function call reduction, and won't be included in the instruction
    // stream eventually passed back to the client, because once the number of arguments
    // have been checked there is no need to have it, and it would complicate the
    // dispatch if it were there.

    int priorListLength = EBVMStreamLengthInBytes(priorList, theVirtualMachineForCompilation);
    int newArgumentLength = EBVMStreamLengthInBytes(newArgument, theVirtualMachineForCompilation);
    char *ptr;
    char *chunk;
    int priorListOpcode = *((int *)(priorList));
    if (priorListOpcode == EB_expressionList_opcode) {
	chunk = (char *)malloc(priorListLength + newArgumentLength);
	ptr = chunk;
    } else {
	// Not yet an argument list, need to prepend the opcode and count
	int opcode = EB_expressionList_opcode;
	chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + sizeof(int) + priorListLength + newArgumentLength,
							   opcode, &ptr);
	ptr = encodeIntAndAdvance(ptr, 2);  // 2 arguments so far
    }
    ptr = encodeParameterAndAdvance(ptr, priorList, priorListLength);
    if (priorListOpcode == EB_expressionList_opcode) {
	// Need to bump up the argument count in the priorList
	int priorCount = *((int *)chunk + 1);
	*(((int *)chunk) + 1) = priorCount + 1;
    }
    encodeParameterAndAdvance(ptr, newArgument, newArgumentLength);
    return chunk;
}

const char *
EBEncodeOpcodeWithFunctionWithNoArgs(const char *identifierName)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:identifierName];
    checkInternalOpcode(opcode, identifierName);
    if (EBVMOpcodeArgumentCounts[opcode] != 0) {
	[theVirtualMachineForCompilation reportGeneralError:[NSString stringWithFormat:@"Mismatched argument count for function %s: expected %d, found %d",
								      identifierName, EBVMOpcodeArgumentCounts[opcode], 0]];
	EBVM_THROW
    }
    free((char*)identifierName);
    return allocateBufAndEncodeOpcode(sizeof(opcode), opcode);
}

const char *
EBEncodeOpcodeWithFunctionWithArgs(const char *identifierName,
				   const char *encodedArguments)
{
    int opcode = [theVirtualMachineForCompilation opcodeForIdentifier:identifierName];
    checkInternalOpcode(opcode, identifierName);
    int encodedArgumentsLength = EBVMStreamLengthInBytes(encodedArguments, theVirtualMachineForCompilation);
    int encodedArgumentsOpcode = *((int*)encodedArguments);
    const char *suppliedArguments = encodedArguments;
    if (encodedArgumentsOpcode == EB_expressionList_opcode) {
	encodedArguments += sizeof(encodedArgumentsOpcode);
	int encodedCount = EBVMSkipPastAndReturnInt(&encodedArguments);
	if (encodedCount != EBVMOpcodeArgumentCounts[opcode]) {
	    [theVirtualMachineForCompilation reportGeneralError:[NSString stringWithFormat:@"Mismatched argument count for function %s: expected %d, found %d",
									  identifierName, EBVMOpcodeArgumentCounts[opcode], encodedCount]];
	    EBVM_THROW
	}
	encodedArgumentsLength -= (sizeof(opcode) + sizeof(int));
    } else {
	if (EBVMOpcodeArgumentCounts[opcode] != 1) {
	    [theVirtualMachineForCompilation reportGeneralError:[NSString stringWithFormat:@"Mismatched argument count for function %s: expected %d, found %d",
									  identifierName, EBVMOpcodeArgumentCounts[opcode], 1]];
	    EBVM_THROW
        }
    }
    char *ptr;
    char *chunk = allocateBufAndEncodeOpcodeWithReturn(sizeof(opcode) + encodedArgumentsLength, opcode, &ptr);
    encodeParameterAndAdvanceWithoutFree(ptr, encodedArguments, encodedArgumentsLength);
    free((char*)suppliedArguments);
    free((char*)identifierName);
    return chunk;
}

void
EBSetRootExpression(const char *expression)
{
    [theVirtualMachineForCompilation setInstructionStreamReturn:expression];
    free((char *)expression);
}

double *
EBVMEvaluateVariableReferenceAndAdvanceStream(const char       **instructionStream,
					      EBVirtualMachine *virtualMachine,
					      bool             initializing)
{
    int varcode = *((int*)(*instructionStream));
    *instructionStream += sizeof(varcode);
    return [virtualMachine variableReferenceForIndex:varcode initializing:initializing];
}

double
EBVMEvaluateAndAdvanceStream(const char       **instructionStream,
			     EBVirtualMachine *virtualMachine)
{
    int opcode = *((int*)(*instructionStream));
    *instructionStream += sizeof(opcode);
    if (opcode < 0 || opcode > numEBVMDispatchFunctions) {
	[virtualMachine reportGeneralError:[NSString stringWithFormat:@"Bad instruction opcode %d (0x%08x)\n",
							opcode, opcode]];
	EBVM_THROW
    }
    double retVal = (*EBVMDispatchFunctions[opcode])(instructionStream, virtualMachine);
    return retVal;
}

void
EBVMSkipStreamPastExpression(const char       **instructionStream,
			     EBVirtualMachine *virtualMachine)
{
    int opcode = *((int*)(*instructionStream));
    *instructionStream += sizeof(opcode);
    if (opcode < 0 || opcode > numEBVMSkipFunctions) {
	[virtualMachine reportGeneralError:[NSString stringWithFormat:@"Bad instruction opcode %d (0x%08x)\n",
						     opcode, opcode]];
	EBVM_THROW
    }
    (*EBVMSkipFunctions[opcode])(instructionStream, virtualMachine);
}

void
EBVMPrintInstructionStreamPvt(FILE             *outputFile,
			      const char       **instructionStream,
			      EBVirtualMachine *virtualMachine,
			      int              indentLevel)
{
    int opcode = *((int*)(*instructionStream));
    *instructionStream += sizeof(opcode);
    if (opcode < 0 || opcode > numEBVMSkipFunctions) {
	[virtualMachine reportGeneralError:[NSString stringWithFormat:@"Bad instruction opcode %d (0x%08x)\n",
						     opcode, opcode]];
	EBVM_THROW
    }
    (*EBVMPrintFunctions[opcode])(outputFile, instructionStream, virtualMachine, indentLevel);
}

void
EBVMPrintInstructionStreamRaw(FILE             *outputFile,
			      const char       *instructionStream,
			      EBVirtualMachine *virtualMachine,
			      int              indentLevel)
{
    if (!instructionStream) {
	[virtualMachine reportGeneralError:@"Invalid instruction stream"];
	return;
    }
    EBVMPrintInstructionStreamPvt(outputFile, &instructionStream, virtualMachine, indentLevel);
}

double
EBVMReadDoubleAndAdvanceStream(const char **instructionStream)
{
    double retValue = *((double *)(*instructionStream));
    *instructionStream += sizeof(double);
    return retValue;
}

void
EBVMSkipStreamPastDouble(const char **instructionStream)
{
    *instructionStream += sizeof(double);
}

int
EBVMSkipPastAndReturnInt(const char **instructionStream)
{
    int num = *((int*)(*instructionStream));
    *instructionStream += sizeof(num);
    return num;
}

void
EBReportYaccError(const char *string, int column)
{
    [theVirtualMachineForCompilation reportYaccError:string atColumn:column];
    EBVM_THROW
}

void
EBAddOpcodeToDictionary(int opcode, const char *opcodeName)
{
    [theVirtualMachineForCompilation addOpcodeToDictionary:(int)opcode withName:(const char *)opcodeName];
}

const char *
EBVMCopyInstructionStream(const char *instructionStream,
			  EBVirtualMachine *virtualMachine)
{
    int streamLength = EBVMStreamLengthInBytes(instructionStream, virtualMachine);
    char *buffer = malloc(streamLength);
    bcopy(instructionStream, buffer, streamLength);
    return buffer;
}
