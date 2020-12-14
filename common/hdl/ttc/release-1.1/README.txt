This directory contains a simple TTC decoder, which is designed
to be used in an AMC module in a crate with an AMC13.

The module assumes that the clock (on FCLKA) and the data
(on port 3) are DC-coupled LVDS inputs with minimal path
delay on the PCB, so that the data may be captured using
a simple IDDR register.

If you have any trouble implementing this module, please
contact us (E. Hazen <hazen@bu.edu> or S. X. Wu <wusx@bu.edu>)

Revisions:
2014-04-03	Initial import into CERN SVN
