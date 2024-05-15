package fw_shared

import "core:thread"
import "core:sync"

Callback :: proc(any)

CbContext :: struct {
    ctx: any,
    callback: Callback,
}

Watcher :: struct {
    lock: sync.Futex,
    paths: map[string]CbContext,
    cont: bool,
    thrd: ^thread.Thread,
    pathHandles: map[int]string,
    evhandle: int
}

