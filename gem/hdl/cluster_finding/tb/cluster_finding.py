class Cluster:
    adr = 0x1ff
    cnt = 0
    prt = 0
    vpf = 0

    def __str__(self):
        return "adr=%02x cnt=%x prt=%x vpf=%x" % (self.adr, self.cnt, self.prt, self.vpf)


def equal(a, b):
    return a.adr == b.adr and a.cnt == b.cnt and a.prt == b.prt and a.vpf == b.vpf

def find_clusters(partitions, cnts, width, nmax, encoder_size):

    MAX_CLUSTERS_PER_ENCODER = 4

    found = []
    encoder_counts = [0,0,0,0,0,0,0,0]

    for iprt in range(len(partitions)):
        print("PARTITION %d width=%d size=%d" % (iprt, width, encoder_size))

        for ichn in range(width):

            if (encoder_size > width):
                encoder = int(iprt // (encoder_size/width))

            if len(found) >= nmax:
                return found

            if ((partitions[iprt] >> ichn) & 0x1):

                partitions[iprt] = partitions[iprt] ^ (1 << ichn)

                if (encoder_size < width):
                    if (ichn >= encoder_size):
                        encoder = int(width/encoder_size) * iprt + 1
                    else:
                        encoder = int(width/encoder_size) * iprt

                encoder_counts[encoder] += 1

                if (encoder_counts[encoder] <= MAX_CLUSTERS_PER_ENCODER):
                    print("Found %d clusters in encoder %d, partition %d channel %d!" % (encoder_counts[encoder], encoder, iprt, ichn))
                    c = Cluster()
                    c.adr = ichn
                    c.cnt = (cnts[iprt] >> 3*ichn) & 0x7
                    c.prt = iprt
                    c.vpf = 1
                    found.append(c)
                else:
                    print("Rejected a cluster in encoder %d, partition %d channel %d!" % (encoder, iprt, ichn))

    return found
