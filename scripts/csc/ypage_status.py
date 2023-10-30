import requests
import execjs
from requests.models import RequestField
from urllib3 import response
from urllib3.contrib.socks import SOCKSProxyManager
from bs4 import BeautifulSoup
import re
    
"""
Dependecies: 
pip3 install requests --user # to make http requests
pip3 install beautifulsoup4 --user # for understanding the pages
pip3 install pySocks # to make sure requests understand the SOCKS proxies setting
pip3 install html5lib # for better webpages parsing like a browser
pip3 install PyExecJS  # to excute javacript commands in python


You need to establish a connection with the cms904usr gateway node using
ssh -ND 1080 user@cms904usr 
"""


class yellowpageStatus(object):
    """
    ypage_base_url : assume that you are bridging via the port 1080
    the base url is: vmepc-e1x07-22-01.cms904:30012
    you can change that in case the yellow page runs for example in a different vmepc machine
    """
    def __init__(self, ypage_base_url='http://vmepc-e1x07-22-01.cms904:30012', proxies=None):
        self.ypage_base_url = ypage_base_url
        # note the h in socks5h it works only that way
        # one has to include the SOCKSProxyManager as well
        if proxies is None:
            self.proxies = {
                'http': 'socks5h://127.0.0.1:1080', 
                'https': 'socks5h://127.0.0.1:1080', 
            }
        else:
            self.proxies = proxies

    def fetch_page(self, page):
        response = requests.get(page, proxies=self.proxies)
        soup = BeautifulSoup(response.text, "html5lib")
        return soup

    def fetch_page_source(self, page):
        response = requests.get(page, proxies=self.proxies)
        return BeautifulSoup(response.text, "html.parser").prettify()

    def _extract_cfeb_status(self, s):
        print(s)
        # Regular expressions for the different parts of the string
        fpga_done_pattern = r'FPGA DONE: (\d+);'
        fpga_id_pattern = r'FPGA id : ([a-fA-F0-9]+);'
        firmware_pattern = r'Firmware Tag: ([a-fA-F0-9]+)'

        # Search for matches
        fpga_done_match = re.search(fpga_done_pattern, s)
        fpga_id_match = re.search(fpga_id_pattern, s)
        firmware_match = re.search(firmware_pattern, s)

        # Extract values
        fpga_done = int(fpga_done_match.group(1)) if fpga_done_match else None
        fpga_id = fpga_id_match.group(1) if fpga_id_match else None
        firmware = firmware_match.group(1) if firmware_match else None

        # Return dictionary
        return {
            "FPGA DONE": fpga_done,
            "FPGA id": fpga_id,
            "Firmware": firmware
        }

    def cfeb_status(self):
        """
        return a dictionary of the form 
        {
            1 : {'FPGA DONE': 1, 'FPGA id': '8424a093', 'Firmware': 'dcfeb631'}, 
            2 : {'FPGA DONE': 1, 'FPGA id': '8424a093', 'Firmware': 'dcfeb631'},
            .... 
            n : {}
        ]

        """
        soup =  self.fetch_page(self.ypage_base_url + '/urn:xdaq-application:lid=70/CFEBStatus?dmb=0')
 
        temp_row = soup.find('td', text='Temp(FPGA) (C)').find_parent()
        temp_val = [td.text for td in temp_row.find_all('td')[1:]]

        status_dic = {}
        for i, b in enumerate(soup.find("fieldset").select('span')): 
            _dic = self._extract_cfeb_status(b.text.strip().splitlines()[0])
            _dic["temperature"] = temp_val[i]
            status_dic[i] = _dic
        
        

        # probably need to change that so it recongnise wich chamber type is, 7 for now
        assert len(status_dic) == 7, f"number of CFEBs should be equal to 7 or 5, got: {len(status_dic)}"
        return status_dic

    def alct_status(self):
        """
        returns a dictionary of the form
        {
            'ALCT' : {'FPGA DONE': 1, 'FPGA id': '', 'firmware': ''}
        }
        """
        soup =  self.fetch_page(self.ypage_base_url + '/urn:xdaq-application:lid=70/ALCTStatus?tmb=0')
        alct_block = soup.find('legend', text='ALCT Firmware Status').find_parent()
        alct_text = alct_block.find_all('span')

        alct_status = 0
        if len(alct_text):
            alct_text = alct_text[0].text
        else:
            alct_text = ''
        
        dates = re.findall(r'\((\d{4}-\d{2}-\d{2})\)', alct_text)
        # looking at the first date year only
        date = dates[0].split('-')[0]
        if int(date) ==  0 or int(date)==99:
            alct_status = 0
        else:
            alct_status = 1

        # extracting firmware and FPGA ids <-- not very clear where that is now in yp
        
        # temperature
        temp_row = soup.find('span', text='ALCT Baseboard:').find_parent()
        FPGA_temp_match = re.search(r'FPGA Temperature = (\d+\.\d+) C', temp_row.text)
        GBTx_temp_match = re.search(r'GBTx Temperature = (\d+\.\d+) C', temp_row.text)


        fpga_temp_val = -99.0
        gbtx_temp_val = -99.0 
        if FPGA_temp_match:
            fpga_temp_val = float(FPGA_temp_match.group(1))

        if GBTx_temp_match:
            gbtx_temp_val = float(FPGA_temp_match.group(1))

        return {
                "ALCT": {'FPGA DONE': alct_status, 'FPGA Temperature': fpga_temp_val, 'GBTx Temperature': gbtx_temp_val}
        }

    def CCB_hard_reset(self):
        hard_reset_url = self.ypage_base_url +  "/urn:xdaq-application:lid=70/HardReset"
        response = requests.get(hard_reset_url, proxies=self.proxies)
        if response.status_code == 200:
            print("CCB hard reset successfull!")
            return True
        else:
            print(f"faild to reset. Status code: {response.status_code}")
            return False

    def CCB_hard_rest_fast(self):
        hard_reset_url = self.ypage_base_url + "/urn:xdaq-application:lid=70/CCBSignals"
        print(hard_reset_url)

        command = {
            'runtype': '4',
            'command': 'Generate Signal'
        }
        response = requests.get(hard_reset_url, params=command, proxies=self.proxies)

        if response.status_code == 200:
            print("CCB hard reset successfull!")
            return True
        else:
            print(f"faild to reset. Status code: {response.status_code}")
            return False





status = yellowpageStatus()
print(status.cfeb_status())
print(status.alct_status())
# print(status.CCB_hard_reset())
print(status.CCB_hard_rest_fast())

