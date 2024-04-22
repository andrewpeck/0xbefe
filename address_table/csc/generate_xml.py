import re
from os import listdir,mkdir
from os.path import isfile
import shutil

# this is a hack script to substitute the external entity references in the xml files that begin with tmpl_ with the actual external entity
# this should not be necessary as a normal xml parser should be able to do it on its own, but it doesn't seem to work with the default python parser (people suggest to use lxml package instead, but this may be problematic to run on ctp7)
# anyway, it's almost midnight now, and I can't be bothered to find a better solution right now, hence the hack...

OUT_DIR = "./generated/"

def main():

    try:
        mkdir(OUT_DIR)
    except OSError as err:
        pass

    reTmplFiles = re.compile('tmpl_(.*)\\.xml')
    reExtEntDecl = re.compile('.*<!ENTITY (.*) SYSTEM "(.*)".*')
    # reEntSubst = re.compile('.*&(.*?);.*')
    reEntSubst = re.compile('.*&(.*?);[^<>]*(?:<!--(.*)-->)?.*')
    reParamTopId = p = re.compile('.*PARAM_TOP_ID=(.*?);.*')
    reParamTopAddr = p = re.compile('.*PARAM_TOP_ADDR=(.*?);.*')

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

            outfname = "%s/%s/csc_fed.xml" % (OUT_DIR, outsubdir)
            print("========================================================")
            print("in = %s, out = %s" % (fname, outfname))
            fin = open(fname, "r")
            fout = open(outfname, "w")

            entities = {}
            for line in fin:
                # if entity declaration
                m = reExtEntDecl.match(line)
                if m:
                    print("External file: %s: %s" % (m.group(1), m.group(2)))
                    fEnt = open(m.group(2), "r")
                    entities[m.group(1)] = fEnt.read()
                    fEnt.close()

                # if entity substitution
                m = reEntSubst.match(line)
                if m:
                    print("Processing %s" % line.replace("\n", ""))
                    line = re.sub('.*&(.*?);.*', entities[m.group(1)], line)
                    if m.group(2) is not None:
                        comment = m.group(2)
                        topId = None
                        topAddr = None
                        subTopId = reParamTopId.match(comment)
                        if subTopId:
                            topId = subTopId.group(1)
                        subTopAddr = reParamTopAddr.match(comment)
                        if subTopAddr:
                            topAddr = subTopAddr.group(1)
                        if topId is None or topAddr is None:
                            print("    WARNING: found a comment next to this module, but wasn't able to parse the replacement top id and top addr, so leaving this module unchanged")
                        else:
                            print("    Replacing top node id and address of this module to id=%s address=%s" % (topId, topAddr))
                            line = re.sub('id="(\w*)"', 'id="%s"' % topId, line, count=1)
                            line = re.sub('address="(\w*)"', 'address="%s"' % topAddr, line, count=1)


                fout.write(line)

            fin.close()
            fout.close()

if __name__ == '__main__':
    main()
