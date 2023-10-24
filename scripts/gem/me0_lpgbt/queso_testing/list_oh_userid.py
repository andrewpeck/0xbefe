import os, sys, glob, math
import argparse

# Parsing arguments
parser = argparse.ArgumentParser(description="OH USER ID Generation")
parser.add_argument("-b", "--batch", action="store", dest="batch", help="batch = prototype or production")
parser.add_argument("-o", "--oh_ver", action="store", dest="oh_ver", help="oh_ver = 1 or 2")
parser.add_argument("-l", "--lpgbt_ver", action="store", dest="lpgbt_ver", help="lpgbt_ver = 0 or 1")
args = parser.parse_args()

oh_ver = int(args.oh_ver)
lpgbt_ver = int(args.lpgbt_ver)
batch = 0x00
if args.batch == "prototype":
    batch = 0x80
elif args.batch == "production":
    batch = 0x88
oh_serial_nr_list = range(1,1019)

output_file = open("me0_lpgbt/queso_testing/resources/oh_user_id_list.txt", "w")
output_file.write("# OH_Serial_Nr    Main_USER_ID    Secondary_USER_ID\n")

for oh_serial_nr in oh_serial_nr_list:
    main_user_id = (batch << 24) | (oh_ver << 20) | (lpgbt_ver << 18) | (1 << 16) | oh_serial_nr
    secondary_user_id = (batch << 24) | (oh_ver << 20) | (lpgbt_ver << 18) | (1 << 17) | oh_serial_nr
    output_file.write("%d    0x%08X    0x%08X\n"%(oh_serial_nr, main_user_id, secondary_user_id))

output_file.close()


