# Poison

[![Build Status](https://travis-ci.org/devinus/poison.svg?branch=master)](https://travis-ci.org/devinus/poison)
[![Coverage Status](https://coveralls.io/repos/github/devinus/poison/badge.svg?branch=master)](https://coveralls.io/github/devinus/poison?branch=master)
[![Hex.pm Version](https://img.shields.io/hexpm/v/poison.svg?style=flat-square)](https://hex.pm/packages/poison)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/poison.svg?style=flat-square)](https://hex.pm/packages/poison)

Poison is a new JSON library for Elixir focusing on wicked-fast **speed**
without sacrificing **simplicity**, **completeness**, or **correctness**.

Poison takes several approaches to be the fastest JSON library for Elixir.

Poison uses extensive [sub binary matching][1], a **hand-rolled parser** using
several techniques that are [known to benefit BeamAsm][2] for JIT compilation,
[IO list][3] encoding and **single-pass** decoding.

Poison benchmarks sometimes puts Poison's performance close to `jiffy` and
usually faster than other Erlang/Elixir libraries.

Poison fully conforms to [RFC 7159][4], [ECMA 404][5], and fully passes the
[JSONTestSuite][6].

## Installation

First, add Poison to your `mix.exs` dependencies:

```elixir
def deps do
  [{:poison, "~> 5.0"}]
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
needed. However, unless you absolutely know what you're doing, do **not** do
it. Atoms are not garbage-collected, see
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

_Note:_ Validating keys can cause a small performance hit.

```iex
iex> Poison.encode!(%{:foo => "foo1", "foo" => "foo2"}, strict_keys: true)
** (Poison.EncodeError) duplicate key found: :foo
```

## Benchmarking

```sh-session
$ MIX_ENV=bench mix run bench/run.exs
```

### Current Benchmarks

As of 2020-06-25:

- Amazon EC2 c5.2xlarge instance running Ubuntu Server 20.04:
  https://gist.github.com/devinus/c82c2f6eaa22456e7ff0f5705466b1de

## License

Poison is released under the [public-domain-equivalent][8] [0BSD][9] license.

[1]: http://www.erlang.org/euc/07/papers/1700Gustafsson.pdf
[2]: https://erlang.org/documentation/doc-12.0-rc1/erts-12.0/doc/html/BeamAsm.html
[3]: http://jlouisramblings.blogspot.com/2013/07/problematic-traits-in-erlang.html
[4]: https://tools.ietf.org/html/rfc7159
[5]: http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
[6]: https://github.com/nst/JSONTestSuite
[7]: http://prog21.dadgum.com/70.html
[8]: https://en.wikipedia.org/wiki/Public-domain-equivalent_license
[9]: https://opensource.org/licenses/0BSD
