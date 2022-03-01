#########################################################################################
#   License                                                                             #
#                                                                                       #
#   Copyright © 2018, Numato Systems Private Limited. All rights reserved.              #
#                                                                                       #
#   This software including all supplied files, Intellectual Property, know-how         #
#   Or part of thereof as applicable (collectively called SOFTWARE) in source           #
#   And/Or binary form with accompanying documentation Is licensed to you by            #
#   Numato Systems Private Limited (LICENSOR) subject To the following conditions.      #
#                                                                                       #
#   1. This license permits perpetual use of the SOFTWARE if all conditions in this     #
#       license are met. This license stands revoked In the Event Of breach Of any      #
#       of the conditions.                                                              #
#   2. You may use, modify, copy the SOFTWARE within your organization. This            #
#       SOFTWARE shall Not be transferred To third parties In any form except           #
#       fully compiled binary form As part Of your final application.                   #
#   3. This SOFTWARE Is licensed only to be used in connection with/executed on         #
#       supported products manufactured by Numato Systems Private Limited.              #
#       Using/ executing this SOFTWARE On/In connection With custom Or third party      #
#       hardware without the LICENSORs prior written permission Is expressly            #
#       prohibited.                                                                     #
#   4. You may Not download Or otherwise secure a copy of this SOFTWARE for the         #
#       purpose of competing with Numato Systems Private Limited Or subsidiaries in     #
#       any way such As but Not limited To sharing the SOFTWARE With competitors,       #
#       reverse engineering etc... You may Not Do so even If you have no gain           #
#       financial Or otherwise from such action.                                        #
#   5. DISCLAIMER                                                                       #
#   5.1. USING THIS SOFTWARE Is VOLUNTARY And OPTIONAL. NO PART OF THIS SOFTWARE        #
#       CONSTITUTE A PRODUCT Or PART Of PRODUCT SOLD BY THE LICENSOR.                   #
#   5.2. THIS SOFTWARE And DOCUMENTATION ARE PROVIDED “AS IS” WITH ALL FAULTS,          #
#       DEFECTS And ERRORS And WITHOUT WARRANTY OF ANY KIND.                            #
#   5.3. THE LICENSOR DISCLAIMS ALL WARRANTIES EITHER EXPRESS Or IMPLIED, INCLUDING     #
#       WITHOUT LIMITATION, ANY WARRANTY Of MERCHANTABILITY Or FITNESS For ANY          #
#       PURPOSE.                                                                        #
#   5.4. IN NO EVENT, SHALL THE LICENSOR, IT'S PARTNERS OR DISTRIBUTORS BE LIABLE OR    #
#       OBLIGATED FOR ANY DAMAGES, EXPENSES, COSTS, LOSS Of MONEY, LOSS OF TANGIBLE     #
#       Or INTANGIBLE ASSETS DIRECT Or INDIRECT UNDER ANY LEGAL ARGUMENT SUCH AS BUT    #
#       Not LIMITED TO CONTRACT, NEGLIGENCE, STRICT LIABILITY, CONTRIBUTION, BREACH     #
#       OF WARRANTY Or ANY OTHER SIMILAR LEGAL DEFINITION.                              #
#########################################################################################

#   Python code demonstrating basic Relay features Of Numato Lab Ethernet Relay Module.

#########################################################################################
#                                                                                       #
#                                   Prerequisites                                       #
#                                   -------------                                       #
#                                 Python version 3.x                                    #
#                                  pip version 6.x                                      #
#                                                                                       #
#########################################################################################

import sys
import telnetlib
import time
import re

#########################################################################################
#                                   Utility Class                                       #
#########################################################################################

class Colors:
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

class ethernet_relay:
    # Object for controlling relay using telnet

    def __init__(self, DeviceIPAddress_input="169.254.1.1", user_input="admin", password_input="admin"):
        self.DeviceIPAddress = DeviceIPAddress_input
        self.user = user_input
        self.password = password_input

        #Create a new TELNET object
        self.telnet_obj = telnetlib.Telnet(self.DeviceIPAddress)

    def __del__(self):
        #Close the TELNET session before exiting
        self.telnet_obj.close()

    #Connect to device with user provided credentials
    def connectToDevice(self):

        #Wait for login prompt from device and enter user name when prompted
        self.telnet_obj.read_until(b"login")
        self.telnet_obj.write(self.user.encode('ascii') + b"\r\n")
    
        #Wait for password prompt and enter password when prompted by device
        self.telnet_obj.read_until(b"Password: ")
        self.telnet_obj.write(self.password.encode('ascii') + b"\r\n")
    
        #Wait for device response
        log_result = self.telnet_obj.read_until(b"successfully\r\n")
        self.telnet_obj.read_until(b">")
    
        #Check if login attempt was successful
        if b"successfully" in log_result:
            print(Colors.GREEN + "\nLogged in successfully... Connected to device: %s\n"%self.DeviceIPAddress + Colors.ENDC)
            #Flush any data that may be left in the input buffer
            response = self.telnet_obj.read_eager()
            return True
        elif "denied" in log_result:
            print(Colors.RED + "ERROR: Login failed!!!! Please check login credentials or Device IP Address\n\n" + Colors.ENDC)
            return False

    def relay_set(self, relay_number, state):
        relay_number = str(relay_number)
        if re.match("^[a-v]*$", relay_number):
            relay_number = relay_number.upper()  #Converts the relay_number(A to V) to upper case if user entered it as lower case

        if state not in [0,1]:
            print(Colors.RED + "ERROR: Invalid State" + Colors.ENDC)
            return False
        try:
            if state==1:# Relay ON
                self.telnet_obj.write(("relay on " + str(relay_number) + "\r\n").encode())
                print("Relay ON", relay_number)
            elif state==0: # Relay OFF
                self.telnet_obj.write(("relay off " + str(relay_number) + "\r\n").encode())
                print("Relay OFF", relay_number)
            time.sleep(1)
            self.telnet_obj.read_eager()
            return True
        except:
            print(Colors.RED + "ERROR: Problem in Setting Relay State" + Colors.ENDC)
            return False

    def relay_read(self, relay_number):
        relay_number = str(relay_number)
        if re.match("^[a-v]*$", relay_number):
            relay_number = relay_number.upper()  #Converts the relay_number(A to V) to upper case if user entered it as lower case
        try:
            self.telnet_obj.write(b"relay read " + str(relay_number).encode("ascii") + b"\r\n")
            time.sleep(1)
            response = self.telnet_obj.read_eager()
            print("\nRelay read", relay_number, ":", re.split(br'[&>]', response)[0].decode())
            return True
        except:
            print(Colors.RED + "ERROR: Problem in Reading Relay State" + Colors.ENDC)
            return False



