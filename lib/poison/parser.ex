defmodule Poison.MissingDependencyError do
  @type t :: %__MODULE__{name: String.t()}

  defexception name: nil

  def message(%{name: name}) do
    "missing optional dependency: #{name}"
  end
end

defmodule Poison.ParseError do
  alias Code.Identifier
  alias Poison.Parser

  @type t :: %__MODULE__{data: String.t(), skip: non_neg_integer, value: Parser.t()}

  defexception data: "", skip: 0, value: nil

  def message(%{data: data, skip: skip, value: value}) when value != nil do
    <<head::binary-size(skip), _rest::bits>> = data
    pos = String.length(head)
    "cannot parse value at position #{pos}: #{inspect(value)}"
  end

  def message(%{data: data, skip: skip}) when is_bitstring(data) do
    <<head::binary-size(skip), rest::bits>> = data
    pos = String.length(head)

    case rest do
      <<>> ->
        "unexpected end of input at position #{pos}"

      <<token::utf8, _rest::bits>> ->
        "unexpected token at position #{pos}: #{escape(token)}"

      _rest ->
        "cannot parse value at position #{pos}: #{inspect(<<rest::bits>>)}"
    end
  end

  def message(%{data: data}) do
    "unsupported value: #{inspect(data)}"
  end

  defp escape(token) do
    {value, _} = Identifier.escape(<<token::utf8>>, ?\\)
    value
  end
end

