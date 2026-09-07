PYTHON ?= python3

.PHONY: test check config-check

test:
	PYTHONPATH=src $(PYTHON) -m pytest tests

check:
	$(PYTHON) -m py_compile src/dingding_me_agent/*.py tests/*.py
	$(MAKE) test

config-check:
	PYTHONPATH=src $(PYTHON) -m dingding_me_agent --config config/agent-config.example.json --config-check
