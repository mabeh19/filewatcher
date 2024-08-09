package fw_impl

import "core:fmt"
import "core:sync"
import "core:time"
import "core:log"
import "core:strings"
import sys "core:sys/linux"

import fws "../fw_shared"

start :: proc(w: ^fws.Watcher) {
    for w.cont { 
        ev := sys.Inotify_Event(){}

        n, errno := sys.read(sys.Fd(w.evhandle), (cast([^]byte)&ev)[:size_of(ev)]); 
        if n == -1 || ev == {} {
            continue
        }

        sync.futex_wait(&w.lock, 1)
        w.lock = 1

        path := w.pathHandles[int(ev.wd)]
        ctx := w.paths[path]
        ctx.callback(ctx.ctx)

        w.lock = 0
        sync.futex_signal(&w.lock)
    }
}

add_path :: proc(w: ^fws.Watcher, path: string, ctx: rawptr, cb: fws.Callback) {
    w.paths[path] = fws.CbContext { ctx, cb }

    c_str := strings.clone_to_cstring(path)
    defer delete(c_str)
    pathHandle, errno := sys.inotify_add_watch(sys.Fd(w.evhandle), c_str, sys.IN_MODIFY)
    if pathHandle < 0 { return }
    w.pathHandles[int(pathHandle)] = path
}

init :: proc(w: ^fws.Watcher) { 
    if h, errno := sys.inotify_init(int(sys.IN_NONBLOCK)); h > -1 {
        w.evhandle = int(h)
    }
}
