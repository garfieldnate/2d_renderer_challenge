CC     = clang
CFLAGS = -std=c11 -Wall -Wextra -O2
LDLIBS = -lm

all: bin/tests bin/render

bin:
	mkdir -p bin out

bin/tests: src/renderer.c src/harness.c src/tests.c src/renderer.h src/harness.h | bin
	$(CC) $(CFLAGS) -o $@ src/renderer.c src/harness.c src/tests.c $(LDLIBS)

bin/render: src/renderer.c src/main.c src/renderer.h | bin
	$(CC) $(CFLAGS) -o $@ src/renderer.c src/main.c $(LDLIBS)

test: bin/tests
	./bin/tests

render: bin/render
	mkdir -p out && ./bin/render

clean:
	rm -rf bin

.PHONY: all test render clean
