# OpenSymbolicRules.jl - Development Roadmap

**Vision:** To evolve `OpenSymbolicRules.jl` from a simple rule-parser into a fully-fledged, general-purpose Computer Algebra System (CAS) in Julia. It will serve as the premier execution engine for the universal OpenSymbolicRules standard, bringing the power of 6000+ RUBI integration rules, algebraic simplifications, and calculus operations to the Julia/SciML ecosystem.

---

## Phase 1: Rule Engine Foundation 🏗️ *(In Progress)*
**Goal:** Establish a robust translation layer between OSR JSON patterns and Julia's `SymbolicUtils.jl`.

- [ ] **Domain modules:** Split the public API into a small `Core` module and
  opt-in `Algebra`, `Calculus`, `Trigonometry`, `Integration`, and `Logic`
  modules. Each module shall export only its OpenMath heads, profile loader,
  and domain-specific operations. `Integration` covers indefinite and defined
  integrals and can orchestrate rule profiles with procedural backends such as
  Risch-family methods; it is deliberately broader than a single `Integral`
  constructor.
- [x] Basic parsing of OSR JSON into Julia AST.
- [~] **OpenMath Interoperability:** An optional `OpenMath.jl` extension now
  converts core arithmetic, propositional logic, and canonical
  lambda-bound derivatives, canonical limits, piecewise expressions, and
  structural lists OSR/SymbolicUtils expressions, including exact rationals,
  to and from typed OpenMath objects.
  Use its Content Dictionary registry, validation, canonicalisation, and
  XML/JSON/MathML/binary encodings at import and export boundaries. Keep
  OpenMath optional and outside rewriting hot paths; OSR rule identities,
  constraints, provenance, and execution semantics remain owned by this
  package. Extend the bridge next to integrals, matrices, tensors, and explicit
  sort information.
- [x] `@load_osr` macro for Ahead-Of-Time (AOT) rule compilation.
- [x] Mapping of primitive constraints (e.g., `is_integer`) to Julia `where` clauses.
- [x] **Advanced Predicates Mapping:** A standard library of Julia predicates for the OSR constraint vocabulary — comparison, integer-qualified, numeric-domain, structural, and polynomial predicates plus the `Not`/`And`/`Or`/`If` combinators — covering 97% of the constraint applications in the RUBI dataset, and 92.6% of its rules use no other predicate.
- [ ] **RUBI-specific Predicates:** Implement the remaining catalogue needed by the full 6000-rule dataset (`MatchQ` and the `*MatchQ` family, `BinomialQ`, `TrinomialQ`, `SumSimplerQ`, the `FunctionOf*` family, and the `Known*IntegrandQ` heuristics).
- [~] **Rule Precompilation:** Optimize the macro to handle thousands of rules (like RUBI) without blowing up Julia's compile time (e.g., splitting into sub-modules or using `PrecompileTools.jl`). A `PrecompileTools.jl` workload now covers the rewriting paths, roughly halving the time to a first `simplify`. The macro itself has now been measured against the real corpus: one `@load_osr` per rule file is linear at about 62 ms per rule with flat memory, whereas one `@load_osr_profile` over the whole manifest did not finish in 50 minutes. Splitting the profile macro per manifest entry is the remaining work.

## Phase 2: Core Algebra & Expression Engine 🧮
**Goal:** Build the CAS front-end and fundamental algebraic simplification engine.

- [x] **AST Interoperability:** Ensure seamless compatibility with `Symbolics.jl` variables (`@variables`) and `Term` structures.
- [x] **Algebraic Simplifier:** Provide `simplify(expr, rules)` for rules loaded from the `OpenSymbolicRules/Algebra` repositories.
- [x] **AC-Matching (Associative-Commutative):** Upgrade `@load_osr` to automatically generate `@acrule` for known AC operators (like `Add`, `Mul`), avoiding combinatoric explosion of rules.
- [ ] **Remote Rule Syncing:** Implement an Artifact or Pkg based mechanism to automatically download the latest version of the OSR specifications from GitHub.
- [ ] **Canonical expression form and rendering:** Define a deterministic
  normalization and pretty-printing layer shared by OSR and Symbolics terms.
  It must preserve required parentheses while removing redundant ones,
  normalize rational unit values such as `1//1` to integer `1` where sound,
  and eliminate superfluous unary-minus forms without changing precedence,
  associativity, domains, or noncommutative factor order. Add round-trip and
  regression tests for parsing, display, simplification, and proof traces.
