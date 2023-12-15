## Overview

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
    directory. Instructions for running this step are
    [here](https://github.com/EmeraldSequoia/Chronometer/blob/main/specs/henry.md).
2.  The Xcode build process for Chronometer uses runtime code, the assets generated by
    the simulator, and other assets generated on the fly, to construct the apps. There
    are two Xcode `products` (Chronometer and ChronometerHD), but the differences between
    them are very small (mostly app metadata indicating what devices are supported,
    "grid mode" layout, and the handling of device orientations).


```mermaid
flowchart
    xml[Watch Definition Files]
    henry[Henry aka\nChronoWithHHD]
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

## Selected details

### Watch definition files (XML)

Watches are defined in XML files inside the
[watches/Builtin](https://github.com/EmeraldSequoia/Chronometer/tree/main/Watches/Builtin)
subdirectory. Each watch gets its own directory, which always contains a single XML file
containing the watch definition, and usually also contains other assets used in the
definition, such as images for hands and backgrounds.

The parser of these files is
[ECWatchDefinitionManager](https://github.com/EmeraldSequoia/Chronometer/blob/main/Classes/ECWatchDefinitionManager.m).
Since at present there is no documentation for the XML syntax used, these files are best
understood by examining the parser code linked above and comparing the XML files with the
watch display it is defining. Another way of tracking down how the parameters are used is
to go to the `QView` class that
[Henry](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#henry)
uses to draw the part.  For example, the `radius2` attribute of the `QDial` XML element (parsed
[here](https://github.com/EmeraldSequoia/Chronometer/blob/main/Classes/ECWatchDefinitionManager.m#L737))
is used in the `QDialView` class
[here](https://github.com/EmeraldSequoia/Chronometer/blob/main/Classes/ECQView.m#L2435).

### Expressions, the "Parser", and VMs

Many of the attributes defined in the XML files are C-like expressions. These are parsed
into byte code by the
[Parser](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#parser), and
interpreted by a
[VM](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#virtual-machine-vm)
inside each runtime "watch".

### Help files

One of the original goals for EC was to be able to run without access to a network, for
use in remote areas (all of the astronomy calculations are done on the device, for
example). Similarly, the help files are also all bundled with the application and don't
require a network to view (though most of them are mirrored in a slightly different way
on the website). At build time, a script is invoked (in an Xcode "build phase") to copy
the files out of the source area into the app bundle.

### OpenGL

All of Emerald Chromnometer's watch displays are drawn with OpenGL. This protocol is
currently deprecated on both iOS and WearOS (Android), but so far is fully supported
by both OS runtimes.

EC uses only a small portion of the OpenGL API. In particular, it only
uses 2D primitves, and it only draws triangles with textures. While
OpenGL is fundamental to the current implementation of EC, it should
be possible to subsitute another high-performance graphics package
with similar primitives, probably without even changing the format of
the
[archives](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#archive)
created by Henry.

In simplified terms, what EC does is

1. Tell OpenGL the current coordinate mapping.
2. Attach an
   [atlas](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#atlas) with the
   images of each part in it.
3. Give OpenGL a pair of triangle lists: One list has the dimensions of the part triangles in
   the atlas image, and the other list has the coordinates on the screen to draw.

### Memory management

At runtime, great care is taken to manage memory on the device. This is far less important
now than it used to be (see [History](#history) below), but for the original device it was
critical to being able to have more than a few watches enabled. Even today, it is required
to be able to respond to OS requests to reduce memory, particularly when running in the
background, lest the app be forcibly removed.

In particular:
*   Management of the texture atlases and of the other watch data is done in a background
    thread to keep ready for drawing the watches most likely to be viewed next. This includes
    dropping atlases when a memory warning is received.
*   OpenGL is used to minimize the amount of code and data required to be in memory in
    order to draw.

## Adding a new watch

Adding a new watch is normally as "simple" as creating a new directory in `Watches/Builtin`,
adding a new XML file (see above), adding any assets required to the directory, and adding the
watch to
[the list of "approved" watches](https://github.com/EmeraldSequoia/Chronometer/blob/main/Watches/Builtin/Approvals.txt).
However, the current count of 25 watches means that additional work will be needed in order
to support a 26th watch, since the current grid of 5x5 watches in "grid mode" is the
maximum size currently supported. To go beyond this, various hand-coded layout arrays
would need to be expanded starting around
[here](https://github.com/EmeraldSequoia/Chronometer/blob/main/Classes/ChronometerAppDelegate.m#L333).

## Testing

There are almost no explicit tests in the entire EC project. Extensive manual testing was
done for every new subsystem as it was brought online, and the products have had very few
bugs in their 15-year lifetime (on the order of a dozen customer-visible bugs in that time).
This is, in part, because much of the most complex code was written and maintained by a
single person; the lack of tests is much more problematic in today's GitHub environment.

That said, the code is extremely stable, and since the pieces are very low-level and don't,
as a rule, have external dependencies, it's unlikely that the low-level code will break.
The use of XML as the way watches are defined means that no new code needs to be written
to change a watch definition.

## History

The complexity evident in the diagram at the top of this page stems from two early goals
of the project:
1.  Be able to swipe through many watches without running out of memory on the device (the
    original iPhone only had about 128 megabytes available to applications, including
    backing storage for Quartz view elements). Much of the
    [Memory management](#memory-management) done in the app is not required today, but it
    would be very difficult to change now.
2.  Be able to define new watches just using XML so that we don't have to write any
    Objective-C++ code to define a new watch (this simplifies code paths and makes it easier
    to test the code that does exist). We also originally intended that users be able to
    define their own watches, but we dropped this goal early on (for one thing, allowing
    customers to define their own watches would open up security holes in the bytecode
    interpreter; for another, better error handling and documentation would need to be
    provided).
    
