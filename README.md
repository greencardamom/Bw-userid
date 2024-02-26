Bw-userid
===========
Custom user scripts to monitor and report about backlinks on Wikipedia.

Install
==========

* Clone the repo

        cd ~
        git clone 'https://github.com/greencardamom/Bw-userid'

* Install BotWikiAwk library

        cd ~ 
        git clone 'https://github.com/greencardamom/BotWikiAwk'
        export AWKPATH=.:/home/user/BotWikiAwk/lib:/usr/share/awk
        export PATH=$PATH:/home/user/BotWikiAwk/bin
        cd ~/BotWikiAwk
        ./setup.sh
        read SETUP for further instructions eg. setting up email

* Configure wikiget.awk which was installed with BotWikiAwk - add Oauth Consumer Secrets so you can post to Wikipedia. See the file "EDITSETUP" at https://github.com/greencardamom/Wikiget

* Edit bw.awk and follow instructions in the "Configuration Variables & Install Instructions". 

Running
==========
Run bw.awk once a day from cron. No CLI arguments are required.

Dependencies
====
* GNU awk 4.1+
* BotWikiAwk library
* Bot account with bot perms to post to Wikipedia, and Oauth Consumer credentials

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License Copyright 2024
