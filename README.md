# mm_mmap

POSIX memory mapping for [Mojo](https://mojolang.org): an owning `MemoryMap`
type that maps a file or fresh anonymous memory into the process address space,
plus the `mmap`/`munmap`/`msync` bindings, `page_size()`, and typed
`Prot`/`MapFlags` flag sets.

Mojo's standard library has no `mmap` today, so every project that needs one
reimplements the same `external_call` plumbing — including the per-OS constant
differences that are easy to get wrong (`MAP_ANONYMOUS` is `0x20` on Linux but
`0x1000` on macOS, `MS_SYNC` differs, and so on). This package is that plumbing,
written once and tested.

Supported on macOS and Linux. See [`docs/design.md`](docs/design.md) for the
design rationale.

## Install

Add the package to your project by vendoring the `mm_mmap/` directory, or by
adding this repository as a git submodule, and put its parent on the import
path:

```bash
mojo -I path/to/mm_mmap your_program.mojo
```

## Usage

```mojo
from mm_mmap import MemoryMap, PROT_READ, PROT_WRITE, MAP_SHARED, MAP_PRIVATE

# File-backed: map a file and access its bytes directly, with no explicit I/O.
with open("data.bin", "r") as f:
    var m = MemoryMap.map(f, prot=PROT_READ, flags=MAP_PRIVATE)
    var first = m.bytes()[0]

# Write through a shared mapping and push the changes to disk.
with open("data.bin", "rw") as f:
    var m = MemoryMap.map(f, prot=PROT_READ | PROT_WRITE, flags=MAP_SHARED)
    m.bytes()[0] = 0x7F
    m.flush()

# Anonymous: zero-initialized scratch memory.
var scratch = MemoryMap.anonymous(64 * 1024)
scratch.bytes()[0] = 1
```

## API

```mojo
struct MemoryMap(Movable, Sized):
    @staticmethod
    def map(file: FileHandle, length: Int = -1, *, offset: Int = 0,
            prot: Prot = PROT_READ | PROT_WRITE,
            flags: MapFlags = MAP_SHARED) raises -> Self
    @staticmethod
    def map_fd(fd: Int, length: Int = -1, *, offset: Int = 0,
               prot: Prot = PROT_READ | PROT_WRITE,
               flags: MapFlags = MAP_SHARED) raises -> Self
    @staticmethod
    def anonymous(length: Int, *,
                  prot: Prot = PROT_READ | PROT_WRITE) raises -> Self

    def bytes(mut self) -> Span[UInt8, origin_of(self)]        # borrowed view
    def unsafe_ptr(mut self) -> Pointer[UInt8, origin_of(self)]
    def flush(self, *, blocking: Bool = True) raises           # msync
    def __len__(self) -> Int
    def __deinit__(deinit self)                                # munmap (RAII)

struct Prot(TrivialRegisterPassable, Writable)      # PROT_NONE/READ/WRITE/EXEC
struct MapFlags(TrivialRegisterPassable, Writable)  # MAP_SHARED/PRIVATE/FIXED/ANONYMOUS

def page_size() -> Int
```

Notes:

- **RAII.** The region is unmapped in `__deinit__`, mirroring `FileHandle`.
  `bytes()` and `unsafe_ptr()` return views parameterized by `origin_of(self)`,
  so the mapping cannot be unmapped while a borrowed view is live.
- **The mapping outlives the file.** `map()` only reads the descriptor during
  the call; per POSIX the mapping stays valid after the file is closed.
- **Any byte offset works.** `offset` need not be page-aligned: the region is
  mapped from the page boundary at or below it, and the returned views point at
  the exact requested byte.
- **Typed flags.** `Prot` and `MapFlags` are distinct types, so passing a
  `MAP_*` value where a `PROT_*` belongs is a compile error.

## Development

```bash
pixi run test     # run the test suite
pixi run main     # run the example
pixi run format   # mojo format
pixi run docs     # check docstrings
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
