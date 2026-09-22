.PHONY: validate
validate:
	python3 -m json.tool source.json >/dev/null
	python3 -m json.tool source-beta.json >/dev/null
	@for f in release-manifests/*.json; do python3 -m json.tool "$$f" >/dev/null; done
	python3 -m py_compile scripts/*.py scripts/greenfield/*.py
	python3 scripts/greenfield/validate.py
