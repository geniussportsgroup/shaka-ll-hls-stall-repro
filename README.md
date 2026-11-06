# shaka-ll-hls-stall-repro

Reproduce and A/B-test the Shaka Player LL-HLS mid-segment stall bug:

when `hls.allowLowLatencyByteRangeOptimization` merges contiguous
`EXT-X-PART` byte ranges into one open-ended fetch, a mid-body abort can
leave a partial `mdat` in `remaining`. Without a fix, NetworkingEngine
retries from byte 0 and concatenates onto that leftover → corrupt MSE
append → `MEDIA_ERR_DECODE` (HTMLMediaElement code 3 / Shaka 3014).

Related Shaka change:
https://github.com/geniussportsgroup/shaka-player/tree/fix/ll-hls-stream-callback-retry

## What’s in this repo

| Path | Role |
|------|------|
| `stall_ll_hls_segment.py` | mitmproxy addon: forward N bytes, then `cut` / `stall` / `kill` one media segment |
| `run_stall_proxy.sh` | venv + reverse-proxy helper (binds `0.0.0.0` by default for LAN devices) |
| `serve_page.sh` | static UI server (also binds all interfaces) |
| `index.html` | player page: Latest stable vs **local fixed** build, Range / `streamCB` logs |
| `vendor/shaka-player.fixed.compiled.js` | compiled build with the mdat-resume fix for offline A/B |

## Quick start

Terminal 1 — stall proxy (size `STALL_BYTES` between one part and the full segment):

```bash
STALL_BYTES=250000 \
STALL_SECONDS=10 \
STALL_AFTER_SECONDS=50 \
STALL_MODE=cut \
STALL_ONCE=1 \
./run_stall_proxy.sh https://your-ll-hls-origin.example/live/public/playlist.m3u8
```

Terminal 2 — UI:

```bash
./serve_page.sh
```

Open `http://<lan-ip>:8090/` (or `http://127.0.0.1:8090/`). Set the manifest to
`http://<lan-ip>:8080/live/public/playlist.m3u8`.

### A/B in the UI

1. **Latest stable** — expect `attempt=1 Range=(none)`, then often
   `HTMLMediaElement error code=3` / Shaka `3014` on Safari after the cut.
2. **This branch fix (local vendor build)** — expect
   `attempt=1 Range=bytes=<committed>-` and recovery without decode error.

`STALL_MODE=cut` (silence past `stallTimeout`, then drop the rest) is the
mode that matches the corrupt-`remaining` bug. `kill` tends to surface as
network `1002` instead.

## Refresh the local fixed build

Keep `vendor/shaka-player.fixed.compiled.js` in sync with your Shaka fix
checkout:

```bash
# After building shaka-player.compiled.js in the fix branch:
./refresh-fixed-build.sh /path/to/shaka-player
# or
SHAKA_PLAYER_DIR=/path/to/shaka-player ./refresh-fixed-build.sh
```

The UI option **This branch fix (local vendor build)** loads
`./vendor/shaka-player.fixed.compiled.js`. You can also paste any compiled
URL via **Custom script URL**.

## Env reference

| Variable | Default | Meaning |
|----------|---------|---------|
| `STALL_BYTES` | `8000` | Bytes to forward before disruption |
| `STALL_SECONDS` | `6` | Silence duration (`cut` / `stall`) |
| `STALL_AFTER_SECONDS` | `0` | Wait this long after first media response before arming |
| `STALL_MODE` | `cut` | `cut` \| `stall` \| `kill` |
| `STALL_ONCE` | `1` | Max segments to disrupt |
| `BIND` / `PAGE_BIND` | `0.0.0.0` | Listen address for proxy / UI |
| `PORT` / `PAGE_PORT` | `8080` / `8090` | Ports |
