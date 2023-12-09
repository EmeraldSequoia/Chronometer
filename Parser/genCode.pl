#!/usr/bin/perl -w

use strict;

# Standard Perl modules
use Carp;
use File::Basename;

# Configuration variables
my $inputM = "$ENV{SRCROOT}/Parser/EBVirtualMachineOps.m";
my $outputC = "$ENV{DERIVED_FILE_DIR}/EBVirtualMachine_gen.m";
my $outputH = "$ENV{DERIVED_FILE_DIR}/EBVirtualMachine_gen.h";
my $verbosity = 1;
my $updating = 1;
my $totalFilesCreatedNew = 0;
my $totalFilesChanged = 0;

# Make a temporary name from given name by adding ".new"
sub tempName {
    my $file = shift;
    return $file . ".new";
}

sub filesAreDifferent {
    my ($file1, $file2, $ignoreComments) = @_;
    if ((defined $ignoreComments) && $ignoreComments) {
	return filesAreDifferentIgnoringComments($file1, $file2);
    } else {
	return system("cmp -s \"$file1\" \"$file2\"") != 0;
    }
}

sub writeFileFromFileWithoutComments {
    my $inputFile = shift;
    my $outputFile = shift;
    open TMP, ">$outputFile"
      or die "Couldn't create $outputFile: $!\n";
    open FILE, $inputFile
      or die "Couldn't read file $inputFile: $!\n";
    while (<FILE>) {
	chomp;
	s/\/\/.*$//go;  # Not quite right, if escaped.  Hard to do right without complete lexing
	print TMP $_, "\n";
    }
    close FILE;
    close TMP;
}

sub filesAreDifferentIgnoringComments {
    my ($file1, $file2) = @_;
    my $tmp1 = "/tmp/extractTariffInfo.1";
    my $tmp2 = "/tmp/extractTariffInfo.2";
    writeFileFromFileWithoutComments $file1, $tmp1;
    writeFileFromFileWithoutComments $file2, $tmp2;
    my $returnValue = filesAreDifferent $tmp1, $tmp2;
    unlink $tmp1
      or die "Couldn't remove $tmp1: $!\n";
    unlink $tmp2
      or die "Couldn't remove $tmp2: $!\n";
    return $returnValue;
}

# Compare the given file's (presumably new) temp file with the given file,
# and if the tempfile has changed, rename it to be the new given file.
sub commitTempIfChanged {
    my $file = shift;
    my $ignoreComments = shift;
    my $tempFile = tempName $file;
    if (! -e $file) {
	rename $tempFile, $file
	  or confess "Couldn't rename $tempFile to $file: $!\n";
	warn "Created new $file\n" if ($verbosity > 2 || ($verbosity > 0 && $updating));
	$totalFilesCreatedNew++;
	return;
    }
    if (! -e $tempFile) {
	die "Tried to commit nonexistent file: $tempFile\n";
    }
    if (filesAreDifferent $file, $tempFile, $ignoreComments) {
	if ($verbosity > 5) {
	    system("diff $file $tempFile");
	}
	unlink $file;
	rename $tempFile, $file
	  or confess "Couldn't rename $tempFile to $file: $!\n";
	warn "Changed $file\n" if ($verbosity > 2 || ($verbosity > 0 && $updating));
	$totalFilesChanged++;
    } else {
	unlink $tempFile;
    }
}

########################################
# End of utility functions
########################################

my @operations;

sub writeExternsForOpcodeFunctions {
    my $outfileRef = shift;
    print $outfileRef "\n";
    foreach my $opDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$opDescriptor;
	if ($special) { # Direct dispatch
	    print $outfileRef "extern double EB_$opcodeName(const char **instructionStream, EBVirtualMachine *virtualMachine);\n";
	    if ($numArgs < 0) {
		print $outfileRef "extern void EB_$opcodeName" . "_skip(const char **instructionStream, EBVirtualMachine *virtualMachine);\n";
		print $outfileRef "extern void EB_$opcodeName" . "_print(FILE *, const char **instructionStream, EBVirtualMachine *virtualMachine, int indentLevel);\n";
	    }
	} elsif ($assign) {
	    print $outfileRef "extern double EB_$opcodeName(double *arg1, double arg2);\n";
	} else {
	    print $outfileRef "extern double EB_$opcodeName(";
	    for (my $i = 0; $i < $numArgs; $i++) {
		print $outfileRef ", " if $i > 0;
		print $outfileRef "double";
	    }
	    print $outfileRef ", " if $numArgs > 0;
	    print $outfileRef "EBVirtualMachine *virtualMachine);\n";
	}
    }
}

