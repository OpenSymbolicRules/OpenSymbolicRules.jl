#!/usr/bin/env julia
"""
Report how much of the RUBI integration corpus this package can actually
rewrite, section by section.

The milestone "load the RUBI rules" is a single checkbox and says nothing about
what happens when a rule fires. This script turns it into a number that moves:
for every test problem in the `Integration` repository it applies the rule set
to the integrand and classifies the outcome, never claiming a closed form it
did not reach.

    julia --project scripts/rubi_conformance.jl [options]

      --integration PATH   the Integration checkout (default: ../Integration)
      --section PREFIX     restrict to sections starting with PREFIX (default: 1.1.1)
      --all                every section; slow, several minutes
      --limit N            at most N test problems per file
      --json PATH          write the per-section report as JSON
      --neq READING        how NeQ answers an undecided inequality:
                           proved_distinct (default) or not_proved_equal,
                           the reading RUBI's own rules assume
      --verbose            print each unresolved or failing problem

Outcomes, deliberately distinguished rather than collapsed into pass/fail:

  verified     the rewrite reached the antiderivative the corpus records,
               compared structurally after folding closed arithmetic. Neither
               side is put in a canonical form, so this is a lower bound
  resolved     the rewrite reached a form with no integral left, but not the
               recorded antiderivative. This is coverage, not correctness: the
               conversion drops RUBI's `x_Symbol` restriction, so a rule can
               match an integrand it was never meant to and still produce a
               closed form
  unevaluated  a rewrite happened but an integral remains; the rule set has no
               applicable continuation
  unchanged    no rule fired at all
  error        a rule fired and its result or guard named something this
               package does not implement; the name is reported and ranked
"""

using OpenSymbolicRules
using OpenSymbolicRules: OSRRule
using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments
using JSON

const DEFAULT_INTEGRATION = normpath(joinpath(@__DIR__, "..", "..", "Integration"))

# Heads that mean "this integral was not solved". A result still carrying one
# of them is not an antiderivative, however far the rewrite went.
const UNRESOLVED_HEADS = Set([:Int, :Integral, :Unintegrable, :CannotIntegrate,
                              :Subst, :Dist, :Simp, :ExpandIntegrand,
                              :NormalizeIntegrand, :SimplifyIntegrand])

# Heads `osr_to_expr` normalizes to left-associated binary terms.
const ASSOCIATIVE_HEADS = Set(["Add", "Multiply", "And", "Or"])

struct Outcome
    kind::Symbol
    detail::String
end

function parse_arguments(arguments::Vector{String})
    options = Dict{String,Any}(
        "integration" => DEFAULT_INTEGRATION,
        "section" => "1.1.1",
        "limit" => typemax(Int),
        "json" => nothing,
        "neq" => "proved_distinct",
        "verbose" => false,
    )
    index = 1
    while index <= length(arguments)
        argument = arguments[index]
        if argument == "--all"
            options["section"] = ""
        elseif argument == "--verbose"
            options["verbose"] = true
        elseif argument in ("--integration", "--section", "--limit", "--json", "--neq")
            index == length(arguments) && error("$(argument) requires a value")
            value = arguments[index + 1]
            key = argument[3:end]
            options[key] = key == "limit" ? parse(Int, value) : value
            index += 1
        else
            error("unknown option $(argument)")
        end
        index += 1
    end
    return options
end

"""
    section_files(root, prefix)

Return the rule and test files whose declared section starts with `prefix`,
each paired with that section.
"""
function section_files(root::AbstractString, prefix::AbstractString)
    found = Tuple{String,String}[]
    isdir(root) || return found
    for (directory, _, names) in walkdir(root), name in names
        endswith(name, ".json") && name != "meta.json" || continue
        path = joinpath(directory, name)
        document = JSON.parsefile(path)
        section = get(document, "section", nothing)
        section isa String || continue
        startswith(section, prefix) || continue
        push!(found, (path, section))
    end
    return sort!(found; by = pair -> pair[2])
end

"""
    load_rules(paths)

Compile each rule file in its own top-level expansion.

`@load_osr_profile` expands a whole manifest into one expression, which for the
6257-rule corpus costs minutes and gigabytes; one expansion per file is linear
and lets a file that fails to compile be reported rather than abort the run.
"""
function load_rules(paths::Vector{String})
    declare_free_symbols(paths)
    rules = OSRRule[]
    failures = Dict{String,String}()
    for path in paths
        try
            compiled = Core.eval(Main, Expr(:macrocall, Symbol("@load_osr"),
                                            LineNumberNode(1, Symbol(path)), path))
            append!(rules, compiled)
        catch exception
            failures[path] = first(split(sprint(showerror, exception), "\n"))
        end
    end
    return rules, failures
