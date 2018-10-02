[![Build Status](https://travis-ci.org/LemonBoy/dtoa.nim.svg?branch=master)](https://travis-ci.org/LemonBoy/dtoa.nim)

# dtoa

Convert a `double` value to a string.

A straightforward port of Milo Yip's fast dtoa implementation used in
[RapidJson](https://github.com/Tencent/rapidjson).

This implementation is tailored for speed and uses Grisu2 as its underlying
algorithm: this means that there's a small where the output won't be represented
in its most compact form.

The resulting string is guaranteed to round-trip.

# FAQ

## What's wrong with `$`?

The `dtoa` provided by this library is much faster than `$`, you can run the
benchmark by yourself by running:

```sh
nimble install criterion
nim c -d:release -r bench.nim
```

And since it doesn't depend on the underlying libc implementation its output is
guaranteed to be the same across different platforms/os.

## What about `float`?

I don't need them at the moment, if you do please open a ticket.
