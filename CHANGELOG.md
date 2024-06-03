<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Changelog](#changelog)
  - [master](#master)
  - [v3.1.0](#v310)
    - [Enhancements](#enhancements)
    - [Bug Fixes](#bug-fixes)
  - [v3.0.0](#v300)
    - [Enhancements](#enhancements-1)
    - [Bug Fixes](#bug-fixes-1)
    - [Incompatible Changes](#incompatible-changes)
  - [v2.2.0](#v220)
    - [Enhancements](#enhancements-2)
    - [Bug Fixes](#bug-fixes-2)
  - [v2.1.0](#v210)
    - [Enhancements](#enhancements-3)
    - [Bug Fixes](#bug-fixes-3)
  - [v2.0.1](#v201)
    - [Bug Fixes](#bug-fixes-4)
  - [v2.0.0](#v200)
    - [Enhancements](#enhancements-4)
    - [Incompatible Changes](#incompatible-changes-1)
  - [v1.5.2](#v152)
    - [Bug Fixes](#bug-fixes-5)
  - [v1.5.1](#v151)
    - [Bug Fixes](#bug-fixes-6)
  - [v1.5.0](#v150)
    - [Enhancements](#enhancements-5)
    - [Bug Fixes](#bug-fixes-7)
  - [v1.4.0](#v140)
    - [Enhancements](#enhancements-6)
    - [Bug Fixes](#bug-fixes-8)
  - [v1.3.1](#v131)
    - [Bug Fixes](#bug-fixes-9)
  - [v1.3.0](#v130)
    - [Enhancements](#enhancements-7)
  - [v1.2.1](#v121)
    - [Enhancements](#enhancements-8)
    - [Bug Fixes](#bug-fixes-10)
  - [v1.1.1](#v111)
  - [v1.1.0](#v110)
  - [v1.0.3](#v103)
  - [v1.0.2](#v102)
    - [Bug Fixes](#bug-fixes-11)
  - [v1.0.1](#v101)
  - [v1.0.0](#v100)
    - [Enhancements](#enhancements-9)
    - [Bug Fixes](#bug-fixes-12)
    - [Incompatible Changes](#incompatible-changes-2)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Changelog

## master
* [#118](https://github.com/devinus/poison/pull/118) - [@KronicDeth](https://github.com/KronicDeth)
  * Add `CHANGELOG.md`
  * Add `UPGRADING.md`

## v3.1.0

### Enhancements
* [#110](https://github.com/devinus/poison/pull/110) - Update `.travis.yml` to include Elixir `1.4.0` - [@Ch4s3](https://github.com/Ch4s3)
* [bf2923d](https://github.com/devinus/poison/commit/bf2923d3ea16ecf626c29e163c79dd973f0ec609) - Use `String.Chars` protocol to encode keys - [@devinus](https://github.com/devinus)

### Bug Fixes
* [#111](https://github.com/devinus/poison/pull/111) - Refactor pipes to start with raw value - [@Ch4s3](https://github.com/Ch4s3)

## v3.0.0

### Enhancements
* [#96](https://github.com/devinus/poison/pull/96) - Fail when a map has matching keys that are a combination of atoms and strings and `strict_keys: true` is passed to `encode` - [@BennyHallett](https://github.com/BennyHallett)
* [#97](https://github.com/devinus/poison/pull/97) - `escape: :html_safe` `encode` option to prevent XSS - [@binaryseed](https://github.com/binaryseed)
* [#100](https://github.com/devinus/poison/pull/100) - Store parser failure position in `Poison.SyntaxError` `pos` - [@devinus](https://github.com/devinus)

### Bug Fixes
* [#82](https://github.com/devinus/poison/pull/82) - Add license title to `LICENSE` - [@waldyrious](https://github.com/waldyrious)
* [#87](https://github.com/devinus/poison/pull/87) - Bump version number in README - [@optikfluffel](https://github.com/optikfluffel)
* [#93](https://github.com/devinus/poison/pull/93) - Fix nested struct decoding when using default struct values with `as:` - [@rschmukler](https://github.com/rschmukler)
* [#95](https://github.com/devinus/poison/pull/95) - Default values in structs when encoded map has atom keys - [@BennyHallett](https://github.com/BennyHallett)

### Incompatible Changes
* [9d0e046](https://github.com/devinus/poison/commit/9d0e0465b40b6e4bdb6cd4224dfedb5f4e1482e4) - Change license from [ISC](https://opensource.org/licenses/ISC) to [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/) - [@devinus](https://github.com/devinus)
* [#100](https://github.com/devinus/poison/pull/100) - [@devinus](https://github.com/devinus)
  * `Poison.SyntaxError` `message` format has changed to include parser position on failures
  * The return type of `Poison.Parser.parse/1,2` has changed to include the position of the failure

## v2.2.0

### Enhancements
* [#78](https://github.com/devinus/poison/pull/78) - Add support for Elixir v1.3 `Calendar` data types - [@josevalim](https://github.com/josevalim)

### Bug Fixes
* [#80](https://github.com/devinus/poison/pull/80) - Fix Elixir 1.4 warnings - [@whatyouhide](https://github.com/whatyouhide)

## v2.1.0

### Enhancements
* [#63](https://github.com/devinus/poison/pull/63) - [@lucidstack](https://github.com/lucidstack)
  * Add the :except option to the `@derive` clause in `Poison.Encoder`. The main reason behind this addition is easiness of usage with `Ecto`. I've seen quite some people complain about the fact that the `__meta__` attribute in `Ecto` models is messing up with `Poison`, and as of now, the only solution seems to `:only` the needed fields (often all of them but `__meta__`) in the `@derive` attribute before `Ecto` schema definitions.

   Having an `:except` option, while seeming a natural counterpart for the already present `:only`, would make tackling that problem simpler, and definitely DRY'er. 😀

   I've also added a little sub-section in the `README.md` file, just to make the whole only/except thing clearer!

### Bug Fixes
* [#65](https://github.com/devinus/poison/pull/65) - Fix documentation for nested decoding - [@alakra](https://github.com/alakra)
* [#67](https://github.com/devinus/poison/pull/67) - Update `README` with 1.x information, so that users stuck on `1.X` know to look for differences in `:as` behavior - [@ono](https://github.com/ono)

## v2.0.1

### Bug Fixes
* [#59](https://github.com/devinus/poison/pull/59) - Update Installation instructions to reflect `2.0.0` release - [@Aesthetikx](https://github.com/Aesthetikx)
* [#61](https://github.com/devinus/poison/pull/61) - Fix bug in nested struct decoding - [@stevedomin](https://github.com/stevedomin)

## v2.0.0

### Enhancements
* [#58](https://github.com/devinus/poison/pull/58) - Nested structs - [@devinus](https://github.com/devinus)

### Incompatible Changes
* [#58](https://github.com/devinus/poison/pull/58) - `:as` option to `Poison.decode(!)/2` now takes a struct (`%Person{}`) instead of the name of the module defining the struct (`Person`) - [@devinus](https://github.com/devinus)

## v1.5.2

### Bug Fixes
* [110cea1](https://github.com/devinus/poison/commit/110cea1ae13969924d84eed235dd2c12a8605a3c) - Escape `U+001F` - [@devinus](https://github.com/devinus)

## v1.5.1

### Bug Fixes
* [#47](https://github.com/devinus/poison/pull/47) - Remove "Experimental" from package description - [@sunaku](https://github.com/sunaku)
* [#52](https://github.com/devinus/poison/pull/52) - Fix `defimpl` example in `README`, so that `Poison.Encoder.BitString.encode` is shown with correct arity of `2` - [@jisaacstone](https://github.com/jisaacstone)
* [#54](https://github.com/devinus/poison/pull/54) - Fix Elixir 1.2 warning - [@tuvistavie](https://github.com/tuvistavie)

## v1.5.0

### Enhancements
* [#37](https://github.com/devinus/poison/pull/37) - Add Installation instructions - [@nettofarah](https://github.com/nettofarah)
* [#40](https://github.com/devinus/poison/pull/40) - Derivable `Poison.Encoder` - [@devinus](https://github.com/devinus)

### Bug Fixes
* [#36](https://github.com/devinus/poison/pull/36) - Fix "Posion" typoes in test modules - [@mitchellhenke](https://github.com/mitchellhenke)

## v1.4.0

### Enhancements
* [#26](https://github.com/devinus/poison/pull/26) - Use travis' elixir support and test multiple versions - [@optikfluffel](https://github.com/optikfluffel)

### Bug Fixes
* [#28](https://github.com/devinus/poison/pull/28) - Document that `keys: :atom` can lead to atom exhaustion - [@cmpitg](https://github.com/cmpitg)
* [#29](https://github.com/devinus/poison/pull/29) - [@jtmoulia](https://github.com/jtmoulia)
  * Fixes `Poison.Decode.transform_struct/4` to only set the keys included in the value which is being decoded. This allows a struct to be created with the default values for missing keys, rather than setting all missing keys to `nil`.

## v1.3.1

### Bug Fixes
* [#20](https://github.com/devinus/poison/pull/20) - Use `async: true` in tests - [@josevalim](https://github.com/josevalim)
* [#23](https://github.com/devinus/poison/pull/23) - [@Frost](https://github.com/Frost)
  * Poison currently requires Elixir version `~> 1.0.0`, which means it will give a warning message when running on any later minor version than `1.0.x`.

    Since Elixir will follow semantic versioning, as stated in the [v1.0.0 release post](http://elixir-lang.org/blog/2014/09/18/elixir-v1-0-0-released/), it can be relaxed to `~> 1.0` instead.

## v1.3.0

### Enhancements
* [#19](https://github.com/devinus/poison/pull/19) - Add `Poison.encode_to_iodata(!)/2` - [@josevalim](https://github.com/josevalim)

## v1.2.1

### Enhancements
* [#16](https://github.com/devinus/poison/pull/16) - Update `mix.lock` for new `hex` version - [@asaaki](https://github.com/asaaki)

### Bug Fixes
* [#15](https://github.com/devinus/poison/pull/15) - Change GitTip badge to Gratipay badge - [@igas](https://github.com/igas)
* [#16](https://github.com/devinus/poison/pull/16) - [@asaaki](https://github.com/asaaki)
  * Fix dialyzer warning for unknown type `Map.t/0`
  * Remove unnecessary whitespace

## v1.1.1

## v1.1.0

## v1.0.3

## v1.0.2

### Bug Fixes
* [#5](https://github.com/devinus/poison/pull/5) - Fix Github URL - [@niku](https://github.com/niku)
* [#8](https://github.com/devinus/poison/pull/8) - Add `VERSION` file to hex package - [@MSch](https://github.com/MSch)

## v1.0.1

## v1.0.0

### Enhancements
* [#1](https://github.com/devinus/poison/pull/1) - Accept iodata - [@fishcakez](https://github.com/fishcakez)

### Bug Fixes
* [#2](https://github.com/devinus/poison/pull/2) - [@fishcakez](https://github.com/fishcakez)
  * `Poison.encode/2` currently rescues all exceptions. This means that it can catch "code bugs" when we only want it to catch "data bugs". Therefore it should only rescue encode errors.

    The situation was also awkward because the errors returned could not easily be pattern matched on because the error information was a string. Including a string in this way is only useful if the string is going to be displayed to an end-user. It is likely that a custom error would be shown - that did not include the string in the error tuple. The errors now return a usable type that can be pattern matched on if required.

    I have made the error returns consistent.

### Incompatible Changes
* [#1](https://github.com/devinus/poison/pull/1) - Return iodata - [@fishcakez](https://github.com/fishcakez)
* [#2](https://github.com/devinus/poison/pull/2) - [@fishcakez](https://github.com/fishcakez)
  * Slightly different return for `Poison.decode/2`. I did this because it is awkward to have an error tuple that can be contain 2 or 3 elements.