sub writeEnumeratedType {
    my $outfileRef = shift;
    print $outfileRef "\n";
    print $outfileRef "typedef enum EBOpcodeEnum {\n";
    foreach my $opDescriptor (@operations) {
	my ($opcodeName) = @$opDescriptor;
	print $outfileRef "    EB_$opcodeName" ."_opcode,\n";
    }
    print $outfileRef "} EBOpcode;\n";
}

sub writeDispatchMethods {
    my $outfileRef = shift;
    my $skipOnly = shift;
    my ($which, $returnValue);
    if ($skipOnly) {
	$which = "skip";
	$returnValue = "void";
	print $outfileRef <<EOF

// ***********
// Skip methods.  These are called to skip past an expression when the semantics
// of C expressions says the expression is not to be evaluated
// ***********
EOF
	  ;
    } else {
	$which = "dispatch";
	$returnValue = "double";
	print $outfileRef <<EOF

// ***********
// Dispatch methods.  These are the functions actually called by the interpreter.
// ***********
EOF
	  ;
    }
    foreach my $operationDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$operationDescriptor;
	my $dispatchName = $opcodeName . "_$which";
	if (defined $special) {
	    next if !$skipOnly;
	    next if $numArgs < 0;
	    print $outfileRef <<EOF

void EB_$dispatchName(const char **instructionStream,
                      EBVirtualMachine *virtualMachine)
{
EOF
	      ;
	    for (my $i = 0; $i < $numArgs; $i++) {
		print $outfileRef "    EBVMSkipStreamPastExpression(instructionStream, virtualMachine);\n";
	    }
	    print $outfileRef "}\n";
	    next;
        } elsif (defined $assign) {
            if ($skipOnly) {
		print $outfileRef <<EOF

void EB_$dispatchName(const char       **instructionStream,
                      EBVirtualMachine *virtualMachine)
{
    EBVMSkipPastVariableReference(instructionStream);
    EBVMSkipStreamPastExpression(instructionStream, virtualMachine);
}
EOF
                  ;
	    } else {
                my $initializingVariable = ($opcodeName eq "assign") ? "true /*initializing*/" : "false /* !initializing*/";
		print $outfileRef <<EOF

double EB_$dispatchName(const char **instructionStream,
			EBVirtualMachine *virtualMachine)
{
    double *variableReference = EBVMEvaluateVariableReferenceAndAdvanceStream(instructionStream, virtualMachine, $initializingVariable);
    double arg = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);
    return EB_$opcodeName(variableReference, arg);
}
EOF
                  ;
	    }
	    next;
        }
	print $outfileRef <<EOF

$returnValue EB_$dispatchName(const char       **instructionStream,
			      EBVirtualMachine *virtualMachine)
{
EOF
	  ;
	my $argList = "";
	my $argno = 0;
	while ($argno++ < $numArgs) {
	    if ($argno > 1) {
		$argList .= ", ";
	    }
	    my $argName = "arg$argno";
	    $argList .= $argName;
	    if ($skipOnly) {
		print $outfileRef "    EBVMSkipStreamPastExpression(instructionStream, virtualMachine);\n";
	    } else {
		print $outfileRef "    double $argName = EBVMEvaluateAndAdvanceStream(instructionStream, virtualMachine);\n";
	    }
	}
	if (!$skipOnly) {
	    if ($numArgs > 0) {
		$argList .= ", ";
	    }
	    print $outfileRef "    return EB_$opcodeName($argList" . "virtualMachine);\n";
	}
	print $outfileRef "}\n";
    }
}

