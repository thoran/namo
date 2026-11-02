#!/usr/bin/env julia
# dataframes_claims.jl

# 20261101
# 0.0.0

# The Julia/DataFrames.jl snippets in COMPARISON.md, in the document's order, each
# run against small inline data, followed by the probes behind its claims about
# DataFrames.jl.
#
# Each step prints its label and its result, or the exception it raised, so a claim
# that something fails is shown failing.

using DataFrames
using Dates
using RollingFunctions
using Statistics
using Tables

function show_step(label, thunk)
    println("## ", label)
    try
        show(stdout, MIME("text/plain"), thunk())
        println()
    catch e
        println("raises ", sprint(showerror, e))
    end
    println()
end

println("julia ", VERSION, " | DataFrames ", pkgversion(DataFrames), " | RollingFunctions ", pkgversion(RollingFunctions), "\n")

df = DataFrame(
    symbol = ["BHP", "RIO", "BHP", "WES"],
    exchange = ["ASX", "ASX", "ASX", "ASX"],
    quarter = ["Q1", "Q1", "Q2", "Q2"],
    close = [42.5, 118.3, 43.1, 15.0],
    pe = [12.0, missing, 16.0, 9.0],
    volume = [100, 200, 0, 50],
    price = [10.0, 20.0, 11.0, 5.0],
    quantity = [3, 2, 4, 10],
    cost = [20.0, 30.0, 25.0, 40.0],
)


# Ingestion and schema

show_step("Schema-free instantiation", () -> DataFrame(symbol = ["BHP", "RIO"], close = [42.5, 118.3]))
show_step("claim: from a vector of NamedTuples", () -> DataFrame([(symbol = "BHP", close = 42.5), (symbol = "RIO", close = 118.3)]))

show_step("No index", () -> filter(:symbol => ==("BHP"), df))
show_step("No index, another column", () -> filter(:close => ==(42.5), df))


# Selection

show_step("Keyword selection, two columns", () -> filter([:symbol, :quarter] => (s, q) -> s == "BHP" && q == "Q1", df))
show_step("claim: subset takes one condition per column", () -> subset(df, :symbol => ByRow(==("BHP")), :quarter => ByRow(==("Q1"))))
show_step("Array selection", () -> filter(:quarter => q -> q in ["Q1", "Q2"], df))
show_step("Range selection", () -> filter(:close => c -> 10.0 <= c <= 20.0, df))
show_step("Proc selection", () -> filter(:pe => v -> !ismissing(v) && v < 15, df))
show_step("Regex selection", () -> filter(:symbol => s -> occursin(r"^BH", s), df))
show_step("claim: a Regex as a column selector picks columns by name", () -> select(df, r"^c"))

show_step("Mixed selection", () -> filter(
    [:symbol, :close, :pe, :quarter] =>
        (s, c, p, q) -> occursin(r"^BH", s) && 10.0 <= c <= 50.0 &&
            !ismissing(p) && p < 15 && q == "Q1",
    df
))
show_step("claim: df[rows, cols] takes a row mask and columns in one indexing call", () -> df[df.quarter .== "Q1", [:symbol, :close]])


# Projection and contraction

show_step("Projection", () -> select(df, :symbol, :close))
show_step("Contraction", () -> select(df, Not([:symbol, :close])))
show_step("Combined selection and projection", () -> select(filter(:quarter => ==("Q1"), df), :symbol, :close))


# Formulae

show_step("Computed dimension, then a change to price", () -> begin
    d = copy(df)
    d.revenue = d.price .* d.quantity
    d.price[1] = 100.0
    d[:, [:price, :quantity, :revenue]]
end)

show_step("Formula chain", () -> begin
    d = copy(df)
    d.revenue = d.price .* d.quantity
    d.profit = d.revenue .- d.cost
    d.margin = d.profit ./ d.revenue
    d[:, [:revenue, :profit, :margin]]
end)

prices = DataFrame(
    symbol = repeat(["BHP", "RIO"], inner = 60),
    date = repeat(Date(2025, 1, 1) .+ Day.(0:59), 2),
    close = vcat(40.0 .+ (0:59), 110.0 .+ (0:59)),
    volume = repeat(1000 .+ 10 .* (0:59), 2),
)

show_step("claim: combine with rollmean returns n - 19 rows per group, without their dates", () ->
    combine(groupby(prices, :symbol), :close => (x -> rollmean(x, 20)) => :sma_20))
show_step("claim: combine with two windows of different lengths", () -> combine(groupby(prices, :symbol),
    :close => (x -> rollmean(x, 20)) => :sma_close_20,
    :volume => (x -> rollmean(x, 50)) => :sma_volume_50
))

show_step("Two-arity formulae", () ->
    transform(groupby(prices, :symbol), :close => (x -> vcat(fill(missing, 19), rollmean(x, 20))) => :sma_20)[[19, 20, 60], :])

