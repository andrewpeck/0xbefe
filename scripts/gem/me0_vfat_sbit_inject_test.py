from gem.gem_utils import *
from time import sleep, time
import sys
import argparse
import random
import glob
import json
# from vfat_config import initialize_vfat_config, configureVfat, enableVfatchannel
import datetime
import numpy as np
from read_ntuple import *

def get_exp_clusters(events,s_bit_cluster_mapping):
    # events should be a dict with vfat# as keys and [sbits] as corresponding values/hits
    clusters = {}
    pos = 0
    size = 0
    for eta,sbits in events.items():
        for sbit in np.unique(sbits):
            if len(sbits)>1:
                if size == 0:
                    pos = sbit
                    size = 1
                if ((sbit - 1) in sbits):
                    size += 1
                if (sbit+1) not in sbits:
                    address = s_bit_cluster_mapping[eta][pos]
                    if address not in clusters.keys():
                        clusters[address]=[size]
                    elif size not in clusters[address]:
                        clusters[address].append(size)
                    size = 0

            else:
                address = s_bit_cluster_mapping[eta][sbit]
                if address not in clusters.keys():
                    clusters[address]=[1]
                elif 1 not in clusters[address]:
                    clusters[address].append(1)
    return clusters

def bits_to_int(data,order="little"):
    data = np.packbits(data,bitorder=order)
    if order=="little":
        data_int = 0
        for i,d in enumerate(data):
            data_int |= d<<(i*8)
    elif order=="big":
        data_int = 0
        for d in data:
            data_int = data_int<<8|d
    return data_int