end

"""
    declare_free_symbols(paths)

Declare, as plain symbols, every name a rule's result or guard mentions that its
pattern never bound.

254 converted RUBI rules name the integration variable `x` this way, because the
conversion drops the `Int[integrand, x_Symbol]` wrapper and with it the binding
of `x`; another hundred name an inert trigonometric head such as `sin`. Without
these the rule raises an undefined-variable error the moment it fires, and the
measurement would report the host's missing vocabulary instead of the rule set's
coverage. Declaring them is instrumentation, not a fix: see `upstream-bugs.md`
and the Integration repository.
"""
function declare_free_symbols(paths::Vector{String})
    free = Set{Symbol}()
    for path in paths
        document = JSON.parsefile(path)
        for rule in get(document, "rules", ())
            bound = OpenSymbolicRules._pattern_bindings(rule["pattern"])
            _free_names!(free, rule["result"], bound)
            for constraint in get(rule, "constraints", ()) 
                _free_names!(free, constraint, bound)
            end
        end
    end
    for name in free
        isdefined(Main, name) && continue
        Core.eval(Main, :(SymbolicUtils.@syms $name))
    end
    return free
end

function _free_names!(free::Set{Symbol}, node, bound; head::Bool = false)
    if node isa String
        # A head is vocabulary the host must implement, not a value: leaving it
        # undeclared is what lets the report name what is missing.
        head && return free
        (occursin('.', node) || endswith(node, "_") || startswith(node, "~")) && return free
        name = Symbol(node)
        name in bound && return free
        all(character -> isletter(character) || isdigit(character), node) || return free
        isuppercase(first(node)) && return free
        push!(free, name)
    elseif node isa AbstractArray
        for (index, element) in enumerate(node)
            _free_names!(free, element, bound; head = index == 1)
        end
    end
    return free
end

"""
    unproved_predicates(paths)

Return, for each constraint predicate no implementation can be found for, the
number of rules whose guard it holds back.

A rule gated by such a predicate is loaded and never fires, so it is invisible
in the outcome counts. Naming these is what turns the report into a work queue.
"""
function unproved_predicates(paths::Vector{String})
    counts = Dict{String,Int}()
    for path in paths
        for rule in get(JSON.parsefile(path), "rules", ())
            seen = Set{String}()
            for constraint in get(rule, "constraints", ())
                _unproved_names!(seen, constraint)
            end
            for name in seen
                counts[name] = get(counts, name, 0) + 1
            end
        end
    end
    return counts
end

const CONSTRAINT_COMBINATORS = ("Not", "And", "Or", "If")

function _unproved_names!(seen::Set{String}, constraint)
    constraint isa AbstractArray && !isempty(constraint) || return seen
    name = first(constraint)
    name isa String || return seen
    if name in CONSTRAINT_COMBINATORS
        for operand in constraint[2:end]
            _unproved_names!(seen, operand)
        end
        return seen
    end
    OpenSymbolicRules._predicate_callee(name, Main) === nothing && push!(seen, name)
    return seen
end

"""
    unresolved_heads(expression)

Return the heads of `expression` that mean the integral was not solved, or that
this package leaves uninterpreted.
"""
function unresolved_heads(expression)
    found = Set{Symbol}()
    _unresolved_heads!(found, expression)
    return found
end

function _unresolved_heads!(found::Set{Symbol}, expression)
    iscall(expression) || return found
    head = operation(expression)
    head isa Symbol && head in UNRESOLVED_HEADS && push!(found, head)
    if !(head isa Symbol) && nameof(head) isa Symbol && nameof(head) in UNRESOLVED_HEADS
        push!(found, nameof(head))
    end
    for argument in arguments(expression)
        _unresolved_heads!(found, argument)
    end
    return found
end

"""
    integrate(problem, rewriter; depth=6)

Apply the rule set to `problem`, an `Int(integrand, variable)` application, and
return the antiderivative it reached.

A RUBI rule rewrites a whole integral into an antiderivative, so the rule set is
applied at the root and never walked bottom-up over subterms. Nor is the result
fed back in — an antiderivative is not another integral, and re-applying the
rules to one produces nonsense. What does continue is an `Int` the result itself
contains: a rule that reduces one integral to another leaves the remaining
integral explicit, and that is what recursion follows.
"""
function integrate(problem, rewriter; depth::Int = 6)
    rewritten = apply_rules(problem, rewriter)
    (rewritten === nothing || isequal(rewritten, problem)) && return problem
    depth <= 0 && return rewritten
    return _integrate_subintegrals(rewritten, rewriter, depth - 1)
