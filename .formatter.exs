# Used by "mix format"
[
  import_deps: [:stream_data],
  inputs: [
    "{.credo,.dialyzer_ignore,.formatter,mix}.exs",
    "{config,bench,lib,profile,test}/**/*.{ex,exs}"
  ]
]
