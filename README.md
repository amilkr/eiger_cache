# Periodic Self-Rehydrating Cache

This Elixir application implements an in-memory cache based on [these requirements](https://github.com/eqlabs/recruitment-exercises/blob/master/cache/cache.md).

Find the documentation in the `doc` folder. Once you clone the repo, you can open `doc/index.html` in your browser.

## Try it

The application API is defined in the `Cache` module.

```console
$ mix deps.get
Resolving Hex dependencies...
Dependency resolution completed:
...

$ iex -S mix
iex(1)> Cache.register_function(fn -> {:ok, length(Process.list)} end, :proc_count, 120_000, 60_000)
:ok
iex(2)> Cache.get(:proc_count)
{:ok, 108}
iex(3)> Cache.get(:foo) # no registered key
{:error, :not_registered}
iex(4)> Cache.register_function(fn -> {:ok, :timer.sleep(30_000)} end, :slow_fn, 120_000, 60_000)
:ok
iex(5)> Cache.get(:slow_fn, 1000) # timeout for slow executions
{:error, :timeout}

```

## Run credo, tests and coverage

```console
$ mix credo --strict
Checking 10 source files ...

Please report incorrect results: https://github.com/rrrene/credo/issues

Analysis took 0.1 seconds (0.04s to load, 0.1s running 64 checks on 10 files)
26 mods/funs, found no issues.
```

```console
$ mix coveralls
===> Compiling parse_trans
...
==> eiger_cache
Compiling 5 files (.ex)
Generated eiger_cache app
....................

Finished in 4.9 seconds
20 tests, 0 failures

Randomized with seed 603260
----------------
COV    FILE                                        LINES RELEVANT   MISSED
100.0% lib/cache.ex                                   70        3        0
100.0% lib/cache/application.ex                       13        1        0
100.0% lib/cache/store.ex                             58        6        0
100.0% lib/cache/supervisor.ex                        48        5        0
100.0% lib/cache/worker.ex                           129       17        0
[TOTAL] 100.0%
----------------
```

## Implementation Details

* The application uses an ETS to store the data. Check `Cache.Store` documentation for details
* Every time a new function is registered (by calling `Cache.register_function/4`), `Cache.Supervisor` spawns
a new `Cache.Worker` process
* The `Cache.Worker` processes are gen_servers. They are registered globally with the given `key`, mainly because the
`:global` module allows to use any type of term as name (the requirements specify that key can be of any type, `key :: any`)
* Each `Cache.Worker` process sends a message to itself every `refresh_interval` milliseconds to execute the function and (if
the function returns `{:ok, any()}`) update the store
