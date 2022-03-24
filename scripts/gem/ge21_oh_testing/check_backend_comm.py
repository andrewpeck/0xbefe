from common.rw_reg import *
from test_utils import *

def Backend_Comm_Check():
    PASSFAIL=main()
    return PASSFAIL

def main():

    PASS = True

    #parseXML()

    PASS = check_GBTx_transmission_CTP7()

    word = ''
    if PASS:
        word = 'PASSED'
    else :
        word = 'FAILED'

    print('Check GBTx transmission to CTP7: %s' % word)

    PASS = check_SCA_ASIC()

    if PASS:
        word = 'PASSED'
    else :
        word = 'FAILED'

    print('Check SCA ASIC: %s' % word)

    return PASS

if __name__ == '__main__':
    parse_xml()
    main()
