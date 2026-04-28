I made these scripts along with the heavy lifting of ChatGPT so I could smoothly and painlessly install some ham radio software on a custom version of Ubuntu 22.10. Specifically, EmComm Tools Community by Gaston (KT7RUN); I am not a coder and have very limted experience with Linux.

As of April 28th, 2026, these scripts work and achieve their stated goals running on my Panasonic FZM1 Mk3 Toughpad running ETC R6. 

All the scripts should automatically detect, grab, and install the latest version of their prospective programs. Both the install and uninstall scripts should not touch/remove any config or settings files, so updating a program to a newer version should be as simple as re-running the install script, and your settings should remain. All software is installed to ~/Applications/ and settings & config files are installed to ~/.config/ and ~/.local/

Specifically for the WSJTX script, it should install alongside the (as of April 28th, 2026) default included 2.7.0 version of WSJTX on EmComm Tools Community OS, and not affect it in any way. This allows you to run two distinct versions independent of each other (they will also have their separate settings/configs and .adi log files) and, if my custom install script fails for any reason, you have the default included version of WSJTX to fall back on, untouched.

Note: 
- For me, as of April 28th, 2026, the following scenario happens to me while running ETC R6 on my FZM1 Mk3 Toughpad with et-radio set to "Yaesu FT-891 (DR-891)" which is the rig I use. 
- For the version of WSJTX my script will install there is a quirk with the audio levels I have noticed but has an easy fix. If you start up my (e.g. v3.1.0) WSJTX the bottom left audio level bar will likely be too high and in the red. Somewhere around 80. To fix this, I found simply opening up the pre-installed version of WSJTX on ETC (right now it is V2.7.0) then closing that, and then opening up the one my script installs does something to fix this audio issue. As if somehow opening up ETC's pre-installed version of WSJTX sets the audio levels, and my version can pick up those settings and all is good. I don't pretend to understand why, but easy fix.