defmodule Poison.Parser do
  @moduledoc """
  An RFC 8259 and ECMA 404 conforming JSON parser.

  See: https://datatracker.ietf.org/doc/html/rfc8259
  See: https://ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf
  """

  @compile :inline
  @compile :inline_list_funcs

  import Bitwise

  alias Poison.{Decoder, ParseError}

  @type scalar :: nil | true | false | float | integer | String.t()

  if Code.ensure_loaded?(Decimal) do
    @type t :: scalar | Decimal.t() | [t] | %{optional(String.t()) => t}
  else
    @type t :: scalar | [t] | %{optional(String.t()) => t}
  end

  whitespace = ~c"\s\t\n\r"
  digits = ?0..?9

  defmacrop syntax_error(skip) do
    quote do
      raise ParseError, skip: unquote(skip)
    end
  end

  @spec parse!(iodata, Decoder.options()) :: t
  def parse!(value, options \\ %{})

  def parse!(data, options) when is_bitstring(data) do
    [value | skip] =
      value(data, data, :maps.get(:keys, options, nil), :maps.get(:decimal, options, nil), 0)

    <<_skip::binary-size(skip), rest::bits>> = data
    skip_whitespace(rest, skip, value)
  rescue
    exception in ParseError ->
      reraise ParseError,
              [data: data, skip: exception.skip, value: exception.value],
              __STACKTRACE__
  end

  def parse!(iodata, options) do
    iodata |> IO.iodata_to_binary() |> parse!(options)
  end

  @compile {:inline, value: 5}

  defp value(<<"null", _rest::bits>>, _data, _keys, _decimal, skip) do
    [nil | skip + 4]
  end

  defp value(<<"true", _rest::bits>>, _data, _keys, _decimal, skip) do
    [true | skip + 4]
  end

  defp value(<<"false", _rest::bits>>, _data, _keys, _decimal, skip) do
    [false | skip + 5]
  end

  defp value(<<?-, rest::bits>>, data, _keys, decimal, skip) do
    number_neg(rest, data, decimal, skip + 1)
  end

  defp value(<<?0, rest::bits>>, data, _keys, decimal, skip) do
    number_frac(rest, data, decimal, skip + 1, skip, 1)
  end

  for digit <- ?1..?9 do
    defp value(<<unquote(digit), rest::bits>>, data, _keys, decimal, skip) do
      number_int(rest, data, decimal, skip + 1, skip, 1)
    end
  end

  defp value(<<?", rest::bits>>, data, _keys, _decimal, skip) do
    string_continue(rest, data, skip + 1)
  end

  defp value(<<?[, rest::bits>>, data, keys, decimal, skip) do
    array_values(rest, data, keys, decimal, skip + 1, [])
  end

  defp value(<<?{, rest::bits>>, data, keys, decimal, skip) do
    object_pairs(rest, data, keys, decimal, skip + 1, [])
  end

  for char <- whitespace do
    defp value(<<unquote(char), rest::bits>>, data, keys, decimal, skip) do
      value(rest, data, keys, decimal, skip + 1)
    end
  end

  defp value(_rest, _data, _keys, _decimal, skip) do
    syntax_error(skip)
  end

  ## Objects

  defmacrop object_name(keys, skip, name) do
    quote bind_quoted: [keys: keys, skip: skip, name: name] do
      case keys do
        :atoms! ->
          try do
            String.to_existing_atom(name)
          rescue
            ArgumentError ->
              reraise ParseError, [skip: skip, value: name], __STACKTRACE__
          end

        :atoms ->
          # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
          String.to_atom(name)

        _keys ->
          name
      end
    end
  end

  @compile {:inline, object_pairs: 6}

  defp object_pairs(<<?", rest::bits>>, data, keys, decimal, skip, acc) do
    start = skip + 1
    [name | skip] = string_continue(rest, data, start)
    <<_skip::binary-size(skip), rest::bits>> = data

    [value | skip] = object_value(rest, data, keys, decimal, skip)
    <<_skip::binary-size(skip), rest::bits>> = data

    object_pairs_continue(rest, data, keys, decimal, skip, [
      {object_name(keys, start, name), value} | acc
    ])
  end

  defp object_pairs(<<?}, _rest::bits>>, _data, _keys, _decimal, skip, []) do
    [%{} | skip + 1]
  end

  for char <- whitespace do
    defp object_pairs(<<unquote(char), rest::bits>>, data, keys, decimal, skip, acc) do
      object_pairs(rest, data, keys, decimal, skip + 1, acc)
    end
  end

  defp object_pairs(_rest, _data, _keys, _decimal, skip, _acc) do
    syntax_error(skip)
  end

  @compile {:inline, object_pairs_continue: 6}

  defp object_pairs_continue(<<?,, rest::bits>>, data, keys, decimal, skip, acc) do
    object_pairs(rest, data, keys, decimal, skip + 1, acc)
  end

  defp object_pairs_continue(<<?}, _rest::bits>>, _data, _keys, _decimal, skip, acc) do
    [:maps.from_list(acc) | skip + 1]
  end

  for char <- whitespace do
    defp object_pairs_continue(<<unquote(char), rest::bits>>, data, keys, decimal, skip, acc) do
      object_pairs_continue(rest, data, keys, decimal, skip + 1, acc)
    end
  end

  defp object_pairs_continue(_rest, _data, _keys, _decimal, skip, _acc) do
    syntax_error(skip)
  end

  @compile {:inline, object_value: 5}

  defp object_value(<<?:, rest::bits>>, data, keys, decimal, skip) do
    value(rest, data, keys, decimal, skip + 1)
  end

  for char <- whitespace do
    defp object_value(<<unquote(char), rest::bits>>, data, keys, decimal, skip) do
      object_value(rest, data, keys, decimal, skip + 1)
    end
  end

  defp object_value(_rest, _data, _keys, _decimal, skip) do
    syntax_error(skip)
  end

  ## Arrays

  @compile {:inline, array_values: 6}

  defp array_values(<<?], _rest::bits>>, _data, _keys, _decimal, skip, acc) do
    [acc | skip + 1]
  end

  for char <- whitespace do
    defp array_values(<<unquote(char), rest::bits>>, data, keys, decimal, skip, acc) do
      array_values(rest, data, keys, decimal, skip + 1, acc)
    end
  end

  defp array_values(rest, data, keys, decimal, skip, acc) do
    [value | skip] = value(rest, data, keys, decimal, skip)
    <<_skip::binary-size(skip), rest::bits>> = data
    array_values_continue(rest, data, keys, decimal, skip, [value | acc])
  end

  @compile {:inline, array_values_continue: 6}

  defp array_values_continue(<<?,, rest::bits>>, data, keys, decimal, skip, acc) do
    [value | skip] = value(rest, data, keys, decimal, skip + 1)
    <<_skip::binary-size(skip), rest::bits>> = data
    array_values_continue(rest, data, keys, decimal, skip, [value | acc])
  end

  defp array_values_continue(<<?], _rest::bits>>, _data, _keys, _decimal, skip, acc) do
    [:lists.reverse(acc) | skip + 1]
  end

  for char <- whitespace do
    defp array_values_continue(<<unquote(char), rest::bits>>, data, keys, decimal, skip, acc) do
      array_values_continue(rest, data, keys, decimal, skip + 1, acc)
    end
  end

  defp array_values_continue(_rest, _data, _keys, _decimal, skip, _acc) do
    syntax_error(skip)
  end

  ## Numbers

  # Digits are scanned without accumulating a value: only the positions of
  # the integer, fraction and exponent digit runs are tracked and each slice is
  # converted once at the end. Folding digit by digit into an arbitrary
  # precision integer costs O(n^2) for an n-digit literal, which lets a single
  # long numeric literal pin a scheduler.
  #
  # Integers (and the coefficient and exponent of a Decimal) still have to be
  # converted into an arbitrary precision integer, so their digit count is
  # limited (default 1024 digits). Floats are never limited.
  @integer_digit_limit Application.compile_env(
                         :poison,
                         :decoding_integer_digit_limit,
                         1024
                       )

  @compile {:inline, number_neg: 4}

  defp number_neg(<<?0, rest::bits>>, data, decimal, skip) do
    number_frac(rest, data, decimal, skip + 1, skip, -1)
  end

  for char <- ?1..?9 do
    defp number_neg(<<unquote(char), rest::bits>>, data, decimal, skip) do
      number_int(rest, data, decimal, skip + 1, skip, -1)
    end
  end

  defp number_neg(_rest, _data, _decimal, skip) do
    syntax_error(skip)
  end

  @compile {:inline, number_int: 6}

  for char <- digits do
    defp number_int(<<unquote(char), rest::bits>>, data, decimal, skip, start, sign) do
      number_int(rest, data, decimal, skip + 1, start, sign)
    end
  end

  defp number_int(rest, data, decimal, skip, start, sign) do
    number_frac(rest, data, decimal, skip, start, sign)
  end

  @compile {:inline, number_frac: 6}

  defp number_frac(<<?., rest::bits>>, data, decimal, skip, start, sign) do
    number_frac_continue(rest, data, decimal, skip + 1, start, sign, skip - start)
  end

  defp number_frac(rest, data, decimal, skip, start, sign) do
    number_exp(rest, data, decimal, skip, start, sign, skip - start, 0)
  end

  @compile {:inline, number_frac_continue: 7}

  for char <- digits do
    defp number_frac_continue(
           <<unquote(char), rest::bits>>,
           data,
           decimal,
           skip,
           start,
           sign,
           int_len
         ) do
      number_frac_continue(rest, data, decimal, skip + 1, start, sign, int_len)
    end
  end

  defp number_frac_continue(rest, data, decimal, skip, start, sign, int_len) do
    case skip - (start + int_len + 1) do
      0 -> syntax_error(skip)
      frac_len -> number_exp(rest, data, decimal, skip, start, sign, int_len, frac_len)
    end
  end

  @compile {:inline, number_exp: 8}

  for e <- ~c(eE) do
    defp number_exp(
           <<unquote(e), rest::bits>>,
           data,
           decimal,
           skip,
           start,
           sign,
           int_len,
           frac_len
         ) do
      [exp | skip] = number_exp_continue(rest, data, skip + 1)
      number_complete(data, decimal, skip, start, sign, int_len, frac_len, exp)
    end
  end

  defp number_exp(_rest, data, decimal, skip, start, sign, int_len, frac_len) do
    number_complete(data, decimal, skip, start, sign, int_len, frac_len, 0)
  end

  @compile {:inline, number_exp_continue: 3}

  defp number_exp_continue(<<?-, rest::bits>>, data, skip) do
    case number_exp_digits(rest, data, skip + 1) do
      [exp | skip] when is_integer(exp) -> [-exp | skip]
      overflow -> overflow
    end
  end

  defp number_exp_continue(<<?+, rest::bits>>, data, skip) do
    number_exp_digits(rest, data, skip + 1)
  end

  defp number_exp_continue(rest, data, skip) do
    number_exp_digits(rest, data, skip)
  end

  @compile {:inline, number_exp_digits: 3}

  for char <- digits do
    defp number_exp_digits(<<unquote(char), rest::bits>>, data, skip) do
      number_exp_digits_continue(rest, data, skip + 1, skip)
    end
  end

  defp number_exp_digits(_rest, _data, skip) do
    syntax_error(skip)
  end

  @compile {:inline, number_exp_digits_continue: 4}

  for char <- digits do
    defp number_exp_digits_continue(<<unquote(char), rest::bits>>, data, skip, start) do
      number_exp_digits_continue(rest, data, skip + 1, start)
    end
  end

  # An exponent with more digits than the limit is never turned into an
  # integer: the literal can only be a float (handled by the float conversion
  # below, which works on the digits directly) or an error.
  defp number_exp_digits_continue(_rest, _data, skip, start)
       when skip - start > @integer_digit_limit do
    [:overflow | skip]
  end

  defp number_exp_digits_continue(_rest, data, skip, start) do
    [:erlang.binary_to_integer(binary_part(data, start, skip - start)) | skip]
  end

  @compile {:inline, number_complete: 8}

  @spec number_complete(
          binary,
          term,
          non_neg_integer,
          non_neg_integer,
          1 | -1,
          non_neg_integer,
          non_neg_integer,
          integer | :overflow
        ) :: nonempty_improper_list(t, non_neg_integer)

  if Code.ensure_loaded?(Decimal) do
    defp number_complete(data, true, skip, start, sign, int_len, frac_len, exp)
         when is_integer(exp) do
      coef = number_coef(data, skip, start, sign, int_len, frac_len)
      [%Decimal{sign: sign, coef: coef, exp: exp - frac_len} | skip]
    end

    defp number_complete(data, true, skip, start, sign, _int_len, _frac_len, :overflow) do
      number_error(data, skip, start, sign)
    end
  else
    defp number_complete(_data, true, _skip, _start, _sign, _int_len, _frac_len, _exp) do
      raise Poison.MissingDependencyError, name: "Decimal"
    end
  end

  # The exponent cancels out the fraction (or there is neither), so the
  # literal is an integer.
  defp number_complete(data, _decimal, skip, start, sign, int_len, frac_len, exp)
       when exp === frac_len do
    [number_coef(data, skip, start, sign, int_len, frac_len) * sign | skip]
  end

  max_sig = 1 <<< 53

  # See: https://arxiv.org/pdf/2101.11408.pdf
  # With at most 16 digits the coefficient may still fit in 53 bits.
  defp number_complete(data, _decimal, skip, start, sign, int_len, frac_len, exp)
       when is_integer(exp) and int_len + frac_len <= 16 and exp - frac_len >= -22 and
              exp - frac_len <= 22 do
    coef = number_coef(data, skip, start, sign, int_len, frac_len)
    number_fast_float(data, skip, start, sign, int_len, frac_len, coef, exp - frac_len)
  end

  defp number_complete(data, _decimal, skip, start, sign, int_len, frac_len, _exp) do
    number_float(data, skip, start, sign, int_len, frac_len)
  end

  @compile {:inline, number_fast_float: 8}

  defp number_fast_float(_data, skip, _start, sign, _int_len, _frac_len, coef, exp)
       when coef <= unquote(max_sig) do
    if exp < 0 do
      [coef / pow10(-exp) * sign | skip]
    else
      [coef * pow10(exp) * sign | skip]
    end
  end

  defp number_fast_float(data, skip, start, sign, int_len, frac_len, _coef, _exp) do
    number_float(data, skip, start, sign, int_len, frac_len)
  end

  @compile {:inline, number_coef: 6}

  defp number_coef(data, skip, start, sign, int_len, frac_len)
       when int_len + frac_len > @integer_digit_limit do
    number_error(data, skip, start, sign)
  end

  defp number_coef(data, _skip, start, _sign, int_len, 0) do
    :erlang.binary_to_integer(binary_part(data, start, int_len))
  end

  defp number_coef(data, _skip, start, _sign, int_len, frac_len) do
    :erlang.binary_to_integer(
      <<binary_part(data, start, int_len)::bits,
        binary_part(data, start + int_len + 1, frac_len)::bits>>
    )
  end

  @compile {:inline, number_float: 6}

  # :erlang.binary_to_float/1 requires a fraction, so "1e5" becomes "1.0e5".
  defp number_float(data, skip, start, sign, int_len, 0) do
    int_end = start + int_len

    number_float(
      <<binary_part(data, start, int_len)::bits, ".0",
        binary_part(data, int_end, skip - int_end)::bits>>,
      data,
      skip,
      start,
      sign
    )
  end

  defp number_float(data, skip, start, sign, _int_len, _frac_len) do
    number_float(binary_part(data, start, skip - start), data, skip, start, sign)
  end

  @compile {:inline, number_float: 5}

  defp number_float(string, data, skip, start, sign) do
    [:erlang.binary_to_float(string) * sign | skip]
  rescue
    ArgumentError ->
      number_error(data, skip, start, sign)
  end

  @compile {:inline, number_error: 4}

  @spec number_error(binary, non_neg_integer, non_neg_integer, 1 | -1) :: no_return
  defp number_error(data, skip, start, sign) do
    start = if sign < 0, do: start - 1, else: start
    raise ParseError, skip: start, value: binary_part(data, start, skip - start)
  end

  @compile {:inline, pow10: 1}

  for n <- 1..10 do
    defp pow10(unquote(n)), do: unquote(:math.pow(10, n))
  end

  defp pow10(n), do: 1.0e10 * pow10(n - 10)

  ## Strings

  defmacrop string_codepoint_size(codepoint) do
    quote bind_quoted: [codepoint: codepoint] do
      cond do
        codepoint <= 0x7FF -> 2
        codepoint <= 0xFFFF -> 3
        true -> 4
      end
    end
  end

  @compile {:inline, string_continue: 3}

  defp string_continue(<<?", _rest::bits>>, _data, skip) do
    ["" | skip + 1]
  end

  defp string_continue(rest, data, skip) do
    string_continue(rest, data, skip, false, 0, [])
  end

  @compile {:inline, string_continue: 6}

  defp string_continue(<<?", _rest::bits>>, data, skip, unicode, len, acc) do
    cond do
      acc == [] ->
        if len > 0 do
          [binary_part(data, skip, len) | skip + len + 1]
        else
          ["" | skip + 1]
        end

      unicode ->
        case :unicode.characters_to_binary([acc | binary_part(data, skip, len)], :utf8) do
          string when is_binary(string) ->
            [string | skip + len + 1]

          _other ->
            syntax_error(skip + len)
        end

      true ->
        [IO.iodata_to_binary([acc | binary_part(data, skip, len)]) | skip + len + 1]
    end
  end

  defp string_continue(<<?\\, rest::bits>>, data, skip, unicode, len, acc) do
    string_escape(rest, data, skip + len + 1, unicode, [acc | binary_part(data, skip, len)])
  end

  defp string_continue(<<char, rest::bits>>, data, skip, unicode, len, acc) when char >= 0x20 do
    string_continue(rest, data, skip, unicode, len + 1, acc)
  end

  defp string_continue(<<codepoint::utf8, rest::bits>>, data, skip, _unicode, len, acc)
       when codepoint > 0x80 do
    string_continue(rest, data, skip, true, len + string_codepoint_size(codepoint), acc)
  end

  defp string_continue(_other, _data, skip, _unicode, len, _acc) do
    syntax_error(skip + len)
  end

  @compile {:inline, string_escape: 5}

  defp string_escape(<<?u, rest::bits>>, data, skip, _unicode, acc) do
    string_escape_unicode(rest, data, skip, acc)
  end

  for {seq, char} <- Enum.zip(~C("\ntr/fb), ~c("\\\n\t\r/\f\b)) do
    defp string_escape(<<unquote(seq), rest::bits>>, data, skip, unicode, acc) do
      string_continue(rest, data, skip + 1, unicode, 0, [acc | [unquote(char)]])
    end
  end

  defp string_escape(_rest, _data, skip, _unicode, _acc), do: syntax_error(skip)

  # https://www.ietf.org/rfc/rfc2781.txt
  # https://perldoc.perl.org/Encode::Unicode#Surrogate-Pairs
  # https://mathiasbynens.be/notes/javascript-encoding#surrogate-pairs
  defguardp is_hi_surrogate(cp) when cp in 0xD800..0xDBFF
  defguardp is_lo_surrogate(cp) when cp in 0xDC00..0xDFFF

  defmacrop get_codepoint(seq, skip) do
    quote bind_quoted: [seq: seq, skip: skip] do
      try do
        String.to_integer(seq, 16)
      rescue
        ArgumentError ->
          reraise ParseError, [skip: skip, value: "\\u#{seq}"], __STACKTRACE__
      end
    end
  end

  @compile {:inline, string_escape_unicode: 4}

  defp string_escape_unicode(<<seq1::binary-size(4), rest::bits>>, data, skip, acc) do
    case get_codepoint(seq1, skip) do
      hi when is_hi_surrogate(hi) ->
        string_escape_surrogate_pair(rest, data, skip, acc, seq1, hi)

      lo when is_lo_surrogate(lo) ->
        raise ParseError, skip: skip, value: "\\u#{seq1}"

      codepoint ->
        string_continue(rest, data, skip + 5, true, 0, [acc | [codepoint]])
    end
  end

  defp string_escape_unicode(_rest, _data, skip, _acc), do: syntax_error(skip + 1)

  @compile {:inline, string_escape_surrogate_pair: 6}

  defp string_escape_surrogate_pair(
         <<"\\u", seq2::binary-size(4), rest::bits>>,
         data,
         skip,
         acc,
         seq1,
         hi
       ) do
    case get_codepoint(seq2, skip + 6) do
      lo when is_lo_surrogate(lo) ->
        codepoint = 0x10000 + ((hi &&& 0x03FF) <<< 10) + (lo &&& 0x03FF)
        string_continue(rest, data, skip + 11, true, 0, [acc | [codepoint]])

      _other ->
        raise ParseError, skip: skip, value: "\\u#{seq1}\\u#{seq2}"
    end
  end

  defp string_escape_surrogate_pair(_rest, _data, skip, _acc, seq1, _hi) do
    raise ParseError, skip: skip, value: "\\u#{seq1}"
  end

  ## Whitespace

  @compile {:inline, skip_whitespace: 3}

  defp skip_whitespace(<<>>, _skip, value) do
    value
  end

  for char <- whitespace do
    defp skip_whitespace(<<unquote(char), rest::bits>>, skip, value) do
      skip_whitespace(rest, skip + 1, value)
    end
  end

  defp skip_whitespace(_rest, skip, _value) do
    syntax_error(skip)
  end
end
