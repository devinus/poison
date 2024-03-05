# Poison Changelog

## v6.0.0

### Features

* Support Erlang 27 and Elixir 1.17
    [#214](https://github.com/devinus/poison/issues/214)
    [#222](https://github.com/devinus/poison/issues/222)
* Reintroduce `Poison.encode_to_iodata!/1` for Phoenix compatibility
    [#172](https://github.com/devinus/poison/issues/172)
    [#206](https://github.com/devinus/poison/pull/206)
* Make [`:html_safe`](`t:Poison.Encoder.escape/0`) encode option follow OWASP
  recommended HTML escaping
    [#194](https://github.com/devinus/poison/issues/194)
* Add `Date.Range` encoding
* Allow [`:as`](`t:Poison.Decoder.as/0`) decode option to be a function
    [#207](https://github.com/devinus/poison/pull/207)
* Add a [CHANGELOG](CHANGELOG.md)
    [#105](https://github.com/devinus/poison/issues/105)

### Bug Fixes

* Stop double decoding structs
    [#191](https://github.com/devinus/poison/issues/191)
* Fix various typespecs
    [#199](https://github.com/devinus/poison/issues/199)
* Correctly encode some UTF-8 surrogate pairs
    [#217](https://github.com/devinus/poison/issues/217)

### Performance Improvements

* Significantly improve performance
    ([2024-06-06](https://gist.github.com/devinus/afb351ae45194a6b93b6db9bf2d4c163))

### Breaking Changes

* Remove deprecated `HashSet` encoding
* Minimum supported versions are now Erlang 24 and Elixir 1.12