end

_head_name(head) = head isa Symbol ? head : nameof(head)

function _integrate_subintegrals(expression, rewriter, depth)
    iscall(expression) || return expression
    head = operation(expression)
    operands = arguments(expression)
    if _head_name(head) === :Int && length(operands) == 2
        # A rule that reduces one integral to another leaves the remaining
        # integral explicit; that is what recursion follows.
        return integrate(expression, rewriter; depth)
    end
    rebuilt = [_integrate_subintegrals(operand, rewriter, depth) for operand in operands]
    if _head_name(head) === :Subst && length(rebuilt) == 3
        substituted = _substitute_when_resolved(rebuilt)
        substituted === nothing || return substituted
    end
    all(isequal.(rebuilt, operands)) && return expression
    return head(rebuilt...)
end

"""
    _substitute_when_resolved(operands)

Carry out a `Subst(u, x, v)` once `u` holds no unevaluated integral, or return
`nothing` while it still does.

RUBI's `Subst` waits for its argument: substituting into an integral that has
not been evaluated would turn `Int(f, x)` into `Int(f[v], v)`, which is a
different integral — the change of variable owes a derivative factor that the
substitution alone does not supply. Once the inner integral has been resolved
there is no integral left to spoil, and the substitution is an ordinary
capture-avoiding one.
"""
function _substitute_when_resolved(operands)
    body, variable, replacement = operands
    OpenSymbolicRules.IntegralFreeQ(body) || return nothing
    name = variable isa SymbolicUtils.BasicSymbolic && SymbolicUtils.issym(variable) ?
           nameof(variable) : return nothing
    return OpenSymbolicRules.osr_substitute(body, name => replacement)
end

"""
    apply_rules(term, dispatch)

Apply the rule set to `term` and return the result of the first rule that fires.

An ordered integration rule set is first-match-wins: the earliest rule whose
guard holds gives the answer, and the rules after it are alternatives for the
same integral rather than further steps. `OSRDispatch` threads a term through
every candidate instead, which is what a simplification profile wants and not
what this is: applying a later alternative to an already-rewritten term
conflates one integration step with the next. Continuing where a rule reduces
one integral to another is the job of the recursion in `integrate`, which
follows the `Int` the result still contains.

Rules are applied one at a time so a failure can be attributed to the rule that
caused it, and through `invokelatest` so heads declared while this script runs
are visible.
"""
function apply_rules(term, dispatch)
    for position in OpenSymbolicRules.candidate_positions(dispatch, term)
        rule = dispatch.rules[position]
        result = try
            Base.invokelatest(rule, term)
        catch exception
            throw(BlockedRule(rule.name, exception))
        end
        result === nothing && continue
        push!(FIRED, rule.name)
        return result
    end
    return term
end

"""
    FIRED

Names of the rules that fired while the current problem was attempted.

Every problem now ends with some rule firing, if only the corpus's last one,
`Int[u_, x_] := CannotIntegrate[u, x]`, which has no constraints. Knowing
whether anything else fired first is what separates a rule set that fails to
start from one that starts and cannot continue.
"""
const FIRED = String[]

"""
    only_gave_up()

Return whether the rules that fired were only the ones that declare defeat.
"""
only_gave_up() = all(name -> any(marker -> occursin(marker, name), GIVING_UP), FIRED)

const GIVING_UP = ("9.3 Miscellaneous integration rules", "9.4 Miscellaneous integration rules")

"""
    _progress_label(withheld, blocked)

Say how far an unsolved problem got, and why it stopped where it did.

A problem that never started splits further. If some predicate decided a guard
against its rule, then a rule's *pattern* did match and its guard declined —
the rule set covers the shape and refuses the instance. If nothing decided
anything, no pattern matched at all and the shape is simply not covered. The
two call for entirely different work, and the counts are already to hand.
"""
function _progress_label(withheld, blocked)
    if !isempty(FIRED) && !only_gave_up()
        return "a rule fired, then it stalled"
    end
    isempty(withheld) && isempty(blocked) &&
        return "never started: no pattern matched"
    isempty(withheld) && return "never started: a guard could not be decided"
    return "never started: a guard was decided against its rule"
end

