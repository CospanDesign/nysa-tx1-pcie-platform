#! /usr/bin/python

# Copyright (c) 2015 Dave McCoy (dave.mccoy@cospandesign.com)
#
# Nysa is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# Nysa is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Nysa; If not, see <http://www.gnu.org/licenses/>.

import site
import os
import sys
import argparse
import json
import datetime

#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))
BOARD_NAME = "tx1_pcie"

PLATFORM_PATH = os.path.abspath(os.path.dirname(__file__))
CONFIG_PATH = os.path.join(PLATFORM_PATH, BOARD_NAME, "board", "config.json")



SCRIPT_NAME = os.path.basename(os.path.realpath(__file__))

DESCRIPTION = "\n" \
              "\n" \
              "usage: %s [options]\n" % SCRIPT_NAME

EPILOG = "\n" \
         "\n" \
         "Examples:\n" \
         "\tSomething\n" \
         "\n"

def main(argv):
    #Parse out the commandline arguments
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=DESCRIPTION,
        epilog=EPILOG
    )

    parser.add_argument("--uninstall",
                        action="store_true",
                        help="Uninstall Board Package")

    parser.add_argument("-d", "--debug",
                        action="store_true",
                        help="Enable Debug Messages")

    args = parser.parse_args()
    print "Running Script: %s" % SCRIPT_NAME

    #Get the configuration dictionary from the ./board_name/board/config.json
    f = open(CONFIG_PATH, "r")
    config_dict = json.load(f)
    f.close()

    name = config_dict["board_name"].lower()

    try:
        import nysa
    except ImportError as e:
        print "Nysa Not Installed! install Nysa:"
        print "How to install Nysa:"
        print "\tsudo apt-get install git verilog gtkwave"
        print "\tsudo -H pip install git+https://github.com/CospanDesign/nysa"
        print "\tnysa init"
        print "\tnysa install-examples all"
        print ""
        print "Then run this script again"
        sys.exit(1)

    if args.uninstall:
        uninstall_board(name, args.debug)

    else:
        install_board(name, PLATFORM_PATH, setup_platform = True, debug = args.debug)

def install_board(name, path, setup_platform, debug):
    from nysa.ibuilder.lib import utils
    from nysa.common.status import Status
    status = Status()
    if debug:
        status.set_level("Verbose")
    utils.install_local_board_package(name, path, setup_platform, status)

def uninstall_board(name, debug):
    from nysa.ibuilder.lib import utils
    from nysa.common.status import Status
    status = Status()
    if debug:
        status.set_level("Verbose")
    utils.uninstall_local_board_package(name, status)

if __name__ == "__main__":
    main(sys.argv)


