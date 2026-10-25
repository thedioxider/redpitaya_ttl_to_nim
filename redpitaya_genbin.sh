echo -n "all:{ $1.bit }" > $1.bif
bootgen -image $1.bif -arch zynq -process_bitstream bin -o $1.bit.bin -w
