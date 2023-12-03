// These are defined as macros to make it easier for the code generator to recognize
#define EBVM_OP0(opcode) double EB_##opcode(EBVirtualMachine *virtualMachine)
#define EBVM_OP1(opcode, arg) double EB_##opcode(double arg, EBVirtualMachine *virtualMachine)
#define EBVM_OP1_SIMPLE(opcode, arg, op) EBVM_OP1(opcode, arg) { return op arg; }
#define EBVM_OP1_INTEGER(opcode, arg, op) EBVM_OP1(opcode, arg) { long long int i = llrint(arg); return (double)(op i); }
#define EBVM_OP2(opcode, arg1, arg2) double EB_##opcode(double arg1, double arg2, EBVirtualMachine *virtualMachine)
#define EBVM_OP2_SIMPLE(opcode, arg1, arg2, op) EBVM_OP2(opcode, arg1, arg2) { return arg1 op arg2; }
#define EBVM_OP2_INTEGER(opcode, arg1, arg2, op) EBVM_OP2(opcode, arg1, arg2) { long long int i1 = llrint(arg1); long long int i2 = llrint(arg2); return (double)(i1 op i2); }
#define EBVM_OP2_ASSIGN(opcode, arg1, arg2, op) double EB_##opcode(double *arg1, double arg2) { return *arg1 op arg2; }
#define EBVM_OP3(opcode, arg1, arg2, arg3) double EB_##opcode(double arg1, double arg2, double arg3, EBVirtualMachine *virtualMachine)
#define EBVM_OP4(opcode, arg1, arg2, arg3, arg4) double EB_##opcode(double arg1, double arg2, double arg3, double arg4, EBVirtualMachine *virtualMachine)
#define EBVM_OP5(opcode, arg1, arg2, arg3, arg4, arg5) double EB_##opcode(double arg1, double arg2, double arg3, double arg4, double arg5, EBVirtualMachine *virtualMachine)
#define EBVM_OP6(opcode, arg1, arg2, arg3, arg4, arg5, arg6) double EB_##opcode(double arg1, double arg2, double arg3, double arg4, double arg5, double arg6, EBVirtualMachine *virtualMachine)
#define EBVM_OP7(opcode, arg1, arg2, arg3, arg4, arg5, arg6, arg7) double EB_##opcode(double arg1, double arg2, double arg3, double arg4, double arg5, double arg6, double arg7, EBVirtualMachine *virtualMachine)
#define EBVM_OP8(opcode, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) double EB_##opcode(double arg1, double arg2, double arg3, double arg4, double arg5, double arg6, double arg7, double arg8, EBVirtualMachine *virtualMachine)

// SPECIAL opcode function definitions are direct dispatch routines, because the arguments are not evaluated before the method is called
// Two-argument form
#define EBVM_OP2_SPECIAL(opcode, instructionStream, virtualMachine) double EB_##opcode(const char **instructionStream, EBVirtualMachine *virtualMachine)
// Three-argument form
#define EBVM_OP3_SPECIAL(opcode, instructionStream, virtualMachine) double EB_##opcode(const char **instructionStream, EBVirtualMachine *virtualMachine)
// Variable-argument form, requiring skip function definition also
#define EBVM_OPX_SPECIAL(opcode, instructionStream, virtualMachine) double EB_##opcode(const char **instructionStream, EBVirtualMachine *virtualMachine)
