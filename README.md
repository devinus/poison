# Poison

Poison is a new JSON library for Elixir focusing on wicked-fast **speed**
without sacrificing **simplicity**, **completeness**, or **correctness**.

Poison takes several approaches to be the fastest JSON library for Elixir.

Poison uses extensive [sub binary matching][1], a **hand-rolled parser** using
several techniques that are [known to benefit HiPE][2] for native compilation,
[IO list][3] encoding and **single-pass** decoding.

Preliminary benchmarking has sometimes put Poison's performance closer to
`jiffy`, and almost always faster than existing Elixir libraries.

```elixir
defmodule Person do
  defstruct [:name, :age]
end

Poison.decode!(~s({"name": "Devin Torres", "age": 27}), as: Person)
#=> %Person{name: "Devin Torres", age: 27}

Poison.decode!(~s({"people": [{"name": "Devin Torres", "age": 27}]}),
  as: %{"people" => [Person]})
#=> %{"people" => [%Person{age: 27, name: "Devin Torres"}]}
```

Every component of Poison -- the encoder, decoder, and parser -- are all usable
on their own without buying into other functionality. For example, if you were
interested purely in the speed of parsing JSON without a decoding step, you
could simply call `Poison.Parser.parse`.

## Parser

```iex
iex> Poison.Parser.parse!(~s({"name": "Devin Torres", "age": 27}))
%{"name" => "Devin Torres", "age" => 27}
iex> Poison.Parser.parse!(~s({"name": "Devin Torres", "age": 27}), keys: :atoms!)
%{name: "Devin Torres", age: 27}
```

## Encoder

```iex
iex> IO.puts Poison.Encoder.encode([1, 2, 3], [])
"[1,2,3]"
```

Anything implementing the Encoder protocol is expected to return an
[IO list][4] to be embedded within any other Encoder's implementation and
passable to any IO subsystem without conversion.

```elixir
defimpl Poison.Encoder, for: Person do
  def encode(%{name: name, age: age}, _options) do
    Poison.Encoder.BitString.encode("#{name} (#{age})")
  end
end
```

## Benchmarking

```sh-session
$ mix archive.install https://github.com/alco/benchfella/releases/download/archive/benchfella-0.0.2.ez
$ mix deps.get
$ MIX_ENV=bench mix compile
$ MIX_ENV=bench mix compile.protocols
$ elixir -pa _build/bench/consolidated -pa _build/bench/lib/\*/ebin -S mix bench
```

## License

Poison is released into the public domain (see `UNLICENSE`).
Poison is also optionally available under the ISC License (see `LICENSE`),
meant especially for jurisdictions that do not recognize public domain works.

[1]: http://www.erlang.org/euc/07/papers/1700Gustafsson.pdf
[2]: http://www.erlang.org/workshop/2003/paper/p36-sagonas.pdf
[3]: http://jlouisramblings.blogspot.com/2013/07/problematic-traits-in-erlang.html
[4]: http://prog21.dadgum.com/70.html