sub writeDispatchTable {
    my $outfileCRef = shift;
    my $outfileHRef = shift;
    my $skipOnly = shift;
    my $which = $skipOnly ? "skip" : "dispatch";
    my $returnValue = $skipOnly ? "void" : "double";
    my $tableName = $skipOnly ? "EBVMSkipFunctions" : "EBVMDispatchFunctions";
    print $outfileHRef <<EOF

extern $returnValue (*$tableName\[])(const char **, EBVirtualMachine *);
extern int num$tableName;
EOF
      ;
    print $outfileCRef <<EOF

$returnValue (*$tableName\[])(const char **, EBVirtualMachine *) = {
EOF
      ;
    foreach my $operationDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$operationDescriptor;
	my $dispatchName = $opcodeName . "_$which";
	if ($special && !$skipOnly) {
	    print $outfileCRef "    EB_$opcodeName,    // dispatchDirectly to SPECIAL functions\n";
	} else {
	    print $outfileCRef "    EB_$dispatchName,\n";
	}
    }
    print $outfileCRef "};\n";
    print $outfileCRef "int num$tableName = sizeof($tableName) / sizeof($returnValue (*)(const char **));\n";
}

sub writePrintMethods {
    my $outfileRef = shift;
    print $outfileRef <<EOF

// ***********
// Print methods.  These are debug methods to print an instruction stream.
// ***********
EOF
       ;
    foreach my $operationDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$operationDescriptor;
	my $printName = $opcodeName . "_print";
	next if $special && $numArgs < 0;
	if ($assign) {
	    print $outfileRef <<EOF

void EB_$printName(FILE *outputFile,
                   const char **instructionStream,
		   EBVirtualMachine *virtualMachine,
                   int indentLevel)
{
    int i;
    for (i = 0; i < indentLevel; i++) {
        fprintf(outputFile, "  ");
    }
    fprintf(outputFile, "$opcodeName\\n");
    int varcode = EBVMSkipPastAndReturnInt(instructionStream);
    for (i = 0; i < indentLevel + 1; i++) {
        fprintf(outputFile, "  ");
    }
    NSString *variableNameString = [virtualMachine variableNameForCode:varcode];
    fprintf(outputFile, "%d (%s)\\n", varcode, [variableNameString UTF8String]);
    EBVMPrintInstructionStreamPvt(outputFile, instructionStream, virtualMachine, indentLevel + 1);
}
EOF
	      ;
	} else {
	    print $outfileRef <<EOF

void EB_$printName(FILE *outputFile,
		   const char **instructionStream,
		   EBVirtualMachine *virtualMachine,
                   int indentLevel)
{
    int i;
    for (i = 0; i < indentLevel; i++) {
        fprintf(outputFile, "  ");
    }
    fprintf(outputFile, "$opcodeName\\n");
EOF
	      ;
	    for (my $i = 0; $i < $numArgs; $i++) {
		print $outfileRef <<EOF
    EBVMPrintInstructionStreamPvt(outputFile, instructionStream, virtualMachine, indentLevel + 1);
EOF
		  ;
	    }
	    print $outfileRef "}\n";
	}
    }
}

sub writePrintTable {
    my $outfileCRef = shift;
    my $outfileHRef = shift;
    my $tableName = "EBVMPrintFunctions";
    print $outfileHRef <<EOF

extern void (*$tableName\[])(FILE *, const char **, EBVirtualMachine *, int);
extern int num$tableName;
EOF
      ;
    print $outfileCRef <<EOF

void (*$tableName\[])(FILE *, const char **, EBVirtualMachine *, int) = {
EOF
      ;
    foreach my $operationDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$operationDescriptor;
	my $printName = $opcodeName . "_print";
	print $outfileCRef "    EB_$printName,\n";
    }
    print $outfileCRef "};\n";
    print $outfileCRef "int num$tableName = sizeof($tableName) / sizeof(void (*)(FILE *, const char **, EBVirtualMachine *, int));\n";
}

sub writeArgumentCountsTable {
    my $outfileCRef = shift;
    my $outfileHRef = shift;
    print $outfileHRef <<EOF

extern int EBVMOpcodeArgumentCounts[];
extern int numEBVMOpcodeArgumentCounts;
EOF
      ;
    print $outfileCRef <<EOF

int EBVMOpcodeArgumentCounts[] = {
EOF
      ;
    foreach my $operationDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$operationDescriptor;
	print $outfileCRef "$numArgs,\n";
    }
    print $outfileCRef "};\n";
    print $outfileCRef "int numEBVMOpcodeArgumentCounts = sizeof(EBVMOpcodeArgumentCounts) / sizeof(int);\n";
}

