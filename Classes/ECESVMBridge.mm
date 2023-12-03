//
//  ECESVMBridge.mm
//
//  Created by Steve Pucci 18 Jan 2016
//  Copyright Emerald Sequoia LLC 2016. All rights reserved.
//

#import "EBVirtualMachine.h"  // Include this only through the real class

#include "ESChronoVMOwner.hpp"
#include "ESVirtualMachine.hpp"
#include "ESChronoVMOwner.hpp"
#include "ESChronoUpdateManager.hpp"
#include "ESErrorReporter.hpp"
#include "ESUtil.hpp"
#include "ESThread.hpp"
#include "ESVirtualMachine.hpp"
#include "ESVirtualMachine_gen.hpp"
#include "ESTimeLocAstroEnvironment.hpp"

class VMErrorReporter : public ESVirtualMachineErrorReporter {
  public:
    virtual void            reportError(const std::string &errorMessage) {
        ESErrorReporter::logError("ESVirtualMachine", "%s", errorMessage.c_str());
    }
};

class ErrorReporterBridge : public ESVirtualMachineErrorReporter {
  public:
                            ErrorReporterBridge(id cocoaErrorReporter)
    :   _cocoaErrorReporter([cocoaErrorReporter retain]) {
    }
                            ~ErrorReporterBridge() {
        [_cocoaErrorReporter release];
    }

    virtual void            reportError(const std::string &errorMessage) {
        [_cocoaErrorReporter reportError:[NSString stringWithUTF8String:errorMessage.c_str()]];
    }
  private:
    id                      _cocoaErrorReporter;
};

class VMOwner : public ESChronoVMOwner {
  public:
                            VMOwner(int numEnvs, const std::string &watchName)
    :   _numEnvironments(numEnvs),
        ESChronoVMOwner(watchName)
    {
        _environments = new ESTimeLocAstroEnvironment *[numEnvs];
        for (int i = 0; i < _numEnvironments; i++) {
            _environments[i] = new ESTimeLocAstroEnvironment("America/Los_Angeles", true /* observingIPhoneTime */);
        }
        _timers = new ESWatchTime*[ECNumTimers];
        for (int i = 0; i < ECNumTimers; i++) {
            _timers[i] = new ESWatchTime;
        }
    }
                            ~VMOwner() 
    {
        for (int i = 0; i < _numEnvironments; i++) {
            delete _environments[i];
        }
        delete [] _environments;
        for (int i = 0; i < ECNumTimers; i++) {
            delete _timers[i];
        }
        delete [] _timers;
    }
    virtual ESWatchTime     *mainTime() { return timerWithIndex(0); }
    virtual ESTimeLocAstroEnvironment **envs() { return _environments; }
    virtual int             numEnvs() { return _numEnvironments; }

    virtual ESWatchTime     *timerWithIndex(unsigned int timerNumber) { return _timers[timerNumber]; }

    virtual ESAstronomyManager *mainAstro() { return astroWithIndex(0); }
    virtual ESAstronomyManager *astroWithIndex(unsigned int envIndex) { return env(envIndex)->astronomyManager(); }

    virtual ESTimeLocAstroEnvironment *mainEnv() { return env(0); }
    virtual ESTimeLocAstroEnvironment *env(unsigned int envIndex) { return _environments[envIndex]; }

    virtual int             topSlot() { return 0; }
    virtual void            setOverrideTopSlot(int tempOverrideSlot) {}

    int                     weekdayStart() { return _weekdayStart; }

  private:
    ESTimeLocAstroEnvironment **_environments;
    int                     _numEnvironments;
    ESWatchTime             **_timers;
    static int              _weekdayStart;
};

// This doesn't really belong here but it needs to be defined somewhere in HfA.
/*static*/ void
ESChronoUpdateManager::forceUpdateAllowingAnimation(ESChronoWatch *watchIfKnown,
                                                    bool          allowAnimation,
                                                    ECDragType    dragType) {
    // Do nothing, HfA doesn't need it to work; it never actually draws anything.
}

/*static*/ int VMOwner::_weekdayStart = 0;

static bool ESLibsInitialized = false;

@implementation EBVirtualMachine

@synthesize vm;

