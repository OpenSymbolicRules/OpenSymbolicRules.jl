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
- [x] `@load_osr` macro for Ahead-Of-Time (AOT) rule compilation.
- [x] Mapping of primitive constraints (e.g., `is_integer`) to Julia `where` clauses.
- [x] **Advanced Predicates Mapping:** A standard library of Julia predicates for the OSR constraint vocabulary — comparison, integer-qualified, numeric-domain, structural, and polynomial predicates plus the `Not`/`And`/`Or` combinators — covering 97% of the constraint applications in the RUBI dataset.
- [ ] **RUBI-specific Predicates:** Implement the remaining catalogue needed by the full 6000-rule dataset (`MatchQ` and the `*MatchQ` family, `BinomialQ`, `TrinomialQ`, `SumSimplerQ`, the `FunctionOf*` family, and the `Known*IntegrandQ` heuristics).
- [ ] **Rule Precompilation:** Optimize the macro to handle thousands of rules (like RUBI) without blowing up Julia's compile time (e.g., splitting into sub-modules or using `PrecompileTools.jl`). A `PrecompileTools.jl` workload now covers the rewriting paths, roughly halving the time to a first `simplify`. What remains is the macro itself: `@load_osr` emits one `@rule` per rule, and expanding thousands of them in one module has not been measured against a real RUBI profile because the dataset does not load yet.

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

## Phase 3: Calculus & The RUBI Integration Challenge 🚀
**Goal:** Achieve state-of-the-art symbolic integration and calculus features.

- [ ] **Limits & Derivatives:** Implement `Limit(expr, x, a)` and `Derivative(expr, x)` using the `OpenSymbolicRules/Calculus` specifications.
- [ ] **The RUBI Milestone:** Successfully parse and load the 6000+ RUBI integration rules. Three blockers remain, measured against the converted dataset in the `Integration` repository:
    - *Globally stable rule identities.* The Integration data currently has
      119 duplicated `section:id` identities (for example, two leaf files share
      section `1.1.2` and rule IDs `1`--`3`). The data must distinguish leaf
      sections or IDs rather than weakening proof and trace identities.
    - *Complete `semantics` declarations.* The rules use 146 distinct operators and declare 6. The schema's `openmath:<cd>#<symbol>` pattern also cannot express a RUBI-specific utility such as `Simp`, `Dist`, or `Rt`, so the specification needs a decision before the converter can emit a complete block.
    - *Optional wildcards.* 36,485 operands are spelled `a.`, as in `(a_. + b_.*x_)^m_`. Matching one needs the identity element of the enclosing operation, which `SymbolicUtils` supplies only for the native `+`, `*`, and `^`. The loader currently rejects them with a diagnostic.
- [x] **Heuristic Rule Dispatcher:** `SymbolicUtils.jl` evaluates rules sequentially. For 6000+ rules, a naive `Chain` is too slow. `OSRDispatch` indexes rules by the operation their pattern requires at the root of a term, selecting candidates with a single dictionary lookup. A deeper index, or `Metatheory.jl` e-graphs, remains an option if root dispatch stops being selective enough.
- [ ] **Validation Suite:** Run the official RUBI test suite natively in Julia to guarantee correctness against Mathematica.

## Phase 4: Formal Proof Engine & Step-by-Step Resolution 🎓
**Goal:** Exploit the purely declarative nature of OSR to provide trackable, formal proofs of equivalence and step-by-step educational solutions.

- [x] **Step-by-Step Output:** Intercept the rule application engine (e.g., via `Metatheory.jl` E-Graphs or a custom `Postwalk` logger) to return a sequential list of all rules applied during a simplification (resolving user needs like Symbolics.jl#703).
- [ ] **Structured operation traces:** Generalize rewrite traces into a
  serializable tree whose nodes record input, output, assumptions, OSR rule
  identity or procedural method, and child steps. Provide minimal, normal, and
  detailed views plus text, LaTeX/MathML, and JSON renderers without emitting
  library output directly.
- [x] **Formal Context & Assumptions:** Implement a rigorous context system (`x ∈ Reals`, `x > 0`) using `task_local_storage` or `DomainSets.jl` so that rules are only applied when formally valid. Each hypothesis is weighed on its own, so the context does not yet combine two hypotheses into a third; that is what SMT delegation in Phase 5 is for.
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
- [ ] **Equation Solving:** Implement `solve(eq, x)` using OSR algebraic isolation rules.
- [ ] **Sets, Relations, and Intervals:** Add membership, inclusion, unions, intersections, inequalities, and solution-set expressions as first-class symbolic structures.
- [ ] **Units, Dimensions, and Uncertainties:** Track physical dimensions as semantic properties of expressions, rejecting dimensionally invalid rewrites. Build a `DynamicQuantities.jl` integration first, aligned with `SymbolicUncertainties.jl`, so values and their uncertainty terms retain compatible dimensions; provide `Unitful.jl` interoperability at the boundary rather than duplicating dimensional semantics.
- [ ] **Trigonometry & Special Functions:** Integrate standard rules for Bessel functions, Gamma, Hypergeometric, etc.
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
  encoded as their exact strict-order alternatives. The default engine shall
  remain pure Julia with no native solver dependency.
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
