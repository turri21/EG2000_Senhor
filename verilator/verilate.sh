OPTIMIZE="-O3 --x-assign fast --x-initial fast --noassert"
WARNINGS="-Wno-fatal"
DEFINES="+define+SIMULATION=1 +define+USE_BLANK=1 +define+USE_CE_PIX=1 +define+MISTER=1 +define+USE_BRAM=1"
echo "verilator -cc --compiler msvc $WARNINGS $OPTIMIZE $DEFINES"
verilator -cc --compiler msvc $WARNINGS $OPTIMIZE $DEFINES \
--converge-limit 6000 \
--top-module emu sim.v \
-I../rtl \
-I../rtl/tv80 \
-I../src/JT49 \
-I../src
