# The 2D Renderer Challenge — C# / .NET 8

Chapters 1 and 2, implemented against a hand-rolled test runner (no NuGet,
no network; the SDK is enough).

## Build, test, render

```
export PATH="/opt/homebrew/Cellar/dotnet@8/8.0.127/libexec:$PATH"
dotnet run
```

That one command builds the project, runs every scenario from
`features/*.feature` (both chapters), prints a pass/fail summary per
feature, and writes all renders to `out/` (P3 for chapter 1, P6 for
chapter 2).
