#!/bin/bash

# @ account_no = my_cineca_computing_account
# @ job_name = ALaDyn
# @ output = opic.$(jobid)
# @ error = epic.$(jobid)
# @ shell = /bin/bash
# @ wall_clock_limit = 0:30:00
# @ job_type = bluegene
# @ notification = always
# @ bg_size = 64
# @ notify_user = myemail@address
# @ queue

runjob --np 64 --ranks-per-node 1 --exe ./ALaDyn 

