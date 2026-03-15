all: bin pre descend generate post

.PHONY: bin

bin:
	cd bin && $(MAKE)

pre:
	./pre.sh

descend:
	find content -name 'Makefile' | \
		while IFS= read -r sub; do \
			[ -z "$$sub" ] && continue; \
			tdir=$$(dirname "$$sub"); \
			cd "$$tdir" && make; \
		done

generate:
	./cyc.sh '*.html' '*.xml'

post:
	./post.sh

clean:
	cd bin && $(MAKE) clean
	rm -rf public
