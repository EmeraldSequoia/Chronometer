This directory currently contains code only for the iOS version of
Emerald Chronometer.  Code for the WearOS version of Chronometer will
eventually be included here as well, under the `android` tree at the
top level, and documentation for building that app will be put there
at that time.

The build process for the iOS version of Emerald Chronometer is
divided into two main pieces:

1.  A preprocessor iOS Simulator app nicknamed
    [Henry](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#henry) and
    found in the Xcode product
    [ChronoWithHHD](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#chronowithhhd)
    is run to generate assets. This step is only necessary when a watch definition has
    changed, either functionally or in appearance; the outputs of the preprocessor are
    checked into the repository under the
    [archiveHD](https://github.com/EmeraldSequoia/Chronometer/tree/main/archiveHD)
    directory.
2.  The Xcode build process for Chronometer uses runtime code, the assets generated by
    the simulator, and other assets generated on the fly, to construct the apps. There
    are two Xcode `products` (Chronometer and ChronometerHD), but the differences between
    them are very small (mostly app metadata indicating what devices are supported,
    "grid mode" layout, and the handling of device orientations.


```mermaid
flowchart
    xml[Watch Definition Files]
    henry[Henry\nChronoWithHHD]
    archives[archive files]
    cDotL[c.l]
    lex
    cDotY[c.y]
    yacc
    lexOut[generated lex output]
    yaccOut[generated yacc output]
    locData[location data files]
    helpFiles[help files]
    vmops[Parser op files]
    genParser[Parser generator]
    parserOut[generated Parser files]
    source[C, C++, & ObjC++ source]
    compiler[compiler]
    xcode[Xcode build process]
    ec[Emerald Chronometer]
    echd[Emerald Chronometer HD]

    xml-->henry
    parserOut-->henry
    henry-->archives
    archives-->xcode
    cDotL-->lex
    cDotY-->yacc
    lex-->lexOut
    yacc-->yaccOut
    lexOut-->compiler
    yaccOut-->compiler
    vmops-->genParser
    genParser-->parserOut
    parserOut-->compiler
    source-->compiler
    helpFiles-->xcode
    locData-->xcode
    compiler-->xcode
    xcode-->ec
    xcode-->echd

```
