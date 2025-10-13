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
