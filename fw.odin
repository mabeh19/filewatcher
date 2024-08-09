package fw

import "core:fmt"
import "core:os"
import "core:thread"
import "core:time"
import "core:testing"
import "core:sync"
import "core:log"

import "fw_impl"
import "fw_shared"

// Create user friendly alias
Watcher     :: fw_shared.Watcher
Callback    :: fw_shared.Callback
CbContext   :: fw_shared.CbContext


new_watcher :: proc() -> ^Watcher {
    w := new(Watcher)
    w.cont = true
    fw_impl.init(w)
    w.thrd = thread.create_and_start_with_poly_data(w, watcher_thread)

    return w
}


watch :: proc(watcher: ^Watcher, path: string, ctx: ^$T, cb: proc(ctx: ^T)) -> bool {

    if !os.exists(path) { return false }

    sync.futex_wait(&watcher.lock, 1)
    watcher.lock = 1
    fw_impl.add_path(watcher, path, ctx, Callback(cb))
    watcher.lock = 0
    sync.futex_signal(&watcher.lock)

    return true
}



stop :: proc(w: ^Watcher) {
    w.cont = false

    thread.join(w.thrd)

    free(w)
}


watcher_thread :: proc(w: ^Watcher) {
    fw_impl.start(w)
}


@(test)
watcher_test :: proc(t: ^testing.T) {
    written := false

    os.write_entire_file("test_foo.txt", {1,2,3,4})
    defer os.remove("test_foo.txt")

    w := new_watcher()
    defer stop(w)

    watch(w, "test_foo.txt", &written, proc(ctx: ^bool) { ctx^ = true })

    os.write_entire_file("test_foo.txt", {1, 2})

    time.sleep(1 * time.Millisecond)

    testing.expect(t, written, "watcher not triggered")
}

