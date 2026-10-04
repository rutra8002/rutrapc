# Usage: python upload.py program.bin COM5
import sys
import serial                            #pyserial

if len(sys.argv) < 3:
    sys.exit("usage: python rutra_upload.py program.bin COM_PORT")

data = open(sys.argv[1], "rb").read()
count = len(data) // 2                   # 2 bytes per instruction
if not 1 <= count <= 256 or len(data) % 2 != 0:
    sys.exit("Not a valid program file (need 1 to 256 whole instructions)")

packet = bytes([0xB7, count % 256]) + data   # sync byte, count (0 = 256), program

port = serial.Serial(sys.argv[2], 115200, timeout=0.1)
port.write(packet)
print("Uploaded", count, "instructions. Listening (Ctrl+C to quit)...")
try:
    while True:
        print(port.read(64).decode("ascii", "replace"), end="", flush=True)
except KeyboardInterrupt:
    pass