%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["config/", "lib/", "test/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      checks: [
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 11},
        {Credo.Check.Refactor.Nesting, max_nesting: 6},
        {Credo.Check.Readability.WithSingleClause, false}
      ]
    }
  ]
}
