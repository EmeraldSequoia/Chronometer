%token IDENTIFIER INTEGER_CONSTANT DOUBLE_CONSTANT DOUBLE_E_CONSTANT
%token LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN ADD_ASSIGN SUB_ASSIGN

%{

// #define YYDEBUG 1
#undef YYPRINT

static void yyerror(char *s);

extern char *yytext;

extern int yylex(void);

#include "EBVirtualMachinePvt.h"
#include <stdio.h>
#include <string.h>

#define YYSTYPE const char *

%}

%start root_expression

%%

primary_expression
	: IDENTIFIER
{
    $$ = EBEncodeOpcodeWithVariableValue($1);
}
	| INTEGER_CONSTANT
{
    $$ = EBEncodeIntegerConstant($1);
}	
        | DOUBLE_CONSTANT
{
    $$ = EBEncodeDoubleConstant($1);
}	
        | DOUBLE_E_CONSTANT
{
    $$ = EBEncodeDoubleEConstant($1);
}	
	| '(' expression ')'
{
    $$ = $2;
}	
	;

argument_expression_list
	: assignment_expression
{
    $$ = $1;
}	
	| argument_expression_list ',' assignment_expression
{
    $$ = EBConcatenateArgumentList($1, $3);
}	
	;

postfix_expression
	: primary_expression
{
    $$ = $1;
}	
	| IDENTIFIER '(' ')'
{
    $$ = EBEncodeOpcodeWithFunctionWithNoArgs($1);
}
	| IDENTIFIER '(' argument_expression_list ')'
{
    $$ = EBEncodeOpcodeWithFunctionWithArgs($1, $3);
}
	;

unary_expression
	: postfix_expression
{
    $$ = $1;
}
        | '+' unary_expression
{
    $$ = EBEncodeOpcodeWithUnaryOperator("unaryPlus", $2);
}
        | '-' unary_expression
{
    $$ = EBEncodeOpcodeWithUnaryOperator("unaryMinus", $2);
}
        | '~' unary_expression
{
    $$ = EBEncodeOpcodeWithUnaryOperator("bitwiseNot", $2);
}
        | '!' unary_expression
{
    $$ = EBEncodeOpcodeWithUnaryOperator("logicalNot", $2);
}
	;

multiplicative_expression
	: unary_expression
{
    $$ = $1;
}
	| multiplicative_expression '*' unary_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("multiply", $1, $3);
}
	| multiplicative_expression '/' unary_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("divide", $1, $3);
}
	| multiplicative_expression '%' unary_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("mod", $1, $3);
}
	;

additive_expression
	: multiplicative_expression
{
    $$ = $1;
}
	| additive_expression '+' multiplicative_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("binaryPlus", $1, $3);
}
	| additive_expression '-' multiplicative_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("binaryMinus", $1, $3);
}
	;

shift_expression
	: additive_expression
{
    $$ = $1;
}
	| shift_expression LEFT_OP additive_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("leftShift", $1, $3);
}
	| shift_expression RIGHT_OP additive_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("rightShift", $1, $3);
}
	;

relational_expression
	: shift_expression
{
    $$ = $1;
}
	| relational_expression '<' shift_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("lessThan", $1, $3);
}
	| relational_expression '>' shift_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("greaterThan", $1, $3);
}
	| relational_expression LE_OP shift_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("lessThanOrEqual", $1, $3);
}
	| relational_expression GE_OP shift_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("greaterThanOrEqual", $1, $3);
}
	;

equality_expression
	: relational_expression
{
    $$ = $1;
}
	| equality_expression EQ_OP relational_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("equal", $1, $3);
}
	| equality_expression NE_OP relational_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("notEqual", $1, $3);
}
	;

and_expression
	: equality_expression
{
    $$ = $1;
}
	| and_expression '&' equality_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("bitwiseAnd", $1, $3);
}
	;

exclusive_or_expression
	: and_expression
{
    $$ = $1;
}
	| exclusive_or_expression '^' and_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("bitwiseXor", $1, $3);
}
	;

inclusive_or_expression
	: exclusive_or_expression
{
    $$ = $1;
}
	| inclusive_or_expression '|' exclusive_or_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("bitwiseOr", $1, $3);
}
	;

logical_and_expression
	: inclusive_or_expression
{
    $$ = $1;
}
	| logical_and_expression AND_OP inclusive_or_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("logicalAnd", $1, $3);
}
	;

logical_or_expression
	: logical_and_expression
{
    $$ = $1;
}
	| logical_or_expression OR_OP logical_and_expression
{
    $$ = EBEncodeOpcodeWithBinaryOperator("logicalOr", $1, $3);
}
	;

assignment_expression
	: conditional_expression
{
    $$ = $1;
}
	| IDENTIFIER '=' assignment_expression
{
    $$ = EBEncodeOpcodeWithAssignmentOperator("assign", $1, $3);
}
	| IDENTIFIER MUL_ASSIGN assignment_expression
{
    $$ = EBEncodeOpcodeWithAssignmentOperator("multiplyAssign", $1, $3);
}
	| IDENTIFIER DIV_ASSIGN assignment_expression
{
    $$ = EBEncodeOpcodeWithAssignmentOperator("divideAssign", $1, $3);
}
	| IDENTIFIER ADD_ASSIGN assignment_expression
{
    $$ = EBEncodeOpcodeWithAssignmentOperator("plusAssign", $1, $3);
}
	| IDENTIFIER SUB_ASSIGN assignment_expression
{
    $$ = EBEncodeOpcodeWithAssignmentOperator("minusAssign", $1, $3);
}
	;

conditional_expression
	: logical_or_expression
{
    $$ = $1;
}
	| logical_or_expression '?' expression ':' conditional_expression
{
    $$ = EBEncodeOpcodeWithTrinaryOperator("questionColon", $1, $3, $5);
}
        ;

expression
	: assignment_expression
{
    $$ = $1;
}
	| expression ',' assignment_expression
{
    $$ = EBConcatenateArgumentList($1, $3);
}	
	;

root_expression
        : expression
{
    EBSetRootExpression($1);
}

%%
#include <stdio.h>

extern char *yytext;
extern int lexColumn;

static void yyerror(s)
char *s;
{
    EBReportYaccError(s, lexColumn);
}