- [ ] **Operation result status:** Make high-level operations distinguish a
  proved closed form, a conditional result, an unevaluated symbolic operation,
  an inapplicable operation, and divergence. An unknown result must never be
  rendered as a proved equality.
- [ ] **Ergonomic CAS API:** Provide high-level constructors such as
  `limit(expression, variable, point; direction)`, `differentiate`,
  `integrate`, and `solve` with an expression-first argument order. They must
  immediately normalize to the single canonical OSR/OpenMath representation;
  do not introduce a second expression tree, duplicated semantics, or a
  persistent adaptation layer.
- [ ] **Unified operation architecture:** Refactor CAS services around a common
  `Problem` / `Capability` / `Strategy` / `Result` / `Trace` contract. Solving,
  simplification, normalization, proving, integration, limits, transforms, and
  series must accept an explicit semantic context and resource limits, select
  only compatible strategies, and return structured `proved`, `conditional`,
  `unevaluated`, `unknown`, or `contradiction` outcomes. A result records its
  method, backend, version, assumptions, rule identities, diagnostics, model
  or certificate, and reproducible limits. The same capability registry shall
  describe exact domains, algebraic structures, logical theories, matrices,
  tensors, units, and external adapters.
- [ ] **Specialised normal-form operations:** Build domain-scoped operations
  with explicit domains, assumptions, result statuses, and testable normal-form
  contracts. Algebra needs `expand`, `collect_terms` (rather than the
  conflicting `Base.collect`), `factor`, `cancel`, `together`, `apart`,
  `numerator`, `denominator`, coefficients, degrees, leading terms, content,
  primitive parts, gcds, and resultants. Trigonometry and elementary functions
  need `expand_trig`, `factor_trig`, `simplify_trig`, logarithm/power expansion
  and combination, and controlled `rewrite(expression, target_form)`. Calculus
  needs series and residues in addition to differentiation, integration, and
  limits. Logic needs CNF, DNF, NNF, Boolean simplification, and eventually
  quantifier elimination. Matrix and tensor variants must wait for the
  shape- and index-aware model. An operation may report `unchanged` or
  `unevaluated`; it must never claim an unavailable normal form.
- [ ] **Exactness and canonical constants:** Treat exactness as an invariant of
  every symbolic transformation. Never introduce floating-point approximations
  implicitly when an exact rational, algebraic expression, irrational constant
  such as `π`, or symbolic term is available. Canonicalise exact constants and
  periodic coefficients without evaluating them numerically.
- [~] **Semantic constant registry:** The OpenMath bridge preserves `π`, `e`,
  and `i` as `nums1#pi`, `nums1#e`, and `complex1#i`. Define the remaining
  constants by stable Content Dictionary identity rather than host-language
  spelling: for example `nums1#infinity`. Keep integers and rationals as exact
  literals, represent algebraic values structurally (for example a square root
  rather than an opaque `sqrt2` constant), and mark every floating approximation
  with its precision. Domain-specific constants must declare their CD symbol,
  sort, exactness, optional unit/value reference, version, and provenance.
  Export/import must never silently turn a named exact constant into `Float64`.
- [ ] **Declarative variable domains:** Let variables carry optional, explicit
  domain facts such as scalar sort, real/complex domain, intervals, sign,
  nonzero status, units, and dimensions. Merge these facts into the existing
  assumption context with provenance and an explicit `unknown` outcome rather
  than treating metadata as an unconditional rewrite licence.
- [ ] **Expression-protocol boundary:** Validate the expression adapter used at
  the SymbolicUtils/TermInterface boundary: applications must expose a complete
  operation-and-arguments interface, and literals, variables, applications,
  and collections must remain distinguishable. Keep OSR's own semantic
  classification independent of host representation accidents.

