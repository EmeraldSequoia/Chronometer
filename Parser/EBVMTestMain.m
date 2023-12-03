#include <stdio.h>
#include "EBVirtualMachine.h"

@interface ErrorReporter : NSObject<EBVirtualMachineErrorDelegate> {
}
@end

@implementation ErrorReporter 
-(void)reportError:(NSString *)errorDescription
{
    printf("ERROR: %s\n", [errorDescription UTF8String]);
    fflush(stdout);
}
@end

bool testExpression(EBVirtualMachine *machine,
		    const char     *cExpression,
		    double         expectedValue)
{
    printf("%s\n", cExpression);
    fflush(stdout);
    ErrorReporter *errorReporter = [[ErrorReporter alloc] init];
    NSString *cExpressionString = [NSString stringWithUTF8String:cExpression];
    EBVMInstructionStream *instructionStream = [machine compileInstructionStreamFromCExpression:cExpressionString errorReporter:errorReporter];
    [instructionStream printWithIndentLevel:1 fromVirtualMachine:machine];
    fflush(stdout);
    double computedValue = [machine evaluateInstructionStream:instructionStream errorReporter:errorReporter];
    printf("%s = %.2f (expected %.2f)\n",
	   cExpression,
	   computedValue,
	   expectedValue);
    fflush(stdout);
    free((char *)instructionStream);
    printf("*************\n");
    return true;
}

int main(int  argc,
	 char **argv)
{
#if 0
    extern int yydebug;
    yydebug = 1;
#endif

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    EBVirtualMachine *theMachine = [EBVirtualMachine theMachine];
    [theMachine importVariableWithName:@"myVariable" andValue:42];
    [theMachine importVariableWithName:@"myOtherVariable" andValue:-42];
    testExpression(theMachine, "myVariable", 42);
    testExpression(theMachine, "myOtherVariable", -42);
    testExpression(theMachine, "1 + 1", 1 + 1);
    testExpression(theMachine, "(7 + 5) * 3", (7 + 5) * 3);
    testExpression(theMachine, "7 + 3 * 4 + 5", 7 + 3 * 4 + 5);
    testExpression(theMachine, "1 ? 354 : 1 / 0", 1 ? 354 : 1 / 0);
    testExpression(theMachine, "0 ? 1 / 0 : 123", 0 ? 1 / 0 : 123);
    testExpression(theMachine, "pi() > 3 ? 111 : 222", M_PI > 3 ? 111 : 222);
    testExpression(theMachine, "a=3", 3);
    testExpression(theMachine, "a", 3);
    testExpression(theMachine, "a + 1", 4);
    testExpression(theMachine, "gwibblefwix", 0);
    testExpression(theMachine, "xya += 4", 4);
    testExpression(theMachine, "sin", 0);
    testExpression(theMachine, "0x123", 0x123);
    testExpression(theMachine, "0123", 0123);
    testExpression(theMachine, "0x123AbC", 0x123abc);
    testExpression(theMachine, "0x123aBc", 0x123abc);
    testExpression(theMachine, "a=3,b=4,a+b", 7);
    testExpression(theMachine, "t=1,f=0,t||t", 1);
    testExpression(theMachine, "t=1,f=0,t||f", 1);
    testExpression(theMachine, "t=1,f=0,f||t", 1);
    testExpression(theMachine, "t=1,f=0,f||f", 0);
    testExpression(theMachine, "t=1,f=0,t&&t", 1);
    testExpression(theMachine, "t=1,f=0,t&&f", 0);
    testExpression(theMachine, "t=1,f=0,f&&t", 0);
    testExpression(theMachine, "t=1,f=0,f&&f", 0);
    testExpression(theMachine, "pi=pi(), pi() + pi + ((pi() && pi()) ? 0 : (pi() ?  pi/12 : -pi/12))", 0);
    testExpression(theMachine, "gwibblefwix()", 0);  // ERROR
    testExpression(theMachine, "constant()", 0);  // ERROR
    testExpression(theMachine, "1 1", 0);  // ERROR  // syntax error last, because the lexer won't reset properly after a syntax error

    [pool release];
    return 0;
}
