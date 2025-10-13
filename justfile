_:
  @just -l

install:
  bash -c ". ./.venv/bin/activate && maturin develop -r"

run-frontend:
  ./.venv/bin/python ./frontend/Game.pygame
  
test-new: install run-frontend

_new-tmux-dev-session SESSION:
  tmux new -ds "{{SESSION}}" -n "README"
  tmux send-keys -t "{{SESSION}}":README 'nv ./README.md "+set wrap"' ENTER
  @just _new-window "{{SESSION}}" "Edit" ""
  @just _new-window "{{SESSION}}" "Cargo" ""
  @just _new-window "{{SESSION}}" "Misc" ""

_new-window SESSION NAME CMD:
  tmux new-w -t "{{SESSION}}" -n "{{NAME}}"
  # tmux send-keys -t "{{SESSION}}":"{{NAME}}" ". ./.venv/bin/activate" ENTER
  [[ "{{CMD}}" != "" ]] && tmux send-keys -t "{{SESSION}}":"{{NAME}}" "{{CMD}}" ENTER || true

tmux:
  tmux has-session -t '=bevy-pyo3-test' || just _new-tmux-dev-session bevy-pyo3-test
  tmux a -t '=bevy-pyo3-test'

hardware-reboot:
  adb reboot

flash-adb:
  adb shell "mkdir /userdata/roms/ports/bevy-pyo3-test/"
  adb push ./{frontend/{Game.pygame,frontend.py},dist/bevy_pyo3_test-0.1.0-cp312-cp312-manylinux_2_17_aarch64.manylinux2014_aarch64.whl,bevy-pyo3-test.sh} /userdata/roms/ports/bevy-pyo3-test/
  adb shell "cd /userdata/roms/ports/bevy-pyo3-test/; .venv/bin/python -m pip install --force-reinstall --no-index ./bevy_pyo3_test-*aarch64.whl"

build-debug:
  # PKG_CONFIG_SYSROOT_DIR=$(pwd)/cross-build-deps/aarch64/ maturin build --out dist --find-interpreter --target aarch64-unknown-linux-gnu --zig
  SYSROOT=$(pwd)/cross-build-deps/aarch64.2/untouched/aarch64-buildroot-linux-gnu_sdk-buildroot/aarch64-buildroot-linux-gnu/sysroot PKG_CONFIG_SYSROOT_DIR=${SYSROOT} PKG_CONFIG_LIBDIR=${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig PKG_CONFIG_PATH=${SYSROOT}/usr/lib/pkgconfig/ PKG_CONFIG_ALLOW_CROSS=1 LD_LIBRARY_PATH=${SYSROOT}/lib/ RUSTFLAGS="-C link-arg=-Wl,-rpath,$LD_LIBRARY_PATH" maturin build --skip-auditwheel --out dist --interpreter python3.12 --target aarch64-unknown-linux-gnu --zig

build-release:
  SYSROOT=$(pwd)/cross-build-deps/aarch64.2/untouched/aarch64-buildroot-linux-gnu_sdk-buildroot/aarch64-buildroot-linux-gnu/sysroot PKG_CONFIG_SYSROOT_DIR=${SYSROOT} PKG_CONFIG_LIBDIR=${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig PKG_CONFIG_PATH=${SYSROOT}/usr/lib/pkgconfig/ PKG_CONFIG_ALLOW_CROSS=1 LD_LIBRARY_PATH=${SYSROOT}/lib/ RUSTFLAGS="-C link-arg=-Wl,-rpath,$LD_LIBRARY_PATH" maturin build --skip-auditwheel --out dist --interpreter python3.12 --target aarch64-unknown-linux-gnu --zig --release

build-bin:
  # SYSROOT=$(pwd)/cross-build-deps/aarch64.2/untouched/aarch64-buildroot-linux-gnu_sdk-buildroot/aarch64-buildroot-linux-gnu/sysroot PKG_CONFIG_SYSROOT_DIR=${SYSROOT} PKG_CONFIG_LIBDIR=${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig PKG_CONFIG_PATH=${SYSROOT}/usr/lib/pkgconfig/ PKG_CONFIG_ALLOW_CROSS=1 LD_LIBRARY_PATH=${SYSROOT}/lib/ cargo zigbuild --target aarch64-unknown-linux-gnu.2.35
  SYSROOT=$(pwd)/cross-build-deps/aarch64.3/untouched/ PKG_CONFIG_SYSROOT_DIR=${SYSROOT} PKG_CONFIG_LIBDIR=${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig PKG_CONFIG_PATH=${SYSROOT}/usr/lib/pkgconfig/ PKG_CONFIG_ALLOW_CROSS=1 LD_LIBRARY_PATH=${SYSROOT}/lib/ cargo zigbuild --target aarch64-unknown-linux-gnu.2.33 -r

force-kill-synth:
  adb shell "killall python"

run-on-device:
  adb shell "RUST_BACKTRACE=full WGPU_BACKEND=\"gl\" WGPU_ALLOW_UNDERLYING_NONCOMPLIANT_ADAPTER=1 /userdata/roms/ports/bevy-pyo3-test/bevy-pyo3-test.sh"