## Phase 3: Calculus & The RUBI Integration Challenge 🚀
**Goal:** Achieve state-of-the-art symbolic integration and calculus features.

- [ ] **Limits & Derivatives:** Implement `Limit(expr, x, a)` and `Derivative(expr, x)` using the `OpenSymbolicRules/Calculus` specifications.
- [~] **The RUBI Milestone:** Successfully parse and load the 6000+ RUBI
  integration rules. Measured against the 6257 rules in 188 rule files of the
  `Integration` repository, the three blockers previously recorded here were
  partly misdiagnosed; the current state is:
    - *Optional wildcards.* **Resolved.** 36,485 operands are spelled `a.`, as
      in `(a. + b.*x)^m.`. Every one of them sits under `Add`, `Multiply`, or
      the exponent of `Power`, no node carries more than one, and none declares
      an explicit default, so the enclosing operation always supplies the
      identity element. The loader now emits a `SymbolicUtils` `DefSlot`, which
      lifted rule compilation from 41 rules to all 6257.
    - *Complete `semantics` declarations.* **Mostly resolved.** No operator in
      any `pattern` or `result` is undeclared. What the validator was flagging
      was the structural head `List`, the guarded-pattern head `Condition`,
      wildcards in operator position, and constraint predicates reached through
      `Condition` — none of which is domain vocabulary. Exempting them raised
      semantic validation from 13 to 151 of the 188 files. The remaining 37
      fail on RUBI utility heads (`Coeff`, `Expon`, `Simplify`, `Denominator`,
      …) that the converter declares in some files and omits in others: an
      `Integration` converter gap, not a specification gap. The `osr` Content
      Dictionary namespace the converter already emits (`openmath:osr#Coeff`)
      answers the question of how to name a RUBI-specific utility.
    - *Globally stable rule identities.* **Not a data problem.** 116 `section:id`
      pairs collide, but the file-level `identity` field distinguishes every one
      of them, and both the loader and the identity validator already key on it.
    - *Remaining.* Execution, not loading: the rules that call an unimplemented
      RUBI predicate (`MatchQ`, `BinomialQ`, the `FunctionOf*` family) resolve
      it in the loading module and fail when tried. 92.6% of rules use only
      predicates this package already implements.
- [x] **Heuristic Rule Dispatcher:** `SymbolicUtils.jl` evaluates rules sequentially. For 6000+ rules, a naive `Chain` is too slow. `OSRDispatch` indexes rules by the operation their pattern requires at the root of a term, selecting candidates with a single dictionary lookup. A deeper index, or `Metatheory.jl` e-graphs, remains an option if root dispatch stops being selective enough.
- [~] **Validation Suite:** Run the official RUBI test suite natively in Julia
  to guarantee correctness against Mathematica. `scripts/rubi_conformance.jl`
  (`just conformance <section>`) applies the rule set to every test problem of a
  section and reports `verified`, `closed form`, `unevaluated`, `unchanged`, and
  `error` separately, so coverage is never mistaken for correctness. The first
  measurement, on section 1.1.1 (906 problems, 186 rules):

  | | verified | closed form | unevaluated | unchanged | error |
  | --- | --- | --- | --- | --- | --- |
  | before the conversion fix | 0 | 903 | 0 | 1 | 2 |
  | after | 0 | 23 | 118 | 748 | 17 |

  The first measurement showed the rule set reaching a closed form for 99.7% of
  the section and the recorded antiderivative for none of it. The cause was
  upstream of this package: the conversion dropped RUBI's
  `Int[integrand, x_Symbol]` wrapper and with it both the integration variable
  and the restriction that binds it, so `x^m. => x^(m+1)/(m+1)` matched the
  constant integrand `-2` and returned `(-2)^2/2`. With the wrapper restored in
  the `Integration` repository and a `symbol` typed wildcard in the
  specification, the rule set no longer answers a problem it cannot solve: what
  it does not know it leaves unevaluated or unchanged. Those 903 closed forms
  were wrong answers, not answers the fix lost.

  What remains is coverage. 748 problems are unchanged because only the 186
  rules of section 1.1.1 were loaded; a run over the whole corpus is the next
  measurement. Structural comparison is strict, so `verified` is a lower bound.
