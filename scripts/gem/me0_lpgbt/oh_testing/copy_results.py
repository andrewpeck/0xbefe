import os
from distutils.dir_util import copy_tree
import shutil
import glob
from common.utils import get_befe_scripts_dir

gem_dir = get_befe_scripts_dir() + "/gem"
results_dir = gem_dir + "/me0_lpgbt/oh_testing/results/acceptance_tests"

eos_dir = "/eos/user/a/asiago/www/"

dir_list = glob.glob(results_dir+"/*")
for dir in dir_list:
    oh_dir = dir.split('/')[-1]
    if not os.path.exists(eos_dir+oh_dir):
        copy_tree(dir, eos_dir+oh_dir)
        shutil.copy(eos_dir+"/index.php",eos_dir+oh_dir)
    else:
        continue