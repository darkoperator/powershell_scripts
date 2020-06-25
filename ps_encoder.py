#!/usr/bin/env python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    PSEncoder
#
#    Copyright (C) 2012  Carlos Perez
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; Applies version 2 of the License.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

__version__ = '0.1'
__author__ = 'Carlos Perez, Carlos_Perez@darkoperator.com'

__doc__ = """
PSEncoder http://www.darkoperator.com

by Carlos Perez, Darkoperator

Encodes a given Windows PowerShell script in to a Base64 String that can be
passed to the powershell.exe program as an option.
"""
import base64
import sys
import re
import os
import getopt


def powershell_encode(data):
    # blank command will store our fixed unicode variable
    blank_command = ""
    powershell_command = ""
    # Remove weird chars that could have been added by ISE
    n = re.compile(u'(\xef|\xbb|\xbf)')
    # loop through each character and insert null byte
    for char in (n.sub("", data)):
        # insert the nullbyte
        blank_command += char + "\x00"
    # assign powershell command as the new one
    powershell_command = blank_command
    # base64 encode the powershell command
    powershell_command = base64.b64encode(powershell_command.encode())
    return powershell_command.decode("utf-8")


def usage():
    print("Version: {0}".format(__version__))
    print("Usage: {0} <options>\n".format(sys.argv[0]))
    print("Options:")
    print("   -h, --help                  Show this help message and exit")
    print("   -s, --script      <script>  PowerShell Script.")
    sys.exit(0)


def main():
    try:
        options, args = getopt.getopt(sys.argv[1:], 'hs:', ['help', 'script='])
    except getopt.GetoptError:
        print("Wrong Option Provided!")
        usage()
    if len(sys.argv) == 1:
        usage()

    for opt, arg in options:
        if opt in ('-h', '--help'):
            usage()
        elif opt in ('-s', '--script'):
            script_file = arg
            if not os.path.isfile(script_file):
                print("The specified powershell script does not exists")
                sys.exit(1)
            else:
                ps_script = open(script_file, 'r').read()
                print(powershell_encode(ps_script))


if __name__ == "__main__":
    main()
