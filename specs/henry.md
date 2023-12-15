As of December 2017, the right way to build the atlases (aka archives) is:

## Preparation

### One-time preparation

You will need a nonstandard Perl module.  Fortunately this is easy to install:

cpan
cpan> install File::Copy::Recursive

### Command server (each session, which times out after 30 minutes).

* You need to run a command server:
    * In a terminal window cd'd to the top level of the sandbox, invoke scripts/commandServer.pl and leave it running while Henry runs below
    NOTE: This script should not be run on a machine that can have untrusted users on it, as it opens a security hole while the script
    is running (if you know the port number, you can send arbitrary commands to it that will run as your user).

* Shut down any apps running in any simulators

* Run `scripts/clearArchives.pl` (deletes **ALL** (Henry) archive directories in all simulator apps **and** in your source area).

* Run `ChronoWithHHD` (short for [ChronometerWithHenryHD](https://github.com/EmeraldSequoia/docs/blob/main/Glossary.md#chronometerwithhenryhd)
  in the simulator, smallest iPhone, latest iOS  (note: NOT iPad) -- this will take several minutes to run
  * Ignore errors about the size of the archive

* Run `scripts/extractArchives.pl` to extract the archives from the simulator app directory.
