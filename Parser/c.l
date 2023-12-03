%option nostdinit

D			[0-9]
L			[a-zA-Z_]
H			[a-fA-F0-9]
E			[Ee][+-]?{D}+

%{
#undef YYPRINT
#define YYSTYPE const char *

#include <stdio.h>
#include <string.h>
#include "y.tab.h"
#include "EBVirtualMachinePvt.h"

static void count(void);
static int yywrap(void);
static void comment(void);

static const char *inputString = NULL;
static const char *inputPointer = NULL;
static int remainingCharacters = 0;

int lexColumn = 0;

void EBSetInputString(const char *s)
{
    inputString = s;
    inputPointer = inputString;
    remainingCharacters = strlen(inputPointer);
    lexColumn = 0;
}

#define YY_INPUT(buf,result,max_size)                             \
    {                                                             \
       if (remainingCharacters > 0) {                             \
            if (remainingCharacters <= max_size) {                \
                bcopy(inputPointer, buf, remainingCharacters);    \
                result = remainingCharacters;                     \
                remainingCharacters = 0;                          \
            } else {                                              \
                bcopy(inputPointer, buf, max_size);               \
                result = max_size;                                \
                remainingCharacters -= max_size;                  \
            }                                                     \
        } else {                                                  \
            result = YY_NULL;                                     \
        }                                                         \
    }

%}

%%
"/*"			{ comment(); }

{L}({L}|{D})*		{ count(); yylval = strdup(yytext); return(IDENTIFIER); }

0[xX]{H}+		{ count(); yylval = strdup(yytext); return(INTEGER_CONSTANT); }
0{D}+			{ count(); yylval = strdup(yytext); return(INTEGER_CONSTANT); }
{D}+			{ count(); yylval = strdup(yytext); return(INTEGER_CONSTANT); }

{D}+{E}		        { count(); yylval = strdup(yytext); return(DOUBLE_E_CONSTANT); }
{D}*"."{D}+{E}	        { count(); yylval = strdup(yytext); return(DOUBLE_E_CONSTANT); }
{D}+"."{D}*{E}	        { count(); yylval = strdup(yytext); return(DOUBLE_E_CONSTANT); }
{D}*"."{D}+	        { count(); yylval = strdup(yytext); return(DOUBLE_CONSTANT); }
{D}+"."{D}*	        { count(); yylval = strdup(yytext); return(DOUBLE_CONSTANT); }

">>"			{ count(); return(RIGHT_OP); }
"<<"			{ count(); return(LEFT_OP); }
"&&"			{ count(); return(AND_OP); }
"||"			{ count(); return(OR_OP); }
"<="			{ count(); return(LE_OP); }
">="			{ count(); return(GE_OP); }
"=="			{ count(); return(EQ_OP); }
"!="			{ count(); return(NE_OP); }
"="			{ count(); return('='); }
"+="			{ count(); return(ADD_ASSIGN); }
"-="			{ count(); return(SUB_ASSIGN); }
"*="			{ count(); return(MUL_ASSIGN); }
"/="			{ count(); return(DIV_ASSIGN); }
":"			{ count(); return(':'); }
"("			{ count(); return('('); }
")"			{ count(); return(')'); }
"&"			{ count(); return('&'); }
"!"			{ count(); return('!'); }
"~"			{ count(); return('~'); }
"-"			{ count(); return('-'); }
"+"			{ count(); return('+'); }
"*"			{ count(); return('*'); }
"/"			{ count(); return('/'); }
"%"			{ count(); return('%'); }
"<"			{ count(); return('<'); }
">"			{ count(); return('>'); }
"^"			{ count(); return('^'); }
"|"			{ count(); return('|'); }
"?"			{ count(); return('?'); }
","			{ count(); return(','); }

[ \t\v\n\f]		{ count(); }
.			{ /* ignore bad characters */ }

%%

static int yywrap()
{
    return(1);
}

static void comment()
{
    char c, c1;
loop:
    while ((c = input()) != '*' && c != 0) {
    }
    if ((c1 = input()) != '/' && c != 0) {
        unput(c1);
	goto loop;
    }
    if (c == 0) {
        EBReportYaccError("Unterminated comment", -1);
    }
}

static void count()
{
    int i;
    for (i = 0; yytext[i] != '\0'; i++) {
	if (yytext[i] == '\n') {
	    lexColumn = 0;
	} else if (yytext[i] == '\t') {
	    lexColumn += 8 - (lexColumn % 8);
	} else {
	    lexColumn++;
	}
    }
}