"""
    BlockedRule

A rule that raised while rewriting, named by its stable OSR identity.

`SymbolicUtils` wraps such a failure in an error that discards the cause (see
`upstream-bugs.md`), so the identity of the rule is what can be reported — and
it is what a reader needs in order to act.
"""
struct BlockedRule <: Exception
    rule::String
    cause::Any
end

"""
    fold_constants(expression)

Evaluate every closed arithmetic subterm of `expression` exactly.

The OSR arithmetic heads are uninterpreted, so a rule that adds one to a matched
exponent leaves `Add(3, 1)` standing. Comparing that against a recorded `4` would
report every correct antiderivative as wrong. Folding is exact and introduces no
floating-point value.
"""
function fold_constants(expression)
    value = OpenSymbolicRules.osr_number(expression)
    value === nothing || return value
    iscall(expression) || return expression
    head = operation(expression)
    operands = arguments(expression)
    folded = [fold_constants(operand) for operand in operands]
    all(isequal.(folded, operands)) && return expression
    return head(folded...)
end

"""
    classify(problem, rewriter, rules, expected)

Say what the rule set reached, distinguishing an antiderivative from a rewrite
that stopped short and from a rewrite that named something unimplemented.
"""
function classify(problem, rewriter, rules, expected)
    OpenSymbolicRules.reset_unproved!()
    OpenSymbolicRules.reset_withheld!()
    empty!(FIRED)
    reached = try
        integrate(problem, rewriter)
    catch exception
        return Outcome(:error, describe_cause(exception, rules))
    end
    isequal(reached, problem) && return Outcome(:unchanged, "")
    remaining = unresolved_heads(reached)
    if isempty(remaining)
        # A closed form is not yet a correct one. Only an exact structural match
        # with the recorded antiderivative is reported as verified, which
        # understates rather than overstates what the rule set achieved.
        expected !== nothing && isequal(fold_constants(reached), fold_constants(expected)) &&
            return Outcome(:verified, "")
        return Outcome(:resolved, "")
    end
    return Outcome(:unevaluated, join(sort!(string.(collect(remaining))), ","))
end

"""
    blocking_predicates()

Return the predicates that abandoned a guard while the last problem was being
attempted.

A problem the rule set leaves unevaluated may be one no rule covers, or one a
rule covers but could not decide. Only the second is unblocked by implementing
a predicate, and this is what separates them.
"""
blocking_predicates() = OpenSymbolicRules.unproved_predicates_seen()

"""
    withholding_predicates()

Return the predicates that decided a guard against its rule while the last
problem was being attempted.
"""
withholding_predicates() = OpenSymbolicRules.withheld_predicates_seen()

"""
    describe_cause(exception)

Name what actually went wrong. `SymbolicUtils` wraps a failure to build a rule's
result in a "Failed to apply rule" error whose message repeats the whole rule,
which buries the one fact worth counting: the head or predicate that is missing.
"""
function describe_cause(exception, rules)
    exception isa BlockedRule && return "rule: " * exception.rule
    # `SymbolicUtils` discards the cause when a rule's result cannot be built
    # (see upstream-bugs.md), so the rule's own OSR identity is what is left to
    # report — and it is what a reader needs in order to act.
    if exception isa SymbolicUtils.RuleRewriteError
        for rule in rules
            rule.rule === exception.rule && return "rule: " * rule.name
        end
        return "rule: " * first(split(sprint(showerror, exception), " on expression"))
    end
    message = first(split(sprint(showerror, exception), "\n"))
    undefined = match(r"`?([A-Za-z_][A-Za-z0-9_!]*)`? not defined", message)
    undefined === nothing || return "undefined: " * undefined.captures[1]
    method = match(r"no method matching ([A-Za-z_][A-Za-z0-9_!]*)", message)
    method === nothing || return "no method: " * method.captures[1]
    return message
end

"""
    head_function(name)

Resolve an OSR head the way the loader does: the caller's binding when it can
act as an operation, and the package's uninterpreted-head registry otherwise.
A test problem has to be built with the same heads its rules were compiled
against, or no pattern can match it.
"""
function head_function(name::AbstractString)
    symbol = Symbol(name)
    if isdefined(Main, symbol)
        value = getfield(Main, symbol)
        value isa Type || return value
    end
    return getfield(OpenSymbolicRules.UninterpretedHeads, symbol)
end

