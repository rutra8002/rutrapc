# Usage: python upload.py program.bin COM5
import sys
import serial                            #pyserial

if len(sys.argv) < 3:
    sys.exit("usage: python upload.py program.bin COM_PORT")

data = open(sys.argv[1], "rb").read()
MAX_WORDS = 1024                         # = 2^MEMORY_ADDRESS_BITS in rutra_top.v
count = len(data) // 2                   # 2 bytes per 16-bit word
if not 1 <= count <= MAX_WORDS or len(data) % 2 != 0:
    sys.exit("Not a valid program file (need 1 to " + str(MAX_WORDS) + " words)")

packet = bytes([0xB7, count >> 8, count & 0xFF]) + data 
port = serial.Serial(sys.argv[2], 115200, timeout=0.1)
port.write(packet)
print("Uploaded", count, "words. Listening (Ctrl+C to quit)...")
try:
    while True:
        print(port.read(64).decode("ascii", "replace"), end="", flush=True)
except KeyboardInterrupt:
    pass