I made these scripts along with the heavy lifting of ChatGPT so I could smoothly and painlessly install some ham radio software on a custom version of Ubuntu 22.10. Specifically, EmComm Tools Community by Gaston (KT7RUN); I am not a coder and have very limted experience with Linux.

As of April 23rd, 2026, these scripts work and achieve their stated goals running on my Panasonic FZM1 Mk3 Toughpad running ETC R6. 

All the scripts should automatically detect, grab, and install the latest version of their prospective programs, except the install/uninstall pair specifically for WSJTX Improved V3.1.0. I built the "universal" / "latest version" version of the script off of this one. Because I know this will work and not potentially break in the future, I kept it, and thought I might as well throw it in here too.

Both the install and uninstall scripts should not touch/remove any config or settings file, so updating a program to a newer version should be as simple as re-running the install script, and your settings should remain. 

Specifically for the WSJTX scripts, they should install alongside the (as of April 23rd, 2026) default included 2.7.0 version of WSJTX on EmComm Tools Community OS, and not affect it in any way. This allows you to run two distinct versions independent of each other (they will also have their separate settings/configs and .adi log files) and, if my custom install script fails for any reason, you have the default included version of WSJTX to fall back on, untouched.
