# Starts an OS thread that never runs any Python code: it is created directly
# with pthread_create and its start routine is libc's pause(), so it has no
# Python frames at all. py-spy only reports it with --native-all.
import ctypes
import ctypes.util
import time

libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)

thread = ctypes.c_ulong()
err = libc.pthread_create(ctypes.byref(thread), None, libc.pause, None)
assert err == 0, err
err = libc.pthread_setname_np(thread, b"pyspy-native")
assert err == 0, err

print("READY", flush=True)
while True:
    time.sleep(1)