-(void)commonInitWithName:(NSString *)nam {
    if (!ESLibsInitialized) {
        ESUtil::init();
        ESThread::inMainThread();  // may be required to initialize main thread
        ESVMInitExterns();
        ESLibsInitialized = true;
    }
    vmErrorReporter = new VMErrorReporter;
    vmOwner = new VMOwner(29/*numEnvs*/, [nam UTF8String]);
}

-(id)init {
    [super init];
    unusedCocoaOwner = nil;
    [self commonInitWithName:@"noName"];
    vm = new ESVirtualMachine(vmOwner, "ECESVMBridge", vmErrorReporter);
    return self;
}

-(id)initWithOwner:(id)owner name:(NSString *)nam {
    [super init];
    unusedCocoaOwner = owner;
    [self commonInitWithName:nam];
    vm = new ESVirtualMachine(vmOwner, [nam UTF8String], vmErrorReporter);
    return self;
}

-(id)initWithOwner:(id)owner name:(NSString *)nam variableCount:(int)variableCount variableImporter:(EBVMvariableImporter)variableImporter {
    [super init];
    unusedCocoaOwner = owner;
    [self commonInitWithName:nam];
    vm = new ESVirtualMachine(vmOwner, [nam UTF8String], vmErrorReporter, variableCount, NULL/*variableImporter*/);
    (*variableImporter)(self);
    return self;
}

-(void)dealloc {
    delete vm;
    delete vmOwner;
    delete vmErrorReporter;
    [super dealloc];
}

-(NSString *)name {
    return [NSString stringWithUTF8String:vm->name().c_str()];
}

-(id)owner {
    return unusedCocoaOwner;
}

-(double)evaluateInstructionStream:(EBVMInstructionStream *)instructionStream errorReporter:(id)errorReporter {
    ErrorReporterBridge errorReporterBridge(errorReporter);
    return vm->evaluateInstructionStream(instructionStream->stream, &errorReporterBridge);
}

-(EBVMInstructionStream *)compileInstructionStreamFromCExpression:(NSString *)CExpressionString errorReporter:(id)errorReporter {
    ErrorReporterBridge errorReporterBridge(errorReporter);
    return [[EBVMInstructionStream alloc] 
            initWithStream:vm->compileInstructionStreamFromCExpression([CExpressionString UTF8String], 
                                                                       &errorReporterBridge)];
}

-(void)importVariableWithName:(NSString *)name andValue:(double)value {
    vm->importVariableWithName([name UTF8String], value);
}

-(int)numVariables {
    return vm->numVariables();
}

-(void)writeVariableNamesToFile:(NSString *)filename {
    vm->writeVariableNamesToFile([filename UTF8String]);
}

-(void)readVariableNamesFromFile:(NSString *)filename {
    vm->readVariableNamesFromFile([filename UTF8String]);
}

-(void)dumpVariableValues {
    vm->dumpVariableValues();
}

-(bool)variableWithIndexIsDefined:(int)indx {
    return vm->variableWithIndexIsDefined(indx);
}

-(double)variableValueForIndex:(int)indx {
    return vm->variableValueForIndex(indx);
}

// -(EBVMInstructionStream *)streamBeingEvaluated {
// }

-(void)printCurrentStream {
    vm->printCurrentStream();
}

-(NSString *)variableNameForCode:(int)varcode {
    return [NSString stringWithUTF8String:vm->variableNameForCode(varcode).c_str()];
}

@end

@implementation EBVMInstructionStream

-(id)initWithStream:(ESVMInstructionStream *)esvmStream {
    [super init];
    stream = esvmStream;
    return self;
}

-(void)dealloc {
    delete stream;
    [super dealloc];
}

-(void)printToOutputFile:(FILE *)outputFile withIndentLevel:(int)indentLevel fromVirtualMachine:(EBVirtualMachine *)virtualMachine {
    stream->printToOutputFile(outputFile, indentLevel, virtualMachine.vm);
}

-(void)writeInstructionStreamToFile:(FILE *)filePointer forVirtualMachine:(EBVirtualMachine *)virtualMachine {
    stream->writeInstructionStreamToFile(filePointer, virtualMachine.vm);
}

-(id)initFromFilePointer:(FILE *)filePointer withStreamLength:(int)streamLength forVirtualMachine:(EBVirtualMachine *)virtualMachine pathForDebugMsgs:(NSString *)path {
    [super init];
    stream = new ESVMInstructionStream(filePointer, streamLength, virtualMachine.vm);
    return self;
}

@end
