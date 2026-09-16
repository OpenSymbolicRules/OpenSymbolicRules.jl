# OpenSymbolicRules.jl - Development Roadmap

**Vision:** To evolve `OpenSymbolicRules.jl` from a simple rule-parser into a fully-fledged, general-purpose Computer Algebra System (CAS) in Julia. It will serve as the premier execution engine for the universal OpenSymbolicRules standard, bringing the power of 6000+ RUBI integration rules, algebraic simplifications, and calculus operations to the Julia/SciML ecosystem.

---

## Phase 1: Rule Engine Foundation 🏗️ *(In Progress)*
**Goal:** Establish a robust translation layer between OSR JSON patterns and Julia's `SymbolicUtils.jl`.

- [x] Basic parsing of OSR JSON into Julia AST.
- [x] `@load_osr` macro for Ahead-Of-Time (AOT) rule compilation.
- [x] Mapping of primitive constraints (e.g., `is_integer`) to Julia `where` clauses.
- [ ] **Advanced Predicates Mapping:** Implement a comprehensive standard library of Julia predicates mapping exactly to the OpenMath/OSR constraints (e.g., `FreeQ`, `MatchQ`, `PolynomialQ`).
- [ ] **Rule Precompilation:** Optimize the macro to handle thousands of rules (like RUBI) without blowing up Julia's compile time (e.g., splitting into sub-modules or using `PrecompileTools.jl`).

## Phase 2: Core Algebra & Expression Engine 🧮
**Goal:** Build the CAS front-end and fundamental algebraic simplification engine.

- [ ] **AST Interoperability:** Ensure seamless compatibility with `Symbolics.jl` variables (`@variables`) and `Term` structures.
- [ ] **Algebraic Simplifier:** Implement `osr_simplify(expr)` powered exclusively by the `OpenSymbolicRules/Algebra` repositories.
- [ ] **AC-Matching (Associative-Commutative):** Upgrade `@load_osr` to automatically generate `@acrule` for known AC operators (like `Add`, `Mul`), avoiding combinatoric explosion of rules.
- [ ] **Remote Rule Syncing:** Implement an Artifact or Pkg based mechanism to automatically download the latest version of the OSR specifications from GitHub.

## Phase 3: Calculus & The RUBI Integration Challenge 🚀
**Goal:** Achieve state-of-the-art symbolic integration and calculus features.

- [ ] **Limits & Derivatives:** Implement `Limit(expr, x, a)` and `Derivative(expr, x)` using the `OpenSymbolicRules/Calculus` specifications.
- [ ] **The RUBI Milestone:** Successfully parse and load the 6000+ RUBI integration rules.
- [ ] **Heuristic Rule Dispatcher:** `SymbolicUtils.jl` evaluates rules sequentially. For 6000+ rules, a naive `Chain` is too slow. Implement a Decision Tree or leverage `Metatheory.jl` (e-graphs) for $O(1)$ or $O(\log N)$ rule application.
- [ ] **Validation Suite:** Run the official RUBI test suite natively in Julia to guarantee correctness against Mathematica.

## Phase 4: Formal Proof Engine & Step-by-Step Resolution 🎓
**Goal:** Exploit the purely declarative nature of OSR to provide trackable, formal proofs of equivalence and step-by-step educational solutions.

- [ ] **Step-by-Step Output:** Intercept the rule application engine (e.g., via `Metatheory.jl` E-Graphs or a custom `Postwalk` logger) to return a sequential list of all rules applied during a simplification (resolving user needs like Symbolics.jl#703).
- [ ] **Formal Context & Assumptions:** Implement a rigorous context system (`x ∈ Reals`, `x > 0`) using `task_local_storage` or `DomainSets.jl` so that rules are only applied when formally valid.
- [ ] **Equivalence Verifier:** Build an API `prove(A == B, context)` that searches for a valid rewrite path between A and B and returns the formal proof.
- [ ] **Proof Assistant Exporter:** Export the generated rewrite traces into formats verifiable by formal assistants like Lean 4 or Coq.

## Phase 5: Equation Solving & Advanced Domains 🔍
**Goal:** Expand the CAS capabilities beyond rewriting into solving and logic.

- [ ] **Equation Solving:** Implement `solve(eq, x)` using OSR algebraic isolation rules.
- [ ] **Trigonometry & Special Functions:** Integrate standard rules for Bessel functions, Gamma, Hypergeometric, etc.
- [ ] **SMT Solver Delegation:** When rules fail or when simplifying boolean constraints, automatically delegate proofs to SMT solvers (Z3, CVC5) via Julia wrappers.
- [ ] **SciML Integration:** Register the CAS as a backend for `ModelingToolkit.jl` and `DifferentialEquations.jl` to simplify massive ODE/PDE systems before numerical compilation.

---

## Technical Challenges & Mitigations
> [!WARNING]
> Loading 6000 rules via macros can crash the Julia compiler or lead to unacceptable loading times. 

* **Mitigation 1:** Use `RuntimeGeneratedFunctions.jl` or cache rule graphs on disk.
* **Mitigation 2:** Infinite Loops in Rewriting. AC rules can sometimes cycle. Implement strict term-ordering (e.g., Lexicographic) for commutative rules to guarantee termination.
