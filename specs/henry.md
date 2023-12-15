See the overall flow diagram [here](https://github.com/EmeraldSequoia/Chronometer/blob/main/README.md).

## Preparation

### One-time preparation

You will need a nonstandard Perl module.  Fortunately this is easy to install:

cpan
cpan> install File::Copy::Recursive

### Session preparation

#### Command server (times out after 30 minutes of inactivity)

* You need to run a command server:
    * In a terminal window cd'd to the top level of the sandbox, invoke scripts/commandServer.pl and leave it running while Henry runs below.
    * **NOTE: This script should not be run on a machine that can have untrusted users on it, as it opens a security hole while the script
      is running (if you know the port number, you can send arbitrary commands to it that will run as your user).**

#### Clear the environment

* Shut down any apps running in any simulators

* Run `scripts/clearArchives.pl` (deletes **ALL** (Henry) archive directories in all simulator apps **and** in your source area).

### Run Henry

* Run `ChronoWithHHD` (short for [ChronometerWithHenryHD](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#chronometerwithhenryhd)
  in the simulator, smallest iPhone, latest iOS  (note: NOT iPad) -- this will take several minutes to run
  * Ignore errors about the size of the archive
* The first time you run the app after clearing out the environment, it will rebuild all watches' artifacts (takes a minute or so).
* After the first time, to save time it will rebuild only the background watch and whichever watch was last active.

### Extract the archives from the Henry simulator

* Run `scripts/extractArchives.pl` to extract the archives from the simulator app directory.
* Commit these files to Git. You should use a visual diff tool on the images to ensure watches that haven't changed are not too different.

At this point you can build Emerald Chronometer or ECHD and the build process will pick up the new artifacts.
