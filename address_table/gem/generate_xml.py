import re
from os import listdir,mkdir
from os.path import isfile

# this is a hack script to substitute the external entity references in the xml files that begin with tmpl_ with the actual external entity
# this should not be necessary as a normal xml parser should be able to do it on its own, but it doesn't seem to work with the default python parser (people suggest to use lxml package instead, but this may be problematic to run on ctp7)
# anyway, it's almost midnight now, and I can't be bothered to find a better solution right now, hence the hack...

OUT_DIR = "./generated/"

def main():

    try:
        mkdir(OUT_DIR)
    except OSError as err:
        pass

    reTmplFiles = re.compile('tmpl_gem_amc_(.*)\\.xml')
    reExtEntDecl = re.compile('.*<!ENTITY (.*) SYSTEM "(.*)".*')
    reEntSubst = re.compile('.*&(.*?);.*')

    for fname in listdir("."):
        if isfile(fname) and "tmpl_" in fname:
            m = reTmplFiles.match(fname)
            outsubdir = ""
            if m:
                outsubdir = m.group(1)

            try:
                mkdir("%s/%s" % (OUT_DIR, outsubdir))
            except OSError as err:
                pass
            
            outfname = "%s/%s/gem_amc.xml" % (OUT_DIR, outsubdir)
            print("========================================================")
            print("in = %s, out = %s" % (fname, outfname))
            fin = open(fname, "r")
            fout = open(outfname, "w")
            
            entities = {}
            for line in fin:
                # if entity declaration
                m = reExtEntDecl.match(line)
                if m:
                    print("%s: %s" % (m.group(1), m.group(2)))
                    fEnt = open(m.group(2), "r")
                    entities[m.group(1)] = fEnt.read()
                    fEnt.close()
                    
                # if entity substitution
                m = reEntSubst.match(line)
                if m:
                    line = re.sub('.*&(.*?);.*', entities[m.group(1)], line)
                
                fout.write(line)
            
            fin.close()
            fout.close()
    

if __name__ == '__main__':
    main()