- [ ] **Profile loading at scale:** `@load_osr_profile` expands a whole manifest
  into a single expression. For the 6257-rule corpus that did not finish within
  50 minutes at over 2 GiB, while compiling the same rules one file per
  top-level expansion is linear at about 62 ms per rule, or roughly 6.5 minutes
  in total. Split the macro per manifest entry, or cache compiled rules, before
  a full profile can be loaded in one call.

## Phase 4: Formal Proof Engine & Step-by-Step Resolution 🎓
**Goal:** Exploit the purely declarative nature of OSR to provide trackable, formal proofs of equivalence and step-by-step educational solutions.

- [x] **Step-by-Step Output:** Intercept the rule application engine (e.g., via `Metatheory.jl` E-Graphs or a custom `Postwalk` logger) to return a sequential list of all rules applied during a simplification (resolving user needs like Symbolics.jl#703).
- [ ] **Structured operation traces:** Generalize rewrite traces into a
  serializable tree whose nodes record input, output, assumptions, OSR rule
  identity or procedural method, and child steps. Provide minimal, normal, and
  detailed views plus text, LaTeX/MathML, and JSON renderers without emitting
  library output directly.
- [x] **Formal Context & Assumptions:** Implement a rigorous context system (`x ∈ Reals`, `x > 0`) using `task_local_storage` or `DomainSets.jl` so that rules are only applied when formally valid. Each hypothesis is weighed on its own, so the context does not yet combine two hypotheses into a third; that is what SMT delegation in Phase 5 is for.
- [~] **Assumption consistency:** The exact rational SMT layer now detects
  contradictions among supported sign, numeric-bound, and interval-membership
  hypotheses. Nonzero hypotheses now retain their required disjunction through
  DPLL(T), and `simplify` rejects a context proven contradictory. Extend the
  bridge to individual conditional rule dispatch while retaining an explicit
  `unknown` outcome for unsupported facts. Conditional sign and nonzero
  predicates now also combine supported hypotheses through counterexample
  checks.
- [x] **Binders and Capture-Avoiding Substitution:** Complete lexical `Lambda`, quantifier, sum, product, integral, and derivative handling with alpha-renaming and capture-avoiding substitution.
- [x] **Piecewise Expressions:** Represent `Piecewise` branches and their conditions so that real/complex domains, absolute values, roots, and logarithms retain their validity conditions.
- [x] **Equivalence Verifier:** `prove(A, B, rules; assumptions)` and `prove(A ~ B, rules)` search for a rewrite path between A and B and return an `OSRProof`. Joining the two normal forms is sound but incomplete, so a failure reads "not proved" rather than "unequal"; equality saturation would be the way to close that gap.
- [ ] **Proof Assistant Exporter:** Export the generated rewrite traces into formats verifiable by formal assistants like Lean 4 or Coq.

## Phase 5: Equation Solving & Advanced Domains 🔍
**Goal:** Expand the CAS capabilities beyond rewriting into solving and logic.

- [x] **Exact sparse polynomial core:** Provide coefficient-normalized
  multivariate polynomial terms, monomial orders, S-polynomials, and normal
  forms over `Rational{BigInt}` without imposing a private expression tree.
- [x] **Gröbner bases:** Provide Buchberger completion, inter-reduction, and
  ideal-membership checks on the exact polynomial core in pure Julia.
- [x] **Symbolic polynomial boundary:** Convert exact `SymbolicUtils`
  polynomials explicitly to and from the sparse core, rejecting coefficients,
  variables, and operators outside the requested ring.
- [ ] **Polynomial-system solving:** Build elimination and solution-set APIs on
  the exact sparse core without weakening exact-domain guarantees.
- [~] **Polynomial invariants:** Exact univariate resultants, discriminants,
  and square-free decomposition are available over the rational polynomial
  core. Add multivariate invariants and algorithm-independent property tests
  with no mandatory native dependency.
- [~] **Equation Solving:** Exact rational-root extraction is available for
  univariate rational polynomials, exposed through a structured solver result,
  and reachable as `solve(eq, x)`. Add algebraic isolation rules, complete
  solution sets, and explicit exclusions.
- [ ] **Conditional and periodic solution sets:** Represent all solution
  branches, periodic integer-parameter families, exclusions, multiplicities,
  and required assumptions structurally. Solvers must return these conditions
  alongside their solutions, never print them as incidental logging or discard
  valid branches.
- [ ] **Sets, Relations, and Intervals:** Add membership, inclusion, unions, intersections, inequalities, and solution-set expressions as first-class symbolic structures.
- [ ] **Units, Dimensions, and Uncertainties:** Track physical dimensions as semantic properties of expressions, rejecting dimensionally invalid rewrites. Build a `DynamicQuantities.jl` integration first, aligned with `SymbolicUncertainties.jl`, so values and their uncertainty terms retain compatible dimensions; provide `Unitful.jl` interoperability at the boundary rather than duplicating dimensional semantics.
- [ ] **Trigonometry & Special Functions:** Integrate standard rules for Bessel functions, Gamma, Hypergeometric, etc.
- [~] **Exact algebraic constants:** Bounded exact normalization now extracts
  perfect-square factors from numeric radicals without floating-point
  conversion. Add algebraic-number domains, higher roots, and conditional
  radical identities next.
- [ ] **Matrix and Tensor Algebra:** Define shape- and index-aware OpenMath-aligned heads for matrix multiplication, tensor products, contractions, and axis permutations. Preserve operand order by default; allow commutativity only when scalarity or compatible additive structure is established.
- [ ] **Noncommutative Algebra:** Model operator composition, Lie products, and quantum-style noncommutative multiplication separately from scalar arithmetic.
- [ ] **Sequences and Discrete Operators:** Add indexed sequences, finite/infinite sums and products, recurrences, and finite differences.
- [ ] **Distributions and Generalized Functions:** Add domain-safe representations for Dirac, Heaviside, and probability distributions.
- [ ] **Parameterized Algebraic Structures:** Carry the coefficient domain (for example `ℤ`, `ℚ`, `ℝ`, `ℂ`, finite fields, rings, and modules) required to validate polynomial and linear-algebra rules.
- [~] **Pure-Julia SMT foundation:** A DPLL SAT kernel now decides
  propositional CNF without external solvers, and an exact rational
  Fourier--Motzkin theory solver decides conjunctions of linear constraints;
  the two are now connected through DPLL(T). Add equality propagation,
  and checkable proof evidence. Ground equality propagation is now available
  through union-find; integrate shared terms between equality and arithmetic
  theories before accepting mixed-sort problems. Negated equalities are now
  encoded as their exact strict-order alternatives. Satisfiable Boolean cores
  and rational linear theory now return checkable models; add model production
  for combined theories and unsatisfiable certificates next. Linear DPLL(T)
  now returns combined Boolean/rational models and equality DPLL(T) returns
  Boolean/equivalence-class models. Rational-variable equality and arithmetic
  now combine through an explicit numeric-sorted entry point and structured
  CommonSolve results; retain the uninterpreted equality theory separately.
  Add unsatisfiable certificates next. The default engine shall remain pure Julia with no native solver
  dependency.
  Interoperability with SMT-LIB and explicit adapters to external solvers may
  be added later, but must remain opt-in and never change the result status or
  proof obligations silently.
- [ ] **SciML Integration:** Register the CAS as a backend for `ModelingToolkit.jl` and `DifferentialEquations.jl` to simplify massive ODE/PDE systems before numerical compilation.

---

## Technical Challenges & Mitigations
> [!WARNING]
> Loading 6000 rules via macros can crash the Julia compiler or lead to unacceptable loading times. 

* **Mitigation 1:** Use `RuntimeGeneratedFunctions.jl` or cache rule graphs on disk.
* **Mitigation 2:** Infinite Loops in Rewriting. AC rules can sometimes cycle. Implement strict term-ordering (e.g., Lexicographic) for commutative rules to guarantee termination; never infer commutativity for matrix multiplication, tensor products, contractions, or axis permutations.
