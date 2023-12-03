.PHONY: dox

dox:
	doxygen dox/doxy.config
	open dox/html/main.html
