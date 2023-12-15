This document describes the expression syntax accepted by the Emerald Chronometer parser.

Expressions may be most syntactically-correct C expressions.  Note that this does not include general C statements;
anything with a semicolon or a curly brace in it is not an expression and is not legal.  There are several
important differences between this virtual machine and a standard C or C++ program:

1.  All expressions have a value of type `double`.
2.  When evaluating the following integer operators, the arguments are first rounded to the nearest `long long int`,
    then the converted arguments are evaluated as `long long int` operands, then the result is converted back to `double`
    and returned:
    ```
      ! (logical not)
      ~ (bitwise not)
      % (mod)
      << (left shift)
      >> (right shift)
      % (bitwise and)
      | (bitwise or)
      ^ (bitwise xor)
      || (logical or)
      && (logical and)
    ```
3.  Logical operators such as `>` or `!=` return either 1.0 (true) or 0.0 (false).  Note that comparison operators such as `==`
    are subject to the implicit rounding done by doubles, so that `1.0 + 1.0` may not equal `2.0` (it might equal `1.99999...`).
    You can work around this by rounding.  `round(1.0 + 1.0) == round(2.0)`.  The round function converts to `long long int` and
    then back to `double`.
4.  As with C/C++, when evaluating `||`, `&&`, and `?:`, only the subexpressions necessary to compute the result are evaluated.  For
    example, in `a() || b()`, `b()` is not evaluated if `a()` returns > 0 (actually, > 0.5).
5.  Assignments may be made to C variable names with the normal assignment operator.  It is not necessary (nor
    possible) to define a variable name before using it.  The initial value of uninitialized variables is always
    zero (although see note 7 about variable lifetimes).  There is no limit to the number of variables defined.
    Arrays are not (yet) implemented.  Variables, like expressions, are always of type double.
6.  Those complex assignment operators which operate directly on doubles are also available.  This set is:
    ```
      +=
      -=
      *=
      /=
    ```
    We may also add `++` and `--`.  But support for the other integer assignments (e.g., `|=`, `>>=`, etc.) is not planned.
7.  Variable values are stored in the virtual machine used to evaluate the expressions containing them, and are not
    reset after each expression.  This has several implications:
    a.  You must use the same EBVirtualMachine to evaluate an instruction stream as you used to create it, otherwise
        the variable index stored in the instruction stream may not map correctly to the name in all expressions.
    b.  Variable values may be passed from one expression to another, or to the same expression when evaluated again
        at a later time.
    c.  To have different "namespaces", you can use a separate virtual machine for each.
8.  There are no if statements (because there are no statements), but conditional expressions are legal as in `a ? b : c`.
    The value is a is defined to be `true` iff b is greater than 0.5; since logical expressions like `a > b` return `0.0`
    or `1.0`, this works as you would expect.
9.  There is no way to write a loop (yet).  When implemented, this will probably be implemented as a special function,
    with a syntax something like:
    ```
       while(condition, expression)
    ```
    and/or possibly
    ```
       for(initial-expression, condition, post-iteration-expression, iteration)
    ```
10.  The comma operator may be used to evaluate independent subexpressions in the same expression, as with C.  The value,
     as with C, is the value of the last such subexpression.  Thus the value of `1.0, 7.0, 10.0` is `10.0`.  Subexpressions
     are evaluated in the order listed, so you can say `a=1.0, b=a+3`.
11.  There is no protection against simultaneous set and get of the same variable in different threads.  If such a situation
     arises it is theoretically possible to get part of the old value and part of the new value in the fetching thread.
     However, this possibility is deemed to be very rare, and no part of EC runs the same VM in different threads.
     Should it arise in practice we could provide synchronized variables at a later time.
12.  It is not possible to define your own functions.  The following built-in functions are available, and additional functions
     are built into EC ([here](https://github.com/EmeraldSequoia/Chronometer/blob/main/ECVirtualMachineOps.m)).  Note that all functions
     return a double, and any arguments are also double:
     `pi()` returns π.
     `sin(arg)` returns the sine of arg with arg in radians starting at 3pm going ccw
     `cos(arg)` returns the cosine of arg with arg in radians starting at 3pm going ccw
     `atan2(y, x)` returns the angle in radians from 3pm ccw of a radial line with coordinates x, y
     `ecnow()` returns a representation of the "current" time for a watch (which may be not be the current time if the watch has been set manually)
     `tzOffset()` returns the number of seconds the current time zone is offset from GMT.
     `fmod(arg1, arg2)` is like an integer mod operator except it returns fractional amounts, e.g., fmod(75.44, 60) == 15.44
     `round(arg1)` returns the closest integer to arg1, recast as a double, e.g., round(1.2) == 1.0
13.  Literal values may be specified in floating point (256.0), exponential form (2.56E2), decimal integer (256),
     hexadecimal integer (0x100), or octal integer (0400).
