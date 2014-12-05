ocsp_sweeper
============

OCSP Sweeper for Nagios, used to queue results and batch process log files. One useful way of using this is to create a ramdisk for the log, the parse it every N seconds and trigger a send_nsca event at X bytes. This was incredibly useful for managing an instance of over a million services.
