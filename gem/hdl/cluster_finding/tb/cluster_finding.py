class Cluster:
    """ """

    adr = 0x1FF
    cnt = 0
    prt = 0
    vpf = 0

    def __str__(self):
        if (self.vpf==0):
            return "None"
        else:
            return "adr=%d cnt=%d prt=%d vpf=%d" % (
                self.adr,
                self.cnt,
                self.prt,
                self.vpf,
        )


def equal(a, b):

    """"""

    if (a==None and b==None):
        return True
    elif (a==None or b==None):
        return False
    else:
        return a.adr == b.adr and a.cnt == b.cnt and a.prt == b.prt and a.vpf == b.vpf


def consecutive_count(field):
    cnt = 0
    while field & 0x1 > 0:
        cnt = cnt + 1
        field = field >> 1
    return cnt


def find_cluster_primaries(vfats, width, INVERT=False):

    NUM_VFATS = len(vfats)
    NUM_PARTITIONS = int(NUM_VFATS / (width / 64))

    partitions = [0] * NUM_PARTITIONS
    vpfs = [0] * NUM_PARTITIONS
    cnts = [0] * NUM_PARTITIONS

    if width == 192:
        partitions[0] = (vfats[16] << 128) | (vfats[8] << 64) | (vfats[0] << 0)
        partitions[1] = (vfats[17] << 128) | (vfats[9] << 64) | (vfats[1] << 0)
        partitions[2] = (vfats[18] << 128) | (vfats[10] << 64) | (vfats[2] << 0)
        partitions[3] = (vfats[19] << 128) | (vfats[11] << 64) | (vfats[3] << 0)
        partitions[4] = (vfats[20] << 128) | (vfats[12] << 64) | (vfats[4] << 0)
        partitions[5] = (vfats[21] << 128) | (vfats[13] << 64) | (vfats[5] << 0)
        partitions[6] = (vfats[22] << 128) | (vfats[14] << 64) | (vfats[6] << 0)
        partitions[7] = (vfats[23] << 128) | (vfats[15] << 64) | (vfats[7] << 0)

    elif width == 384:
        partitions[0] = (
            (vfats[11] << 320)
            | (vfats[10] << 256)
            | (vfats[9] << 192)
            | (vfats[8] << 128)
            | (vfats[7] << 64)
            | (vfats[6] << 0)
        )
        partitions[1] = (
            (vfats[5] << 320)
            | (vfats[4] << 256)
            | (vfats[3] << 192)
            | (vfats[2] << 128)
            | (vfats[1] << 64)
            | (vfats[0] << 0)
        )

    if INVERT==1:
        partitions.reverse()

    total = 0

    for ipartition in range(len(partitions)):

        prior_strip = 0
        partition = partitions[ipartition]

        for istrip in range(width):
            # strip zero, no look behind
            this_strip = partition & 0x1
            if prior_strip == 0 and this_strip == 1:
                total = total + 1
                vpfs[ipartition] |= 1 << istrip
                cnts[ipartition] |= (
                    consecutive_count((partition >> 1) & 0x7F) << 3 * istrip
                )

            prior_strip = this_strip
            partition = partition >> 1

    # print(" partition[0] = " + str(partitions[0]))
    # print(" vpfs=" + str(vpfs))
    # print(" vpfs[0]=" + str(vpfs[0]))

    return (vpfs, cnts, total)


def find_clusters(vpfs, cnts, width, nmax, encoder_size):
    """

    Args:
      vpfs: list of bignums representing valid cluster primaries, length of the list is the number of partitions
      cnts:
      width: 
      nmax: 
      encoder_size: 

    Returns:

    """

    MAX_CLUSTERS_PER_ENCODER = 4

    found = [None]*nmax
    encoder_counts = [0, 0, 0, 0, 0, 0, 0, 0]

    found_count = 0

    for iprt in range(len(vpfs)):
        # print("PARTITION %d width=%d size=%d" % (iprt, width, encoder_size))

        encoder = 0

        for ichn in range(width):

            if encoder_size > width:
                encoder = int(iprt // (encoder_size / width))

            if found_count >= nmax:
                break

            if (vpfs[iprt] >> ichn) & 0x1:

                vpfs[iprt] = vpfs[iprt] ^ (1 << ichn)

                if encoder_size < width:
                    if ichn >= encoder_size:
                        encoder = int(width / encoder_size) * iprt + 1
                    else:
                        encoder = int(width / encoder_size) * iprt

                encoder_counts[encoder] += 1

                if encoder_counts[encoder] <= MAX_CLUSTERS_PER_ENCODER:
                    # print(
                    #     "Found %d clusters in encoder %d, partition %d channel %d!"
                    #     % (encoder_counts[encoder], encoder, iprt, ichn)
                    # )
                    c = Cluster()
                    c.adr = ichn
                    c.cnt = (cnts[iprt] >> 3 * ichn) & 0x7
                    c.prt = iprt
                    c.vpf = 1
                    found[found_count]=c
                    found_count += 1
                # else:
                #     print(
                #         "Rejected a cluster in encoder %d, partition %d channel %d!"
                #         % (encoder, iprt, ichn)
                #     )

    null = Cluster()
    null.adr = 511
    null.cnt = 0x7
    null.prt = 0x7
    null.vpf = 0

    for iclst in range(len(found)):
        if found[iclst]==None:
            found[iclst]  = null


    found = sorted(found, key=lambda x: x.vpf << 12 | x.prt << 8 | x.adr, reverse=True)

    return found
