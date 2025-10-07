# Keeps creating and joining short-lived threads, so that threads regularly exit
# while py-spy is sampling. Both python threads and native-only threads (created
# with pthread_create, running libc's usleep) are spawned.
import ctypes
import ctypes.util
import threading

libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)


def spawn_python_threads():
    while True:
        th = threading.Thread(target=lambda: None)
        th.start()
        th.join()


def spawn_native_threads():
    while True:
        thread = ctypes.c_ulong()
        # usleep(50) as start routine: the thread argument is the sleep duration
        err = libc.pthread_create(
            ctypes.byref(thread), None, libc.usleep, ctypes.c_void_p(50)
        )
        assert err == 0, err
        libc.pthread_join(thread, None)


for target in [spawn_python_threads, spawn_native_threads] * 2:
    threading.Thread(target=target, daemon=True).start()

print("READY", flush=True)
threading.Event().wait()
