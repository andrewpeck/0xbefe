#!/bin/env python

import ROOT as r

tr = r.TTree('data','trigger data')
# tr.ReadFile("sbit2L1A_25us_timeout_1M_evt_L1A_delayed500ns_HighSBITRate.csv")
tr.ReadFile("/tmp/latencyScan_thresh_250.csv")

# hist = r.TH1D("hist","",2500,-0.5,2499.5)
hist = r.TH1D("hist","",250,-0.5,249.5)

for ev in tr:
    # hist.SetBinContent(ev.BX+1,ev.Count)
    hist.SetBinContent(ev.Latency+1,100.*ev.hits/(1.0*ev.L1As))
    pass

can = r.TCanvas("can","",800,800)

hist.Draw()

raw_input("enter")