"""
    build_term(node, symbols)

Build a `SymbolicUtils` term from an OSR expression, creating a symbol for each
name it mentions. Only the test corpus is read this way; a rule always goes
through `@load_osr`.
"""
function build_term(node, symbols::Dict{String,Any})
    node === nothing && return nothing
    if node isa String
        return get!(symbols, node) do
            # `@syms` is the supported way to make a symbolic variable; building
            # the underlying type directly depends on SymbolicUtils internals.
            first(Core.eval(Main, :(SymbolicUtils.@syms $(Symbol(node)))))
        end
    elseif node isa AbstractArray
        head = first(node)
        head isa String || error("an OSR operator must be a string")
        built = [build_term(argument, symbols) for argument in node[2:end]]
        head == "List" && return built
        operation = head_function(head)
        # The OSR heads are declared binary, and `osr_to_expr` normalizes an
        # n-ary associative expression to left-associated binary terms. A test
        # problem has to be built the same way or it cannot match a pattern.
        if length(built) > 2 && head in ASSOCIATIVE_HEADS
            return reduce((left, right) -> operation(left, right), built)
        end
        return operation(built...)
    end
    return node
end

"""
    prepare(options)

Compile the rule files the run needs.

This is deliberately separate from [`run`](@ref) and called before it, at top
level. Compiling a rule file declares the heads it uses, which changes bindings
in `OpenSymbolicRules.UninterpretedHeads`; code already executing in an older
world age does not see those changes, so measuring from inside the same call
that compiled would read stale bindings.
"""
function prepare(options)
    prefix = options["section"]
    rule_paths = first.(section_files(joinpath(options["integration"], "rules"), prefix))
    isempty(rule_paths) && error("no rule file matches section $(prefix)")
    @info "compiling rules" files = length(rule_paths)
    compile_seconds = @elapsed ((rules, failures) = load_rules(rule_paths))
    @info "compiled" rules = length(rules) failed_files = length(failures) seconds = round(compile_seconds, digits = 1)
    for (path, message) in failures
        @warn "rule file did not compile" file = basename(path) message
    end

    unproved = unproved_predicates(rule_paths)
    if !isempty(unproved)
        held = sum(values(unproved))
        println("Predicates with no implementation, by rules they hold back",
                " (", length(unproved), " predicates, ", held, " rule guards):")
        for (name, count) in first(sort!(collect(unproved); by = pair -> -pair[2]), 15)
            println("  ", lpad(count, 5), "  ", name)
        end
        println()
    end
    return rules
end

