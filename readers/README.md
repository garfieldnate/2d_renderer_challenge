# Reader implementations

One implementation of the book per language, each written by a reader agent working from
nothing but the chapter text, the feature files and the reference images. They are kept so
that every new chapter can be tested the way a reader experiences it: as an increment on the
code the previous chapters produced, not a rewrite.

| Directory | Language | Run the tests |
| --- | --- | --- |
| `python/` | Python 3, stdlib | `python3 test_runner.py` |
| `javascript/` | Node 22, `node:test` | `node --test test.js` |
| `typescript/` | Deno 2 | `deno test --allow-read` |
| `ruby/` | Ruby 2.6, minitest | `ruby test_chapter01.rb` |
| `rust/` | Rust, stdlib only | `cargo test` |
| `java/` | Java 21, no JUnit | `javac -d classes src/*.java && java -cp classes Chapter01Tests` |
| `csharp/` | .NET 8 | `dotnet run` |
| `c/` | C11, clang | `make test` |
| `swift/` | Swift 6 toolchain, Swift 5 mode | `./build.sh && ./run` |
| `lean/` | Lean 4.29.1 (via `lean-toolchain`) | `lake test` or as its README says |
| `dart/` | Dart SDK 2.18, no pub packages | `dart test/run_tests.dart` |

Each directory's own `README.md` is the authority on how to build, test and render; agents
keep it current. `feedback/chapterNN-<lang>.md` is the candid report each agent wrote after
finishing that chapter. They are the reason chapters changed; read them before editing one.

Staging and collecting is done by `tools/readers.py`. Agents never work in this directory
directly: they get an isolated copy with the built chapters, and only their code comes back.