sub writeOpcodeCallback {
    my $outfileCRef = shift;
    my $outfileHRef = shift;
    print $outfileHRef <<EOF

extern void EBCallBackWithOpcodeStrings(void);
EOF
      ;
    print $outfileCRef <<EOF

void EBCallBackWithOpcodeStrings(void)
{
#ifdef EC_HENRY
EOF
      ;
    foreach my $operationDescriptor (@operations) {
	my ($opcodeName, $numArgs, $special, $assign) = @$operationDescriptor;
	my $enumValue = $opcodeName . "_opcode";
	print $outfileCRef "    EBAddOpcodeToDictionary(EB_$enumValue, \"$opcodeName\");\n";
    }
      ;
    print $outfileCRef <<EOF
#endif
}
EOF
      ;
}

sub processInputFile {
    my $inputFile = shift;
    open M, $inputFile
      or die "Couldn't read file $inputFile: $!\n";
    while (<M>) {
	next if /^\s*#\s*define/;
	if (/EBVM_OP(\d+|X)(_SIMPLE|_INTEGER|_(SPECIAL)|_(ASSIGN))?\s*\(\s*([^,\)]+)([^\)]*)\)/) {
	    my $numArgsNamed = $1;
	    $numArgsNamed = -1 if $numArgsNamed eq "X";
	    my $modifier = $2;
	    my $special = $3;
	    my $assign = $4;
	    my $opcode = $5;
	    my $args = $6;
	    my $argCount;
	    if ($args eq "") {
		$argCount = 0;
	    } else {
		my @args = split /,/, $args;
		$argCount = (scalar @args) - 1;
		$argCount-- if defined $modifier;
	    }
	    if (defined $special) {
		$argCount = $numArgsNamed;
	    } else {
		$numArgsNamed == $argCount
		  or die "Number of arguments named ($numArgsNamed) doesn't match number of arguments supplied ($argCount) for $opcode\n";
	    }
	    push @operations, [$opcode, $argCount, $special, $assign];
	    # print "$opcode: '$args' $argCount\n";
	}
    }
    close M;
}

processInputFile $inputM;
foreach my $inputFile (@ARGV) {
    processInputFile $inputFile;
}

@operations = sort {$$a[0] cmp $$b[0]} @operations;

my $tempOut = tempName $outputC;
open OUTC, ">$tempOut"
  or die "Couldn't create $tempOut: $!\n";

$tempOut = tempName $outputH;
open OUTH, ">$tempOut"
  or die "Couldn't create $tempOut: $!\n";

my $dateString = localtime;
my $scriptName = fileparse $0;

print OUTC <<EOF
//
// THIS IS A GENERATED FILE.  DO NOT EDIT DIRECTLY.
//
// It was generated $dateString by the script $scriptName.
//
#include <stdio.h>
//
#include "EBVirtualMachinePvt.h"
#include "EBVirtualMachinePvtObjC.h"
#include "EBVirtualMachine_gen.h"
#include "EBVirtualMachine.h"
EOF
  ;

print OUTH <<EOF
//
// THIS IS A GENERATED FILE.  DO NOT EDIT DIRECTLY.
//
// It was generated $dateString by the script $scriptName.
//
EOF
  ;

writeExternsForOpcodeFunctions \*OUTC;
writeEnumeratedType \*OUTH;
writeDispatchMethods \*OUTC, 0;
writeDispatchTable \*OUTC, \*OUTH, 0;
writeDispatchMethods \*OUTC, 1;
writeDispatchTable \*OUTC, \*OUTH, 1;
writeOpcodeCallback \*OUTC, \*OUTH;
writeArgumentCountsTable \*OUTC, \*OUTH;
writePrintMethods \*OUTC;
writePrintTable \*OUTC, \*OUTH;

close OUTC;

commitTempIfChanged $outputC, 1;
commitTempIfChanged $outputH, 1;