function run(options, rules)
    integration = options["integration"]
    prefix = options["section"]

    # Root-only application: see `classify`.
    rewriter = OpenSymbolicRules.OSRDispatch(rules)
    symbols = Dict{String,Any}()

    report = Dict{String,Any}()
    totals = Dict(:verified => 0, :resolved => 0, :unevaluated => 0, :unchanged => 0, :error => 0)
    reasons = Dict{String,Int}()
    # Problems left unsolved, counted against each predicate that could not be
    # decided while trying them; "" counts those no predicate blocked.
    undecided = Dict{String,Int}()
    # Predicates that decided a guard against its rule, per unsolved problem.
    withheld = Dict{String,Int}()
    # How far an unsolved problem got before the rule set ran out.
    progress = Dict{String,Int}()
    # Predicates that turned a matching rule away on a problem nothing fired on.
    refused = Dict{String,Int}()
    OpenSymbolicRules.record_withheld!(true)
    OpenSymbolicRules.neq_reading!(Symbol(options["neq"]))
    @info "NeQ reading" reading = options["neq"]

    for (path, section) in section_files(joinpath(integration, "tests"), prefix)
        document = JSON.parsefile(path)
        counts = Dict(:verified => 0, :resolved => 0, :unevaluated => 0, :unchanged => 0, :error => 0)
        for problem in first(get(document, "tests", []), options["limit"])
            integrand = try
                build_term(problem["expression"], symbols)
            catch exception
                outcome = Outcome(:error, "build: " * first(split(sprint(showerror, exception), "\n")))
                counts[outcome.kind] += 1
                totals[outcome.kind] += 1
                reasons[outcome.detail] = get(reasons, outcome.detail, 0) + 1
                continue
            end
            expected = try
                build_term(get(problem, "expected_result", nothing), symbols)
            catch
                nothing
            end
            variable = build_term(get(problem, "variable", "x"), symbols)
            outcome = classify(head_function("Int")(integrand, variable),
                               rewriter, rules, expected)
            counts[outcome.kind] += 1
            totals[outcome.kind] += 1
            isempty(outcome.detail) ||
                (reasons[outcome.detail] = get(reasons, outcome.detail, 0) + 1)
            if outcome.kind in (:unevaluated, :unchanged)
                label = _progress_label(withholding_predicates(), blocking_predicates())
                progress[label] = get(progress, label, 0) + 1
                # Which predicate turned a matching rule away is only telling
                # for a problem no rule ever fired on: elsewhere a predicate
                # declining is the rule set doing its job.
                if startswith(label, "never started")
                    for name in withholding_predicates()
                        refused[name] = get(refused, name, 0) + 1
                    end
                end
            end
            if outcome.kind in (:unevaluated, :unchanged)
                for name in withholding_predicates()
                    withheld[name] = get(withheld, name, 0) + 1
                end
                blocked = blocking_predicates()
                isempty(blocked) ? (undecided[""] = get(undecided, "", 0) + 1) :
                    for name in blocked
                        undecided[name] = get(undecided, name, 0) + 1
                    end
            end
            if options["verbose"] && outcome.kind != :verified
                println("  ", section, ":", problem["id"], "  ", outcome.kind, "  ", outcome.detail)
            end
        end
        report[section] = Dict(String(key) => value for (key, value) in counts)
        total = sum(values(counts))
        total == 0 && continue
        println(rpad(section, 12), lpad(total, 6), " problems   ",
                lpad(counts[:verified], 5), " verified (",
                lpad(round(100 * counts[:verified] / total, digits = 1), 5), "%)   ",
                lpad(counts[:resolved], 5), " closed form   ",
                lpad(counts[:unevaluated], 5), " unevaluated   ",
                lpad(counts[:unchanged], 5), " unchanged   ",
                lpad(counts[:error], 5), " error")
    end

    total = sum(values(totals))
    println()
    println("TOTAL ", total, " problems: ",
            totals[:verified], " verified, ",
            totals[:resolved], " closed form, ",
            totals[:unevaluated], " unevaluated, ",
            totals[:unchanged], " unchanged, ",
            totals[:error], " error")
    if total > 0
        println("verified:    ", round(100 * totals[:verified] / total, digits = 2), "%")
        println("closed form: ",
                round(100 * (totals[:verified] + totals[:resolved]) / total, digits = 2),
                "%  (coverage, not correctness)")
    end

    if !isempty(reasons)
        println()
        println("What stands in the way, by number of problems:")
        for (reason, count) in first(sort!(collect(reasons); by = pair -> -pair[2]), 20)
            println("  ", lpad(count, 6), "  ", reason)
        end
    end

    if !isempty(undecided)
        covered = sum(count for (name, count) in undecided if !isempty(name); init = 0)
        println()
        println("Unsolved problems where a rule was blocked by an undecidable predicate",
                " (", covered, " of ", get(undecided, "", 0) + covered, "):")
        for (name, count) in first(sort!([pair for pair in undecided if !isempty(pair[1])];
                                         by = pair -> -pair[2]), 15)
            println("  ", lpad(count, 6), "  ", name)
        end
        println("  ", lpad(get(undecided, "", 0), 6), "  (no rule was blocked; none covers the problem)")
    end

    OpenSymbolicRules.record_withheld!(false)
    OpenSymbolicRules.neq_reading!(:proved_distinct)
    if !isempty(refused)
        println()
        println("Predicates that turned a matching rule away on a problem nothing fired on:")
        for (name, count) in first(sort!(collect(refused); by = pair -> -pair[2]), 12)
            println("  ", lpad(count, 6), "  ", name)
        end
    end

    if !isempty(progress)
        println()
        println("How far an unsolved problem got:")
        for (label, count) in sort!(collect(progress); by = pair -> -pair[2])
            println("  ", lpad(count, 6), "  ", label)
        end
    end
    if !isempty(withheld)
        println()
        println("Predicates that decided a guard against its rule, by unsolved problems:")
        for (name, count) in first(sort!(collect(withheld); by = pair -> -pair[2]), 12)
            println("  ", lpad(count, 6), "  ", name)
        end
    end

    if options["json"] !== nothing
        report["totals"] = Dict(String(key) => value for (key, value) in totals)
        report["reasons"] = reasons
        report["undecided"] = undecided
        report["withheld"] = withheld
        report["progress"] = progress
        report["refused"] = refused
        open(options["json"], "w") do handle
            JSON.print(handle, report, 2)
        end
        println("\nwrote ", options["json"])
    end
    return totals
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    const OPTIONS = parse_arguments(ARGS)
    const RULES = prepare(OPTIONS)
    run(OPTIONS, RULES)
end