sma(x, n) = vcat(fill(missing, n - 1), rollmean(x, n))
show_step("Parameterised formulae", () -> transform(groupby(prices, :symbol),
    :close => (x -> sma(x, 20)) => :sma_close_20,
    :volume => (x -> sma(x, 50)) => :sma_volume_50
)[[49, 50, 60], :])


# Composition

ohlcv = DataFrame(
    symbol = ["BHP", "BHP", "RIO"], exchange = "ASX",
    date = [Date(2025, 3, 31), Date(2025, 7, 1), Date(2025, 7, 1)], close = [42.5, 44.0, 118.3],
)
fundamentals = DataFrame(
    symbol = ["BHP", "BHP", "RIO"], exchange = "ASX",
    quarter_end = [Date(2024, 12, 31), Date(2025, 6, 30), Date(2025, 6, 30)], pe = [11.0, 12.0, 9.0],
)

show_step("Equi-join", () -> innerjoin(ohlcv, fundamentals, on = [:symbol, :exchange]))
show_step("claim: innerjoin with no on", () -> innerjoin(ohlcv, fundamentals))
show_step("Cartesian product", () -> crossjoin(ohlcv[:, [:symbol, :close]], fundamentals[:, [:pe]]))

combined = crossjoin(ohlcv[:, [:symbol, :close]], fundamentals[:, [:pe]])
show_step("Decomposition", () -> unique(select(combined, Not(names(ohlcv[:, [:symbol, :close]])))))


# Aggregation

show_step("Group-by-aggregate", () -> combine(groupby(df, :symbol), :close => mean))
show_step("claim: groupby takes column names, not expressions", () -> groupby(df, :pe => (p -> p .< 10)))
show_step("Group by a transformed column", () -> combine(groupby(transform(df, :pe => ByRow(p -> !ismissing(p) && p < 10) => :value_score), :value_score), :close => mean))
show_step("claim: the GroupedDataFrame can be held, indexed by key and recombined", () -> begin
    g = groupby(df, :symbol)
    (typeof(g), combine(g, :close => mean), g[("BHP",)], isequal(DataFrame(g), sort(df, :symbol, alg = MergeSort)))
end)


# Set operators

a = DataFrame(x = [1, 2])
b = DataFrame(x = [2, 3])
show_step("Concatenation", () -> vcat(a, b))
show_step("claim: set operations through Sets of rows", () -> begin
    as = Set(copy.(eachrow(a)))
    bs = Set(copy.(eachrow(b)))
    (intersect(as, bs), union(as, bs), setdiff(as, bs), symdiff(as, bs))
end)

today = DataFrame(symbol = ["BHP", "RIO", "WES"])
exclusions = DataFrame(symbol = ["RIO"])
show_step("Keyed anti-join", () -> antijoin(today, exclusions, on = :symbol))


# Type handling

show_step("Type agnosticism", () -> begin
    d = copy(df)
    d.label = d.symbol .* " (" .* d.exchange .* ")"
    d.status = ifelse.(d.volume .> 0, "active", "suspended")
    filter(:status => ==("active"), d)[:, [:label, :status]]
end)


# Enumerable integration

show_step("eachrow", () -> begin
    d = copy(df)
    d.revenue = d.price .* d.quantity
    [typeof(row) for row in eachrow(d)][1], [row.revenue for row in eachrow(d)]
end)
show_step("Filtering returns a DataFrame", () -> typeof(filter(:close => c -> c > 40, df)))
show_step("Sorting", () -> sort(df, :close).close)


# Comparison

c1 = DataFrame(x = [1, 2], y = ["a", "b"])
c2 = c1[[2, 1], :]
show_step("claim: == on DataFrames returns a Bool", () -> (c1 == c2, c1 == copy(c1)))
show_step("isequal, same rows in another order", () -> isequal(c1, c2))
show_step("claim: .== compares element by element", () -> c1 .== c2)

show_step("Subset through Sets of rows, as the document has it", () -> begin
    a = DataFrame(x = [1])
    b = DataFrame(x = [1, 2])
    a_set = Set(eachrow(a))
    b_set = Set(eachrow(b))
    issubset(a_set, b_set)
end)


# Introspection

v = DataFrame(symbol = ["BHP", "RIO", "BHP"], close = [42.5, 118.3, 43.1])
show_step("Dimensions", () -> names(v))
show_step("Coordinates", () -> unique(v.symbol))
show_step("Values", () -> v.symbol)
show_step("Dict built by hand", () -> Dict(name => v[!, name] for name in names(v)))
show_step("claim: Tables.columntable", () -> Tables.columntable(v))
show_step("claim: pairs(eachcol(df))", () -> Dict(pairs(eachcol(v))))


# What Namo doesn't have

show_step("Reshaping", () -> (stack(v, :close), unstack(stack(v, :close; variable_name = :k), :k, :value; combine = first)))
show_step("Missing values", () -> (dropmissing(df), coalesce.(df.pe, 0.0), ismissing.(df.pe)))
show_step("Column-level operations", () -> (mean(df.close), std(df.close)))
show_step("claim: DataFrames.jl exports no reader", () -> filter(n -> occursin("read", lowercase(string(n))), names(DataFrames)))
