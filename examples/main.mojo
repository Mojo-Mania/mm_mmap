"""Small demo of `mm_mmap`: anonymous memory and a file-backed round-trip."""

from mm_mmap import (
    MemoryMap,
    page_size,
    PROT_READ,
    PROT_WRITE,
    MAP_SHARED,
    MAP_PRIVATE,
)
from std.tempfile import NamedTemporaryFile


def main() raises:
    print("page size:", page_size())

    # Anonymous, zero-initialized scratch memory.
    var scratch = MemoryMap.anonymous(64 * 1024)
    print(
        "anonymous mapping of",
        len(scratch),
        "bytes, first byte is",
        scratch.bytes()[0],
    )
    scratch.bytes()[0] = 7
    print("after writing, first byte is", scratch.bytes()[0])

    # File-backed: write through the mapping, then read it back from disk.
    var tmp = NamedTemporaryFile("rw")
    tmp.write_bytes(String("hello, memory map").as_bytes())

    with open(tmp.name, "rw") as f:
        var m = MemoryMap.map(f, prot=PROT_READ | PROT_WRITE, flags=MAP_SHARED)
        print("mapped", len(m), "bytes of", tmp.name)
        m.bytes()[0] = UInt8(ord("H"))
        m.flush()

    with open(tmp.name, "r") as f:
        var m = MemoryMap.map(f, prot=PROT_READ, flags=MAP_PRIVATE)
        print("file now starts with:", StringSlice(unsafe_from_utf8=m.bytes()))

    tmp.close()
