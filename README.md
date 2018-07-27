# Poison

[![Build Status](https://travis-ci.org/devinus/poison.svg?branch=master)](https://travis-ci.org/devinus/poison)
[![Coverage Status](https://coveralls.io/repos/github/devinus/poison/badge.svg?branch=master)](https://coveralls.io/github/devinus/poison?branch=master)
[![Hex.pm Version](https://img.shields.io/hexpm/v/poison.svg?style=flat-square)](https://hex.pm/packages/poison)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/poison.svg?style=flat-square)](https://hex.pm/packages/poison)

Poison is a new JSON library for Elixir focusing on wicked-fast **speed**
without sacrificing **simplicity**, **completeness**, or **correctness**.

Poison takes several approaches to be the fastest JSON library for Elixir.

Poison uses extensive [sub binary matching][1], a **hand-rolled parser** using
several techniques that are [known to benefit HiPE][2] for native compilation,
[IO list][3] encoding and **single-pass** decoding.

Poison benchmarks sometimes puts Poison's performance close to `jiffy` and
usually faster than other Erlang/Elixir libraries.

Poison fully conforms to [RFC 7159][4], [ECMA 404][5], and the
[JSONTestSuite][6].

## Installation

First, add Poison to your `mix.exs` dependencies:

```elixir
def deps do
  [{:poison, "~> 3.1"}]
end
```

Then, update your dependencies:

```sh-session
$ mix deps.get
```

## Usage

```elixir
Poison.encode!(%{"age" => 27, "name" => "Devin Torres"})
#=> "{\"name\":\"Devin Torres\",\"age\":27}"

Poison.decode!(~s({"name": "Devin Torres", "age": 27}))
#=> %{"age" => 27, "name" => "Devin Torres"}

defmodule Person do
  @derive [Poison.Encoder]
  defstruct [:name, :age]
end

Poison.encode!(%Person{name: "Devin Torres", age: 27})
#=> "{\"name\":\"Devin Torres\",\"age\":27}"

Poison.decode!(~s({"name": "Devin Torres", "age": 27}), as: %Person{})
#=> %Person{name: "Devin Torres", age: 27}

Poison.decode!(~s({"people": [{"name": "Devin Torres", "age": 27}]}),
  as: %{"people" => [%Person{}]})
#=> %{"people" => [%Person{age: 27, name: "Devin Torres"}]}
```

Every component of Poison (encoder, decoder, and parser) are all usable on
their own without buying into other functionality. For example, if you were
interested purely in the speed of parsing JSON without a decoding step, you
could simply call `Poison.Parser.parse`.

## Parser

```iex
iex> Poison.Parser.parse!(~s({"name": "Devin Torres", "age": 27}), %{})
%{"name" => "Devin Torres", "age" => 27}
iex> Poison.Parser.parse!(~s({"name": "Devin Torres", "age": 27}), %{keys: :atoms!})
%{name: "Devin Torres", age: 27}
```

Note that `keys: :atoms!` reuses existing atoms, i.e. if `:name` was not
allocated before the call, you will encounter an `argument error` message.

You can use the `keys: :atoms` variant to make sure all atoms are created as
needed.  However, unless you absolutely know what you're doing, do **not** do
it.  Atoms are not garbage-collected, see
[Erlang Efficiency Guide](http://www.erlang.org/doc/efficiency_guide/commoncaveats.html)
for more info:

> Atoms are not garbage-collected. Once an atom is created, it will never be
> removed. The emulator will terminate if the limit for the number of atoms
> (1048576 by default) is reached.

## Encoder

```iex
iex> Poison.Encoder.encode([1, 2, 3], %{}) |> IO.iodata_to_binary
"[1,2,3]"
```

Anything implementing the Encoder protocol is expected to return an
[IO list][7] to be embedded within any other Encoder's implementation and
passable to any IO subsystem without conversion.

```elixir
defimpl Poison.Encoder, for: Person do
  def encode(%{name: name, age: age}, options) do
    Poison.Encoder.BitString.encode("#{name} (#{age})", options)
  end
end
```

For maximum performance, make sure you `@derive [Poison.Encoder]` for any
struct you plan on encoding.

### Encoding only some attributes

When deriving structs for encoding, it is possible to select or exclude
specific attributes. This is achieved by deriving `Poison.Encoder` with the
`:only` or `:except` options set:

```elixir
defmodule PersonOnlyName do
  @derive {Poison.Encoder, only: [:name]}
  defstruct [:name, :age]
end

defmodule PersonWithoutName do
  @derive {Poison.Encoder, except: [:name]}
  defstruct [:name, :age]
end
```

In case both `:only` and `:except` keys are defined, the `:except` option is
ignored.

### Key Validation

According to [RFC 7159][4] keys in a JSON object should be unique. This is
enforced and resolved in different ways in other libraries. In the Ruby JSON
library for example, the output generated from encoding a hash with a duplicate
key (say one is a string, the other an atom) will include both keys. When
parsing JSON of this type, Chromium will override all previous values with the
final one.

Poison will generate JSON with duplicate keys if you attempt to encode a map
with atom and string keys whose encoded names would clash. If you'd like to
ensure that your generated JSON doesn't have this issue, you can pass the
`strict_keys: true` option when encoding. This will force the encoding to fail.

*Note:* Validating keys can cause a small performance hit.

```iex
iex> Poison.encode!(%{:foo => "foo1", "foo" => "foo2"}, strict_keys: true)
** (Poison.EncodeError) duplicate key found: :foo
```

## Benchmarking

```sh-session
$ MIX_ENV=bench mix run bench/run.exs
```

### Current Benchmarks

As of 2017-05-15 on a 2.8 GHz Intel Core i7:

```
## EncoderBench
benchmark name             iterations   average time
maps (jiffy)                   500000   7.88 µs/op
structs (Poison)               200000   9.46 µs/op
structs (Jazz)                 100000   15.43 µs/op
structs (JSX)                  100000   18.45 µs/op
maps (Poison)                  100000   19.45 µs/op
maps (Jazz)                    100000   21.61 µs/op
maps (JSX)                      50000   31.76 µs/op
maps (JSON)                     50000   34.08 µs/op
structs (JSON)                  50000   47.56 µs/op
strings (jiffy)                 10000   107.68 µs/op
lists (Poison)                  10000   120.79 µs/op
string escaping (jiffy)         10000   139.92 µs/op
lists (jiffy)                   10000   229.18 µs/op
lists (Jazz)                    10000   236.86 µs/op
strings (JSON)                  10000   237.97 µs/op
strings (JSX)                   10000   283.87 µs/op
lists (JSX)                      5000   336.96 µs/op
jiffy                            5000   429.92 µs/op
strings (Jazz)                   5000   430.78 µs/op
jiffy (pretty)                   5000   431.55 µs/op
lists (JSON)                     5000   559.31 µs/op
strings (Poison)                 5000   574.26 µs/op
string escaping (Jazz)           1000   1313.51 µs/op
string escaping (JSX)            1000   1474.66 µs/op
Poison                           1000   1546.53 µs/op
string escaping (Poison)         1000   1728.66 µs/op
Poison (pretty)                  1000   1784.37 µs/op
Jazz                             1000   2060.77 µs/op
JSON                             1000   2250.89 µs/op
JSX                              1000   2252.77 µs/op
Jazz (pretty)                    1000   2317.55 µs/op
JSX (pretty)                      500   5577.33 µs/op
## ParserBench
benchmark name             iterations   average time
UTF-8 unescaping (jiffy)        50000   60.05 µs/op
UTF-8 unescaping (Poison)       10000   112.53 µs/op
UTF-8 unescaping (JSX)          10000   282.83 µs/op
UTF-8 unescaping (JSON)          5000   469.26 µs/op
jiffy                            5000   479.07 µs/op
Poison                           5000   730.85 µs/op
JSX                              1000   1947.77 µs/op
JSON                              500   5175.11 µs/op
Issue 90 (jiffy)                  100   18864.70 µs/op
Issue 90 (Poison)                  50   50091.16 µs/op
Issue 90 (JSX)                     10   155975.20 µs/op
Issue 90 (JSON)                     1   1964860.00 µs/op
```

## License

Poison is released under [CC0-1.0][8].

[1]: http://www.erlang.org/euc/07/papers/1700Gustafsson.pdf
[2]: http://www.erlang.org/workshop/2003/paper/p36-sagonas.pdf
[3]: http://jlouisramblings.blogspot.com/2013/07/problematic-traits-in-erlang.html
[4]: https://tools.ietf.org/html/rfc7159
[5]: http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
[6]: https://github.com/nst/JSONTestSuite
[7]: http://prog21.dadgum.com/70.html
[8]: https://creativecommons.org/publicdomain/zero/1.0/
