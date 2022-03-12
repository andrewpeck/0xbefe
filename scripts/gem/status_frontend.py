from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.gem_utils import *

def main():
    print("Frontend status:")
    gem_print_status()

if __name__ == '__main__':
    parse_xml()
    main()
