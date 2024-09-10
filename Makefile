SRC = $(wildcard ./*.ipynb)

all: pacmel_mining_use_case docs

pacmel_mining_use_case: $(SRC)
	nbdev_export
	touch pacmel_mining_use_case

docs_serve: docs
	cd docs && bundle exec jekyll serve

docs: $(SRC)
	nbdev_docs
	touch docs

test:
	nbdev_test_nbs

release: pypi
	nbdev_bump_version

pypi: dist
	twine upload --repository pypi dist/*

dist: clean
	python setup.py sdist bdist_wheel

clean:
	rm -rf dist