def vfat_sbit(gem, system, oh_select, from_root, root_data, hits, eta_partitions, sbit_list, trigger, n_bxs, s_bit_cluster_mapping, verbose):
    
    resultDir = "results"
    try:
        os.makedirs(resultDir) # create directory for results
    except FileExistsError: # skip if directory already exists
        pass
    vfatDir = "results/vfat_data"
    try:
        os.makedirs(vfatDir) # create directory for VFAT data
    except FileExistsError: # skip if directory already exists
        pass
    dataDir = "results/vfat_data/vfat_sbit_inject_test_results"
    try:
        os.makedirs(dataDir) # create directory for data
    except FileExistsError: # skip if directory already exists
        pass
    now = str(datetime.datetime.now())[:16]
    now = now.replace(":", "_")
    now = now.replace(" ", "_")
    file_out = open(dataDir + "/%s_OH%d_vfat_sbit_inject_test_output_"%(gem,oh_select) + now + ".txt", "w")
    print ("%s S-Bit Injection Test\n"%gem)
    file_out.write("%s S-Bit Injection Test\n\n"%gem)

    global_reset()
    #gem_link_reset()
    #sleep(0.1)

    # Configure TTC generator
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), 1)

    if from_root:
        n_bxs=len(root_data)
    # n_cluster_expected = 0
    if n_bxs>512:
        print("FIFOs will loop %d times to record all BXs"%(np.ceil(n_bxs/512).astype(int)))
        file_out.write("FIFOs will loop %d times to record all BXs\n"%(np.ceil(n_bxs/512).astype(int)))

    # Initialize sbit data
    cl_events = []
    if from_root:
        # Use root data
        # Can't use full data, must select 1 OH
        # sbit_inj_data = np.zeros([216,len(root_data),24,64],dtype=int) # will be formatted [OH][BX][VFAT][SBIT]
        sbit_inj_data = np.zeros([len(root_data),24,64],dtype=int) # will be formatted [BX][VFAT][SBIT]

        for (bx,event) in enumerate(root_data):
            if hits=="digi":
                region = (1 - event["me0_digi_hit_region"])/2
                chamber = event["me0_digi_hit_chamber"] - 1
                eta_partition = event["me0_digi_hit_eta_partition"] - 1
                layer = event["me0_digi_hit_layer"] - 1
                strips = event["me0_digi_hit_strip"]-1
            elif hits=="rec":
                region = (1 - event["me0_rec_hit_region"])/2
                chamber = event["me0_rec_hit_chamber"] - 1
                eta_partition = event["me0_rec_hit_eta_partition"] - 1
                layer = event["me0_rec_hit_layer"] - 1
                strips = event["me0_rec_hit_strip"]-1
            oh = np.uint16(layer + 6*chamber + 108*region)
            etas = np.uint8(eta_partition)
            vfats = np.uint8(etas + 8*np.floor_divide(strips,128))
            sbits_inj = np.uint8(np.floor_divide(strips%128,2))
            sbits = np.uint8(np.floor(strips/2))
            cl_events.append({})
            if oh.size>0:
                oh_mask = oh == oh[0]
                vfats = vfats[oh_mask]
                etas = etas[oh_mask]
                sbits = sbits[oh_mask]
                sbits_inj = sbits_inj[oh_mask]
                if etas.size>0:
                    # sbit_inj_data[oh,bx,vfats,sbits]=1
                    sbit_inj_data[bx,vfats,sbits_inj]=1 # flatten data to 1 oh
                    for eta,sbit in zip(etas,sbits):
                        if eta not in cl_events[-1].keys():
                            cl_events[-1][eta]=[sbit]
                        else:
                            cl_events[-1][eta].append(sbit)
    else:
        # Create test data from vfat,sbit lists
        sbit_inj_data = np.zeros([n_bxs,24,64],dtype=int)
        etas = np.array(eta_partitions,dtype=int)
        sbits = np.array(sbit_list,dtype=int)
        vfats = []
        sbits_inj = []
        for eta in etas:
            for sbit in sbits:
                vfats.append(eta + 8*np.floor_divide(sbit,64))
                sbits_inj.append(sbit%64)
        vfats = np.array(vfats,dtype=int)
        sbits_inj = np.array(sbits_inj,dtype=int)
        sbit_inj_data[:,vfats,sbits_inj]=1
        for bx in range(n_bxs):
            cl_events.append({})
            for eta in etas:
                cl_events[bx][eta]=sbit_list
    expected_clusters_list=[get_exp_clusters(events,s_bit_cluster_mapping) for events in cl_events]
    # sbit inject fifo nodes
    dinh_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.DATA_H")
    dinl_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.DATA_L")
    read_en_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.READ_EN")
    write_en_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.WRITE_EN")
    reset_fifo_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.CTRL.FIFO_RESET")
    fifo_sel_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.SEL")
    fifo_empty_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.EMPTY")
    fifo_full_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.FULL")
    fifo_sync_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.SYNC_FLAG")
    fifo_rst_flag_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.RST_FLAG")
    fifo_err_flag_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.ERR_FLAG")
    fifo_data_cnt_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.TOT_DATA_CNT")
    fifo_pr_full_sbit_inj_node = get_backend_node("BEFE.GEM.SBIT_ME0.INJECT.FIFO.PR_FULL_OH0")

    # Configure TTC generator
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.CTRL.MODULE_RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_GAP"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_L1A_COUNT"), 1)
    write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 1)

    # Nodes for Sbit Monitor
    write_backend_reg(get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.OH_SELECT"), oh_select)
    reset_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.RESET")  # To reset S-bit Monitor
    reset_sbit_cluster_node = get_backend_node("BEFE.GEM.TRIGGER.CTRL.CNT_RESET")  # To reset Cluster Counter
    sbit_monitor_nodes = []
    cluster_count_nodes = []
    for j in range(0,8):
        sbit_monitor_nodes.append(get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.CLUSTER%d"%j))
        cluster_count_nodes.append(get_backend_node("BEFE.GEM.TRIGGER.OH%d.CLUSTER_COUNT_%d_CNT"%(oh_select,j)))
    fifo_empty_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_EMPTY")
    fifo_en_l1a_trigger_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_EN_L1A_TRIGGER")
    fifo_en_sbit_trigger_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_EN_SBIT_TRIGGER")
    trigger_delay_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_TRIGGER_DELAY")
    fifo_data_sbit_monitor_node = get_backend_node("BEFE.GEM.TRIGGER.SBIT_MONITOR.FIFO_DATA")
    
    # Configure SBit Monitor

    # Reset S-bit Monitor
    write_backend_reg(reset_sbit_monitor_node, 1)
    write_backend_reg(reset_sbit_cluster_node, 1)

    # Setting Trigger Delay
    write_backend_reg(trigger_delay_sbit_monitor_node, 509)

    # Setting Trigger Enable
    if trigger == "l1a":
        write_backend_reg(fifo_en_l1a_trigger_sbit_monitor_node, 1)
    elif trigger == "sbit":
        write_backend_reg(fifo_en_sbit_trigger_sbit_monitor_node, 1)

    # Helper functions
    def check_err_flag(verbose=False):
        err_flag = read_backend_reg(fifo_err_flag_sbit_inj_node)
        if err_flag==0:
            if verbose:
                print(Colors.GREEN + "No R/W errors in injection FIFO" + Colors.ENDC)
        if err_flag==1:
            print(Colors.YELLOW + "Write enabled while all FIFOs are full" + Colors.ENDC)
        elif err_flag==2:
            print(Colors.YELLOW + "Read enabled while all FIFOs are empty" + Colors.ENDC)
        elif err_flag==3:
            print(Colors.YELLOW + "Write enabled while FIFOs in reset state" + Colors.ENDC)
        elif err_flag==4:
            print(Colors.YELLOW + "Read enabled while FIFOs in reset state" + Colors.ENDC)
        elif err_flag==5:
            print(Colors.YELLOW + "Read enabled while FIFOs out-of-sync" + Colors.ENDC)
        return err_flag
    
    def read_flags(verbose=False):
        fifo_sel = read_backend_reg(fifo_sel_sbit_inj_node)
        empty = read_backend_reg(fifo_empty_sbit_inj_node)
        full = read_backend_reg(fifo_full_sbit_inj_node)
        data_cnt = read_backend_reg(fifo_data_cnt_sbit_inj_node)
        sync = read_backend_reg(fifo_sync_sbit_inj_node)
        rst_flag = read_backend_reg(fifo_rst_flag_sbit_inj_node)
        err_flag = read_backend_reg(fifo_err_flag_sbit_inj_node)
        if verbose==True:
            print("FIFO_sel: 0x%x, Empty: %r, Full %r, Data Count: %d, Sync: %r, Reset flag: %r, Error flag: %x"%(fifo_sel,bool(empty),bool(full),data_cnt,bool(sync),bool(rst_flag),err_flag))
        if verbose==False:
            print("Data Count: %d, Sync: %r, Error flag: %x"%(data_cnt,bool(sync),err_flag))

    # Reset fifos
    write_backend_reg(reset_fifo_sbit_inj_node,1)

    fifo_rst_flag = read_backend_reg(fifo_rst_flag_sbit_inj_node)
    
    print("Writing S-Bit data to injection FIFOs...")
    file_out.write("Writing S-Bit data to injection FIFOs...\n")
    # loop to write 512 BXs at a time
    t0 = time()
    sbit_inj_cnt = 0
    n_bx_cl = 0
    n_clusters = 0
    n_cluster_size_error = 0
    n_cluster_pos_error = 0
    max_ohs = read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH")
    for i in range(np.ceil(n_bxs/512).astype(int)):
        while fifo_rst_flag==1:
            sleep(0.1)
        # Loop over OHs
        for oh in range(max_ohs):
            # Loop through vfats
            for vfat in range(24):
                # Loop through bxs
                for bx in range(i*512,min((i+1)*512,n_bxs)):
                    if oh==oh_select:
                        dinl = bits_to_int(sbit_inj_data[bx,vfat,:32])
                        dinh = bits_to_int(sbit_inj_data[bx,vfat,32:64])
                    else:
                        dinl = 0
                        dinh = 0
                    # Set data bus
                    write_backend_reg(dinl_sbit_inj_node,dinl)
                    write_backend_reg(dinh_sbit_inj_node,dinh)
                    # Set FIFO sel - Bits [15:8] OH number, bits [7:0] VFAT number
                    fifo_sel_addr = oh<<8 | vfat
                    write_backend_reg(fifo_sel_sbit_inj_node,fifo_sel_addr)
                    # Pulse load sbits enable
                    write_backend_reg(write_en_sbit_inj_node,1)
                    # read_flags()
                    check_err_flag()
                    sbit_inj_cnt += 1
                    if verbose:
                        print("Writing to FIFO for OH#%d: VFAT#: %d, BX#: %d, DATA = %#016x"%(oh,vfat,bx,np.uint64(dinh<<32|dinl)))
                        print("s-bits written: %d"%sbit_inj_cnt)
                    file_out.write("Writing to FIFO for OH#%d: VFAT#: %d, BX#: %d, DATA = %#032x\n"%(oh,vfat,bx,np.uint64(dinh<<32|dinl)))
                    file_out.write("s-bits written: %d\n"%sbit_inj_cnt)
        sleep(1)
        # Read flag registers
        sbit_inj_fifo_data_cnt = read_backend_reg(fifo_data_cnt_sbit_inj_node)
        sbit_inj_fifo_sync = read_backend_reg(fifo_sync_sbit_inj_node)
        sbit_inj_fifo_empty = read_backend_reg(fifo_empty_sbit_inj_node)
        
        if sbit_inj_cnt==sbit_inj_fifo_data_cnt:
            print("\n%d x 64 s-bits written into injection FIFOs"%sbit_inj_cnt)
            file_out.write("\n%d x 64 s-bits written into injection FIFOs\n"%sbit_inj_cnt)
            check_err_flag(verbose=True)
            write_backend_reg(fifo_sel_sbit_inj_node,0)
        else:
            print(Colors.YELLOW + "%d x 64 s-bits sent, but only %d x 64 s-bits written in FIFOs"%(sbit_inj_cnt,sbit_inj_fifo_data_cnt) + Colors.ENDC)
            file_out.write("%d x 64 s-bits sent, but only %d x 64 s-bits written in FIFOs\n"%(sbit_inj_cnt,sbit_inj_fifo_data_cnt))
            check_err_flag()
            # terminate()
        if not sbit_inj_fifo_sync:
            print(Colors.RED + "FIFOs are out of sync. Resetting FIFOs." + Colors.ENDC)
            check_err_flag()
            # reset injection FIFOs
            write_backend_reg(reset_fifo_sbit_inj_node,1)
            write_backend_reg(dinl_sbit_inj_node,0)
            write_backend_reg(dinh_sbit_inj_node,0)
            write_backend_reg(fifo_sel_sbit_inj_node,0)
            continue
        
        print("\nInjecting s-bits into data stream...")
        file_out.write("\nInjecting s-bits into data stream...\n")

        # Inject s-bits and send l1a if needed
        if trigger == "l1a":
            write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.CYCLIC_START"),1) # send l1a
            write_backend_reg(read_en_sbit_inj_node,1) # read fifo/inject sbits into clusterizer
            write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.RESET"), 1) # end cyclic generator
        elif trigger == "sbit":
            write_backend_reg(read_en_sbit_inj_node,1) # read fifo/inject sbits into clusterizer
        sleep(0.001) # allow for data propogation

        # Reading the Sbit Monitor FIFO
        # l1a_counter = read_backend_reg(l1a_node)
        cl_fifo_empty = read_backend_reg(fifo_empty_sbit_monitor_node)

        # expected_clusters_list = get_exp_clusters(cl_events,s_bit_cluster_mapping)
        #n_clusters_error = 0
        n = 0
        status_str = ""
        min_cluster = 0

        while (not cl_fifo_empty):
            fifo_data = read_backend_reg(fifo_data_sbit_monitor_node)
            cluster1_sbit_monitor_value = fifo_data & 0x0000ffff
            cluster1_sbit_cluster_address = cluster1_sbit_monitor_value & 0x7ff
            cluster1_sbit_cluster_size = ((cluster1_sbit_monitor_value >> 12) & 0x7) + 1
            cluster1_l1a = cluster1_sbit_monitor_value >> 15

            cluster2_sbit_monitor_value = (fifo_data >> 16) & 0x0000ffff
            cluster2_sbit_cluster_address = cluster2_sbit_monitor_value & 0x7ff
            cluster2_sbit_cluster_size = ((cluster2_sbit_monitor_value >> 12) & 0x7) + 1
            cluster2_l1a = cluster2_sbit_monitor_value >> 15

            expected_clusters = expected_clusters_list[min(n_bxs-1,n_bx_cl)]
            if n==0:
                status_str = "BX %d:  \n"%n_bx_cl
                min_cluster = 0

            if cluster1_sbit_cluster_address != 0x7ff and cluster1_sbit_cluster_size != 8:
                status_str += "  Cluster: %d (size = %d)"%(cluster1_sbit_cluster_address, cluster1_sbit_cluster_size)
                n_clusters += 1
                min_cluster = 1
                if cluster1_sbit_cluster_address in expected_clusters.keys():
                    if cluster1_sbit_cluster_size not in expected_clusters[cluster1_sbit_cluster_address]:
                        n_cluster_size_error += 1
                        if verbose:
                            print(Colors.YELLOW+"SIZE_ERROR: BX: %d, received cluster: %d (size = %d), expected clusters: "%(n_bx_cl, cluster1_sbit_cluster_address, cluster1_sbit_cluster_size),expected_clusters,Colors.ENDC)
                else:
                    n_cluster_pos_error += 1
                    if verbose:
                        print(Colors.YELLOW+"POS_ERROR: BX: %d, received cluster: %d (size = %d), expected clusters: "%(n_bx_cl, cluster1_sbit_cluster_address, cluster1_sbit_cluster_size),expected_clusters,Colors.ENDC)

            if cluster2_sbit_cluster_address != 0x7ff and cluster2_sbit_cluster_size != 8:
                status_str += "  Cluster: %d (size = %d)"%(cluster2_sbit_cluster_address, cluster2_sbit_cluster_size)
                n_clusters += 1
                min_cluster = 1
                if cluster2_sbit_cluster_address in expected_clusters.keys():
                    if cluster2_sbit_cluster_size not in expected_clusters[cluster2_sbit_cluster_address]:
                        n_cluster_size_error += 1
                        if verbose:
                            print(Colors.YELLOW+"SIZE_ERROR: BX: %d, received cluster: %d (size = %d), expected clusters: "%(n_bx_cl, cluster2_sbit_cluster_address, cluster2_sbit_cluster_size),expected_clusters,Colors.ENDC)
                else:
                    n_cluster_pos_error += 1
                    if verbose:
                        print(Colors.YELLOW+"POS_ERROR: BX: %d, received cluster: %d (size = %d), expected clusters: "%(n_bx_cl, cluster2_sbit_cluster_address, cluster2_sbit_cluster_size),expected_clusters,Colors.ENDC)
            n+=1
            if (n==4):
                n=0
                n_bx_cl+=1
                if min_cluster:
                    if verbose:
                        print(status_str)
                    file_out.write(status_str + "\n")

            cl_fifo_empty = read_backend_reg(fifo_empty_sbit_monitor_node)
        
        # reset injection FIFOs
        write_backend_reg(reset_fifo_sbit_inj_node,1)
        write_backend_reg(dinl_sbit_inj_node,0)
        write_backend_reg(dinh_sbit_inj_node,0)
        write_backend_reg(fifo_sel_sbit_inj_node,0)
        # Reset S-bit Monitor
        write_backend_reg(reset_sbit_monitor_node, 1)
        write_backend_reg(reset_sbit_cluster_node, 1)

    # Disable Trigger Enable
    if trigger == "l1a":
        write_backend_reg(fifo_en_l1a_trigger_sbit_monitor_node, 0)
        write_backend_reg(get_backend_node("BEFE.GEM.TTC.GENERATOR.ENABLE"), 0)
    elif trigger == "sbit":
        write_backend_reg(fifo_en_sbit_trigger_sbit_monitor_node, 0)


    print ("\nTime taken: %.2f seconds for %d BXs" % ((time()-t0), n_bxs))
    file_out.write("\nTime taken: %.2f seconds for %d BXs\n" % ((time()-t0), n_bxs))

    #if n_clusters_error == 0:
        #print (Colors.GREEN + "Nr. of cluster expected = %d, Nr. of clusters recorded = %d"%(n_cluster_expected, n_clusters) + Colors.ENDC)
    #else:
        #print (Colors.RED + "Nr. of cluster expected = %d, Nr. of clusters recorded = %d"%(n_cluster_expected, n_clusters) + Colors.ENDC)
    print ("Nr. of clusters recorded = %d"%(n_clusters))
    #file_out.write("Nr. of cluster expected = %d, Nr. of clusters recorded = %d\n"%(n_cluster_expected, n_clusters))
    file_out.write("Nr. of clusters recorded = %d\n"%(n_clusters))
    if n_cluster_size_error == 0:
        print (Colors.GREEN + "Nr. of cluster size mismatches = %d"%n_cluster_size_error + Colors.ENDC)
    else:
        print (Colors.RED + "Nr. of cluster size mismatches = %d"%n_cluster_size_error + Colors.ENDC)
    file_out.write("Nr. of cluster size mismatches = %d\n"%n_cluster_size_error)
    if n_cluster_pos_error == 0:
        print (Colors.GREEN + "Nr. of cluster position mismatches = %d"%n_cluster_pos_error + Colors.ENDC)
    else:
        print (Colors.RED + "Nr. of cluster position mismatches = %d"%n_cluster_pos_error + Colors.ENDC)
    file_out.write("Nr. of cluster position mismatches = %d\n"%n_cluster_pos_error)

    print ("\nS-bit Injection testing done\n")
    file_out.write("\nS-bit Injection testing done\n\n")
    file_out.close()

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="ME0 VFAT S-Bit Injection Test")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    #parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-e", "--eta", action="store", dest="eta", nargs="+", help="eta = list of eta partitions (0-7)")
    parser.add_argument("-b", "--sbit", action="store", dest="sbit", nargs="+", help='sbit = list of s-bits (0-191) to inject')
    parser.add_argument("-n", "--n_bxs", action="store", dest="n_bxs", help="n_bxs = Number of bunch crossings.")
    # parser.add_argument("-e", "--elink", action="store", dest="elink", nargs="+", help="elink = list of ELINKs (0-7) for S-bits")
    # parser.add_argument("-c", "--channels", action="store", dest="channels", nargs="+", help="channels = list of channels for chosen VFAT and ELINK (list allowed only for 1 elink, by default all channels used for the elinks)")
    parser.add_argument("-t", "--trigger", action="store", dest="trigger", default="sbit", help="trigger = l1a or sbit")
    # parser.add_argument("-m", "--cal_mode", action="store", dest="cal_mode", default = "current", help="cal_mode = voltage or current (default = current)")
    # parser.add_argument("-d", "--cal_dac", action="store", dest="cal_dac", help="cal_dac = Value of CAL_DAC register (default = 50 for voltage pulse mode and 150 for current pulse mode)")
    # parser.add_argument("-p", "--parallel", action="store", dest="parallel", help="parallel = all (inject calpulse in all channels) or select (inject calpulse in selected channels) simultaneously (only possible in voltage mode, not a preferred option)")
    # parser.add_argument("-r", "--use_dac_scan_results", action="store_true", dest="use_dac_scan_results", help="use_dac_scan_results = to use previous DAC scan results for configuration")
    # parser.add_argument("-u", "--use_channel_trimming", action="store", dest="use_channel_trimming", help="use_channel_trimming = to use latest trimming results for either options - daq or sbit (default = None)")
    # parser.add_argument("-l", "--calpulse_only", action="store_true", dest="calpulse_only", help="calpulse_only = to use only calpulsing without L1A's")
    # parser.add_argument("-b", "--bxgap", action="store", dest="bxgap", default="500", help="bxgap = Nr. of BX between two L1As (default = 500 i.e. 12.5 us)")
    # parser.add_argument("-m", "--latest_map", action="store_true", dest="latest_map", help="latest_map = use the latest sbit mapping")
    parser.add_argument("-r", "--from_root", action="store_true", dest="from_root", help='from_root = read in sbit data from a root file, must provide file address in arg "-f --file_path"')
    parser.add_argument("-f", "--file_path", action="store", dest="file_path", help="file_path = the .root file path to be read")
    parser.add_argument("-i", "--hits", action="store", dest="hits", default="digi", help="hits = digi or rec")
    parser.add_argument("-p", "--verbose", action="store_true",dest="verbose",help="verbose = print verbose")    

    args = parser.parse_args()

    if args.system == "backend":
        print ("Using Backend for S-bit test")
    elif args.system == "dryrun":
        print ("Dry Run - not actually running sbit test")
    else:
        print (Colors.YELLOW + "Only valid options: backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()

    s_bit_cluster_mapping = {}
    print ("")
    eta_partitions = np.arange(8)
    sbits = np.arange(192)
    for eta in eta_partitions:
        s_bit_cluster_mapping[eta] = (sbits+eta*192).tolist()


    if args.from_root:
        if args.file_path is None:
            print(Colors.YELLOW + "Must provide a path to .root file" + Colors.ENDC)
            sys.exit()
        if args.hits not in ["digi", "rec"]:
            print ("Incorrect argument for hits option")
            sys.exit()
        # read in the data
        root_data = read_ntuple(args.file_path)
        eta_partitions = None
        sbit_list = None
        args.n_bxs = len(root_data)
    else:
        root_data = None
        if args.eta is None:
            print (Colors.YELLOW + "Enter list of eta partitions" + Colors.ENDC)
            sys.exit()
        eta_partitions = []
        for e in args.eta:
            eta = int(e)
            if eta not in range(0,8):
                print (Colors.YELLOW + "Invalid eta partition, only allowed 0-7" + Colors.ENDC)
                sys.exit()
            eta_partitions.append(eta)
        eta_partitions.sort()
        if args.sbit is None:
            print (Colors.YELLOW + 'Enter list of s-bit numbers, or "all"' + Colors.ENDC)
            sys.exit()
        else:
            sbit_list = []
            for s in args.sbit:
                sbit = int(s)
                if sbit not in range(0,192):
                    print (Colors.YELLOW + "Invalid s-bit number, only allowed 0-191" + Colors.ENDC)
                    sys.exit()
                sbit_list.append(sbit)    
        sbit_list.sort()
    # Initialization 
    initialize(args.gem, args.system)
    # initialize_vfat_config(args.gem, int(args.ohid), args.use_dac_scan_results, args.use_channel_trimming)
    print("Initialization Done\n")
 
    # Running sbit injection
    try:
        vfat_sbit(args.gem, args.system, int(args.ohid), args.from_root, root_data, args.hits, eta_partitions, sbit_list, args.trigger, int(args.n_bxs), s_bit_cluster_mapping, args.verbose)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        terminate()
    
    # Termination
    terminate()




