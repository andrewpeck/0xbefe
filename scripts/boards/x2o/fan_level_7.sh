#!/usr/bin/expect
spawn ssh root@10.0.2   
expect "root@10.0.0.2's password:"    
send "\r"
expect "#"
send "clia minfanlevel 7\r"
expect "#"

