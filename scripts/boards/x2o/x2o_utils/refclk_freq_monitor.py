from common.rw_reg import *
from common.utils import *
from time import *
import os
import statistics

def main():
    DATA_DIR=os.getenv('DATA_DIR')
    now = datetime.now()
    d_time = now.strftime("%Y-%m-%d")
    isExist = os.path.exists(DATA_DIR+"/refclk_data/"+d_time)
    if not isExist:
       os.makedirs(DATA_DIR+"/refclk_data/"+d_time)
    run_num=1
    filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
    if(len(list(sys.argv))>2):
        run_num=int(sys.argv[2])
    else:
        while(os.path.exists(filename)):
            run_num+=1
            filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"

    filename=DATA_DIR+"/summary/"+d_time+"/"+d_time+"_"+str(run_num)+".csv"
    sum_f=open(filename,"a")
    f=open(DATA_DIR+"/refclk_data/"+d_time+"/"+d_time+"_"+str(run_num)+".csv","w") 
                   



    num_mgts = read_reg("BEFE.SYSTEM.RELEASE.NUM_MGTS")
    #num_mgts = 8
    print(num_mgts)
    #header
    header = "CLK40_AVG,CLK40_DEV"
    results=[[]]
    for i in range(0, num_mgts, 4):
        header += ",MGT%d_REFCLK0_AVG,MGT%d_REFCLK0_DEV,MGT%d_REFCLK1_AVG,MGT%d_REFCLK1_DEV" % (i, i,i,i)
        results.append([])
        results.append([])
    print(header)
    sum_f.write(header)
    f.write(header)
    n_iters=0
    max_iters=30
    data=""
    results[0]=[]
    while n_iters<max_iters:
        if os.getenv("BEFE_FLAVOR")=="csc":
            data = "%d" % read_reg("BEFE.CSC_FED.TTC.STATUS.CLK.CLK40_FREQUENCY")
            results[0].append(read_reg("BEFE.CSC_FED.TTC.STATUS.CLK.CLK40_FREQUENCY"))
        for i in range(0, num_mgts, 4):
            results[i//2+1].append(read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK0_FREQ" % i))
            results[i//2+2].append(read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK1_FREQ" % i))
            data += ",%d" % read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK0_FREQ" % i)
            data += ",%d" % read_reg("BEFE.MGTS.MGT%d.STATUS.REFCLK1_FREQ" % i)

        n_iters+=1
        sleep(1)
        f.write(data+"\n")
    print("CLK40_AVG:" +str(statistics.mean(results[0])))
    print("CLK40_STDEV:"+str(statistics.stdev(results[0])))
    
    sum_f.write(str(statistics.mean(results[0]))+",")
    sum_f.write(str(statistics.stdev(results[0]))+",")
    f.write(str(statistics.mean(results[0]))+",")
    f.write(str(statistics.stdev(results[0]))+",")
    for i in range(0,num_mgts,4):
        print("MGT%d_0_AVG: %d" % (i,statistics.mean(results[i//2+1])))
        print("MGT%d_0_DEV: %d" % (i,statistics.stdev(results[i//2+1])))
        print("MGT%d_1_AVG: %d" % (i,statistics.mean(results[i//2+2])))
        print("MGT%d_1_DEV: %d" % (i,statistics.stdev(results[i//2+2])))
        sum_f.write("%d," % (statistics.mean(results[i//2+1])))
        sum_f.write("%d," % (statistics.stdev(results[i//2+1])))
        sum_f.write("%d," % (statistics.mean(results[i//2+2])))
        sum_f.write("%d," % (statistics.stdev(results[i//2+2])))
        f.write("%d," % (statistics.mean(results[i//2+1])))
        f.write("%d," % (statistics.stdev(results[i//2+1])))
        f.write("%d," % (statistics.mean(results[i//2+2])))
        f.write("%d," % (statistics.stdev(results[i//2+2])))



if __name__ == '__main__':
    parse_xml()
    main()

