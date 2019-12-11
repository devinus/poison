# Used by "mix format"
[
  import_deps: [:stream_data],
  inputs: [
    "{mix,.credo,.formatter}.exs",
    "{config,lib,test,bench,profile}/**/*.{ex,exs}"
  ],
  line_length: 120
]
