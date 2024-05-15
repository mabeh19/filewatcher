package fw_impl

import "core:fmt"
import "core:sync"
import "core:time"
import "core:log"
import "core:strings"
import sys "core:sys/linux"


import fws "../fw_shared"


start :: proc(w: ^fws.Watcher) {
    for len(w.paths) == 0 {
        time.sleep(100 * time.Millisecond)
    }

    for w.cont { 
        ev := sys.Inotify_Event{}
        sys.read(sys.Fd(w.evhandle), (cast([^]byte)&ev)[:size_of(ev)])

        sync.futex_wait(&w.lock, 1)
        w.lock = 1

        path := w.pathHandles[int(ev.wd)]
        ctx := w.paths[path]

        ctx.callback(ctx.ctx)
        w.lock = 0
        sync.futex_signal(&w.lock)
    }
}

add_path :: proc(w: ^fws.Watcher, path: string, ctx: any, cb: fws.Callback) {
    w.paths[path] = fws.CbContext { ctx, cb }

    c_str := strings.clone_to_cstring(path)
    defer delete(c_str)
    sys.inotify_add_watch(i32(w.evhandle), c_str, sys.IN_MODIFY)
}

init :: proc(w: ^fws.Watcher) { 
    w.evhandle = int(sys.inotify_init())
}
