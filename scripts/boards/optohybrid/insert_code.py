#/usr/env python2
from __future__ import unicode_literals
import io
import shutil
import tempfile
import sys

def insert_code (input_file_name, output_file_name, marker_start, marker_end, write_function):

    # build a python netlist from the Altium exported Multiwire netlist

    f = io.open (input_file_name, "r", newline='')
    lines = f.readlines()
    f.close()

    tempname = tempfile.mktemp();
    shutil.copy (input_file_name, tempname)

    start_found = False
    end_found   = False

    # check for the presence of delimiters

    for line in lines:
        if marker_start in line:
            start_found = True
        if marker_end in line:
            end_found = True

    ok_to_write = start_found and end_found

    if (not ok_to_write):
        print ("start and end section markers not found in %s" % input_file_name)
        print ("please insert the following lines into the file")
        print ("%s" % marker_start)
        print ("%s" % marker_end)
        return sys.exit(1)
    else:

        start_found = False
        end_found = False

        wrote_constraints = False

        f = io.open (tempname, "w", newline='')

        for line in lines:

            if (not start_found):
                f.write(line)

            if (end_found or (marker_end in line)):
                f.write(line)

            if marker_start in line:
                start_found = True

            if marker_end in line:
                end_found = True

            if (start_found and not end_found and not wrote_constraints):
                wrote_constraints = True

                write_function(f)

        f.close()
        shutil.copy (tempname, output_file_name)


    f.close()

