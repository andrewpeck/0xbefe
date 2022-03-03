create this file: /etc/udev/rules.d/75-gbtx-dongle.rules with these contents:
ACTION=="add", ATTR{idVendor}=="16c0", ATTR{idProduct}=="05df", MODE:="666"
then run: udevadm control --reload-rules && udevadm trigger

the dongle should be associated with usbhid driver, you can check by running: usb-devices | less
if it's for some reason associated with a different driver, like usbfs, follow the steps outlined here to bind it to usbhid: https://lwn.net/Articles/143397/

to install hidapi follow these steps:

sudo yum makecache
sudo yum -y update
sudo yum -y install hidapi
#sudo yum groupinstall 'development tools'
sudo yum install libusb-devel
sudo yum install libusbx-devel
sudo yum install libudev-devel

sudo yum install python3-devel
sudo pip3 install setuptools --upgrade
sudo pip3 install wheel


sudo pip3 install hidapi==0.7.99.post14
