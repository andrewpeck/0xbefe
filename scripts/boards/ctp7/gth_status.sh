bin#!/bin/sh

gth_stat_base_reg=0x69000000
gth_ctrl_base_reg=0x69000008
gth_prbs_sel_base_reg=0x6900000C
gth_prbs_cnt_base_reg=0x69000010
gth_rx_notintable_cnt_base_reg=0x69000014
gth_rx_disperr_cnt_base_reg=0x69000018

printf "\n"
printf "Ch # |  GTH Status  |    GTH Ctrl  |   PRBS Sel  |   PRBS Cnt   | NotInTable Cnt |  Disperr Cnt  | \n"
printf "--------------------------------------------------------------------------------------------------\n"
        for i in `seq 0 11`
        do
                printf " %02d     " $i
                mpeek $gth_stat_base_reg | tr -d "\n"
                echo -n "     "
                mpeek $gth_ctrl_base_reg | tr -d "\n"
                echo -n "    "
                mpeek $gth_prbs_sel_base_reg | tr -d "\n"
                echo -n "     "
                mpeek $gth_prbs_cnt_base_reg | tr -d "\n"
                echo -n "     "
                mpeek $gth_rx_notintable_cnt_base_reg | tr -d "\n"
                echo -n "     "
                mpeek $gth_rx_disperr_cnt_base_reg | tr -d "\n"
                echo ""

                gth_stat_base_reg=$(($gth_stat_base_reg+256))
                gth_ctrl_base_reg=$(($gth_ctrl_base_reg+256))
                gth_prbs_sel_base_reg=$(($gth_prbs_sel_base_reg+256))
                gth_prbs_cnt_base_reg=$(($gth_prbs_cnt_base_reg+256))
		gth_rx_notintable_cnt_base_reg=$(($gth_rx_notintable_cnt_base_reg+256))
		gth_rx_disperr_cnt_base_reg=$(($gth_rx_disperr_cnt_base_reg+256))

        done
printf "--------------------------------------------------------------------------------------------------\n"


