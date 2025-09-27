_:
  @just -l

install:
  bash -c ". ./.venv/bin/activate && maturin develop -r"

run-frontend:
  ./.venv/bin/python ./frontend/Game.pygame
  
test-new: install run-frontend
